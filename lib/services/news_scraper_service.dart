import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'dart:convert';

class NewsScraperService {
  static const Map<String, String> _headers = {
    'User-Agent': 'python-requests/2.31.0',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate',
    'Connection': 'keep-alive',
  };

  /// Scrapes OpenGraph metadata from the given article URL.
  static Future<Map<String, String?>> scrapeMetadata(String url) async {
    try {
      String targetUrl = url;

      // 1. Direct Decoding: Bypass Google's redirector entirely if possible
      if (url.contains('news.google.com/rss/articles/')) {
        final directUrl = _decodeGoogleUrl(url);
        if (directUrl != null) {
          targetUrl = directUrl;
          print('DEBUG [NewsScraper]: Decoded direct URL=$targetUrl');
        }
      }

      // 2. Fetch the article page
      var response = await http.get(Uri.parse(targetUrl), headers: _headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        return {};
      }

      var finalUrl = response.request?.url.toString() ?? targetUrl;
      var body = response.body;

      // 3. Anti-Google-Splash Logic: (Keep as fallback for non-Base64 links)
      if (finalUrl.contains('google.com') || body.contains('Redirecting') || body.contains('window.google')) {
        final doc = parse(body);
        String? redirectLink = doc.querySelector('a[class*="ytWv9b"]')?.attributes['href'] ?? 
                             doc.querySelector('a')?.attributes['href'];
        
        if (redirectLink != null && redirectLink.startsWith('http')) {
          final res2 = await http.get(Uri.parse(redirectLink), headers: _headers).timeout(const Duration(seconds: 10));
          if (res2.statusCode == 200) {
            body = res2.body;
            finalUrl = res2.request?.url.toString() ?? redirectLink;
          }
        }
      }

      final document = parse(body);
      
      // 4. Extract og:image
      var imageUrl = document.querySelector('meta[property="og:image"]')?.attributes['content'];
      
      if (isJunkImage(imageUrl)) imageUrl = null;
      
      // Fallback: twitter:image
      imageUrl ??= document.querySelector('meta[name="twitter:image"]')?.attributes['content'];
      if (isJunkImage(imageUrl)) imageUrl = null;
      
      // Fallback: search for first large image
      if (imageUrl == null || imageUrl.isEmpty) {
        final images = document.querySelectorAll('img');
        for (var img in images) {
          final src = img.attributes['src'];
          final width = int.tryParse(img.attributes['width'] ?? '0') ?? 0;
          if (src != null && src.startsWith('http') && !isJunkImage(src)) {
            if (width > 200 || src.contains('article') || src.contains('news')) {
              imageUrl = src;
              break;
            }
          }
        }
      }

      // 5. Extract og:description
      String? description = document.querySelector('meta[property="og:description"]')?.attributes['content'];
      description ??= document.querySelector('meta[name="description"]')?.attributes['content'];

      if (imageUrl != null && !imageUrl.startsWith('http')) {
        final uri = Uri.parse(finalUrl);
        if (imageUrl.startsWith('//')) {
          imageUrl = '${uri.scheme}:$imageUrl';
        } else if (imageUrl.startsWith('/')) {
          imageUrl = '${uri.scheme}://${uri.host}$imageUrl';
        }
      }

      print('DEBUG [NewsScraper]: Final Image=$imageUrl');

      return {
        'imageUrl': imageUrl,
        'description': description,
      };
    } catch (e) {
      print('DEBUG [NewsScraper]: Error scraping $url: $e');
      return {};
    }
  }

  /// Decodes a Google News redirect URL to its direct source link.
  static String? _decodeGoogleUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final b64 = uri.pathSegments.last;
      
      // Clean and pad the base64 string
      String cleanB64 = b64.replaceAll('-', '+').replaceAll('_', '/');
      while (cleanB64.length % 4 != 0) {
        cleanB64 += '=';
      }
      
      final List<int> decodedBytes = base64Decode(cleanB64);
      final decodedString = utf8.decode(decodedBytes, allowMalformed: true);
      
      // Regex to find http/https links in the binary blob
      final match = RegExp(r'https?://[^\s\x00-\x1f\x7f-\xff"<>]+').firstMatch(decodedString);
      return match?.group(0);
    } catch (e) {
      return null;
    }
  }

  static bool isJunkImage(String? url) {
    if (url == null || url.isEmpty) return true;
    final lower = url.toLowerCase();
    
    // Blacklist common logo/tracker domains and patterns
    return lower.contains('google.com') ||
           lower.contains('gstatic.com') ||
           lower.contains('googleusercontent.com') ||
           lower.contains('googlesyndication.com') ||
           lower.contains('favicon') ||
           lower.contains('logo') ||
           lower.contains('icon') ||
           lower.contains('pixel') ||
           lower.contains('tracker') ||
           lower.contains('advertisement') ||
           lower.endsWith('.ico');
  }
}
