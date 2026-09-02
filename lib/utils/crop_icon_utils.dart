import 'package:flutter/material.dart';

class CropIconUtils {
  static const String _iconBasePath = 'assets/icons/';

  static const Map<String, String> _cropIconMap = {
    // English Keys
    'potato': 'potato.webp',
    'wheat': 'wheat.webp',
    'cotton': 'cotton.webp',
    'mustard': 'mustard.webp',
    'cumin': 'cumin.webp',
    'bajra': 'bajra.webp',
    'tomato': 'tomato.webp',
    'groundnut': 'groundnut.webp',
    'groundut': 'groundnut.webp',
    'castor': 'castor.webp',
    'chana': 'chana.webp',
    'lemon': 'lemon.webp',
    'onion': 'onion.webp',
    'chilli': 'chilli.webp',
    'garlic': 'garlic.webp',
    'cauliflower': 'cauliflower.webp',
    'caulifiower': 'cauliflower.webp',
    'rajgaro': 'rajgaro.webp',
    'jowar': 'jowar.webp',
    'variyali': 'variyali.webp',
    'isabgul': 'isabgul.webp',
    'guwar': 'guwar.webp',
    'mung': 'mung.webp',
    'urad': 'urad.webp',
    'tuver': 'tuver.webp',
    'til': 'til.webp',
    'methi': 'methi.webp',
    'maize': 'maize.webp',
    'halder': 'halder.webp',
    'adu': 'adu.webp',
    'soybean': 'soybean.webp',
    'apple': 'apple.webp',
    'pomegranate': 'pomegranate.webp',
    'banana': 'banana.webp',
    'barley': 'barley.webp',
    // Local Synonyms for deduplication
    'bataka': 'potato.webp',
    'ghau': 'wheat.webp',
    'magfali': 'groundnut.webp',
    'bajari': 'bajra.webp',
    'bajri': 'bajra.webp',
    'tarbuch': 'watermelon.webp',
    'beetroot': 'beetroot.webp',
    'okra': 'okra.webp',
    'cabbage': 'cabbage.webp',
    'carrot': 'carrot.webp',
    'dudhi': 'dudhi.webp',
    'cucumber': 'cucumber.webp',
    'karela': 'karela.webp',
    'mango': 'mango.webp',
    'papaya': 'papaya.webp',
    'peas': 'peas.webp',
    'ragi': 'ragi.webp',
    'paddy': 'paddy.webp',
    'brinjal': 'brinjal.webp',
    'tindora': 'tindora.webp',
    'watermelon': 'watermelon.webp',
    'coconut': 'coconut.webp',
    'grapes': 'grapes.webp',
    'guava': 'guava.webp',
    'tobacco': 'tobacco.webp',
    'tobbaco': 'tobacco.webp',
    'tobacco leaf': 'tobacco.webp',
    'tobacco seed': 'tobacco.webp',
    'bitter gourd': 'karela.webp',
    'lady finger': 'okra.webp',
    'eggplant': 'brinjal.webp',
    'cluster beans': 'guwar.webp',
    'guar seed': 'guwar.webp',
    'ridge gourd': 'turiya.webp',
    'sponge gourd': 'turiya.webp',
    'indian beans': 'valor.webp',
    'ginger': 'adu.webp',
    'turmeric': 'halder.webp',
    'green gram': 'mung.webp',
    'black gram': 'urad.webp',
    'chickpea': 'chana.webp',
    'gram': 'chana.webp',
    'bengal gram': 'chana.webp',
    'moong': 'mung.webp',
    'mung bean': 'mung.webp',
    'urd beans': 'urad.webp',
    'green peas': 'peas.webp',
    'pea pod': 'peas.webp',
    'peas cod': 'peas.webp',
    'bhindi': 'okra.webp',
    'ladies finger': 'okra.webp',
    'snake gourd': 'turiya.webp',
    'arhar': 'tuver.webp',
    'fennel seeds': 'variyali.webp',
    'soanf': 'variyali.webp',
    'dill seeds': 'variyali.webp',
    'sesamum': 'til.webp',
    'sesame': 'til.webp',
    'dhan': 'paddy.webp',
    'mustard seed': 'mustard.webp',
    'castor seed': 'castor.webp',
    'pearl millet': 'bajra.webp',
    'sorghum': 'jowar.webp',
    'coriander': 'coriander.webp',
    'kothmir': 'coriander.webp',
    'amla': 'amla.webp',
    'radish': 'radish.webp',
    'mula': 'radish.webp',
    'spinach': 'spinach.webp',
    'palak': 'spinach.webp',
    'yam': 'yam.webp',
    'suran': 'yam.webp',
    'suva': 'suva.webp',
    'chiku': 'chiku.webp',
    'muskmelon': 'muskmelon.webp',
    'valor': 'valor.webp',
    'sweet_potato': 'sweet_potato.webp',
    'drumstick': 'drumstick.webp',
    'custard_apple': 'custard_apple.webp',
    'sapota': 'chiku.webp',
    'limbu': 'lemon.webp',
    'tameta': 'tomato.webp',
    'lasan': 'garlic.webp',
    'marcha': 'chilli.webp',
    'vatana': 'peas.webp',
    'chick pea': 'chana.webp',
    'ringan': 'brinjal.webp',
    'kakadi': 'cucumber.webp',
    'shakkariya': 'sweet_potato.webp',
    'fulavar': 'cauliflower.webp',
    'gajar': 'carrot.webp',
    'saragavo': 'drumstick.webp',
    'mag': 'mung.webp',
    'makai': 'maize.webp',
    'jeera': 'cumin.webp',
    'ajmo': 'ajmo.webp',
    'ajao': 'ajmo.webp',
    'chola': 'chola.webp',
    'cowpea': 'chola.webp',
    'cowpeas': 'chola.webp',

    // Gujarati Keys
    'બટાકા': 'potato.webp',
    'બટેટા': 'potato.webp',
    'ઘઉં': 'wheat.webp',
    'કપાસ': 'cotton.webp',
    'રાયડો': 'mustard.webp',
    'સરસવ': 'mustard.webp',
    'જીરું': 'cumin.webp',
    'બાજરી': 'bajra.webp',
    'ટામેટા': 'tomato.webp',
    'મગફળી': 'groundnut.webp',
    'એરંડા': 'castor.webp',
    'ચણા': 'chana.webp',
    'લીંબુ': 'lemon.webp',
    'ડુંગળી': 'onion.webp',
    'મરચા': 'chilli.webp',
    'લસણ': 'garlic.webp',
    'ફુલેવર': 'cauliflower.webp',
    'રાજગરો': 'rajgaro.webp',
    'જુવાર': 'jowar.webp',
    'વરિયાળી': 'variyali.webp',
    'વરીયાળી': 'variyali.webp',
    'ઇસબગુલ': 'isabgul.webp',
    'ગવાર': 'guwar.webp',
    'ગુવાર': 'guwar.webp',
    'મગ': 'mung.webp',
    'અડદ': 'urad.webp',
    'તુવેર': 'tuver.webp',
    'તલ': 'til.webp',
    'મેથી': 'methi.webp',
    'મકાઈ': 'maize.webp',
    'હળદર': 'halder.webp',
    'આદુ': 'adu.webp',
    'સોયાબીન': 'soybean.webp',
    'સફરજન': 'apple.webp',
    'દાડમ': 'pomegranate.webp',
    'કેળા': 'banana.webp',
    'જવ': 'barley.webp',
    'બીટ': 'beetroot.webp',
    'ભીંડા': 'okra.webp',
    'કોબીજ': 'cabbage.webp',
    'ગાજર': 'carrot.webp',
    'દૂધી': 'dudhi.webp',
    'કાકડી': 'cucumber.webp',
    'કારેલા': 'karela.webp',
    'કેરી': 'mango.webp',
    'પપૈયા': 'papaya.webp',
    'વટાણા': 'peas.webp',
    'રાગી': 'ragi.webp',
    'ડાંગર': 'paddy.webp',
    'રીંગણ': 'brinjal.webp',
    'ટીંડોળા': 'tindora.webp',
    'તરબૂચ': 'watermelon.webp',
    'નારિયળ': 'coconut.webp',
    'દ્રાક્ષ': 'grapes.webp',
    'જામફળ': 'guava.webp',
    'તમાકુ': 'tobacco.webp',
    'તુરિયા': 'turiya.webp',
    'ચીકુ': 'chiku.webp',
    'ટેટી': 'muskmelon.webp',
    'વાલોળ': 'valor.webp',
    'શક્કરીયા': 'sweet_potato.webp',
    'સરગવો': 'drumstick.webp',
    'સીતાફળ': 'custard_apple.webp',
    'કોથમીર': 'coriander.webp',
    'આમળા': 'amla.webp',
    'મૂળા': 'radish.webp',
    'પાલક': 'spinach.webp',
    'સુરણ': 'yam.webp',
    'સુવા': 'suva.webp',
    'ગુવારબીજ': 'guwar.webp',
    'ગુવાર (બીજ)': 'guwar.webp',
    'અજમો': 'ajmo.webp',
    'ચોળા': 'chola.webp',
  };

  /// Returns the asset path for a given crop name.
  static String getCropIconPath(String name) {
    if (name.isEmpty) return '${_iconBasePath}default.webp';
    final lowerName = name.toLowerCase().trim();
    
    if (_cropIconMap.containsKey(lowerName)) {
      return '$_iconBasePath${_cropIconMap[lowerName]}';
    }

    // Substring match
    for (var entry in _cropIconMap.entries) {
      if (lowerName.contains(entry.key)) {
        return '$_iconBasePath${entry.value}';
      }
    }

    return '${_iconBasePath}default.webp';
  }

  /// A structured list of all supported crops for the "Add Crop" screen.
  static List<Map<String, String>> get allCrops {
    final List<Map<String, String>> list = [];
    final seen = <String>{};
    
    // We use the Gujarati keys for display
    _cropIconMap.forEach((key, icon) {
       // Only process Gujarati keys to get proper labels
       bool isGujarati = RegExp(r'[અ-હ]').hasMatch(key);
       if (isGujarati && !seen.contains(icon)) {
          seen.add(icon);
          
          String nameEn = icon.replaceAll('.webp', '').replaceAll('.png', '').replaceAll('_', ' ');
          nameEn = nameEn[0].toUpperCase() + nameEn.substring(1);
          
          list.add({
            'en': nameEn,
            'gu': key,
            'value': nameEn,
            'icon': icon,
          });
       }
    });

    return list;
  }

  static Widget getCropIcon(String name, {double size = 24, Color? color}) {
    final path = getCropIconPath(name);
    final isDefault = path.contains('default.webp');
    final isCastor = path.contains('castor.webp');
    
    return Transform.scale(
      scale: isCastor ? 1.85 : 1.4,
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: isDefault ? const Color(0xFF2E7D32) : null,
        colorBlendMode: isDefault ? BlendMode.srcIn : null,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.eco_rounded, size: size, color: color ?? const Color(0xFF2E7D32));
        },
      ),
    );
  }
}
