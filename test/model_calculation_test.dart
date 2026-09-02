import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_accounting/models/investment.dart';
import 'package:farmer_accounting/models/investment_item.dart';
import 'package:farmer_accounting/models/output.dart';
import 'package:farmer_accounting/models/helper_transaction.dart';

void main() {
  group('Investment Calculations', () {
    test('Biyaran calculation: kataQuantity * pricePerKata', () {
      final inv = Investment(
        crop: 'Bataka',
        investmentType: 'Biyaran',
        kataQuantity: 10,
        pricePerKata: 500,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(inv.totalAmount, 5000);
    });

    test('Dawa/Khatar calculation from items list', () {
      final inv = Investment(
        crop: 'Bataka',
        investmentType: 'Khatar',
        items: [
          InvestmentItem(investmentUuid: 'u1', itemName: 'Item 1', quantity: 2, pricePerUnit: 500),
          InvestmentItem(investmentUuid: 'u1', itemName: 'Item 2', quantity: 3, pricePerUnit: 1000),
        ],
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(inv.totalAmount, 4000);
    });

    test('Dawa/Khatar fallback to cost if items list is empty', () {
      final inv = Investment(
        crop: 'Bataka',
        investmentType: 'Dawa',
        items: [],
        cost: 1500,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(inv.totalAmount, 1500);
    });

    test('Other investment type returns cost', () {
      final inv = Investment(
        crop: 'Bataka',
        investmentType: 'Others',
        cost: 2500,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(inv.totalAmount, 2500);
    });
  });

  group('Output Calculations', () {
    test('Revenue (Bataka): ((bharati * 80) + remainingKg) / 20 * pricePer20kg', () {
      final output = Output(
        crop: 'Bataka',
        field: 'North Field',
        bharati: 10, // 10 * 80 = 800kg
        remainingKg: 10, // 800 + 10 = 810kg
        pricePer20kg: 400, // 810 / 20 = 40.5 units. 40.5 * 400 = 16200
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(output.revenue, 16200);
    });

    test('Revenue (Magfali): ((bharati * 34) + remainingKg) / 20 * pricePer20kg', () {
      final output = Output(
        crop: 'Magfali',
        field: 'East Field',
        bharati: 10, // 10 * 34 = 340kg
        remainingKg: 10, // 340 + 10 = 350kg
        pricePer20kg: 400, // 350 / 20 = 17.5 units. 17.5 * 400 = 7000
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(output.revenue, 7000);
    });

    test('Revenue (Bajari/Ghau): ((bharati * 99) + remainingKg) / 20 * pricePer20kg', () {
      final bajari = Output(
        crop: 'Bajari',
        field: 'North Field',
        bharati: 10, // 10 * 99 = 990kg. 990 / 20 = 49.5 units. 400 * 49.5 = 19800
        pricePer20kg: 400,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(bajari.revenue, 19800);

      final ghau = Output(
        crop: 'Ghau',
        field: 'South Field',
        bharati: 20, // 20 * 99 = 1980kg. 1980 / 20 = 99 units. 99 * 500 = 49500
        pricePer20kg: 500,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(ghau.revenue, 49500);
    });

    test('Revenue (Tarbuch): weight * pricePerKg', () {
      final output = Output(
        crop: 'Tarbuch',
        field: 'Watermelon Patch',
        bharati: 0, // Ignored for Tarbuch
        remainingKg: 100, // Weight in kg
        pricePer20kg: 5, // Price per kg
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(output.revenue, 500);
    });

    test('Revenue with zero remainingKg (Bataka)', () {
      final output = Output(
        crop: 'Bataka',
        field: 'Potato Field',
        bharati: 20, // 20 * 80 = 1600kg. 1600 / 20 = 80 units. 80 * 500 = 40000
        remainingKg: 0,
        pricePer20kg: 500,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(output.revenue, 40000);
    });

    test('Revenue (Custom Crop): bharati * pricePerKata', () {
      final tomato = Output(
        crop: 'Tomato',
        field: 'Custom Field',
        bharati: 50, // 50 Kata
        pricePer20kg: 200, // ₹200/Kata
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(tomato.revenue, 10000); // 50 * 200
    });
  });

  group('HelperTransaction Calculations', () {
    test('Majur calculation: workerCount * amountPerWorker', () {
      final tx = HelperTransaction(
        transactionType: 'Majur',
        helperName: 'Team A',
        workerCount: 5,
        amountPerWorker: 300,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(tx.totalAmount, 1500);
    });

    test('Tractor calculation (Hours): hours * pricePerHour', () {
      final tx = HelperTransaction(
        transactionType: 'Tractor',
        helperName: 'Tractor Service',
        equipmentType: 'Cultivator',
        hours: 2.5,
        pricePerHour: 800,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(tx.totalAmount, 2000);
    });

    test('Tractor calculation (Fixed): Tola no Fero', () {
      final tx = HelperTransaction(
        transactionType: 'Tractor',
        helperName: 'Tractor Service',
        equipmentType: 'Tola no Fero',
        amount: 1200,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(tx.totalAmount, 1200);
    });

    test('Upaad calculation returns amount', () {
      final tx = HelperTransaction(
        transactionType: 'Upaad',
        helperName: 'Worker X',
        amount: 1000,
        date: DateTime.now().millisecondsSinceEpoch,
      );
      expect(tx.totalAmount, 1000);
    });
  });
}
