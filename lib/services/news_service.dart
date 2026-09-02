import 'dart:io';
import 'dart:convert';
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news.dart';

class NewsService {
  static const String gujaratiRSS = 
      'https://news.google.com/rss/search?q=%E0%AA%96%E0%AB%87%E0%AA%A4%E0%AB%80&hl=gu&gl=IN&ceid=IN:gu';
  
  static const String hindiRSS = 
      'https://news.google.com/rss/search?q=%E0%A4%95%E0%A5%83%E0%A4%B7%E0%A4%BF+%E0%A4%B8%E0%A4%AE%E0%A4%BE%E0%A4%9A%E0%A4%BE%E0%A4%B0&hl=hi&gl=IN&ceid=IN:hi';

  // Public so NewsProvider can read cache directly for stale-while-revalidate
  static const String cacheKeyGujarati = 'news_cache_gujarati';
  static const String cacheKeyHindi = 'news_cache_hindi';
  static const String _cacheTimeKeyGujarati = 'news_cache_time_gujarati';
  static const String _cacheTimeKeyHindi = 'news_cache_time_hindi';
  
  // Cache expires in 1 hour
  static const Duration _cacheDuration = Duration(hours: 1);

  static Future<List<News>> fetchHindiNews({bool forceRefresh = false}) async {
    return _fetchWithCache(hindiRSS, cacheKeyHindi, _cacheTimeKeyHindi, forceRefresh);
  }

  static Future<List<News>> fetchGujaratiNews({bool forceRefresh = false}) async {
    return _fetchWithCache(gujaratiRSS, cacheKeyGujarati, _cacheTimeKeyGujarati, forceRefresh);
  }

  static Future<List<News>> _fetchWithCache(String url, String cacheKey, String timeKey, bool forceRefresh) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!forceRefresh) {
      final cachedJson = prefs.getString(cacheKey);
      final cachedTimeUnix = prefs.getInt(timeKey);
      
      if (cachedJson != null && cachedTimeUnix != null) {
        final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedTimeUnix);
        final now = DateTime.now();
        
        if (now.difference(cachedTime) < _cacheDuration) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedJson);
            return decoded.map((item) => News.fromJson(item)).toList();
          } catch (e) {
            // If decoding fails, proceed to fetch fresh
          }
        }
      }
    }

    final freshNews = await _fetchFromRSS(url);
    if (freshNews.isNotEmpty) {
      await prefs.setString(cacheKey, jsonEncode(freshNews.map((e) => e.toJson()).toList()));
      await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
    } else {
       // If fetch failed but we have cache (even if expired), return it as fallback
       final cachedJson = prefs.getString(cacheKey);
       if (cachedJson != null) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedJson);
            return decoded.map((item) => News.fromJson(item)).toList();
          } catch (e) {}
       }
    }
    
    return freshNews;
  }

  static Future<List<News>> _fetchFromRSS(String url) async {
    try {
      var client = HttpClient();
      var request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      var response = await request.close();
      if (response.statusCode != 200) return [];

      var responseBody = await response.transform(utf8.decoder).join();
      var document = XmlDocument.parse(responseBody);
      var items = document.findAllElements('item');
      
      List<News> newsList = [];
      for (var item in items) {
        String title = item.getElement('title')?.innerText ?? '';
        String link = item.getElement('link')?.innerText ?? '';
        String pubDateStr = item.getElement('pubDate')?.innerText ?? '';
        String source = item.getElement('source')?.innerText ?? 'Google News';
        String description = item.getElement('description')?.innerText ?? '';
        
        // Attempt to extract high-quality image URL
        String? imageUrl;
        // 1. Check media:content (Google News standard)
        for (var element in item.descendantElements) {
          if (element.name.local == 'content' && element.getAttribute('url') != null) {
            imageUrl = element.getAttribute('url');
            break;
          }
        }
        
        // 2. Fallback: Parse <img> tag from CDATA description
        if (imageUrl == null || imageUrl.isEmpty) {
          final imgMatch = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(description);
          imageUrl = imgMatch?.group(1);
        }

        // Clean up description (remove HTML tags)
        final cleanDescription = description.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '').trim();
        
        DateTime? pubDate;
        try {
          pubDate = DateFormat("EEE, dd MMM yyyy HH:mm:ss Z").parse(pubDateStr);
        } catch (e) {
          pubDate = DateTime.tryParse(pubDateStr);
        }

        if (title.isNotEmpty && link.isNotEmpty) {
          newsList.add(News(
            title: title.split(' - ').first, // Google News often appends ' - Source' to title
            link: link,
            imageUrl: imageUrl, 
            date: pubDate != null ? DateFormat('dd MMM yyyy').format(pubDate) : '',
            description: cleanDescription.isNotEmpty ? cleanDescription : null,
            source: source,
            pubDate: pubDate,
          ));
        }
      }
      
      return newsList;
    } catch (e) {
      return [];
    }
  }
}
