import 'dart:convert';
import 'package:flutter/services.dart';

class PanchangHelper {
  static Map<String, Map<String, dynamic>>? _data;

  static Future<void> loadData() async {
    if (_data != null) return;
    try {
      final raw = await rootBundle.loadString('assets/panchang.json');
      final list = json.decode(raw) as List<dynamic>;
      // Index the list by the "date" field for O(1) lookup
      _data = {
        for (final item in list)
          (item as Map<String, dynamic>)['date'] as String: item,
      };
    } catch (_) {
      _data = {};
    }
  }

  /// Returns panchang info string for a given date like "06-03-2026".
  /// Pass [gujarati] = true to get Gujarati text, false for English.
  static String? getPanchangForDate(String dateStr, {bool gujarati = false}) {
    if (_data == null || _data!.isEmpty) return null;
    final m = _data![dateStr];
    if (m == null) return null;

    if (gujarati) {
      final tithi = m['tithi_short_gu'] as String?;
      final paksha = m['paksha_gu'] as String?;
      final month = m['gujarati_month_gu'] as String?;
      final parts = <String>[
        if (month != null) month,
        if (paksha != null) paksha,
        if (tithi != null) tithi,
      ];
      return parts.isEmpty ? null : '🗓 ${parts.join(' • ')}';
    } else {
      final tithi = m['tithi_short'] as String?;
      final paksha = m['paksha'] as String?;
      final month = m['gujarati_month'] as String?;
      final parts = <String>[
        if (month != null) month,
        if (paksha != null) paksha,
        if (tithi != null) tithi,
      ];
      return parts.isEmpty ? null : '🗓 ${parts.join(' • ')}';
    }
  }
}
