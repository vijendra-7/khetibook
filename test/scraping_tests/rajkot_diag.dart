import '../../lib/services/rajkot_apmc_service.dart';

void main() async {
  final now = DateTime(2026, 4, 1);
  print('Testing Rajkot for TODAY ($now)...');
  
  for (int i = 0; i < 7; i++) {
    final testDate = now.subtract(Duration(days: i));
    print('Trying ${testDate.day}/${testDate.month}/${testDate.year}...');
    final prices = await RajkotApmcService.fetchPrices(date: testDate);
    if (prices.isNotEmpty) {
      print('SUCCESS found ${prices.length} items on loop $i');
      return;
    }
    print('Failed to find items on loop $i');
  }
}
