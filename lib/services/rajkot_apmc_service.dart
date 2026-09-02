import 'dart:io';
import 'dart:convert';
import '../models/crop_price.dart';
import '../utils/crop_translation_utils.dart';
import '../utils/apmc_category_utils.dart';

class RajkotApmcService {
  static Future<List<CropPrice>> fetchPrices({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final day = targetDate.day.toString().padLeft(2, '0');
    final month = targetDate.month.toString().padLeft(2, '0');
    final year = targetDate.year;
    final dateStr = '$day/$month/$year';
    
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('https://www.apmcrajkot.com/home/get_daily_rates'));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
      request.headers.set('X-Requested-With', 'XMLHttpRequest');
      
      final body = 'date=${Uri.encodeQueryComponent(dateStr)}';
      request.write(body);
      
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      
      final responseBody = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      final data = jsonDecode(responseBody);
      final List<CropPrice> prices = [];
      
      const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formattedDate = '${targetDate.day} ${monthsEn[targetDate.month - 1]} ${targetDate.year}';
      
      if (data is Map) {
        final grains = data['data'] as List?;
        if (grains != null) {
          for (var item in grains) {
            final name = (item['jansi_gujarati_name'] ?? '').toString().trim();
            final min = (item['lowrate'] ?? '0').toString().trim();
            final max = (item['highrate'] ?? '0').toString().trim();
            if (name.isNotEmpty && (min != '0' || max != '0')) {
              prices.add(CropPrice(
                name: name,
                minPrice: min,
                maxPrice: max,
                date: formattedDate,
                gujaratiName: CropTranslationUtils.translate(name),
                yardName: ApmcCategory.grains,
                variety: '',
              ));
            }
          }
        }
        
        final veggies = data['datas'] as List?;
        if (veggies != null) {
          for (var item in veggies) {
            final name = (item['jansi_gujarati_name'] ?? '').toString().trim();
            final min = (item['lowrate'] ?? '0').toString().trim();
            final max = (item['highrate'] ?? '0').toString().trim();
            if (name.isNotEmpty && (min != '0' || max != '0')) {
              prices.add(CropPrice(
                name: name,
                minPrice: min,
                maxPrice: max,
                date: formattedDate,
                gujaratiName: CropTranslationUtils.translate(name),
                yardName: ApmcCategory.vegetables,
                variety: '',
              ));
            }
          }
        }
      }
      return prices;
    } catch (e) {
      return [];
    }
  }
}
