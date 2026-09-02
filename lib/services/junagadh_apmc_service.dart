import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/crop_price.dart';
import '../utils/crop_translation_utils.dart';
import '../utils/apmc_category_utils.dart';

class JunagadhApmcService {
  static Future<List<CropPrice>> fetchPrices({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    try {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      
      final mainPageUrl = 'https://apmcjunagadh.org/daily-rates';
      final mainRequest = await client.getUrl(Uri.parse(mainPageUrl));
      mainRequest.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      
      final mainResponse = await mainRequest.close().timeout(const Duration(seconds: 20));
      final mainHtml = await mainResponse.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
      final cookies = mainResponse.cookies;
      
      String? token;
      final jsTokenMatch = RegExp(r'_token:\s*"(.*)"').firstMatch(mainHtml) ?? 
                           RegExp(r"_token:\s*'(.*)'").firstMatch(mainHtml);
      if (jsTokenMatch != null) {
        token = jsTokenMatch.group(1);
      } else {
        final inputTokenMatch = RegExp(r'name="_token"\s+value="([^"]+)"').firstMatch(mainHtml);
        token = inputTokenMatch?.group(1);
      }
      
      if (token == null) {
        debugPrint('Junagadh: CSRF token not found');
        return [];
      }

      final dateStr = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}';
      List<CropPrice> allPrices = [];
      const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formattedDate = '${targetDate.day} ${monthsEn[targetDate.month - 1]} ${targetDate.year}';

      final categoryNames = {
        1: ApmcCategory.grainsAndPulses, 
        2: ApmcCategory.vegetables, 
        3: ApmcCategory.fruits
      };
      
      for (int type in [1, 2, 3]) {
        final uri = Uri.parse('https://apmcjunagadh.org/daily-rates-ajax-list').replace(queryParameters: {
          'date': dateStr,
          'jansi_type': type.toString(),
          '_token': token,
        });
        
        final request = await client.getUrl(uri);
        request.headers.set('X-Requested-With', 'XMLHttpRequest');
        request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        request.headers.set(HttpHeaders.refererHeader, mainPageUrl);
        request.cookies.addAll(cookies);
        
        final response = await request.close().timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) continue;
        
        final htmlContent = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
        if (htmlContent.contains('ડેટા મળ્યો નથી')) continue;
        
        final fragment = parser.parse('<table>$htmlContent</table>');
        final rows = fragment.querySelectorAll('tr');
        
        for (var row in rows) {
          final tds = row.querySelectorAll('td');
          if (tds.length >= 4) {
            final name = tds[1].text.trim();
            final min = tds[2].text.trim();
            final max = tds[3].text.trim();
            
            if (name.isNotEmpty && (min != '0' || max != '0')) {
              allPrices.add(CropPrice(
                name: name,
                minPrice: min,
                maxPrice: max,
                date: formattedDate,
                gujaratiName: CropTranslationUtils.translate(name),
                yardName: categoryNames[type]!,
                variety: '',
              ));
            }
          }
        }
      }
      
      return allPrices;
    } catch (e) {
      debugPrint('Junagadh Error ($date): $e');
      return [];
    }
  }
}
