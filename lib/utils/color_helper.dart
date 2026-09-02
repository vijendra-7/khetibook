import 'package:flutter/material.dart';

class ColorHelper {
  /// Safely parse a hex string into a Color.
  /// Handles prefixes like '0x', '#', or none at all.
  /// Returns [fallback] if parsing fails.
  static Color parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;

    try {
      String cleanHex = hex.trim().replaceAll('0x', '').replaceAll('#', '');
      
      // If only 6 characters (RRGGBB), add Alpha (FF)
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      
      if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
      
      // Fallback for unexpected lengths
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}
