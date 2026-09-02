class LanguageMapper {
  static const Map<String, String> _cropMapGu = {
    'Bataka': 'બટાકા',
    'Magfali': 'મગફળી',
    'Bajari': 'બાજરી',
    'Tarbuch': 'તરબૂચ',
    'Ghau': 'ઘઉ',
    'Cauliflower': 'ફુલેવર',
    'Gavar': 'ગુવાર',
    'Mustard': 'રાયડો',
    'Mustard_agra': 'સરસવ',
    'Castor': 'એરંડા',
    'Cumin': 'જીરું',
    'Chana': 'ચણા',
    'Groundnut': 'મગફળી',
    'Methi': 'મેથી',
    'Bajri': 'બાજરી',
    'Custard': 'સીતાફળ',
    'Wheat': 'ઘઉં',
    'Chola': 'ચોળા',
    'Cowpea': 'ચોળા',
  };

  static String _ls(Map<String, String> map, String key) {
    // Case-insensitive lookup
    final lowerKey = key.toLowerCase().trim();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == lowerKey) return entry.value;
    }
    return map[key] ?? key;
  }

  static const _investmentTypeMapGu = {
    'Biyaran': 'બિયારણ',
    'Khatar': 'ખાતર',
    'Dawa': 'દવા',
    'Khed': 'ખેડ',
    'Rotavator': 'રોટાવેટર',
    'Peyani': 'પેયણી',
    'Plough': 'પ્લાઉ',
    'Zero': 'ઝેરો',
    'Thresher': 'થ્રેશર',
    'Digger': 'ડીગર',
    'Others': 'અન્ય',
  };

  static const _serviceProviderMapGu = {
    'Ramesh Bhai': 'રમેશ ભાઈ',
    'Suresh Bhai': 'સુરેશ ભાઈ',
    'Mahesh Agro': 'મહેશ એગ્રો',
    'N.P Patel': 'એન.પી.પટેલ',
    'Babulal': 'બાબુલાલ',
  };

  static const _equipmentTypeMapGu = {
    'Khed': 'ખેડ',
    'Rotavator': 'રોટાવેટર',
    'Peyani': 'પેયણી',
    'Plough': 'પ્લાઉ',
    'Thresher': 'થ્રેશર',
    'Zero': 'ઝેરો',
    'Digger': 'ડીગર',
    'Tola no Fero': 'ટોળા નો ફેરો',
    'Others': 'અન્ય',
  };

  static const _transactionTypeMapGu = {
    'Upaad': 'ઉપાડ',
    'Bhaag': 'ભાગ',
    'Majur': 'મજૂર',
    'Tractor': 'ટ્રેક્ટર',
  };

  static const _seedTypeMapGu = {
    'Desi': 'દેશી',
    'Hybrid': 'હાઇબ્રિડ',
    'Imported': 'આયાતી',
  };

  static const _batakaSeedMapGu = {
    'Pukhraj': 'પુખરાજ',
    'Khyati': 'ખ્યાતી',
    'Badshah': 'બાદશાહ',
    'HyFun': 'હાયફન',
    'Manali': 'મનાલી',
    'Columbo': 'કોલંબો',
  };

  static const _magfaliSeedMapGu = {
    '24 number': '24 નંબર',
    'TG 37A': 'ટીજી 37એ',
    'GG20': 'જીજી 20',
    'GG2': 'જીજી 2',
    'Somnath': 'સોમનાથ',
    'Kadiri-9': 'કાદિરી-9',
    'Girnar-2': 'ગિરનાર-2',
  };

  static const _ghauSeedMapGu = {
    'GW322': 'જીડબ્લ્યુ 322',
    'Lok-1': 'લોક-1',
    'HD2781': 'એચડી 2781',
    'WL711': 'ડબ્લ્યુએલ 711',
    'GW496': 'જીડબ્લ્યુ 496',
  };

  static const _tarbuchSeedMapGu = {
    'Sugar Baby': 'શુગર બેબી',
    'Arka Manik': 'અર્કા માણિક',
    'Kiran': 'કિરણ',
    'Shingar': 'શિંગાર',
    'NS295': 'એનએસ 295',
  };

  static const _bajariSeedMapGu = {
    'GHB558': 'જીએચબી 558',
    'GHB719': 'જીએચબી 719',
    'HHB67': 'એચએચબી 67',
    'GHB538': 'જીએચબી 538',
    'Pusa Composite': 'પુસા કોમ્પોઝિટ',
  };

  static const _allSeedMapsGu = <String, Map<String, String>>{
    'Bataka': _batakaSeedMapGu,
    'Magfali': _magfaliSeedMapGu,
    'Ghau': _ghauSeedMapGu,
    'Tarbuch': _tarbuchSeedMapGu,
    'Bajari': _bajariSeedMapGu,
  };

  static const _buyerMapGu = {
    'Hiro Kako': 'હિરો કાકો',
    'Natwaralal': 'નટવરલાલ',
  };

  static const _driverMapGu = {
    'Laxman': 'લક્ષ્મણ',
    'Dinesh': 'દિનેશ',
    'Tino': 'ટીનો',
  };

  static const _fertilizerMapGu = {
    'DAP': 'ડીએપી',
    'NPK': 'એનપીકે',
    'Urea': 'યુરિયા',
    'MOP- POTASH': 'પોટાશ',
    'Sulphate': 'સલ્ફેટ',
    'Sulphur': 'સલ્ફર',
    'Zinc': 'ઝીંક',
    'Potash': 'પોટાશ',
    'Suphala': 'સુફલા',
    'Calcium': 'કેલ્શિયમ',
    'Magnesium': 'મેગ્નેશિયમ',
    'Bentonite': 'બેન્ટોનાઈટ',
    'Prom': 'પ્રોમ',
    'Ammonium': 'એમોનિયમ',
  };

  static const Map<String, String> _medicineMapGu = {
    // Add common medicines if known, or leave empty for dynamic
  };

  static String localizedQuantityUnit(String crop, bool gujarati) {
    if (crop == 'Bajari' || crop == 'Ghau' || crop == 'બાજરી' || crop == 'ઘઉ') {
      return gujarati ? 'થેલી' : 'Theli';
    }
    return gujarati ? 'કટા' : 'Kata';
  }

  // ── To localized ──
  static String localizedCrop(String en, bool gujarati, [Map<String, String>? globalMap]) {
    if (gujarati) {
      if (globalMap != null && globalMap.containsKey(en)) return globalMap[en]!;
      return _ls(_cropMapGu, en);
    }
    // For English, also try to fetch the premium display name from the global map
    if (globalMap != null && globalMap.containsKey(en)) return globalMap[en]!;
    return en;
  }

  static String localizedInvestmentType(String en, bool gujarati, [Map<String, String>? globalMap]) {
    if (gujarati) {
      if (globalMap != null && globalMap.containsKey(en)) return globalMap[en]!;
      return _ls(_investmentTypeMapGu, en);
    }
    // For English, also try to fetch the premium display name from the global map
    if (globalMap != null && globalMap.containsKey(en)) return globalMap[en]!;
    if (en == 'Dawa') return 'Medicine';
    if (en == 'Khatar') return 'Fertilizer';
    if (en == 'Shed') return 'Khed';
    return en;
  }

  static String localizedServiceProvider(String en, bool gujarati) =>
      gujarati ? _ls(_serviceProviderMapGu, en) : en;

  static String localizedEquipmentType(String en, bool gujarati) =>
      gujarati ? _ls(_equipmentTypeMapGu, en) : en;

  static String localizedTransactionType(String en, bool gujarati) =>
      gujarati ? _ls(_transactionTypeMapGu, en) : en;

  static String localizedSeedType(String en, bool gujarati) =>
      gujarati ? _ls(_seedTypeMapGu, en) : en;

  static String localizedBuyer(String en, bool gujarati) =>
      gujarati ? _ls(_buyerMapGu, en) : en;

  static String localizedDriver(String en, bool gujarati) =>
      gujarati ? _ls(_driverMapGu, en) : en;

  static String localizedBatakaSeed(String en, bool gujarati) =>
      gujarati ? _ls(_batakaSeedMapGu, en) : en;

  static List<String> localizedBatakaSeeds(List<String> seeds, bool gujarati) =>
      seeds.map((s) => localizedBatakaSeed(s, gujarati)).toList();

  /// Localize a seed variety name for any crop using its English name.
  static String localizedSeedForCrop(String crop, String en, bool gujarati) {
    if (!gujarati) return en;
    return (_allSeedMapsGu[crop]?[en]) ?? en;
  }

  static String localizedAgriItem(String en, bool gujarati) {
    if (!gujarati) return en;
    final fert = _ls(_fertilizerMapGu, en);
    if (fert != en) return fert;
    return _ls(_medicineMapGu, en);
  }

  /// Localize a list of seeds for a given crop.
  static List<String> localizedSeedsForCrop(String crop, List<String> seeds, bool gujarati) =>
      seeds.map((s) => localizedSeedForCrop(crop, s, gujarati)).toList();

  /// Generic method to localize any custom option value based on its category.
  static String localizedOption(
    String category,
    String value,
    bool gujarati, {
    Map<String, String>? globalCropMap,
    Map<String, String>? globalInvestmentTypeMap,
  }) {
    if (!gujarati) return value;
    switch (category) {
      case 'crops':
        return localizedCrop(value, true, globalCropMap);
      case 'service_providers':
      case 'tractor_providers':
        return localizedServiceProvider(value, true);
      case 'investment_types':
        return localizedInvestmentType(value, true, globalInvestmentTypeMap);
      case 'equipment_types':
        return localizedEquipmentType(value, true);
      case 'buyers':
        return localizedBuyer(value, true);
      case 'drivers':
        return localizedDriver(value, true);
      case 'dawa':
      case 'khatar':
        return localizedAgriItem(value, true);
      case 'bataka_seeds':
        return localizedSeedForCrop('Bataka', value, true);
      case 'magfali_seeds':
        return localizedSeedForCrop('Magfali', value, true);
      case 'ghau_seeds':
        return localizedSeedForCrop('Ghau', value, true);
      case 'tarbuch_seeds':
        return localizedSeedForCrop('Tarbuch', value, true);
      case 'bajari_seeds':
        return localizedSeedForCrop('Bajari', value, true);
      default:
        return value;
    }
  }

  /// Convert a localized seed name back to English for a given crop.
  static String englishSeedForCrop(String crop, String localized, bool gujarati) {
    if (!gujarati) return localized;
    final map = _allSeedMapsGu[crop];
    if (map == null) return localized;
    return map.entries
        .firstWhere((e) => e.value == localized,
            orElse: () => MapEntry(localized, localized))
        .key;
  }

  // ── To English ──
  static String englishCrop(String localized, bool gujarati, [Map<String, String>? globalMap]) {
    if (!gujarati) return localized;
    final entry = _cropMapGu.entries.cast<MapEntry<String, String>?>().firstWhere(
          (e) => e?.value == localized,
          orElse: () => null,
        );
    if (entry != null) return entry.key;
    if (globalMap != null) {
      final globalEntry = globalMap.entries.cast<MapEntry<String, String>?>().firstWhere(
            (e) => e?.value == localized,
            orElse: () => null,
          );
      if (globalEntry != null) return globalEntry.key;
    }
    return localized;
  }

  static String englishInvestmentType(String localized, bool gujarati, [Map<String, String>? globalMap]) {
    if (!gujarati) {
      if (localized == 'Medicine') return 'Dawa';
      if (localized == 'Fertilizer') return 'Khatar';
      if (localized == 'Khed') return 'Shed';
      return localized;
    }
    final entry = _investmentTypeMapGu.entries.cast<MapEntry<String, String>?>().firstWhere(
          (e) => e?.value == localized,
          orElse: () => null,
        );
    if (entry != null) return entry.key;
    if (globalMap != null) {
      final globalEntry = globalMap.entries.cast<MapEntry<String, String>?>().firstWhere(
            (e) => e?.value == localized,
            orElse: () => null,
          );
      if (globalEntry != null) return globalEntry.key;
    }
    return localized;
  }

  static String englishServiceProvider(String localized, bool gujarati) {
    if (!gujarati) return localized;
    return _serviceProviderMapGu.entries
            .firstWhere((e) => e.value == localized,
                orElse: () => MapEntry(localized, localized))
            .key;
  }

  static String localizedWorkLabel(bool gu) => gu ? 'કામ' : 'Work';

  static String englishEquipmentType(String type, bool gu) {
    if (!gu) return type;
    return _equipmentTypeMapGu.entries
        .firstWhere((e) => e.value == type, orElse: () => MapEntry(type, type))
        .key;
  }

  static String localizedPersonForWork(String? equipmentType, bool gu) {
    if (equipmentType == null || equipmentType.isEmpty) {
      return gu ? 'ડ્રાઈવરનું નામ' : 'Driver Name';
    }

    final en = englishEquipmentType(equipmentType, gu);

    if (en == 'Khed') {
      return gu ? 'કલ્ટિવેટર ચલાવનાર નું નામ' : 'Cultivator Driver Name';
    }

    if (en == 'Tola no Fero' || en == 'Others') {
      return gu ? 'ડ્રાઈવરનું નામ' : 'Driver Name';
    }

    final localizedWork = localizedEquipmentType(en, gu);
    return gu ? '$localizedWork ચલાવનાર નું નામ' : '$en Driver Name';
  }

  static String englishSeedType(String localized, bool gujarati) {
    if (!gujarati) return localized;
    return _seedTypeMapGu.entries
            .firstWhere((e) => e.value == localized,
                orElse: () => MapEntry(localized, localized))
            .key;
  }

  static String englishBuyer(String localized, bool gujarati) {
    if (!gujarati) return localized;
    return _buyerMapGu.entries
            .firstWhere((e) => e.value == localized,
                orElse: () => MapEntry(localized, localized))
            .key;
  }

  static String englishDriver(String localized, bool gujarati) {
    if (!gujarati) return localized;
    return _driverMapGu.entries
            .firstWhere((e) => e.value == localized,
                orElse: () => MapEntry(localized, localized))
            .key;
  }

  static String englishBatakaSeed(String localized, bool gujarati) {
    if (!gujarati) return localized;
    return _batakaSeedMapGu.entries
            .firstWhere((e) => e.value == localized,
                orElse: () => MapEntry(localized, localized))
            .key;
  }

  static String englishTransactionType(String localized, bool gujarati) {
    if (!gujarati) return localized;
    return _transactionTypeMapGu.entries
            .firstWhere((e) => e.value == localized,
                orElse: () => MapEntry(localized, localized))
            .key;
  }

  static String englishAgriItem(String localized, bool gujarati) {
    if (!gujarati) return localized;
    final fertEntry = _fertilizerMapGu.entries.cast<MapEntry<String, String>?>().firstWhere(
          (e) => e?.value == localized,
          orElse: () => null,
        );
    if (fertEntry != null) return fertEntry.key;
    
    final medEntry = _medicineMapGu.entries.cast<MapEntry<String, String>?>().firstWhere(
          (e) => e?.value == localized,
          orElse: () => null,
        );
    if (medEntry != null) return medEntry.key;
    
    return localized;
  }
}
