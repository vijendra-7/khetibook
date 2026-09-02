class GujaratiNumberHelper {
  static const _arabicDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  static const _gujaratiDigits = ['૦', '૧', '૨', '૩', '૪', '૫', '૬', '૭', '૮', '૯'];

  static const _numberWordsMap = {
    'એક': '1', 'બે': '2', 'ત્રણ': '3', 'ચાર': '4', 'પાંચ': '5',
    'છ ': '6 ', 'સાત': '7', 'આઠ': '8', 'નવ': '9', 'દસ': '10',
    'અગિયાર': '11', 'બાર': '12', 'તેર': '13', 'ચૌદ': '14', 'પંદર': '15',
    'સોળ': '16', 'સત્તર': '17', 'અઢાર': '18', 'ઓગણીસ': '19', 'વીસ': '20',
    'ત્રીસ': '30', 'ચાલીસ': '40', 'પચાસ': '50', 'સાઠ': '60', 'સિત્તેર': '70',
    'એંસી': '80', 'નેવું': '90', 'સો': '100', 'હજાર': '1000',
    'પાંચસો': '500', 'બસો': '200', 'ત્રણસો': '300', 'ચારસો': '400',
  };

  static String replaceNumberWords(String text) {
    var result = text;
    // Iterate by length descending to avoid partial matches (e.g., 'પંદર' before 'દસ')
    final sortedKeys = _numberWordsMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (var key in sortedKeys) {
      result = result.replaceAll(key, _numberWordsMap[key]!);
    }
    return result;
  }

  static String toGujarati(String text) {
    var result = text;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(_arabicDigits[i], _gujaratiDigits[i]);
    }
    return result;
  }

  static String toGujaratiInt(int input) => toGujarati(input.toString());

  static String formatCurrency(double amount, {bool gujarati = false}) {
    final formatted = '₹${amount.toStringAsFixed(0)}';
    return gujarati ? toGujarati(formatted) : formatted;
  }

  static String formatNumber(double value, {bool gujarati = false}) {
    // Remove .0 suffix if it's an integer, otherwise show as is (up to reasonable precision)
    String formatted = value.toString();
    if (formatted.endsWith('.0')) {
      formatted = formatted.substring(0, formatted.length - 2);
    } else if (formatted.contains('.')) {
      // Limit to 2 decimal places if it's a long float, but keep it if it's short like 2.4
      if (formatted.split('.')[1].length > 2) {
        formatted = value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      }
    }
    return gujarati ? toGujarati(formatted) : formatted;
  }

  static String toEnglish(String text) {
    var result = text;
    for (var i = 0; i < 10; i++) {
        result = result.replaceAll(_gujaratiDigits[i], _arabicDigits[i]);
    }
    return result;
  }

  static String toEnglishInt(String input) => toEnglish(input);
}
