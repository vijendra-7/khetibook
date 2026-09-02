class CropCategoryUtils {
  static const String catAll = 'All';
  static const String catVegetables = 'Vegetables';
  static const String catGrains = 'Grains';
  static const String catOilseeds = 'Oilseeds';
  static const String catPulses = 'Pulses';
  static const String catSpices = 'Spices';
  static const String catFruits = 'Fruits';
  static const String catOthers = 'Others';

  static const List<String> categories = [
    catAll,
    catVegetables,
    catGrains,
    catOilseeds,
    catPulses,
    catSpices,
    catFruits,
    catOthers,
  ];

  static const Map<String, String> gujaratiCategories = {
    catAll: 'બધા',
    catVegetables: 'શાકભાજી',
    catGrains: 'અનાજ',
    catOilseeds: 'તેલીબિયાં',
    catPulses: 'કઠોળ',
    catSpices: 'મસાલા',
    catFruits: 'ફળ',
    catOthers: 'અન્ય',
  };

  static String getCategory(String cropName) {
    if (cropName.isEmpty) return catOthers;
    
    final lowerName = cropName.toLowerCase();
    
    // Default single category logic
    if (_isVegetable(lowerName)) return catVegetables;
    if (_isOilseed(lowerName)) return catOilseeds;
    if (_isPulse(lowerName)) return catPulses;
    if (_isSpice(lowerName)) return catSpices;
    if (_isFruit(lowerName)) return catFruits;
    if (_isGrain(lowerName)) return catGrains;
    
    return catOthers;
  }

  /// Returns true if a crop belongs to a category. 
  /// Supports dual categorization for items like Maize, Peas, and Beans.
  static bool isInCategory(String cropName, String category) {
    if (category == catAll) return true;
    if (cropName.isEmpty) return category == catOthers;

    final lowerName = cropName.toLowerCase();

    if (category == catVegetables) return _isVegetable(lowerName);
    
    // Grains & Pulses often overlap in dual-usage (Maize, Peas, Beans)
    if (category == catGrains) {
      // Maize is both a Vegetable (Sweet Corn) and a Grain
      if (_containsAny(lowerName, ['maize', 'મકાઈ', 'makai'])) return true;
      return _isGrain(lowerName);
    }

    if (category == catPulses) {
      // Peas and Beans are both Vegetables and Pulses
      if (_containsAny(lowerName, ['peas', 'વટાણા', 'vatana', 'beans', 'વાલોળ', 'valor', 'પાપડી', 'choli', 'ચોળી'])) return true;
      // Green variants of pulses are vegetables but also pulses
      if (_containsAny(lowerName, ['લીલો', 'લીલા', 'લીલી'])) {
         if (_isPulse(lowerName)) return true;
      }
      return _isPulse(lowerName);
    }

    if (category == catOilseeds) return _isOilseed(lowerName);
    if (category == catSpices) return _isSpice(lowerName);
    if (category == catFruits) return _isFruit(lowerName);
    if (category == catOthers) {
      return getCategory(cropName) == catOthers;
    }

    return false;
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw.toLowerCase())) return true;
    }
    return false;
  }

  static bool _isVegetable(String name) {
    return _containsAny(name, [
      'potato', 'બટાકા', 'બટેટા', 'આગ્રા',
      'tomato', 'ટામેટા', 'ટમેટાં',
      'onion', 'ડુંગળી', // Explicitly placed in Vegetable
      'cabbage', 'કોબીજ',
      'cauliflower', 'ફુલેવર', 'ફલાવર',
      'brinjal', 'ringan', 'રીંગણ', 'રીંગણા', 'રવૈયા',
      'okra', 'bhindi', 'ભીંડા', 'ભીંડો',
      'gourd', 'દૂધી', 'ગલકા', 'તુરિયા', 'કારેલા', 'ટીંડોળા', 'ગીલોડા', 'પરવળ', 'કોળું', 'કુન્દરું', 'પડોળા',
      'lemon', 'limbu', 'લીંબુ',
      'carrot', 'ગજર', 'ગાજર',
      'beetroot', 'બીટ',
      'radish', 'મૂળા', 'મોગરી',
      'spinach', 'પાલક', 'તાંદળજો', 'ભાજી', 'પાંદડા',
      'cucumber', 'કાકડી', 'kheera',
      'chilli', 'મરચા', 'મરચું', 'સીમલા', 'શિમલા', 'capsicum',
      'peapod', 'વટાણા', 'લીલા વટાણા', 'મકાઈ (સ્વીટ કોર્ન)', 'સ્વીટ કોર્ન',
      'beans', 'choli', 'ચોળી', 'વાલોળ', 'પાપડી', 'ફણસી', 'ગુવાર', 'gavar', 'ગોવાર',
      'suran', 'સુરણ', 'રતાળુ', 'શક્કરીયા', 'અળવી',
      'drumstick', 'સરગવો',
      'kothmir', 'કોથમીર', // Included as leafy veg
    ]);
  }

  static bool _isGrain(String name) {
    return _containsAny(name, [
      'wheat', 'ઘઉં', 'લોકવન', 'ટુકડા',
      'bajri', 'bajra', 'બાજરી',
      'jowar', 'જુવાર',
      'maize', 'મકાઈ',
      'paddy', 'ડાંગર',
      'barley', 'જવ',
      'ragi', 'રાગી', 'નાગલી',
      'rajgaro', 'રાજગરો', 'રાજગીર',
      'sorghum',
    ]);
  }

  static bool _isOilseed(String name) {
    return _containsAny(name, [
      'groundnut', 'peanut', 'મગફળી', 'g-20', 'girnar', // Covers "મગફળી"
      'castor', 'ricinus', 'એરંડા',
      'mustard', 'રાયડો', 'સરસવ',
      'sesamum', 'sesame', 'તલ', 'કાળા તલ', 'સફેદ તલ',
      'soyabean', 'soybean', 'સોયાબીન',
    ]);
  }

  static bool _isPulse(String name) {
    return _containsAny(name, [
      'gram', 'chana', 'ચણા', 'કાબુલી', 'chickpea',
      'mung', 'moong', 'મગ', // Placed after _isOilseed
      'urad', 'urd', 'અડદ',
      'tuver', 'pigeon pea', 'arhar', 'તુવેર',
      'cowpea', 
      'mataki', 'મઠ',
    ]);
  }

  static bool _isSpice(String name) {
    return _containsAny(name, [
      'cumin', 'jeera', 'જીરું',
      'coriander', 'corriander', 'ધાણા', // Coriander seed
      'fennel', 'soanf', 'વરિયાળી',
      'fenugreek', 'methi', 'મેથી',
      'ajwain', 'ajwan', 'અજમો',
      'garlic', 'lasan', 'લસણ',
      'ginger', 'adu', 'આદુ',
      'turmeric', 'હળદર',
      'dill', 'suva', 'સુવાદાણા', 'સુવા',
      'kalonji', 'nigella', 'કલૌંજી',
    ]);
  }

  static bool _isFruit(String name) {
    return _containsAny(name, [
      'apple', 'સફરજન',
      'banana', 'કેળા',
      'mango', 'કેરી',
      'papaya', 'પપૈયા', 'પપૈયું',
      'pomegranate', 'દાડમ',
      'watermelon', 'તરબૂચ',
      'muskmelon', 'ટેટી',
      'sapota', 'ચીકુ',
      'guava', 'જામફળ',
      'custard apple', 'સીતાફળ',
      'coconut', 'નાળિયેર',
      'amla', 'આમળા',
      'gunda', 'ગુંદા',
      'tamarind', 'આંબલી',
    ]);
  }
}
