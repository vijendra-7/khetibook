import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../models/crop_price.dart';
import '../utils/crop_translation_utils.dart';
import 'junagadh_apmc_service.dart';
import 'rajkot_apmc_service.dart';
import 'babra_apmc_service.dart';

class CropPriceService {
  static String translate(String englishName) => CropTranslationUtils.translate(englishName);

  static Future<List<CropPrice>> _fetchApmcDeesaPrices(String url) async {
    try {
      var client = HttpClient();
      var request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      var response = await request.close();
      if (response.statusCode != 200) return [];
      
      var responseBody = await response.transform(utf8.decoder).join();
      var document = parser.parse(responseBody);
      List<CropPrice> prices = [];
      
      var boxes = document.querySelectorAll('div.box');
      for (var box in boxes) {
        var h3 = box.querySelector('h3');
        if (h3 == null) continue;
        String yardName = h3.text.trim();
        var table = box.querySelector('table.scroll');
        if (table == null) continue;
        
        String dateString = '';
        var ths = table.querySelectorAll('thead tr th');
        if (ths.isNotEmpty) {
          final rawDate = ths.first.text.trim();
          // Normalize from DD/MM/YYYY to "DD Mon YYYY" (expected by sort logic)
          dateString = _normalizeDDMMYYYY(rawDate);
        }
        
        var rows = table.querySelectorAll('tbody tr');
        for (var row in rows) {
          var tds = row.querySelectorAll('td');
          if (tds.length >= 3) {
            String name = tds[0].text.trim();
            String min = tds[1].text.trim();
            String max = tds[2].text.trim();
            if (name.isNotEmpty) {
              prices.add(CropPrice(
                name: name.toLowerCase().trim(),
                minPrice: min,
                maxPrice: max,
                date: dateString,
                gujaratiName: translate(name),
                yardName: yardName,
                variety: '', // Deesa embeds variety in name
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

  /// Converts "DD/MM/YYYY" → "DD Mon YYYY" so the shared sort logic works.
  /// Returns the original string unchanged if it doesn't match the expected format.
  static String _normalizeDDMMYYYY(String raw) {
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    try {
      final parts = raw.split('/');
      if (parts.length == 3) {
        final day   = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year  = int.parse(parts[2]);
        if (month >= 1 && month <= 12) {
          return '${day.toString().padLeft(2, '0')} ${monthNames[month]} $year';
        }
      }
    } catch (_) {}
    return raw; // pass-through if format is already different
  }

  static Future<List<CropPrice>> _fetchNapantaPrices(String url, String yardName) async {
    try {
      var client = HttpClient();
      var request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      var response = await request.close();
      if (response.statusCode != 200) return [];
      
      var responseBody = await response.transform(utf8.decoder).join();
      var document = parser.parse(responseBody);
      List<CropPrice> prices = [];
      var tables = document.querySelectorAll('table');
      if (tables.isEmpty) return [];
      
      var rows = tables.first.querySelectorAll('tr');
      for (var i = 1; i < rows.length; i++) {
        var tds = rows[i].querySelectorAll('td');
        if (tds.length >= 7) {
          String commodityRaw = tds[0].text.trim();
          String variety = tds[1].text.trim();
          String maxPrice = tds[3].text.replaceAll('₹', '').replaceAll(',', '').trim();
          String minPrice = tds[5].text.replaceAll('₹', '').replaceAll(',', '').trim();
          String arrivalDate = tds[6].text.trim();
          
          String cleanName = commodityRaw.toLowerCase();
          String finalGujaratiName = translate(cleanName);
          
          prices.add(CropPrice(
            name: cleanName,
            minPrice: minPrice,
            maxPrice: maxPrice,
            date: arrivalDate,
            gujaratiName: finalGujaratiName,
            variety: variety,
            yardName: yardName,
          ));
        }
      }
      return prices;
    } catch (e) {
      return [];
    }
  }

  static Future<List<CropPrice>> _fetchKisandealsPrices(String url) async {
    try {
      var client = HttpClient();
      var request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      var response = await request.close();
      if (response.statusCode != 200) return [];
      
      var responseBody = await response.transform(utf8.decoder).join();
      var document = parser.parse(responseBody);
      List<CropPrice> prices = [];
      
      var stateTds = document.querySelectorAll('td[title="राज्य"], td[title="State"]');
      
      if (stateTds.isNotEmpty) {
        for (var stateTd in stateTds) {
          var parentTr = stateTd.parent;
          if (parentTr != null) {
            String commodity = '';
            String variety = '';
            String mandi = '';
            String minPrice = '';
            String maxPrice = '';
            String modalPrice = '';
            String arrivalDate = '';
            
            for (var td in parentTr.querySelectorAll('td')) {
              var title = td.attributes['title']?.toLowerCase() ?? '';
              var text = td.text.trim().replaceAll('₹', '').replaceAll(',', '').trim();
              
              if (title.contains('commodity') || title == 'सामग्री' || title == 'સામગ્રી') {
                commodity = td.text.trim();
              } else if (title.contains('variety') || title == 'किस्म' || title == 'જાત') {
                variety = td.text.trim();
              } else if (title.contains('mandi') || title.contains('market') || title == 'मंडी' || title == 'બજાર') {
                mandi = td.text.trim();
              } else if (title.contains('min') || title == 'न्यूनतम मूल्य' || title == 'ન્યૂનતમ મૂલ્ય') {
                minPrice = text;
              } else if (title.contains('max') || title == 'अधिकतम मूल्य' || title == 'અધિકતમ મૂલ્ય') {
                maxPrice = text;
              } else if (title.contains('modal') || title == 'औसत मूल्य' || title == 'સરેરાશ મૂલ્ય') {
                modalPrice = text;
              } else if (title.contains('arrival') || title == 'आगमन तिथि' || title == 'આગમન તિથિ') {
                arrivalDate = td.text.trim();
              }
            }
            
            if (mandi.isNotEmpty) {
              String finalMin = minPrice;
              String finalMax = maxPrice;
              if (modalPrice.isNotEmpty && (finalMin.isEmpty || finalMax.isEmpty)) {
                finalMin = modalPrice;
                finalMax = modalPrice;
              }

              String combinedName = commodity;
              if (variety.isNotEmpty && variety.toLowerCase() != 'other') {
                combinedName = '$commodity ($variety)';
              }

              prices.add(CropPrice(
                name: combinedName.toLowerCase(),
                minPrice: finalMin,
                maxPrice: finalMax,
                date: arrivalDate,
                gujaratiName: translate(combinedName),
                yardName: mandi,
                variety: '',
              ));
            }
          }
        }
      } else {
        var tables = document.querySelectorAll('table');
        for (var table in tables) {
          var rows = table.querySelectorAll('tr');
          if (rows.length > 1) {
             for (var row in rows.skip(1)) {
               var tds = row.querySelectorAll('td');
               if (tds.length >= 9) {
                 String variety = tds[1].text.trim();
                 String mandi = tds[4].text.trim();
                 String min = tds[5].text.trim().replaceAll('₹', '').replaceAll(',', '').trim();
                 String max = tds[7].text.trim().replaceAll('₹', '').replaceAll(',', '').trim();
                 String date = tds[8].text.trim();
                 
                 String combinedName = variety; // Kisandeals often has crop in variety column
                 prices.add(CropPrice(
                   name: combinedName.toLowerCase(),
                   minPrice: min,
                   maxPrice: max,
                   date: date,
                   gujaratiName: mandi,
                   variety: '',
                 ));
               }
             }
          }
        }
      }
      return prices;
    } catch (e) {
      return [];
    }
  }

  static Future<List<CropPrice>> _fetchApmcAhmedabadPrices(String url, {DateTime? date}) async {
    try {
      var client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.badCertificateCallback = (cert, host, port) => true;

      var request = await client.postUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      request.headers.set('X-Requested-With', 'XMLHttpRequest');
      request.headers.set('Connection', 'keep-alive');
      
      final targetDate = date ?? DateTime.now();
      final dateStr = '${targetDate.day.toString().padLeft(2, '0')}/${targetDate.month.toString().padLeft(2, '0')}/${targetDate.year}';
      
      final body = 'inputDate=${Uri.encodeQueryComponent(dateStr)}&onLoad=yes';
      request.headers.set(HttpHeaders.contentLengthHeader, body.length);
      request.write(body);
      
      var response = await request.close().timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) return [];
      
      var responseBody = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      
      final data = jsonDecode(responseBody);
      List<CropPrice> prices = [];
      
      if (data is Map) {
        final rows = (data['aaData'] ?? data['CommodityData']) as List?;
        if (rows != null) {
          for (var row in rows) {
            String name = (row['CommodityName'] ?? '').toString().trim();
            String min = (row['MinRate'] ?? '0').toString().trim();
            String max = (row['MaxRate'] ?? '0').toString().trim();
            String rawDate = (row['RateDate'] ?? '').toString().trim();
            
            if (name.isNotEmpty && min != '0' && max != '0') {
              String formattedDate = rawDate;
              try {
                final d = DateTime.parse(rawDate);
                const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                formattedDate = '${d.day} ${monthsEn[d.month - 1]} ${d.year}';
              } catch (_) {}

              prices.add(CropPrice(
                name: name.toLowerCase(),
                minPrice: min,
                maxPrice: max,
                date: formattedDate,
                gujaratiName: translate(name),
                yardName: 'Ahmedabad',
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

  static Future<List<CropPrice>> _fetchApmcPalanpurPrices(String url, {DateTime? date}) async {
    try {
      var client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.badCertificateCallback = (cert, host, port) => true;

      final dateStr = date != null
          ? '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}'
          : '';
      final requestUrl = '$url$dateStr';

      var request = await client.getUrl(Uri.parse(requestUrl)).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      
      var response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      
      var responseBody = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      final data = jsonDecode(responseBody);
      List<CropPrice> prices = [];
      
      if (data is Map && data['data'] is List) {
        final rows = data['data'] as List;
        for (var row in rows) {
          String name = (row['name_of_crop'] ?? '').toString().trim();
          String min = (row['minvalue'] ?? '0').toString().trim();
          String max = (row['max_value'] ?? '0').toString().trim();
          String rawDate = (row['date'] ?? '').toString().trim();
          String income = (row['income'] ?? '').toString().trim();
          
          if (name.isNotEmpty && min != '0' && max != '0') {
            String dateString = _normalizeDDMMYYYY(rawDate.replaceAll('-', '/'));
            
            prices.add(CropPrice(
              name: name.toLowerCase(),
              minPrice: min,
              maxPrice: max,
              date: dateString,
              gujaratiName: translate(name),
              yardName: 'Palanpur',
              variety: '',
              income: income,
            ));
          }
        }
      }
      return prices;
    } catch (e) {
      debugPrint('Error fetching Palanpur prices: $e');
      return [];
    }
  }

  static Future<List<CropPrice>> fetchPrices() => _fetchApmcDeesaPrices('https://www.apmcdeesa.com/');
  static Future<List<CropPrice>> fetchPalanpurPrices({DateTime? date}) => _fetchApmcPalanpurPrices('https://marketprice.apmcpalanpur.com/Admin/marketprice/getallmarketpricedataforfilter?_date=', date: date);
  static Future<List<CropPrice>> fetchAgraPrices() => _fetchKisandealsPrices('https://www.kisandeals.com/mandiprices/district/POTATO/AGRA/ALL');
  static Future<List<CropPrice>> fetchAhmedabadPrices({DateTime? date}) => _fetchApmcAhmedabadPrices('https://www.apmcahmedabad.com/fetchCommodityData.php', date: date);
  
  static Future<List<CropPrice>> fetchRajkotPrices({DateTime? date}) => 
    RajkotApmcService.fetchPrices(date: date);

  static Future<List<CropPrice>> fetchJunagadhPrices({DateTime? date}) => 
    JunagadhApmcService.fetchPrices(date: date);

  static Future<List<CropPrice>> fetchBabraPrices() =>
    BabraApmcService.fetchPrices();
}
