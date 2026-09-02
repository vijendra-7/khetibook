import 'dart:io';
import 'dart:convert';
import '../models/crop_price.dart';
import '../utils/crop_translation_utils.dart';

class BagasaraApmcService {
  static Future<List<CropPrice>> fetchPrices({DateTime? date}) async {
    final url = 'https://envisiontechnolabs.com/apmc/bagasara-apmc-mandi-bhav';
    final yardName = 'Bagasara';
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set(HttpHeaders.refererHeader, 'https://envisiontechnolabs.com/apmc-mandi-bhav');
      
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      
      final html = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      final regExp = RegExp(r'const encodedData = "(.*?)";');
      final match = regExp.firstMatch(html);
      if (match == null) return [];
      
      final encodedData = match.group(1)!;
      final decodedBytes = base64.decode(encodedData);
      final decodedStr = utf8.decode(decodedBytes);
      final data = jsonDecode(decodedStr);
      
      final dateRaw = (data['date'] ?? '').toString();
      String formattedDate = dateRaw;
      if (dateRaw.contains('-')) {
        final parts = dateRaw.split('-');
        if (parts.length == 3) {
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final monthIdx = int.parse(parts[1]) - 1;
          if (monthIdx >= 0 && monthIdx < 12) {
            formattedDate = '${parts[2]} ${months[monthIdx]} ${parts[0]}';
          }
        }
      }
      
      final items = data['data'] as List?;
      final List<CropPrice> prices = [];
      if (items != null) {
        for (var item in items) {
          final name = (item['name'] ?? '').toString().trim();
          final min = (item['min_price'] ?? '0').toString().trim();
          final max = (item['max_price'] ?? '0').toString().trim();
          if (name.isNotEmpty) {
            prices.add(CropPrice(
              name: name.toLowerCase(),
              minPrice: min,
              maxPrice: max,
              date: formattedDate,
              gujaratiName: CropTranslationUtils.translate(name),
              yardName: yardName,
              variety: '',
            ));
          }
        }
      }
      return prices;
    } catch (e) {
      return [];
    }
  }
}
