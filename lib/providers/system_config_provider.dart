import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/firebase_init.dart';

class SystemConfigProvider with ChangeNotifier {
  bool _isMaintenance = false;
  String _maintenanceMsgEn = 'App is under maintenance. Please try again later.';
  String _maintenanceMsgGu = 'એપ્લિકેશન મેન્ટેનન્સમાં છે. કૃપા કરીને થોડા સમય પછી પ્રયાસ કરો.';
  String _minVersion = '1.0.0';
  String _updateUrl = '';
  String _updateImageUrl = '';
  bool _needsUpdate = false;
  bool _checkOfficialUpdate = true;
  bool _isLoading = true;
  
  // News Hero Section Controls
  String _newsHeroMode = 'news'; // 'news', 'video', 'hidden'
  String _newsHeroYoutubeUrl = '';
  
  StreamSubscription? _subscription;
  
  bool get isMaintenance => _isMaintenance;
  String get maintenanceMsgEn => _maintenanceMsgEn;
  String get maintenanceMsgGu => _maintenanceMsgGu;
  String get minVersion => _minVersion;
  String get updateUrl => _updateUrl;
  String get updateImageUrl => _updateImageUrl;
  bool get needsUpdate => _needsUpdate;
  bool get checkOfficialUpdate => _checkOfficialUpdate;
  bool get isLoading => _isLoading;
  String get newsHeroMode => _newsHeroMode;
  String get newsHeroYoutubeUrl => _newsHeroYoutubeUrl;

  SystemConfigProvider() {
    _listenToConfig();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToConfig() async {
    await FirebaseInit.initialize();
    
    _subscription = FirebaseFirestore.instance
        .collection('system_controls')
        .doc('app_config')
        .snapshots()
        .listen((doc) async {
      if (doc.exists) {
        final data = doc.data()!;
        _isMaintenance = data['isMaintenance'] ?? false;
        _maintenanceMsgEn = data['maintenanceMsgEn'] ?? _maintenanceMsgEn;
        _maintenanceMsgGu = data['maintenanceMsgGu'] ?? _maintenanceMsgGu;
        _minVersion = data['minVersion'] ?? '1.0.0';
        _updateUrl = data['updateUrl'] ?? '';
        _updateImageUrl = data['updateImageUrl'] ?? '';
        _checkOfficialUpdate = data['checkOfficialUpdate'] ?? true;
        _newsHeroMode = data['newsHeroMode'] ?? 'news';
        _newsHeroYoutubeUrl = data['newsHeroYoutubeUrl'] ?? '';
        
        await _checkVersion();
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to system config: $e');
      _isLoading = false;
      notifyListeners();
    });

    // Fallback: stop loading after 2 seconds regardless (was 5s — too slow)
    Future.delayed(const Duration(seconds: 2), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      _needsUpdate = _isVersionLower(currentVersion, _minVersion);
    } catch (e) {
      debugPrint('Error checking version: $e');
    }
  }

  bool _isVersionLower(String current, String min) {
    if (current == min) return false;
    final currentParts = current.split('.').map(int.parse).toList();
    final minParts = min.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final m = i < minParts.length ? minParts[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }
}
