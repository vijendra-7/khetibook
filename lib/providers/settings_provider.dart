import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isGujarati = true;
  ThemeMode _themeMode = ThemeMode.light;
  List<String> _hiddenApmcCrops = ['cumin', 'chana', 'asaliyo', 'sarsav', 'methi'];
  List<String> _hiddenAgraCrops = []; // Agra market crops hidden by user
  List<String> _favoriteCrops = []; // IDs of favorite crops
  int? _lastSyncTime;
  bool _isSyncing = false;
  bool _isAdminMode = true; // Default to true for admin users


  bool get isGujarati => _isGujarati;
  ThemeMode get themeMode => _themeMode;
  List<String> get hiddenApmcCrops => _hiddenApmcCrops;
  List<String> get hiddenAgraCrops => _hiddenAgraCrops;
  List<String> get favoriteCrops => _favoriteCrops;
  int? get lastSyncTime => _lastSyncTime;
  bool get isSyncing => _isSyncing;
  bool get isAdminMode => _isAdminMode;


  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isGujarati = prefs.getBool('isGujarati') ?? true;
    final tm = prefs.getString('themeMode') ?? 'light';
    _themeMode = tm == 'light'
        ? ThemeMode.light
        : tm == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light;
    _hiddenApmcCrops = prefs.getStringList('hiddenApmcCrops') ?? ['cumin', 'chana', 'asaliyo', 'sarsav', 'methi'];
    _hiddenAgraCrops = prefs.getStringList('hiddenAgraCrops') ?? [];
    _favoriteCrops = prefs.getStringList('favoriteCrops') ?? [];
    _lastSyncTime = prefs.getInt('lastSyncTime');
    _isAdminMode = prefs.getBool('isAdminMode') ?? true;

    notifyListeners();
  }

  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  Future<void> updateLastSyncTime() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastSyncTime = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSyncTime', now);
    notifyListeners();
  }

  Future<void> toggleFavoriteCrop(String cropId) async {
    final list = List<String>.from(_favoriteCrops);
    if (list.contains(cropId)) {
      list.remove(cropId);
    } else {
      list.add(cropId);
    }
    _favoriteCrops = list;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteCrops', list);
  }

  bool isFavorite(String cropId) => _favoriteCrops.contains(cropId);

  Future<void> toggleApmcCrop(String cropId) async {
    final list = List<String>.from(_hiddenApmcCrops);
    if (list.contains(cropId)) {
      list.remove(cropId);
    } else {
      list.add(cropId);
    }
    _hiddenApmcCrops = list;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hiddenApmcCrops', list);
  }

  Future<void> toggleAgraCrop(String cropId) async {
    final list = List<String>.from(_hiddenAgraCrops);
    if (list.contains(cropId)) {
      list.remove(cropId);
    } else {
      list.add(cropId);
    }
    _hiddenAgraCrops = list;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hiddenAgraCrops', list);
  }

  Future<void> setLanguage(bool gujarati) async {
    _isGujarati = gujarati;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGujarati', gujarati);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString('themeMode', key);
  }

  Future<void> toggleLanguage() async {
    await setLanguage(!_isGujarati);
  }

  Future<void> setAdminMode(bool value) async {
    _isAdminMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAdminMode', value);
  }
}
