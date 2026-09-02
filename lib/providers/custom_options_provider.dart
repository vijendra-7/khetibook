import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/custom_options_manager.dart';
import '../database/app_database.dart';

class CustomOptionsProvider with ChangeNotifier {
  StreamSubscription? _dbSubscription;

  CustomOptionsProvider() {
    _dbSubscription = AppDatabase.instance.onDataChangedStream.listen((_) {
      // Refresh all currently loaded categories, but DON'T trigger more DB writes here
      final categories = _all.keys.toList();
      for (final cat in categories) {
        // We use loadOptions but maybe we should avoid the auto-adder here
        _reloadOnly(cat);
      }
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  final Map<String, List<String>> _predefined = {};
  final Map<String, List<String>> _custom = {};
  final Map<String, List<String>> _all = {};

  List<String> getPredefined(String category) => _predefined[category] ?? [];
  List<String> getCustom(String category) => _custom[category] ?? [];
  List<String> getAll(String category) => _all[category] ?? [];

  Future<void> loadOptions(String category) async {
    if (category == CustomOptionsManager.categorysCrops) {
      await ensureUsedCropsAreAdded();
    }
    await _reloadOnly(category);
  }

  Future<void> _reloadOnly(String category) async {
    final predefinedRaw = await CustomOptionsManager.getAccessiblePredefined(category);
    final customRaw = await CustomOptionsManager.getCustomOptions(category);
    
    // Deduplicate custom list (in case DB has duplicates inherited from older versions)
    final Map<String, String> uniqueCustomMap = {};
    for (final c in customRaw) {
      uniqueCustomMap[c.toLowerCase().trim()] = c;
    }
    final deduplicatedCustom = uniqueCustomMap.values.toList();
    
    // Filter predefined: if an option is in custom_options, hide it from predefined display
    final customLower = uniqueCustomMap.keys.toSet();
    _predefined[category] = predefinedRaw.where((p) => !customLower.contains(p.toLowerCase().trim())).toList();
    _custom[category] = deduplicatedCustom;
    
    _all[category] = await CustomOptionsManager.getAllOptions(category);
    notifyListeners();
  }

  /// Automatically add crops that have existing entries in investments/outputs
  Future<void> ensureUsedCropsAreAdded() async {
    try {
      final used = await AppDatabase.instance.getUsedCrops();
      final currentCustom = await CustomOptionsManager.getCustomOptions(CustomOptionsManager.categorysCrops);
      final currentCustomSet = currentCustom.map((e) => e.toLowerCase()).toSet();

      for (final crop in used) {
        if (!currentCustomSet.contains(crop.toLowerCase())) {
          await CustomOptionsManager.addCustomOption(CustomOptionsManager.categorysCrops, crop);
        }
      }
    } catch (e) {
      debugPrint('Error in ensureUsedCropsAreAdded: $e');
    }
  }

  Future<void> addOption(String category, String value) async {
    await CustomOptionsManager.addCustomOption(category, value);
    await loadOptions(category);
  }

  Future<void> removeOption(String category, String value) async {
    await CustomOptionsManager.removeCustomOption(category, value);
    await loadOptions(category);
  }

  Future<bool> canDeleteOption(String category, String value) async {
    return await CustomOptionsManager.canDeleteOption(category, value);
  }

  void refresh(String category) {
    _predefined.remove(category);
    _custom.remove(category);
    _all.remove(category);
    notifyListeners();
  }
}
