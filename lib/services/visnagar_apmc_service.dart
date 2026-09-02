import 'dart:io';
import 'dart:convert';
import 'package:html/parser.dart' as parser;
import '../models/crop_price.dart';
import '../utils/crop_translation_utils.dart';

class VisnagarApmcService {
  static String _translateGuToEn(String guName) {
    const customMap = {
      'જીરું': 'cumin',
      'જીરુ': 'cumin',
      'વરીયાળી': 'fennel seeds',
      'વરિયાળી': 'fennel seeds',
      'ઘઉં': 'wheat',
      'બાજરી': 'pearl millet',
      'ગવાર': 'guar seed',
      'રાયડો': 'mustard seed',
      'એરંડા': 'castor seed',
      'મેથી': 'fenugreek',
      'કપાસ': 'cotton',
    };
    
    if (customMap.containsKey(guName)) {
      return customMap[guName]!;
    }
    
    for (var entry in CropTranslationUtils.cropTranslations.entries) {
      if (entry.value == guName) {
        return entry.key;
      }
    }
    
    return guName;
  }

  static Future<List<CropPrice>> fetchPrices({DateTime? date}) async {
    final url = 'https://www.visnagarcity.com/apmc/';
    final yardName = 'Visnagar';
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      
      final html = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      final document = parser.parse(html);
      
      // Parse date
      String dateStr = '';
      final pTags = document.querySelectorAll('p');
      for (var p in pTags) {
        final text = p.text.trim();
        if (text.contains('Last updated Date:')) {
          final match = RegExp(r'Last updated Date:\s*([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{4})').firstMatch(text);
          if (match != null) {
            dateStr = match.group(1)!.replaceAll('-', ' ');
          }
          break;
        }
      }
      
      // Parse table
      final tables = document.querySelectorAll('table.rates');
      if (tables.isEmpty) return [];
      
      final rows = tables.first.querySelectorAll('tr');
      final List<CropPrice> prices = [];
      
      for (var row in rows) {
        final tds = row.querySelectorAll('td');
        if (tds.length >= 3) {
          final guName = tds[0].text.trim();
          if (guName.isEmpty) continue;
          
          final minRaw = tds[1].text.replaceAll(RegExp(r'[^0-9.]'), '').trim();
          final maxRaw = tds[2].text.replaceAll(RegExp(r'[^0-9.]'), '').trim();
          
          final min = double.tryParse(minRaw)?.round().toString() ?? minRaw;
          final max = double.tryParse(maxRaw)?.round().toString() ?? maxRaw;
          
          final enName = _translateGuToEn(guName);
          
          prices.add(CropPrice(
            name: enName.toLowerCase(),
            minPrice: min,
            maxPrice: max,
            date: dateStr,
            gujaratiName: guName,
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
