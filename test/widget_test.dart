import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_accounting/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build the app and verify it doesn't crash
    await tester.pumpWidget(const FarmerApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
