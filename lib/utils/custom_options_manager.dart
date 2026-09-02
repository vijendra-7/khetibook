import '../database/app_database.dart';
import '../models/custom_option.dart';

class CustomOptionsManager {
  static const categorysCrops = 'crops';
  static const categoryServiceProviders = 'service_providers';
  static const categoryTractorProviders = 'tractor_providers';
  static const categoryInvestmentTypes = 'investment_types';
  static const categoryEquipmentTypes = 'equipment_types';
  static const categoryBuyers = 'buyers';
  static const categoryDrivers = 'drivers';
  static const categoryDawa = 'dawa';
  static const categoryKhatar = 'khatar';
  static const categoryFields = 'fields';
  static const categoryHelpers = 'helpers';
  // Per-crop seed variety categories
  static const categoryBatakaSeeds = 'bataka_seeds';
  static const categoryMagfaliSeeds = 'magfali_seeds';
  static const categoryGhauSeeds = 'ghau_seeds';
  static const categoryTarbuchSeeds = 'tarbuch_seeds';
  static const categoryBajariSeeds = 'bajari_seeds';

  static String? seedCategoryForCrop(String crop) => const {
    'Bataka': categoryBatakaSeeds,
    'Magfali': categoryMagfaliSeeds,
    'Ghau': categoryGhauSeeds,
    'Tarbuch': categoryTarbuchSeeds,
    'Bajari': categoryBajariSeeds,
  }[crop];

  static const _predefined = {
    categorysCrops: ['Bataka', 'Magfali', 'Bajari', 'Tarbuch', 'Ghau'],
    categoryServiceProviders: [],
    categoryTractorProviders: [],
    categoryInvestmentTypes: ['Biyaran', 'Khatar', 'Dawa', 'Khed', 'Rotavator', 'Peyani', 'Plough', 'Zero', 'Thresher', 'Others'],
    categoryEquipmentTypes: [],
    categoryKhatar: ['DAP', 'NPK', 'Urea', 'MOP- POTASH', 'Sulphate', 'Sulphur', 'Zinc'],
    categoryDawa: [],
    categoryBuyers: [],
    categoryDrivers: [],
    categoryBatakaSeeds: ['Pukhraj', 'Khyati', 'Badshah', 'HyFun', 'Manali', 'Columbo'],
    categoryMagfaliSeeds: ['24 number', 'TG 37A', 'GG20', 'GG2', 'Somnath', 'Kadiri-9', 'Girnar-2'],
    categoryGhauSeeds: ['GW322', 'Lok-1', 'HD2781', 'WL711', 'GW496'],
    categoryTarbuchSeeds: ['Sugar Baby', 'Arka Manik', 'Kiran', 'Shingar', 'NS295'],
    categoryBajariSeeds: ['GHB558', 'GHB719', 'HHB67', 'GHB538', 'Pusa Composite'],
    categoryFields: [],
    categoryHelpers: [],
  };

  static List<String> getPredefined(String category) {
    return List<String>.from(_predefined[category] ?? []);
  }

  static Future<List<String>> getAccessiblePredefined(String category) async {
    final allPredefined = getPredefined(category);
    final db = AppDatabase.instance;
    
    // Check custom_options table for isDeleted=1 for these predefined values
    final deletedFromDb = await db.getDeletedCustomOptionsByCategory(category);
    final deletedValues = deletedFromDb.map((o) => o.value).toSet();
    
    return allPredefined.where((val) => !deletedValues.contains(val)).toList();
  }

  static Future<List<String>> getCustomOptions(String category) async {
    final opts = await AppDatabase.instance.getCustomOptionsByCategory(category);
    return opts.map((o) => o.value).toList();
  }

  static Future<List<String>> getAllOptions(String category) async {
    final predefined = await getAccessiblePredefined(category);
    final custom = await getCustomOptions(category);
    
    // Case-insensitive deduplication
    final Map<String, String> uniqueOptions = {};
    for (final opt in predefined) {
      uniqueOptions[opt.toLowerCase().trim()] = opt;
    }
    for (final opt in custom) {
      final key = opt.toLowerCase().trim();
      if (!uniqueOptions.containsKey(key)) {
        uniqueOptions[key] = opt;
      }
    }
    
    return uniqueOptions.values.toList();
  }

  static Future<void> addCustomOption(String category, String value) async {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return;

    final existing = await getAllOptions(category);
    final existingLower = existing.map((e) => e.toLowerCase().trim()).toSet();
    
    if (!existingLower.contains(trimmedValue.toLowerCase())) {
      // Check if it was a deleted predefined option
      final db = AppDatabase.instance;
      final wasDeleted = await db.restoreDeletedCustomOption(category, trimmedValue);
      if (!wasDeleted) {
        final opt = CustomOption(category: category, value: trimmedValue);
        await db.insertCustomOption(opt);
      }
    }
  }

  static Future<bool> canDeleteOption(String category, String value) async {
    if (category == categorysCrops) {
      return !(await AppDatabase.instance.hasEntriesForCrop(value));
    }
    return true;
  }

  static Future<void> removeCustomOption(String category, String value) async {
    await AppDatabase.instance.softDeleteCustomOption(category, value);
  }
}
