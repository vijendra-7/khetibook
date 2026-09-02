import 'dart:io';
import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/crop_price.dart';
import '../utils/crop_translation_utils.dart';

class SuratApmcService {
  static Future<List<CropPrice>> fetchPrices({DateTime? date}) async {
    final url = 'https://www.napanta.com/hi/market-price/gujarat/surat/surat';
    final yardName = 'Surat';
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      
      final html = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      final document = parser.parse(html);
      final tables = document.querySelectorAll('table');
      if (tables.isEmpty) return [];
      
      final rows = tables.first.querySelectorAll('tr');
      final List<CropPrice> prices = [];
      
      for (var row in rows) {
        final tds = row.querySelectorAll('td');
        if (tds.length >= 6) {
          final nameRaw = tds[0].text.trim();
          if (nameRaw.isEmpty || nameRaw.toLowerCase().contains('free price alerts')) continue;
          
          final hasExtraCol = tds.length >= 9;
          final variety = tds[hasExtraCol ? 2 : 1].text.trim();
          final max = tds[hasExtraCol ? 3 : 2].text.replaceAll(RegExp(r'[^0-9]'), '').trim();
          final min = tds[hasExtraCol ? 4 : 4].text.replaceAll(RegExp(r'[^0-9]'), '').trim();
          final dateStr = tds[hasExtraCol ? 6 : 5].text.trim();
          
          final cleanName = nameRaw.toLowerCase();
          final combinedName = variety.isNotEmpty && variety.toLowerCase() != 'other' 
              ? '$cleanName ($variety)' 
              : cleanName;
              
          prices.add(CropPrice(
            name: combinedName.toLowerCase(),
            minPrice: min,
            maxPrice: max,
            date: dateStr,
            gujaratiName: CropTranslationUtils.translate(combinedName),
            yardName: yardName,
            variety: '',
          ));
        }
      }
      return prices;
    } catch (e) {
      return [];
    }
  }
}
