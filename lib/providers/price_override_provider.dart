import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_init.dart';

class PriceOverride {
  final String id; // market_crop (e.g., Deesa_Potato)
  final String minPrice;
  final String maxPrice;
  final DateTime? expiry;

  PriceOverride({
    required this.id,
    required this.minPrice,
    required this.maxPrice,
    this.expiry,
  });

  factory PriceOverride.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PriceOverride(
      id: doc.id,
      minPrice: data['minPrice'] ?? '',
      maxPrice: data['maxPrice'] ?? '',
      expiry: (data['expiry'] as Timestamp?)?.toDate(),
    );
  }
}

class PriceOverrideProvider with ChangeNotifier {
  Map<String, PriceOverride> _overrides = {};
  bool _isLoading = true;

  Map<String, PriceOverride> get overrides => _overrides;
  bool get isLoading => _isLoading;

  PriceOverrideProvider() {
    _listenToOverrides();
  }

  void _listenToOverrides() async {
    await FirebaseInit.initialize();
    FirebaseFirestore.instance
        .collection('price_overrides')
        .snapshots()
        .listen((snapshot) {
      final Map<String, PriceOverride> newOverrides = {};
      final now = DateTime.now();
      
      for (var doc in snapshot.docs) {
        final override = PriceOverride.fromFirestore(doc);
        // Only include if not expired
        if (override.expiry == null || override.expiry!.isAfter(now)) {
          newOverrides[override.id] = override;
        }
      }
      _overrides = newOverrides;
      _isLoading = false;
      notifyListeners();
    });
  }
}
