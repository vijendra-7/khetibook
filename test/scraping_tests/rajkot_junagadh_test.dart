import 'dart:io';
import '../../lib/services/crop_price_service.dart';

void main() async {
  print('--- Testing Rajkot APMC (7-day lookback logic) ---');
  for (int i = 0; i < 7; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    print('Fetching Rajkot for ${date.day}/${date.month}/${date.year}...');
    final prices = await CropPriceService.fetchRajkotPrices(date: date);
    if (prices.isNotEmpty) {
      print('Found ${prices.length} prices for Rajkot on ${prices.first.date}');
      print('Sample: ${prices.first.gujaratiName}: ${prices.first.minPrice} - ${prices.first.maxPrice}');
      break;
    } else {
      print('No data for this date.');
    }
  }

  print('\n--- Testing Junagadh APMC (AJAX + Token logic) ---');
  for (int i = 0; i < 7; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    print('Fetching Junagadh for ${date.day}/${date.month}/${date.year}...');
    final prices = await CropPriceService.fetchJunagadhPrices(date: date);
    if (prices.isNotEmpty) {
      print('Found ${prices.length} prices for Junagadh on ${prices.first.date}');
      print('Sample: ${prices.first.gujaratiName}: ${prices.first.minPrice} - ${prices.first.maxPrice}');
      break;
    } else {
      print('No data for this date.');
    }
  }
}
