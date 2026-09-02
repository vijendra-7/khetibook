import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/language_mapper.dart';
import '../utils/custom_options_manager.dart';
import '../providers/custom_options_provider.dart';
import '../utils/color_helper.dart';
import 'investment_screen.dart';
import 'output_screen.dart';
import 'add_crop_options_screen.dart';

import '../providers/global_options_provider.dart';
import '../widgets/crop_image_widget.dart';
import '../utils/crop_icon_utils.dart';

enum SelectionType { investment, output }

class CropSelectionScreen extends StatefulWidget {
  final SelectionType selectionType;
  const CropSelectionScreen({super.key, required this.selectionType});

  @override
  State<CropSelectionScreen> createState() => _CropSelectionScreenState();
}

class _CropSelectionScreenState extends State<CropSelectionScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    setState(() => _isLoading = true);
    await context.read<CustomOptionsProvider>().loadOptions(CustomOptionsManager.categorysCrops);
    if (mounted) setState(() => _isLoading = false);
  }

  void _goToAddCrop() {
     Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AddCropOptionsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        fullscreenDialog: true,
      ),
    );
  }

  static const _cropEmojis = {
    'Bataka': '🥔',
    'Magfali': '🥜',
    'Bajari': '🌿',   // millet / pearl millet — tall grass plant
    'Tarbuch': '🍉',
    'Ghau': '🌾',    // wheat sheaf
    'Kapas': '☁️',    // cotton
    'Raydo': '🌼',    // mustard
  };

  static const _cropColors = [
    Color(0xFF2D6A4F), // Deep Forest Green
    Color(0xFF40916C), // Medium Green
    Color(0xFF52B788), // Sage Green
    Color(0xFF795548), // Warm Brown (earthy)
    Color(0xFF5D4037), // Deep Brown
    Color(0xFF6D8B74), // Muted Olive Green
    Color(0xFF388E3C), // Standard Green
  ];

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final globalMetadata = context.watch<GlobalOptionsProvider>();
    final customProvider = context.watch<CustomOptionsProvider>();
    final rawCrops = customProvider.getAll(CustomOptionsManager.categorysCrops);
    
    // Canonical mapping for deduplication
    final Map<String, String> synonyms = {
      'potato': 'Bataka',
      'wheat': 'Ghau',
      'groundnut': 'Magfali',
      'bajra': 'Bajari',
      'millet': 'Bajari',
      'watermelon': 'Tarbuch',
    };

    // Deduplicate the list to display in the grid
    final Map<String, String> seenNormalized = {};
    for (final c in rawCrops) {
       final lower = c.toLowerCase().trim();
       final normalized = synonyms[lower] ?? c;
       if (!seenNormalized.containsKey(normalized.toLowerCase())) {
          seenNormalized[normalized.toLowerCase()] = normalized;
       }
    }
    final displayCrops = seenNormalized.values.toList();

    final title = widget.selectionType == SelectionType.investment
        ? (gu ? 'પાક પસંદ કરો' : 'Select Crop')
        : (gu ? 'ઉત્પાદન માટે પાક' : 'Select Crop for Harvest');
    final cs = Theme.of(context).colorScheme;

    // We no longer auto-redirect to Add Crop, as the 5 default crops should already be there.
    // The user can manually click 'Add Crop' if they need more.

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddCrop,
        icon: const Icon(Icons.add),
        label: Text(gu ? 'નવો પાક' : 'Add Crop'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : displayCrops.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.eco_outlined, size: 64, color: cs.primary.withOpacity(0.5)),
                   const SizedBox(height: 16),
                   Text(
                     gu ? 'કોઈ પાક ઉમેર્યા નથી' : 'No crops added yet',
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     gu ? 'શરૂ કરવા માટે નવો પાક ઉમેરો' : 'Add a new crop to get started',
                     style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7)),
                   ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
              itemCount: displayCrops.length,
              itemBuilder: (context, i) {
                final cropEn = displayCrops[i];
                final isBajari = cropEn == 'Bajari';
                final emoji = _cropEmojis[cropEn] ?? '🌱';
                final globalOpt = globalMetadata.options.firstWhere(
                  (o) => o.value.toLowerCase() == cropEn.toLowerCase(),
                  orElse: () => GlobalOption(id: '', type: '', labelEn: '', labelGu: '', value: ''),
                );
                final isValidGlobal = globalOpt.id.isNotEmpty;
                final cropColorHex = isValidGlobal ? globalOpt.backgroundColor : null;

                final baseColor = cs.surfaceContainerHighest;
                final textColor = cs.onSurface;
                final innerCircleColor = cs.surfaceContainerHigh;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigate(context, cropEn),
                    borderRadius: BorderRadius.circular(24),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Hero(
                            tag: 'crop_icon_$cropEn',
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: innerCircleColor,
                                  shape: BoxShape.circle,
                                ),
                                child: CropIconUtils.getCropIcon(
                                  cropEn.toString(),
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              LanguageMapper.localizedCrop(
                                cropEn,
                                gu,
                                globalMetadata.getGlobalCropMap(gu),
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _navigate(BuildContext context, String cropEn) {
    if (widget.selectionType == SelectionType.investment) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InvestmentScreen(crop: cropEn)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OutputScreen(crop: cropEn)),
      );
    }
  }
}
