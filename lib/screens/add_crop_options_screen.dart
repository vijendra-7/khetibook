import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/global_options_provider.dart';
import '../providers/custom_options_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/custom_options_manager.dart';
import '../widgets/crop_image_widget.dart';
import '../utils/language_mapper.dart';
import '../utils/color_helper.dart';
import '../utils/crop_icon_utils.dart';

class AddCropOptionsScreen extends StatelessWidget {
  const AddCropOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final globalProvider = context.watch<GlobalOptionsProvider>();
    final customProvider = context.watch<CustomOptionsProvider>();
    final cs = Theme.of(context).colorScheme;

    final globalCrops = globalProvider.getGlobalCrops();
    final predefinedCrops = CustomOptionsManager.getPredefined(CustomOptionsManager.categorysCrops);
    final userCrops = customProvider.getAll(CustomOptionsManager.categorysCrops).toSet();

    // Combine global and predefined into a unified list
    final List<dynamic> allAvailable = [];
    allAvailable.addAll(globalCrops);
    for (final p in predefinedCrops) {
      if (!globalCrops.any((g) => g.value.toLowerCase() == p.toLowerCase())) {
        allAvailable.add(p);
      }
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(gu ? 'પાક ઉમેરો' : 'Add Crop'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: globalProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : globalCrops.isEmpty
              ? Center(child: Text(gu ? 'કોઈ નવા પાક ઉપલબ્ધ નથી' : 'No new crops available'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: allAvailable.length,
                  itemBuilder: (context, i) {
                    final item = allAvailable[i];
                    final isGlobal = item is GlobalOption;
                    final cropEn = isGlobal ? item.value : item.toString();
                    final isAdded = userCrops.any((c) => c.toLowerCase() == cropEn.toLowerCase());

                    final cropColorHex = isGlobal ? item.backgroundColor : null;
                    final baseColor = ColorHelper.parseHex(cropColorHex, (isGlobal ? cs.surfaceContainerHigh : _getPredefinedColor(cropEn)));
                    
                    final isLight = (cropColorHex != null || !isGlobal) ? ThemeData.estimateBrightnessForColor(baseColor) == Brightness.light : true;
                    final textColor = isLight ? cs.onSurface : Colors.white;
                    final innerCircleColor = isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.2);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isAdded ? null : () => _addCrop(context, item),
                        borderRadius: BorderRadius.circular(24),
                        child: Opacity(
                          opacity: isAdded ? 0.6 : 1.0,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: baseColor,
                              gradient: cropColorHex != null ? LinearGradient(
                                colors: [
                                  baseColor,
                                  Color.lerp(baseColor, Colors.black, 0.1) ?? baseColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ) : null,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: (cropColorHex != null ? baseColor : Colors.black).withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: innerCircleColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: Center(
                                        child: CropIconUtils.getCropIcon(
                                          cropEn.toString(),
                                          size: 56,
                                        ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isGlobal 
                                      ? (gu ? item.labelGu : item.labelEn)
                                      : LanguageMapper.localizedCrop(cropEn, gu),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                if (isAdded) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isLight ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      gu ? 'ઉમેરેલ છે' : 'Added',
                                      style: TextStyle(
                                        color: isLight ? Colors.green : Colors.white, 
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _addCrop(BuildContext context, dynamic item) async {
    final gu = context.read<SettingsProvider>().isGujarati;
    final isGlobal = item is GlobalOption;
    final cropEn = isGlobal ? item.value : item.toString();
    final labelEn = isGlobal ? item.labelEn : cropEn;
    final labelGu = isGlobal ? item.labelGu : LanguageMapper.localizedCrop(cropEn, true);

    await context.read<CustomOptionsProvider>().addOption(CustomOptionsManager.categorysCrops, cropEn);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gu ? '$labelGu ઉમેરાયો!' : '$labelEn added!'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Color _getPredefinedColor(String crop) {
    switch (crop) {
      case 'Bataka': return const Color(0xFF2D6A4F);
      case 'Magfali': return const Color(0xFF40916C);
      case 'Bajari': return const Color(0xFF8D6E63);
      case 'Tarbuch': return const Color(0xFF5D4037);
      case 'Ghau': return const Color(0xFF52B788);
      default: return const Color(0xFF6D8B74);
    }
  }

  String _getPredefinedEmoji(String crop) {
    switch (crop) {
      case 'Bataka': return '🥔';
      case 'Magfali': return '🥜';
      case 'Bajari': return '🌾';
      case 'Tarbuch': return '🍉';
      case 'Ghau': return '🌾';
      default: return '🌱';
    }
  }
}
