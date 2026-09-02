import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../models/crop_price.dart';
import '../services/crop_price_service.dart';
import '../services/junagadh_apmc_service.dart';
import '../services/dhanera_apmc_service.dart';
import '../services/rajkot_apmc_service.dart';

import '../services/amirgadh_apmc_service.dart';
import '../services/surat_apmc_service.dart';
import '../services/siddhpur_apmc_service.dart';
import '../services/radhanpur_apmc_service.dart';
import '../services/himatnagar_apmc_service.dart';
import '../services/unjha_apmc_service.dart';
import '../services/mahuva_apmc_service.dart';
import '../services/gondal_apmc_service.dart';
import '../services/botad_apmc_service.dart';
import '../services/amreli_apmc_service.dart';
import '../services/babra_apmc_service.dart';
import '../services/visnagar_apmc_service.dart';
import '../services/bagasara_apmc_service.dart';
import '../services/jasdan_apmc_service.dart';
import '../services/jetpur_apmc_service.dart';
import '../services/jamnagar_apmc_service.dart';
import '../services/rajula_apmc_service.dart';
import '../services/patan_apmc_service.dart';
import '../services/savarkundla_apmc_service.dart';
import '../utils/gujarati_number_helper.dart';

List<CropPrice> _parseCropList(String jsonString) {
  final List<dynamic> decoded = jsonDecode(jsonString);
  return decoded.map((item) => CropPrice.fromJson(item)).toList();
}

class CropPriceProvider with ChangeNotifier {
  List<CropPrice> _prices = []; // This will now act as the history for Deesa
  List<CropPrice> _palanpurPrices = [];
  List<CropPrice> _ahmedabadPrices = [];
  List<CropPrice> _junagadhPrices = [];
  List<CropPrice> _rajkotPrices = [];
  List<CropPrice> _agraPrices = [];
  List<CropPrice> _dhaneraPrices = [];
  List<CropPrice> _amirgadhPrices = [];
  List<CropPrice> _suratPrices = [];
  List<CropPrice> _siddhpurPrices = [];
  List<CropPrice> _radhanpurPrices = [];
  List<CropPrice> _himatnagarPrices = [];
  List<CropPrice> _unjhaPrices = [];
  List<CropPrice> _mahuvaPrices = [];
  List<CropPrice> _gondalPrices = [];
  List<CropPrice> _botadPrices = [];
  List<CropPrice> _amreliPrices = [];
  List<CropPrice> _babraPrices = [];
  List<CropPrice> _visnagarPrices = [];
  List<CropPrice> _bagasaraPrices = [];
  List<CropPrice> _jasdanPrices = [];
  List<CropPrice> _jetpurPrices = [];
  List<CropPrice> _jamnagarPrices = [];
  List<CropPrice> _rajulaPrices = [];
  List<CropPrice> _patanPrices = [];
  List<CropPrice> _savarkundlaPrices = [];
  
  static const Map<String, int> _monthMap = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    'January': 1, 'February': 2, 'March': 3, 'April': 4, 'June': 6, 'July': 7, 'August': 8, 'September': 9, 'October': 10, 'November': 11, 'December': 12
  };

  /// Parses a date string in either "DD Mon YYYY" or "DD/MM/YYYY" format.
  /// Returns null if neither format matches.
  static DateTime? parseDate(String date) {
    try {
      // Format 1: "22 May 2026" (3 space-separated parts)
      final spaceParts = date.split(' ');
      if (spaceParts.length == 3) {
        final month = _monthMap[spaceParts[1]];
        if (month != null) {
          return DateTime(int.parse(spaceParts[2]), month, int.parse(spaceParts[0]));
        }
      }
      // Format 2: "22/05/2026" (DD/MM/YYYY)
      final slashParts = date.split('/');
      if (slashParts.length == 3) {
        return DateTime(int.parse(slashParts[2]), int.parse(slashParts[1]), int.parse(slashParts[0]));
      }
    } catch (_) {}
    return null;
  }

  String? _dhaneraImageUrl;
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _lastUpdated;
  // Per-market last-updated timestamps. Key = market index.
  final Map<int, DateTime> _marketLastUpdated = {};
  int _selectedApmcIndex = 0; // 0..4, 5: Dhanera, 6: Amirgadh, 7: Surat, 8: Siddhpur, 9: Radhanpur, 10: Himatnagar, 11: Unjha, 12: Mahuva, 13: Gondal, 14: Botad, 15: Amreli, 16: Babra, 17: Visnagar, 18: Agra

  DateTime? _selectedPalanpurDate;
  DateTime? _selectedAhmedabadDate;
  DateTime? _selectedJunagadhDate;
  DateTime? _selectedRajkotDate;
  DateTime? _selectedGondalDate;
  bool _isPalanpurDateManual = false;
  bool _isAhmedabadDateManual = false;
  bool _isJunagadhDateManual = false;
  bool _isRajkotDateManual = false;
  bool _isGondalDateManual = false;

  final Set<String> _emptyPalanpurDates = {};
  final Set<String> _emptyAhmedabadDates = {};
  final Set<String> _emptyJunagadhDates = {};
  final Set<String> _emptyRajkotDates = {};
  final Set<String> _emptyGondalDates = {};

  DateTime? get selectedPalanpurDate => _selectedPalanpurDate;
  DateTime? get selectedAhmedabadDate => _selectedAhmedabadDate;
  DateTime? get selectedJunagadhDate => _selectedJunagadhDate;
  DateTime? get selectedRajkotDate => _selectedRajkotDate;
  DateTime? get selectedGondalDate => _selectedGondalDate;
  bool get isPalanpurDateManual => _isPalanpurDateManual;
  bool get isAhmedabadDateManual => _isAhmedabadDateManual;
  bool get isJunagadhDateManual => _isJunagadhDateManual;
  bool get isRajkotDateManual => _isRajkotDateManual;
  bool get isGondalDateManual => _isGondalDateManual;

  bool isPalanpurDateEmpty(DateTime date) {
    final key = '${date.day}-${date.month}-${date.year}';
    return _emptyPalanpurDates.contains(key);
  }

  bool isAhmedabadDateEmpty(DateTime date) {
    final key = '${date.day}-${date.month}-${date.year}';
    return _emptyAhmedabadDates.contains(key);
  }

  bool isJunagadhDateEmpty(DateTime date) {
    final key = '${date.day}-${date.month}-${date.year}';
    return _emptyJunagadhDates.contains(key);
  }

  bool isRajkotDateEmpty(DateTime date) {
    final key = '${date.day}-${date.month}-${date.year}';
    return _emptyRajkotDates.contains(key);
  }

  bool isGondalDateEmpty(DateTime date) {
    final key = '${date.day}-${date.month}-${date.year}';
    return _emptyGondalDates.contains(key);
  }

  Future<void> _saveSelectedDate(String key, DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, date.millisecondsSinceEpoch);
    }
  }

  void setPalanpurDate(DateTime? date, {bool isManual = true}) {
    if (_selectedPalanpurDate != date || _isPalanpurDateManual != isManual) {
      _selectedPalanpurDate = date;
      _isPalanpurDateManual = isManual;
      if (date == null) _isPalanpurDateManual = false;
      _saveSelectedDate('sel_date_palanpur', date);
      _palanpurPrices = [];
      _updateProcessedData();
      notifyListeners();
      _fetchSingleMarket(1);
    }
  }

  void setAhmedabadDate(DateTime? date, {bool isManual = true}) {
    if (_selectedAhmedabadDate != date || _isAhmedabadDateManual != isManual) {
      _selectedAhmedabadDate = date;
      _isAhmedabadDateManual = isManual;
      if (date == null) _isAhmedabadDateManual = false;
      _saveSelectedDate('sel_date_ahmedabad', date);
      _ahmedabadPrices = [];
      _updateProcessedData();
      notifyListeners();
      _fetchSingleMarket(2);
    }
  }

  void setJunagadhDate(DateTime? date, {bool isManual = true}) {
    if (_selectedJunagadhDate != date || _isJunagadhDateManual != isManual) {
      _selectedJunagadhDate = date;
      _isJunagadhDateManual = isManual;
      if (date == null) _isJunagadhDateManual = false;
      _saveSelectedDate('sel_date_junagadh', date);
      _junagadhPrices = [];
      _updateProcessedData();
      notifyListeners();
      _fetchSingleMarket(3);
    }
  }

  void setRajkotDate(DateTime? date, {bool isManual = true}) {
    if (_selectedRajkotDate != date || _isRajkotDateManual != isManual) {
      _selectedRajkotDate = date;
      _isRajkotDateManual = isManual;
      if (date == null) _isRajkotDateManual = false;
      _saveSelectedDate('sel_date_rajkot', date);
      _rajkotPrices = [];
      _updateProcessedData();
      notifyListeners();
      _fetchSingleMarket(4);
    }
  }

  void setGondalDate(DateTime? date, {bool isManual = true}) {
    if (_selectedGondalDate != date || _isGondalDateManual != isManual) {
      _selectedGondalDate = date;
      _isGondalDateManual = isManual;
      if (date == null) _isGondalDateManual = false;
      _saveSelectedDate('sel_date_gondal', date);
      _gondalPrices = [];
      _updateProcessedData();
      notifyListeners();
      _fetchSingleMarket(13);
    }
  }
  
  Map<String, List<CropPrice>> _yardGroups = {};
  Map<String, List<CropPrice>> _groupedByName = {};
  Map<String, List<CropPrice>> _byDate = {};
  List<String> _sortedDates = [];
  List<String> _widgetCrops = [];

  List<CropPrice> get apmcPrices {
    if (_selectedApmcIndex == 1) return _palanpurPrices;
    if (_selectedApmcIndex == 2) return _ahmedabadPrices;
    if (_selectedApmcIndex == 3) return _junagadhPrices;
    if (_selectedApmcIndex == 4) return _rajkotPrices;
    if (_selectedApmcIndex == 5) return _dhaneraPrices;
    if (_selectedApmcIndex == 6) return _amirgadhPrices;
    if (_selectedApmcIndex == 7) return _suratPrices;
    if (_selectedApmcIndex == 8) return _siddhpurPrices;
    if (_selectedApmcIndex == 9) return _radhanpurPrices;
    if (_selectedApmcIndex == 10) return _himatnagarPrices;
    if (_selectedApmcIndex == 11) return _unjhaPrices;
    if (_selectedApmcIndex == 12) return _mahuvaPrices;
    if (_selectedApmcIndex == 13) return _gondalPrices;
    if (_selectedApmcIndex == 14) return _botadPrices;
    if (_selectedApmcIndex == 15) return _amreliPrices;
    if (_selectedApmcIndex == 16) return _babraPrices;
    if (_selectedApmcIndex == 17) return _visnagarPrices;
    if (_selectedApmcIndex == 18) return _agraPrices;
    if (_selectedApmcIndex == 19) return _bagasaraPrices;
    if (_selectedApmcIndex == 20) return _jasdanPrices;
    if (_selectedApmcIndex == 21) return _jetpurPrices;
    if (_selectedApmcIndex == 22) return _jamnagarPrices;
    if (_selectedApmcIndex == 23) return _rajulaPrices;
    if (_selectedApmcIndex == 24) return _patanPrices;
    if (_selectedApmcIndex == 25) return _savarkundlaPrices;
    return _prices;
  }
  
  List<CropPrice> get deesaPrices => _prices;
  List<CropPrice> get palanpurPrices => _palanpurPrices;
  List<CropPrice> get ahmedabadPrices => _ahmedabadPrices;
  List<CropPrice> get junagadhPrices => _junagadhPrices;
  List<CropPrice> get rajkotPrices => _rajkotPrices;
  List<CropPrice> get agraPrices => _agraPrices;
  List<CropPrice> get dhaneraPrices => _dhaneraPrices;
  List<CropPrice> get amirgadhPrices => _amirgadhPrices;
  List<CropPrice> get suratPrices => _suratPrices;
  List<CropPrice> get siddhpurPrices => _siddhpurPrices;
  List<CropPrice> get radhanpurPrices => _radhanpurPrices;
  List<CropPrice> get himatnagarPrices => _himatnagarPrices;
  List<CropPrice> get unjhaPrices => _unjhaPrices;
  List<CropPrice> get mahuvaPrices => _mahuvaPrices;
  List<CropPrice> get gondalPrices => _gondalPrices;
  List<CropPrice> get botadPrices => _botadPrices;
  List<CropPrice> get amreliPrices => _amreliPrices;
  List<CropPrice> get babraPrices => _babraPrices;
  List<CropPrice> get visnagarPrices => _visnagarPrices;
  String? get dhaneraImageUrl => _dhaneraImageUrl;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get selectedApmcIndex => _selectedApmcIndex;
  DateTime? get lastUpdated => _lastUpdated;
  DateTime? lastUpdatedForMarket(int index) => _marketLastUpdated[index];
  
  Map<String, List<CropPrice>> get yardGroups => _yardGroups;
  Map<String, List<CropPrice>> get groupedByName => _groupedByName;
  Map<String, List<CropPrice>> get byDate => _byDate;
  List<String> get sortedDates => _sortedDates;
  List<String> get widgetCrops => _widgetCrops;

  CropPriceProvider() {
    _loadFromCache().then((_) {
      // Lazy startup: only fetch the currently-selected market.
      // All other markets load on-demand when the user switches to them.
      // This replaces the previous 21-market simultaneous fetch.
      _lazyFetchIfNeeded(_selectedApmcIndex);
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deesaJson = prefs.getString('cache_deesa_prices');
      final palanpurJson = prefs.getString('cache_palanpur_prices');
      final ahmedabadJson = prefs.getString('cache_ahmedabad_prices_v2');
      final junagadhJson = prefs.getString('cache_junagadh_prices_v2');
      final rajkotJson = prefs.getString('cache_rajkot_prices_v1');
      final agraJsonv2 = prefs.getString('cache_agra_prices_v2');
      final lastUpdateUnix = prefs.getInt('cache_last_updated');
      // Load per-market timestamps
      for (int i = 0; i <= 25; i++) {
        final ts = prefs.getInt('cache_market_updated_$i');
        if (ts != null) _marketLastUpdated[i] = DateTime.fromMillisecondsSinceEpoch(ts);
      }
      final selectedIndex = prefs.getInt('cache_selected_apmc_index');
      final widgetCropsStr = prefs.getString('cache_widget_crops');
      final dhaneraUrl = prefs.getString('cache_dhanera_image_url');
      final dhaneraJson = prefs.getString('cache_dhanera_prices');
      final amirgadhJson = prefs.getString('cache_amirgadh_prices');
      final suratJson = prefs.getString('cache_surat_prices');
      final siddhpurJson = prefs.getString('cache_siddhpur_prices');
      final radhanpurJson = prefs.getString('cache_radhanpur_prices');
      final himatnagarJson = prefs.getString('cache_himatnagar_prices');
      final unjhaJson = prefs.getString('cache_unjha_prices');
      final mahuvaJson = prefs.getString('cache_mahuva_prices');
      final gondalJson = prefs.getString('cache_gondal_prices');
      final botadJson = prefs.getString('cache_botad_prices');
      final amreliJson = prefs.getString('cache_amreli_prices');
      final babraJson = prefs.getString('cache_babra_prices');
      final visnagarJson = prefs.getString('cache_visnagar_prices');
      final bagasaraJson = prefs.getString('cache_bagasara_prices');
      final jasdanJson = prefs.getString('cache_jasdan_prices');
      final jetpurJson = prefs.getString('cache_jetpur_prices');
      final jamnagarJson = prefs.getString('cache_jamnagar_prices');
      final rajulaJson = prefs.getString('cache_rajula_prices');
      final patanJson = prefs.getString('cache_patan_prices');
      final savarkundlaJson = prefs.getString('cache_savarkundla_prices');

      final futures = <Future<void>>[];
      if (deesaJson != null) futures.add(compute(_parseCropList, deesaJson).then((v) => _prices = v));
      if (palanpurJson != null) futures.add(compute(_parseCropList, palanpurJson).then((v) => _palanpurPrices = v));
      if (ahmedabadJson != null) futures.add(compute(_parseCropList, ahmedabadJson).then((v) => _ahmedabadPrices = v));
      if (junagadhJson != null) futures.add(compute(_parseCropList, junagadhJson).then((v) => _junagadhPrices = v));
      if (agraJsonv2 != null) futures.add(compute(_parseCropList, agraJsonv2).then((v) => _agraPrices = v));
      if (rajkotJson != null) futures.add(compute(_parseCropList, rajkotJson).then((v) => _rajkotPrices = v));
      if (dhaneraJson != null) futures.add(compute(_parseCropList, dhaneraJson).then((v) => _dhaneraPrices = v));
      if (amirgadhJson != null) futures.add(compute(_parseCropList, amirgadhJson).then((v) => _amirgadhPrices = v));
      if (suratJson != null) futures.add(compute(_parseCropList, suratJson).then((v) => _suratPrices = v));
      if (siddhpurJson != null) futures.add(compute(_parseCropList, siddhpurJson).then((v) => _siddhpurPrices = v));
      if (radhanpurJson != null) futures.add(compute(_parseCropList, radhanpurJson).then((v) => _radhanpurPrices = v));
      if (himatnagarJson != null) futures.add(compute(_parseCropList, himatnagarJson).then((v) => _himatnagarPrices = v));
      if (unjhaJson != null) futures.add(compute(_parseCropList, unjhaJson).then((v) => _unjhaPrices = v));
      if (mahuvaJson != null) futures.add(compute(_parseCropList, mahuvaJson).then((v) => _mahuvaPrices = v));
      if (gondalJson != null) futures.add(compute(_parseCropList, gondalJson).then((v) => _gondalPrices = v));
      if (botadJson != null) futures.add(compute(_parseCropList, botadJson).then((v) => _botadPrices = v));
      if (amreliJson != null) futures.add(compute(_parseCropList, amreliJson).then((v) => _amreliPrices = v));
      if (babraJson != null) futures.add(compute(_parseCropList, babraJson).then((v) => _babraPrices = v));
      if (visnagarJson != null) futures.add(compute(_parseCropList, visnagarJson).then((v) => _visnagarPrices = v));
      if (bagasaraJson != null) futures.add(compute(_parseCropList, bagasaraJson).then((v) => _bagasaraPrices = v));
      if (jasdanJson != null) futures.add(compute(_parseCropList, jasdanJson).then((v) => _jasdanPrices = v));
      if (jetpurJson != null) futures.add(compute(_parseCropList, jetpurJson).then((v) => _jetpurPrices = v));
      if (jamnagarJson != null) futures.add(compute(_parseCropList, jamnagarJson).then((v) => _jamnagarPrices = v));
      if (rajulaJson != null) futures.add(compute(_parseCropList, rajulaJson).then((v) => _rajulaPrices = v));
      if (patanJson != null) futures.add(compute(_parseCropList, patanJson).then((v) => _patanPrices = v));
      if (savarkundlaJson != null) futures.add(compute(_parseCropList, savarkundlaJson).then((v) => _savarkundlaPrices = v));
      await Future.wait(futures);
      if (lastUpdateUnix != null) _lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdateUnix);
      if (selectedIndex != null) _selectedApmcIndex = selectedIndex;
      if (dhaneraUrl != null) _dhaneraImageUrl = dhaneraUrl;
      if (widgetCropsStr != null) {
        _widgetCrops = List<String>.from(jsonDecode(widgetCropsStr));
      }

      // Fix 4: Restore selected dates from persistent storage
      final today = DateTime.now();
      DateTime? _restoreDate(String key) {
        final ms = prefs.getInt(key);
        if (ms == null) return null;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        // Only restore if it's today or in the past (not a future date)
        return dt.isAfter(today) ? null : dt;
      }
      final restoredPalanpur = _restoreDate('sel_date_palanpur');
      if (restoredPalanpur != null) {
        _selectedPalanpurDate = restoredPalanpur;
        _isPalanpurDateManual = true;
      }
      final restoredAhmedabad = _restoreDate('sel_date_ahmedabad');
      if (restoredAhmedabad != null) {
        _selectedAhmedabadDate = restoredAhmedabad;
        _isAhmedabadDateManual = true;
      }
      final restoredJunagadh = _restoreDate('sel_date_junagadh');
      if (restoredJunagadh != null) {
        _selectedJunagadhDate = restoredJunagadh;
        _isJunagadhDateManual = true;
      }
      final restoredRajkot = _restoreDate('sel_date_rajkot');
      if (restoredRajkot != null) {
        _selectedRajkotDate = restoredRajkot;
        _isRajkotDateManual = true;
      }
      final restoredGondal = _restoreDate('sel_date_gondal');
      if (restoredGondal != null) {
        _selectedGondalDate = restoredGondal;
        _isGondalDateManual = true;
      }

      _updateProcessedData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_deesa_prices', jsonEncode(_prices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_palanpur_prices', jsonEncode(_palanpurPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_ahmedabad_prices_v2', jsonEncode(_ahmedabadPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_junagadh_prices_v2', jsonEncode(_junagadhPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_rajkot_prices_v1', jsonEncode(_rajkotPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_agra_prices_v2', jsonEncode(_agraPrices.map((e) => e.toJson()).toList()));
      await prefs.setInt('cache_selected_apmc_index', _selectedApmcIndex);
      await prefs.setString('cache_widget_crops', jsonEncode(_widgetCrops));
      if (_dhaneraImageUrl != null) {
        await prefs.setString('cache_dhanera_image_url', _dhaneraImageUrl!);
      }
      await prefs.setString('cache_dhanera_prices', jsonEncode(_dhaneraPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_amirgadh_prices', jsonEncode(_amirgadhPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_surat_prices', jsonEncode(_suratPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_siddhpur_prices', jsonEncode(_siddhpurPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_radhanpur_prices', jsonEncode(_radhanpurPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_himatnagar_prices', jsonEncode(_himatnagarPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_unjha_prices', jsonEncode(_unjhaPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_mahuva_prices', jsonEncode(_mahuvaPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_gondal_prices', jsonEncode(_gondalPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_botad_prices', jsonEncode(_botadPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_amreli_prices', jsonEncode(_amreliPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_babra_prices', jsonEncode(_babraPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_visnagar_prices', jsonEncode(_visnagarPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_bagasara_prices', jsonEncode(_bagasaraPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_jasdan_prices', jsonEncode(_jasdanPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_jetpur_prices', jsonEncode(_jetpurPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_jamnagar_prices', jsonEncode(_jamnagarPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_rajula_prices', jsonEncode(_rajulaPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_patan_prices', jsonEncode(_patanPrices.map((e) => e.toJson()).toList()));
      await prefs.setString('cache_savarkundla_prices', jsonEncode(_savarkundlaPrices.map((e) => e.toJson()).toList()));
      
      final now = DateTime.now();
      await prefs.setInt('cache_last_updated', now.millisecondsSinceEpoch);
      _lastUpdated = now;
      // Persist per-market timestamps
      for (final entry in _marketLastUpdated.entries) {
        await prefs.setInt('cache_market_updated_${entry.key}', entry.value.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  void setSelectedApmc(int index) {
    if (_selectedApmcIndex != index) {
      _selectedApmcIndex = index;
      _updateProcessedData();
      _saveToCache();
      notifyListeners();
      // Lazily fetch fresh data for the newly-selected market if needed.
      _lazyFetchIfNeeded(index);
    }
  }

  void _updateProcessedData() {
    var currentPrices = apmcPrices;
    final isDeesa = _selectedApmcIndex == 0;
    String selectedMarket = 'Deesa';
    if (_selectedApmcIndex == 1) selectedMarket = 'Palanpur';
    if (_selectedApmcIndex == 2) selectedMarket = 'Ahmedabad';
    if (_selectedApmcIndex == 3) selectedMarket = 'Junagadh';
    if (_selectedApmcIndex == 4) selectedMarket = 'Rajkot';
    if (_selectedApmcIndex == 5) selectedMarket = 'Dhanera';
    if (_selectedApmcIndex == 6) selectedMarket = 'Amirgadh';
    if (_selectedApmcIndex == 7) selectedMarket = 'Surat';
    if (_selectedApmcIndex == 8) selectedMarket = 'Siddhpur';
    if (_selectedApmcIndex == 9) selectedMarket = 'Radhanpur';
    if (_selectedApmcIndex == 10) selectedMarket = 'Himatnagar';
    if (_selectedApmcIndex == 11) selectedMarket = 'Unjha';
    if (_selectedApmcIndex == 12) selectedMarket = 'Mahuva';
    if (_selectedApmcIndex == 13) selectedMarket = 'Gondal';
    if (_selectedApmcIndex == 14) selectedMarket = 'Botad';
    if (_selectedApmcIndex == 15) selectedMarket = 'Amreli';
    if (_selectedApmcIndex == 16) selectedMarket = 'Babra';
    if (_selectedApmcIndex == 17) selectedMarket = 'Visnagar';
    if (_selectedApmcIndex == 18) selectedMarket = 'Agra';
    if (_selectedApmcIndex == 19) selectedMarket = 'Bagasara';
    if (_selectedApmcIndex == 20) selectedMarket = 'Jasdan';
    if (_selectedApmcIndex == 21) selectedMarket = 'Jetpur';
    if (_selectedApmcIndex == 22) selectedMarket = 'Jamnagar';
    if (_selectedApmcIndex == 23) selectedMarket = 'Rajula';
    if (_selectedApmcIndex == 24) selectedMarket = 'Patan';
    if (_selectedApmcIndex == 25) selectedMarket = 'Savarkundla';

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    
    currentPrices = currentPrices.where((p) {
      // Enforce 30-day recency globally for all markets
      final pDate = parseDate(p.date);
      if (pDate == null) return true; // keep if unparseable
      return pDate.isAfter(cutoff) || pDate.isAtSameMomentAs(cutoff);
    }).toList();

    debugPrint('PROCESSED DATA: Index: $_selectedApmcIndex, Market: $selectedMarket, Total: ${apmcPrices.length}, Filtered: ${currentPrices.length}');

    final Map<String, List<CropPrice>> yards = {};
    if (isDeesa || _selectedApmcIndex == 3 || _selectedApmcIndex == 4 || _selectedApmcIndex == 13) {
      for (var price in currentPrices) {
        final yName = price.yardName.isEmpty ? selectedMarket : price.yardName;
        yards.putIfAbsent(yName, () => []).add(price);
      }
    } else {
      yards[selectedMarket] = currentPrices;
    }
    _yardGroups = yards;

    final Map<String, List<CropPrice>> byName = {};
    for (var price in currentPrices) {
      byName.putIfAbsent(price.name, () => []).add(price);
    }
    
    for (var list in byName.values) {
      list.sort((a, b) {
        final aDate = parseDate(a.date);
        final bDate = parseDate(b.date);
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        return b.date.compareTo(a.date);
      });
    }
    _groupedByName = byName;

    final Map<String, List<CropPrice>> byD = {};
    for (var p in currentPrices) {
      byD.putIfAbsent(p.date, () => []).add(p);
    }
    _byDate = byD;

    final dates = byD.keys.toList()..sort((a, b) {
      final aDate = parseDate(a);
      final bDate = parseDate(b);
      if (aDate != null && bDate != null) return bDate.compareTo(aDate);
      return b.compareTo(a);
    });
    _sortedDates = dates;
  }

  void _mergeIntoDeesaHistory(List<CropPrice> freshPrices) {
    if (freshPrices.isEmpty) return;
    final existingSet = _prices.map((p) => '${p.name}_${p.yardName}_${p.date}_${p.minPrice}_${p.maxPrice}').toSet();
    for (var newP in freshPrices) {
      final key = '${newP.name}_${newP.yardName}_${newP.date}_${newP.minPrice}_${newP.maxPrice}';
      if (!existingSet.contains(key)) {
        _prices.add(newP);
      }
    }
  }

  // ── Lazy loading helpers ──────────────────────────────────────────────────

  /// Returns true if this market's data is older than 2 hours (or never fetched).
  bool _isMarketStale(int index) {
    final last = _marketLastUpdated[index];
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(hours: 2);
  }

  /// Fetches [index] market only if its data is empty or the per-market cache is stale (2 h).
  void _lazyFetchIfNeeded(int index) {
    final prices = _pricesForIndex(index);
    if (prices.isEmpty || _isMarketStale(index)) {
      _fetchSingleMarket(index, silent: true);
    }
  }

  /// Called when the app returns to the foreground – re-fetches the active market if stale.
  void fetchOnResume() {
    _lazyFetchIfNeeded(_selectedApmcIndex);
  }

  /// Returns the in-memory price list for a given market index.
  List<CropPrice> _pricesForIndex(int index) {
    switch (index) {
      case 1: return _palanpurPrices;
      case 2: return _ahmedabadPrices;
      case 3: return _junagadhPrices;
      case 4: return _rajkotPrices;
      case 5: return _dhaneraPrices;
      case 6: return _amirgadhPrices;
      case 7: return _suratPrices;
      case 8: return _siddhpurPrices;
      case 9: return _radhanpurPrices;
      case 10: return _himatnagarPrices;
      case 11: return _unjhaPrices;
      case 12: return _mahuvaPrices;
      case 13: return _gondalPrices;
      case 14: return _botadPrices;
      case 15: return _amreliPrices;
      case 16: return _babraPrices;
      case 17: return _visnagarPrices;
      case 18: return _agraPrices;
      case 19: return _bagasaraPrices;
      case 20: return _jasdanPrices;
      case 21: return _jetpurPrices;
      case 22: return _jamnagarPrices;
      case 23: return _rajulaPrices;
      case 24: return _patanPrices;
      case 25: return _savarkundlaPrices;
      default: return _prices; // 0 = Deesa
    }
  }

  /// Fetches a single market by index. The core of lazy loading.
  Future<void> _fetchSingleMarket(int index, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
    }
    try {
      Future<List<CropPrice>> Function()? fetcher;
      switch (index) {
        case 0: fetcher = CropPriceService.fetchPrices; break;
        case 1:
          if (_isPalanpurDateManual && _selectedPalanpurDate != null) {
            fetcher = () async {
              final result = await CropPriceService.fetchPalanpurPrices(date: _selectedPalanpurDate);
              if (result.isEmpty) {
                final key = '${_selectedPalanpurDate!.day}-${_selectedPalanpurDate!.month}-${_selectedPalanpurDate!.year}';
                _emptyPalanpurDates.add(key);
              }
              return result;
            };
          } else {
            fetcher = _fetchPalanpurWithFallback;
          }
          break;
        case 2:
          if (_isAhmedabadDateManual && _selectedAhmedabadDate != null) {
            fetcher = () async {
              final result = await CropPriceService.fetchAhmedabadPrices(date: _selectedAhmedabadDate);
              if (result.isEmpty) {
                final key = '${_selectedAhmedabadDate!.day}-${_selectedAhmedabadDate!.month}-${_selectedAhmedabadDate!.year}';
                _emptyAhmedabadDates.add(key);
              }
              return result;
            };
          } else {
            fetcher = _fetchAhmedabadWithFallback;
          }
          break;
        case 3:
          if (_isJunagadhDateManual && _selectedJunagadhDate != null) {
            fetcher = () async {
              final result = await CropPriceService.fetchJunagadhPrices(date: _selectedJunagadhDate);
              if (result.isEmpty) {
                final key = '${_selectedJunagadhDate!.day}-${_selectedJunagadhDate!.month}-${_selectedJunagadhDate!.year}';
                _emptyJunagadhDates.add(key);
              }
              return result;
            };
          } else {
            fetcher = _fetchJunagadhWithFallback;
          }
          break;
        case 4:
          if (_isRajkotDateManual && _selectedRajkotDate != null) {
            fetcher = () async {
              final result = await CropPriceService.fetchRajkotPrices(date: _selectedRajkotDate);
              if (result.isEmpty) {
                final key = '${_selectedRajkotDate!.day}-${_selectedRajkotDate!.month}-${_selectedRajkotDate!.year}';
                _emptyRajkotDates.add(key);
              }
              return result;
            };
          } else {
            fetcher = _fetchRajkotWithFallback;
          }
          break;
        case 5: fetcher = DhaneraApmcService.fetchPrices; break;
        case 6: fetcher = AmirgadhApmcService.fetchPrices; break;
        case 7: fetcher = SuratApmcService.fetchPrices; break;
        case 8: fetcher = SiddhpurApmcService.fetchPrices; break;
        case 9: fetcher = RadhanpurApmcService.fetchPrices; break;
        case 10: fetcher = HimatnagarApmcService.fetchPrices; break;
        case 11: fetcher = UnjhaApmcService.fetchPrices; break;
        case 12: fetcher = MahuvaApmcService.fetchPrices; break;
        case 13:
          if (_isGondalDateManual && _selectedGondalDate != null) {
            fetcher = () async {
              final result = await GondalApmcService.fetchPrices(date: _selectedGondalDate);
              if (result.isEmpty) {
                final key = '${_selectedGondalDate!.day}-${_selectedGondalDate!.month}-${_selectedGondalDate!.year}';
                _emptyGondalDates.add(key);
              }
              return result;
            };
          } else {
            fetcher = _fetchGondalWithFallback;
          }
          break;
        case 14: fetcher = BotadApmcService.fetchPrices; break;
        case 15: fetcher = AmreliApmcService.fetchPrices; break;
        case 16: fetcher = CropPriceService.fetchBabraPrices; break;
        case 17: fetcher = VisnagarApmcService.fetchPrices; break;
        case 18: fetcher = CropPriceService.fetchAgraPrices; break;
        case 25: fetcher = SavarkundlaApmcService.fetchPrices; break;
        case 24: fetcher = PatanApmcService.fetchPrices; break;
        case 23: fetcher = RajulaApmcService.fetchPrices; break;
        case 22: fetcher = JamnagarApmcService.fetchPrices; break;
        case 21: fetcher = JetpurApmcService.fetchPrices; break;
        case 20: fetcher = JasdanApmcService.fetchPrices; break;
        case 19: fetcher = BagasaraApmcService.fetchPrices; break;
        default: fetcher = null;
      }
      if (fetcher != null) {
        final result = await fetcher();
        _assignResult(index, result);
        // Record per-market fetch timestamp before saving
        _marketLastUpdated[index] = DateTime.now();
        _updateProcessedData();
        await _saveToCache();
      }
    } catch (e) {
      debugPrint('Error fetching market $index: $e');
      if (!silent) _errorMessage = 'Failed to load prices.';
    } finally {
      _isLoading = false;
      _updateProcessedData();
      notifyListeners();
    }
  }

  /// Assigns fetched results to the correct market list.
  void _assignResult(int index, List<CropPrice> result) {
    switch (index) {
      case 0: _mergeIntoDeesaHistory(result); break;
      case 1: _palanpurPrices = result; break;
      case 2: _ahmedabadPrices = result; break;
      case 3: _junagadhPrices = result; break;
      case 4: _rajkotPrices = result; break;
      case 5: _dhaneraPrices = result; break;
      case 6: _amirgadhPrices = result; break;
      case 7: _suratPrices = result; break;
      case 8: _siddhpurPrices = result; break;
      case 9: _radhanpurPrices = result; break;
      case 10: _himatnagarPrices = result; break;
      case 11: _unjhaPrices = result; break;
      case 12: _mahuvaPrices = result; break;
      case 13: _gondalPrices = result; break;
      case 14: _botadPrices = result; break;
      case 15: _amreliPrices = result; break;
      case 16: _babraPrices = result; break;
      case 17: _visnagarPrices = result; break;
      case 18: _agraPrices = result; break;
      case 19: _bagasaraPrices = result; break;
      case 20: _jasdanPrices = result; break;
      case 21: _jetpurPrices = result; break;
      case 22: _jamnagarPrices = result; break;
      case 23: _rajulaPrices = result; break;
      case 24: _patanPrices = result; break;
      case 25: _savarkundlaPrices = result; break;
    }
  }

  // ── Full refresh (manual) ─────────────────────────────────────────────────

  Future<void> fetchPrices({bool forceRefresh = false, bool silent = false}) async {
    if (!forceRefresh && _prices.isNotEmpty && _palanpurPrices.isNotEmpty && 
        _ahmedabadPrices.isNotEmpty && _junagadhPrices.isNotEmpty && 
        _agraPrices.isNotEmpty && _lastUpdated != null) {
      if (DateTime.now().difference(_lastUpdated!) < const Duration(hours: 6)) {
        return;
      }
    }

    if (!silent) {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
    }

    try {
      final List<Future<List<CropPrice>> Function()> fetchers = [
        () => CropPriceService.fetchPrices(), // 0
        () => _isPalanpurDateManual && _selectedPalanpurDate != null
            ? CropPriceService.fetchPalanpurPrices(date: _selectedPalanpurDate).then((res) {
                if (res.isEmpty) {
                  final key = '${_selectedPalanpurDate!.day}-${_selectedPalanpurDate!.month}-${_selectedPalanpurDate!.year}';
                  _emptyPalanpurDates.add(key);
                }
                return res;
              })
            : _fetchPalanpurWithFallback(), // 1
        () => _isAhmedabadDateManual && _selectedAhmedabadDate != null
            ? CropPriceService.fetchAhmedabadPrices(date: _selectedAhmedabadDate).then((res) {
                if (res.isEmpty) {
                  final key = '${_selectedAhmedabadDate!.day}-${_selectedAhmedabadDate!.month}-${_selectedAhmedabadDate!.year}';
                  _emptyAhmedabadDates.add(key);
                }
                return res;
              })
            : _fetchAhmedabadWithFallback(), // 2
        () => _isJunagadhDateManual && _selectedJunagadhDate != null
            ? CropPriceService.fetchJunagadhPrices(date: _selectedJunagadhDate).then((res) {
                if (res.isEmpty) {
                  final key = '${_selectedJunagadhDate!.day}-${_selectedJunagadhDate!.month}-${_selectedJunagadhDate!.year}';
                  _emptyJunagadhDates.add(key);
                }
                return res;
              })
            : _fetchJunagadhWithFallback(), // 3
        () => _isRajkotDateManual && _selectedRajkotDate != null
            ? CropPriceService.fetchRajkotPrices(date: _selectedRajkotDate).then((res) {
                if (res.isEmpty) {
                  final key = '${_selectedRajkotDate!.day}-${_selectedRajkotDate!.month}-${_selectedRajkotDate!.year}';
                  _emptyRajkotDates.add(key);
                }
                return res;
              })
            : _fetchRajkotWithFallback(), // 4
        () => DhaneraApmcService.fetchPrices(), // 5
        () => AmirgadhApmcService.fetchPrices(), // 6
        () => SuratApmcService.fetchPrices(), // 7
        () => SiddhpurApmcService.fetchPrices(), // 8
        () => RadhanpurApmcService.fetchPrices(), // 9
        () => HimatnagarApmcService.fetchPrices(), // 10
        () => UnjhaApmcService.fetchPrices(), // 11
        () => MahuvaApmcService.fetchPrices(), // 12
        () => _isGondalDateManual && _selectedGondalDate != null
            ? GondalApmcService.fetchPrices(date: _selectedGondalDate).then((res) {
                if (res.isEmpty) {
                  final key = '${_selectedGondalDate!.day}-${_selectedGondalDate!.month}-${_selectedGondalDate!.year}';
                  _emptyGondalDates.add(key);
                }
                return res;
              })
            : _fetchGondalWithFallback(), // 13
        () => BotadApmcService.fetchPrices(), // 14
        () => AmreliApmcService.fetchPrices(), // 15
        () => CropPriceService.fetchBabraPrices(), // 16
        () => VisnagarApmcService.fetchPrices(), // 17
        () => CropPriceService.fetchAgraPrices(), // 18
        () => SavarkundlaApmcService.fetchPrices(), // 25
        () => PatanApmcService.fetchPrices(), // 24
        () => RajulaApmcService.fetchPrices(), // 23
        () => JamnagarApmcService.fetchPrices(), // 22
        () => JetpurApmcService.fetchPrices(), // 21
        () => JasdanApmcService.fetchPrices(), // 20
        () => BagasaraApmcService.fetchPrices(), // 19
      ];

      final selectedIndex = _selectedApmcIndex;
      if (selectedIndex >= 0 && selectedIndex < fetchers.length) {
        final result = await fetchers[selectedIndex]();
        _assignResult(selectedIndex, result);
        _updateProcessedData();
        if (!silent) {
           _isLoading = false;
           notifyListeners();
        }
      }

      final List<Future<void>> backgroundTasks = [];
      for (int i = 0; i < fetchers.length; i++) {
        if (i != selectedIndex) {
          backgroundTasks.add(() async {
            try {
              final result = await fetchers[i]();
              _assignResult(i, result);
            } catch (e) {
              debugPrint('Error fetching market $i: $e');
            }
          }());
        }
      }
      
      await Future.wait(backgroundTasks);
      
      _updateProcessedData();
      _pruneHistory();
      await _saveToCache();
    } catch (e) {
      debugPrint('Fetch Error: $e');
      _errorMessage = 'Failed to load daily prices.';
    } finally {
      _isLoading = false;
      _updateProcessedData();
      notifyListeners();
    }
  }

  Future<List<CropPrice>> _fetchJunagadhWithFallback() async {
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      try {
        final results = await JunagadhApmcService.fetchPrices(date: date);
        if (results.isNotEmpty) {
          debugPrint('Junagadh found ${results.length} items on day $i ($date)');
          _selectedJunagadhDate = date;
          return results;
        }
      } catch (e) {
        debugPrint('Junagadh Fallback Error (day $i): $e');
      }
    }
    return [];
  }

  Future<List<CropPrice>> _fetchRajkotWithFallback() async {
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      try {
        final results = await RajkotApmcService.fetchPrices(date: date);
        if (results.isNotEmpty) {
          debugPrint('Rajkot found ${results.length} items on day $i ($date)');
          _selectedRajkotDate = date;
          return results;
        }
      } catch (e) {
        debugPrint('Rajkot Fallback Error (day $i): $e');
      }
    }
    return [];
  }

  Future<void> toggleWidgetCrop(String cropName, {bool isGujarati = false}) async {
    if (_widgetCrops.contains(cropName)) {
      _widgetCrops.remove(cropName);
    } else {
      if (_widgetCrops.length >= 4) {
        _widgetCrops.removeAt(0);
      }
      _widgetCrops.add(cropName);
    }
    await _saveToCache();
    await updateHomeWidget(isGujarati: isGujarati);
    notifyListeners();
  }

  Future<void> updateHomeWidget({bool isGujarati = false}) async {
    try {
      final List<Map<String, String>> widgetData = [];
      for (final cropName in _widgetCrops) {
        final history = _groupedByName[cropName] ?? [];
        if (history.isNotEmpty) {
          final latest = history.first;
          String displayName = isGujarati && latest.gujaratiName.isNotEmpty ? latest.gujaratiName : latest.name;
          String minP = isGujarati ? GujaratiNumberHelper.toGujarati(latest.minPrice) : latest.minPrice;
          String maxP = isGujarati ? GujaratiNumberHelper.toGujarati(latest.maxPrice) : latest.maxPrice;

          widgetData.add({
            'name': displayName,
            'min': minP,
            'max': maxP,
            'date': latest.date,
          });
        }
      }
      await HomeWidget.saveWidgetData<String>('cropData', jsonEncode(widgetData));
      await HomeWidget.saveWidgetData<bool>('isGujarati', isGujarati);
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.farmer.farmer_accounting.CropWidgetProvider');
    } catch (e) {
      debugPrint('Error updating home widget: $e');
    }
  }

  Future<void> requestPinWidget({bool isGujarati = false}) async {
    try {
      if (_widgetCrops.length <= 1) {
        final bool isSupported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
        if (isSupported) {
          await HomeWidget.requestPinWidget(qualifiedAndroidName: 'com.farmer.farmer_accounting.CropWidgetProvider');
        }
      } else {
        await updateHomeWidget(isGujarati: isGujarati);
      }
    } catch (e) {
      debugPrint('Error requesting PinWidget: $e');
    }
  }

  void _pruneHistory() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _prices.removeWhere((p) {
      final pDate = parseDate(p.date);
      if (pDate == null) return false; // keep if unparseable
      return pDate.isBefore(cutoff);
    });
  }

  Future<List<CropPrice>> _fetchPalanpurWithFallback() async {
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      try {
        final results = await CropPriceService.fetchPalanpurPrices(date: date);
        if (results.isNotEmpty) {
          debugPrint('Palanpur found ${results.length} items on day $i ($date)');
          _selectedPalanpurDate = date;
          return results;
        }
      } catch (e) {
        debugPrint('Palanpur Fallback Error (day $i): $e');
      }
    }
    return [];
  }

  Future<List<CropPrice>> _fetchAhmedabadWithFallback() async {
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      try {
        final results = await CropPriceService.fetchAhmedabadPrices(date: date);
        if (results.isNotEmpty) {
          debugPrint('Ahmedabad found ${results.length} items on day $i ($date)');
          _selectedAhmedabadDate = date;
          return results;
        }
      } catch (e) {
        debugPrint('Ahmedabad Fallback Error (day $i): $e');
      }
    }
    return [];
  }

  Future<List<CropPrice>> _fetchGondalWithFallback() async {
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      try {
        final results = await GondalApmcService.fetchPrices(date: date);
        if (results.isNotEmpty) {
          debugPrint('Gondal found ${results.length} items on day $i ($date)');
          _selectedGondalDate = date;
          return results;
        }
      } catch (e) {
        debugPrint('Gondal Fallback Error (day $i): $e');
      }
    }
    return [];
  }
}
