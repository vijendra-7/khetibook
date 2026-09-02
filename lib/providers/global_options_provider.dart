import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_init.dart';
import '../utils/crop_icon_utils.dart';

class GlobalOption {
  final String id;
  final String type;
  final String labelEn;
  final String labelGu;
  final String value;
  final String? imageUrl;
  final double imageScale;
  final double imageOffsetX;
  final double imageOffsetY;
  final String? backgroundColor;

  GlobalOption({
    required this.id,
    required this.type,
    required this.labelEn,
    required this.labelGu,
    required this.value,
    this.imageUrl,
    this.imageScale = 1.0,
    this.imageOffsetX = 0.0,
    this.imageOffsetY = 0.0,
    this.backgroundColor,
  });

  factory GlobalOption.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) throw Exception('No data for doc ${doc.id}');
      
      return GlobalOption(
        id: doc.id,
        type: (data['type'] ?? '').toString(),
        labelEn: (data['labelEn'] ?? '').toString(),
        labelGu: (data['labelGu'] ?? '').toString(),
        value: (data['value'] ?? '').toString(),
        imageUrl: data['imageUrl']?.toString(),
        imageScale: (data['imageScale'] as num?)?.toDouble() ?? 1.0,
        imageOffsetX: (data['imageOffsetX'] as num?)?.toDouble() ?? 0.0,
        imageOffsetY: (data['imageOffsetY'] as num?)?.toDouble() ?? 0.0,
        backgroundColor: data['backgroundColor']?.toString(),
      );
    } catch (e) {
      debugPrint('Error parsing GlobalOption ${doc.id}: $e');
      // Return a minimal valid object to avoid blocking the whole list
      return GlobalOption(
        id: doc.id,
        type: 'error',
        labelEn: 'Error Loading',
        labelGu: 'Error Loading',
        value: 'error_${doc.id}',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalOption &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          labelEn == other.labelEn &&
          labelGu == other.labelGu &&
          value == other.value &&
          imageUrl == other.imageUrl &&
          imageScale == other.imageScale &&
          imageOffsetX == other.imageOffsetX &&
          imageOffsetY == other.imageOffsetY &&
          backgroundColor == other.backgroundColor;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      labelEn.hashCode ^
      labelGu.hashCode ^
      value.hashCode ^
      imageUrl.hashCode ^
      imageScale.hashCode ^
      imageOffsetX.hashCode ^
      imageOffsetY.hashCode ^
      backgroundColor.hashCode;
}

class GlobalOptionsProvider with ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  List<GlobalOption> _options = [];
  bool _isLoading = true;

  StreamSubscription? _subscription;
  
  GlobalOptionsProvider() {
    _init();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _init() async {
    await FirebaseInit.initialize();
    _subscription = _firestore.collection('global_metadata').snapshots().listen((snapshot) {
      final newOptions = snapshot.docs.map((doc) => GlobalOption.fromFirestore(doc)).toList();
      
      // Deep equality check to prevent redundant UI rebuilds if data hasn't changed
      if (!listEquals(_options, newOptions)) {
        _options = newOptions;
        _isLoading = false;
        notifyListeners();
      } else if (_isLoading) {
        // Still need to clear loading state even if data is same as initial cache
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('GlobalOptionsProvider listener error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  List<GlobalOption> get options => _options;
  bool get isLoading => _isLoading;

  List<GlobalOption> getGlobalInvestmentTypes() {
    return _options.where((o) => o.type == 'investment_type').toList();
  }

  List<GlobalOption> getGlobalCrops() {
    final firestoreCrops = _options.where((o) => o.type == 'crop').toList();
    final List<GlobalOption> allCrops = [...firestoreCrops];

    // Canonical mapping for deduplication
    final Map<String, String> synonyms = {
      'potato': 'bataka',
      'wheat': 'ghau',
      'groundnut': 'magfali',
      'bajra': 'bajari',
      'millet': 'bajari',
      'watermelon': 'tarbuch',
    };

    // Tracking seen crops (using lower-case normalized names)
    final Set<String> seenValues = firestoreCrops.map((c) {
      final val = c.value.toLowerCase();
      return synonyms[val] ?? val;
    }).toSet();

    // Synthesis: Add crops from local 3D library if not already seen
    for (final local in CropIconUtils.allCrops) {
       final value = local['value'] ?? '';
       final lowerVal = value.toLowerCase();
       final normalized = synonyms[lowerVal] ?? lowerVal;

       if (!seenValues.contains(normalized)) {
          seenValues.add(normalized);
          allCrops.add(GlobalOption(
            id: 'local_${normalized}',
            type: 'crop',
            labelEn: local['en'] ?? value,
            labelGu: local['gu'] ?? value,
            value: normalized == 'bataka' ? 'Bataka' : (normalized == 'ghau' ? 'Ghau' : (normalized == 'magfali' ? 'Magfali' : value)),
            imageUrl: 'assets/icons/${local['icon']}',
            imageScale: 1.0, 
          ));
       }
    }
    
    return allCrops;
  }

  Map<String, String> getGlobalCropMap(bool gu) {
    return {
      for (var o in getGlobalCrops()) o.value: gu ? o.labelGu : o.labelEn
    };
  }

  Map<String, String> getGlobalInvestmentTypeMap(bool gu) {
    return {
      for (var o in getGlobalInvestmentTypes()) o.value: gu ? o.labelGu : o.labelEn
    };
  }
}
