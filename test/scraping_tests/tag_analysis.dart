import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final url = 'https://apmcjunagadh.org/daily-rates';
  final response = await http.get(Uri.parse(url));
  final document = parser.parse(response.body);
  
  // Find all elements that contain category names
  final categories = ['અનાજ અને કઠોળ', 'શાકભાજી', 'ફળ'];
  
  print('--- Tag Analysis ---');
  for (var category in categories) {
    bool found = false;
    document.querySelectorAll('*').forEach((element) {
      if (element.text.trim() == category) {
        print('Category: "$category" found in tag: <${element.localName}> with classes: ${element.className}');
        found = true;
      }
    });
    if (!found) {
      // Try partial match
      document.querySelectorAll('*').forEach((element) {
        if (element.text.trim().contains(category) && element.children.isEmpty) {
          print('Category: "$category" partial match: "${element.text.trim()}" in tag: <${element.localName}>');
        }
      });
    }
  }
}
