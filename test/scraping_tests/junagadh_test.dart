import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

Future<void> main() async {
  final url = 'https://apmcjunagadh.org/daily-rates';
  print('Fetching $url...');
  
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      print('Failed to load page: ${response.statusCode}');
      return;
    }

    final document = parser.parse(response.body);
    final h6s = document.querySelectorAll('h6');
    print('Found ${h6s.length} h6 tags');

    List<Map<String, String>> prices = [];
    for (int i = 0; i < h6s.length - 4; i++) {
        String text = h6s[i].text.trim();
        if (text.isNotEmpty && !RegExp(r'^[0-9| ]+$').hasMatch(text) && text.length > 1) {
            String min = h6s[i+1].text.trim();
            String sep1 = h6s[i+2].text.trim();
            String max = h6s[i+3].text.trim();
            
            if (sep1 == '|' && RegExp(r'^[0-9]+$').hasMatch(min) && RegExp(r'^[0-9]+$').hasMatch(max)) {
                prices.add({
                    'name': text,
                    'min': min,
                    'max': max,
                });
                i += 3;
            }
        }
    }

    final nonZero = prices.where((p) => p['min'] != '0' || p['max'] != '0').toList();
    print('Extracted ${prices.length} total items, ${nonZero.length} non-zero items:');
    for (var p in nonZero.take(20)) {
        print('${p['name']}: ${p['min']} - ${p['max']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
