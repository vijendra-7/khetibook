import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/crop_price.dart';
import '../utils/crop_translation_utils.dart';
import '../utils/apmc_category_utils.dart';
import 'package:path_provider/path_provider.dart';

class GondalApmcService {
  static String _translateGuToEn(String guName) {
    const customMap = {
      'કપાસ': 'cotton',
      'ઘઉં લોકવન': 'wheat lokwan',
      'ઘઉં ટુકડા': 'wheat tukda',
      'મગફળી જીણી': 'groundnut small',
      'મગફળી જાડી': 'groundnut bold',
      'સિંગદાણા જાડા': 'groundnut bold',
      'સિંગ ફાડીયા': 'groundnut splits',
      'એરંડા / એરંડી': 'castor',
      'એરંડા': 'castor',
      'તલ લાલ': 'til red',
      'તલ કાળા': 'til black',
      'તલ સફેદ': 'til white',
      'જીરૂ': 'cumin',
      'જીરું': 'cumin',
      'ક્લંજી': 'kalonji',
      'ધાણા': 'coriander',
      'લસણ સુકું': 'garlic',
      'ડુંગળી લાલ': 'onion red',
      'ડુંગળી સફેદ': 'onion white',
      'અડદ': 'urad',
      'ટમેટા': 'tomato',
      'મરચા': 'chilli',
      'ગુવાર': 'guwar',
      'કોબી': 'cabbage',
      'કોબીજ': 'cabbage',
      'દુધી': 'dudhi',
      'ફલાવર': 'cauliflower',
      'કાકડી': 'cucumber',
      'રીંગણા': 'brinjal',
      'રીંગણ': 'brinjal',
      'ભીંડો': 'okra',
      'ભીંડા': 'okra',
      'ગલકા': 'turiya',
      'ગાજર': 'carrot',
      'ટિંડોરા': 'tindora',
      'વટાણા': 'peas',
      'કેરી કાચી': 'mango raw',
      'બદામ કેરી': 'mango badam',
      'હાફુસ કેરી': 'mango hafusa',
      'કેસર કેરી': 'mango kesar',
      'દાડમ': 'pomegranate',
      'સફરજન': 'apple',
      'કેળા': 'banana',
      'ક્મલમ': 'dragon_fruit',
      'લિચી': 'litchi',
      'ઓરેંજ': 'orange',
      'દ્રાક્ષ': 'grapes',
      'કીવી': 'kiwi',
      'વરીયાળી': 'variyali',
      'વરિયાળી': 'variyali',
      'મેથી': 'methi',
      'બાજરી': 'bajra',
      'તુવેર': 'tuver',
      'ચણા': 'chana',
      'મગ': 'mung',
      'મકાઈ': 'maize',
      'અજમો': 'ajmo',
      'સુવા': 'suva',
      'સોયાબીન': 'soybean',
      'બીટ': 'beetroot',
      'પાલક': 'spinach',
      'આદુ': 'adu',
      'હળદર': 'halder',
      'આમળા': 'amla',
      'તરબૂચ': 'watermelon',
      'ચીકુ': 'chiku',
      'સરગવો': 'drumstick',
      'સીતાફળ': 'custard_apple',
    };
    
    final trimmed = guName.trim();
    if (customMap.containsKey(trimmed)) {
      return customMap[trimmed]!;
    }
    
    // Substring match
    for (var entry in customMap.entries) {
      if (trimmed.contains(entry.key) || entry.key.contains(trimmed)) {
        return entry.value;
      }
    }
    
    for (var entry in CropTranslationUtils.cropTranslations.entries) {
      if (entry.value == trimmed) {
        return entry.key;
      }
    }
    
    return trimmed;
  }

  static Future<List<CropPrice>> fetchPrices({DateTime? date}) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    final List<CropPrice> allPrices = [];
    
    try {
      final markets = [
        {
          'url': 'https://apmcgondal.scmsolution.in/Daily_Rate.aspx',
          'category': ApmcCategory.grains,
          'tableId': '#ctl00_ContentPlaceHolder1_grid_pak'
        },
        {
          'url': 'https://apmcgondal.scmsolution.in/Daily_Rates_Veg.aspx',
          'category': ApmcCategory.vegetables,
          'tableId': '#ctl00_ContentPlaceHolder1_grid_veg'
        },
        {
          'url': 'https://apmcgondal.scmsolution.in/Daily_Rates_Fruits.aspx',
          'category': ApmcCategory.fruits,
          'tableId': '#ctl00_ContentPlaceHolder1_grid_frt'
        }
      ];

      for (var market in markets) {
        final prices = await _fetchSubMarket(client, market['url']!, market['category']!, market['tableId']!, date);
        allPrices.addAll(prices);
      }
      
      return allPrices;
    } catch (e) {
      debugPrint('Gondal Scraper Error: $e');
      return [];
    } finally {
      client.close();
    }
  }

  static Future<List<CropPrice>> _fetchSubMarket(
      HttpClient client, String url, String category, String tableId, DateTime? targetDate) async {
    try {
      // 1. GET Request
      final getRequest = await client.getUrl(Uri.parse(url));
      getRequest.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final getResponse = await getRequest.close().timeout(const Duration(seconds: 15));
      if (getResponse.statusCode != 200) return [];
      
      var html = await getResponse.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      
      if (targetDate != null) {
        final document = parser.parse(html);
        final viewstate = document.querySelector('#__VIEWSTATE')?.attributes['value'] ?? '';
        final generator = document.querySelector('#__VIEWSTATEGENERATOR')?.attributes['value'] ?? '';
        final validation = document.querySelector('#__EVENTVALIDATION')?.attributes['value'] ?? '';
        final btnVal = document.querySelector('#ctl00_ContentPlaceHolder1_btn_show')?.attributes['value'] ?? 'ભાવ જોવો';
        final currentInputDate = document.querySelector('#ctl00_ContentPlaceHolder1_txt_date')?.attributes['value'] ?? '';
        
        final dateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
        
        if (currentInputDate != dateStr && viewstate.isNotEmpty) {
          // Perform POST
          final postRequest = await client.postUrl(Uri.parse(url));
          postRequest.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
          postRequest.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
          
          final body = {
            '__VIEWSTATE': viewstate,
            '__VIEWSTATEGENERATOR': generator,
            '__EVENTVALIDATION': validation,
            'ctl00\$ContentPlaceHolder1\$txt_date': dateStr,
            'ctl00\$ContentPlaceHolder1\$btn_show': btnVal,
          };
          
          final bodyStr = body.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
          postRequest.write(bodyStr);
          
          final postResponse = await postRequest.close().timeout(const Duration(seconds: 15));
          if (postResponse.statusCode == 200) {
            html = await postResponse.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
          }
        }
      }
      
      // Parse HTML
      final document = parser.parse(html);
      
      // Parse date from txt_date input or document
      final dateInputVal = document.querySelector('#ctl00_ContentPlaceHolder1_txt_date')?.attributes['value'] ?? '';
      String formattedDate = '';
      if (dateInputVal.isNotEmpty && dateInputVal.contains('-')) {
        // YYYY-MM-DD -> DD Mon YYYY
        final parts = dateInputVal.split('-');
        if (parts.length == 3) {
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final monthIdx = int.tryParse(parts[1]);
          if (monthIdx != null && monthIdx >= 1 && monthIdx <= 12) {
            final day = int.tryParse(parts[2])?.toString() ?? parts[2];
            formattedDate = '$day ${months[monthIdx - 1]} ${parts[0]}';
          }
        }
      }
      if (formattedDate.isEmpty) {
        // Fallback to targetDate or current date
        final d = targetDate ?? DateTime.now();
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        formattedDate = '${d.day} ${months[d.month - 1]} ${d.year}';
      }
      
      final table = document.querySelector(tableId);
      if (table == null) return [];
      
      final rows = table.querySelectorAll('tr');
      final List<CropPrice> prices = [];
      
      for (var i = 1; i < rows.length; i++) {
        final tds = rows[i].querySelectorAll('td');
        if (tds.length >= 4) {
          final guName = tds[1].text.trim();
          final min = tds[2].text.trim();
          final max = tds[3].text.trim();
          
          if (guName.isNotEmpty && (min != '0' || max != '0')) {
            final enName = _translateGuToEn(guName);
            prices.add(CropPrice(
              name: enName.toLowerCase(),
              minPrice: min,
              maxPrice: max,
              date: formattedDate,
              gujaratiName: guName,
              yardName: category,
              variety: '',
            ));
          }
        }
      }
      return prices;
    } catch (e) {
      debugPrint('Gondal _fetchSubMarket Error ($url): $e');
      return [];
    }
  }

  static Future<String?> downloadGondalPdf(DateTime? targetDate) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    try {
      final url = Uri.parse('https://apmcgondal.scmsolution.in/Daily_Rate.aspx');
      final getRequest = await client.getUrl(url);
      getRequest.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      final getResponse = await getRequest.close().timeout(const Duration(seconds: 15));
      if (getResponse.statusCode != 200) return null;
      
      final html = await getResponse.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      final document = parser.parse(html);
      
      final viewstate = document.querySelector('#__VIEWSTATE')?.attributes['value'] ?? '';
      final generator = document.querySelector('#__VIEWSTATEGENERATOR')?.attributes['value'] ?? '';
      final validation = document.querySelector('#__EVENTVALIDATION')?.attributes['value'] ?? '';
      final btnVal = document.querySelector('#ctl00_ContentPlaceHolder1_btn_pdf_guj')?.attributes['value'] ?? 'Gujrati';
      
      final d = targetDate ?? DateTime.now();
      final dateStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      
      final postRequest = await client.postUrl(url);
      postRequest.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      postRequest.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
      
      final body = {
        '__VIEWSTATE': viewstate,
        '__VIEWSTATEGENERATOR': generator,
        '__EVENTVALIDATION': validation,
        'ctl00\$ContentPlaceHolder1\$txt_date': dateStr,
        'ctl00\$ContentPlaceHolder1\$btn_pdf_guj': btnVal,
      };
      
      final bodyStr = body.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
      postRequest.write(bodyStr);
      
      final postResponse = await postRequest.close().timeout(const Duration(seconds: 30));
      if (postResponse.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(postResponse);
        if (bytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/gondal_rates_$dateStr.pdf';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          return filePath;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Gondal PDF Download Error: $e');
      return null;
    } finally {
      client.close();
    }
  }
}
