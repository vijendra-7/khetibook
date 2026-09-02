import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../utils/apmc_category_utils.dart';
import '../utils/crop_translation_utils.dart';
import '../utils/crop_category_utils.dart';
import '../providers/crop_price_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/firebase_init.dart';
import '../services/crop_price_service.dart';
import '../models/crop_price.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/gujarati_number_helper.dart';
import '../providers/price_override_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/announcement_card.dart';
import 'agra_potato_prices_screen.dart';
import 'settings_screen.dart';
import '../utils/crop_icon_utils.dart';
import 'full_screen_image_screen.dart';
import '../services/gondal_apmc_service.dart';
import 'pdf_viewer_screen.dart';

class CropPriceScreen extends StatefulWidget {
  const CropPriceScreen({super.key});

  @override
  State<CropPriceScreen> createState() => _CropPriceScreenState();
}

class _CropPriceScreenState extends State<CropPriceScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;
  late AnimationController _refreshController;
  String _selectedCategory = CropCategoryUtils.catAll;
  List<int> _recentMarketIndices = [];

  late ScrollController _scrollController;
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);
  final GlobalKey _marketCardKey = GlobalKey();

  static const _recentMarketsKey = 'recent_apmc_markets';


  Future<void> _loadRecentMarkets() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_recentMarketsKey) ?? [];
    if (mounted) {
      setState(() {
        _recentMarketIndices = saved.map(int.parse).toList();
      });
    }
  }

  Future<void> _saveRecentMarket(int index) async {
    final updated = [index, ..._recentMarketIndices.where((i) => i != index)].take(3).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentMarketsKey, updated.map((i) => i.toString()).toList());
    if (mounted) {
      setState(() => _recentMarketIndices = updated);
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final double offset = _scrollController.offset;
    
    final renderBox = _marketCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final cardHeight = renderBox.size.height;
      final appBarBottom = MediaQuery.of(context).padding.top + 56;
      
      final double sStart = offset + (position.dy - appBarBottom);
      final double sEnd = sStart + cardHeight;
      
      double t = 0.0;
      if (cardHeight <= 0.0) {
        t = (offset >= sStart) ? 1.0 : 0.0;
      } else {
        if (offset <= sStart) {
          t = 0.0;
        } else if (offset >= sEnd) {
          t = 1.0;
        } else {
          t = (offset - sStart) / cardHeight;
        }
      }
      
      if (t.isNaN || t.isInfinite) {
        t = 0.0;
      }
      
      if (_scrollProgress.value != t) {
        _scrollProgress.value = t;
      }
    } else {
      final t = (offset > 150) ? 1.0 : 0.0;
      if (_scrollProgress.value != t) {
        _scrollProgress.value = t;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadRecentMarkets();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Re-fetch the active market silently when coming back from background
      context.read<CropPriceProvider>().fetchOnResume();
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshController.dispose();
    _scrollController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final gu = context.select<SettingsProvider, bool>((p) => p.isGujarati);
    final priceProvider = context.watch<CropPriceProvider>();

    if (priceProvider.isLoading && !_refreshController.isAnimating) {
      _refreshController.repeat();
    } else if (!priceProvider.isLoading && _refreshController.isAnimating) {
      _refreshController.stop();
    }

    final selectedIndex = priceProvider.selectedApmcIndex;
    final marketNames = ['Deesa', 'Palanpur', 'Ahmedabad', 'Junagadh', 'Rajkot', 'Dhanera', 'Amirgadh', 'Surat', 'Siddhpur', 'Radhanpur', 'Himatnagar', 'Unjha', 'Mahuva', 'Gondal', 'Botad', 'Amreli', 'Babra', 'Visnagar', 'Agra Potato', 'Bagasara', 'Jasdan', 'Jetpur', 'Jamnagar', 'Rajula', 'Patan', 'Savarkundla'];
    final safeSelectedIndex = selectedIndex >= marketNames.length ? 0 : selectedIndex;
    final selectedMarketName = marketNames[safeSelectedIndex];

    final apmcStyle = TextStyle(
      color: cs.primary,
      fontSize: 26,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );

    // Dynamic text painter to get precise width of the market name for smooth clipping animation
    final marketPainter = TextPainter(
      text: TextSpan(text: selectedMarketName, style: apmcStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final marketWidth = marketPainter.width;

    return RefreshIndicator(
      onRefresh: () => priceProvider.fetchPrices(forceRefresh: true),
      edgeOffset: MediaQuery.of(context).padding.top + 56, // Push below status bar + app bar
      displacement: 40,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            centerTitle: true,
            toolbarHeight: 56,
            backgroundColor: cs.surfaceContainerLowest,
            actions: [
              Builder(
                builder: (context) {
                  final user = context.watch<AuthProvider>().user;
                  final isAdmin = user?.email == 'thevijendrachaudhary@gmail.com';
                  if (!isAdmin) return const SizedBox.shrink();
                  return IconButton(
                    tooltip: gu ? 'એડમિન પેનલ' : 'Switch to Admin Mode',
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    onPressed: () => context.read<SettingsProvider>().setAdminMode(true),
                  );
                }
              ),
              AnimatedBuilder(
                animation: _scrollProgress,
                builder: (context, child) {
                  final t = _scrollProgress.value;
                  // Smooth opacity for refresh button
                  final opacity = 1.0 - Curves.easeOut.transform(t);
                  // Width animation to slide/remove layout space smoothly
                  final width = 145.0 * (1.0 - t);
                  
                  if (width <= 0.0) return const SizedBox.shrink();
                  
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: SizedBox(
                      width: width,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: 145.0,
                          child: Center(
                            child: FilledButton.tonal(
                              onPressed: priceProvider.isLoading
                                  ? null
                                  : () => priceProvider.fetchPrices(forceRefresh: true),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RotationTransition(
                                    turns: _refreshController,
                                    child: const Icon(Icons.refresh_rounded, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    gu ? 'રિફ્રેશ કરો' : 'Refresh',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _scrollProgress,
                builder: (context, child) {
                  final t = _scrollProgress.value;
                  return SizedBox(width: 8.0 * (1.0 - t));
                },
              ),
            ],
            title: AnimatedBuilder(
              animation: _scrollProgress,
              builder: (context, child) {
                final t = _scrollProgress.value;
                // iOS-like easeOut transition curve
                final curveT = Curves.easeOut.transform(t);
                
                final opacity = curveT;
                // Add 8.0 for spacing width
                final width = (marketWidth + 8.0) * curveT;
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'APMC',
                      style: apmcStyle,
                    ),
                    Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: SizedBox(
                        width: width,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: marketWidth + 8.0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  selectedMarketName,
                                  style: apmcStyle,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnnouncementCard(context, gu),
                  const SizedBox(height: 16),
                  _buildDailyPricesSection(context, gu),
                  const SizedBox(height: 24),
                  _buildAgraButton(context, gu),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, bool gu) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<void>(
      future: FirebaseInit.initialize(),
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink(); // Hide silently while Firebase boots
        }
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('announcements')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Announcement Error: ${snapshot.error}');
              return const SizedBox.shrink();
            }
        
            if (!snapshot.hasData) return const SizedBox.shrink();

            final allDocs = snapshot.data!.docs;
            // Filter and sort client-side
            final activeDocs = allDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              if (d['isActive'] != true) return false;
              
              final targetLang = d['targetLanguage'] ?? 'both';
              if (targetLang == 'both') return true;
              if (gu && targetLang == 'gu') return true;
              if (!gu && targetLang == 'en') return true;
              return false;
            }).toList();

            if (activeDocs.isEmpty) return const SizedBox.shrink();

            activeDocs.sort((a, b) {
              final pa = (a.data() as Map<String, dynamic>)['priority'] ?? 0;
              final pb = (b.data() as Map<String, dynamic>)['priority'] ?? 0;
              return pb.compareTo(pa); // Descending
            });

            final isDark = Theme.of(context).brightness == Brightness.dark;

            final data = activeDocs.first.data() as Map<String, dynamic>;
            final title = gu ? data['titleGu'] : data['titleEn'];
            final message = gu ? data['messageGu'] : data['messageEn'];
            final url = data['actionUrl'] as String?;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? cs.primaryContainer : cs.primary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withAlpha(isDark ? 100 : 50)),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withAlpha(isDark ? 50 : 30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (url != null && url.isNotEmpty)
                      ? () async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isDark ? cs.onPrimaryContainer : Colors.white).withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.campaign_rounded, 
                            color: isDark ? cs.onPrimaryContainer : Colors.white, 
                            size: 28
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title ?? '',
                                style: TextStyle(
                                  color: isDark ? cs.onPrimaryContainer : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message ?? '',
                                    style: TextStyle(
                                  color: (isDark ? cs.onPrimaryContainer : Colors.white).withAlpha(220),
                                  fontSize: 14,
                                ),
                              ),
                              if (url != null && url.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Center(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      icon: Icon(Icons.arrow_outward_rounded, size: 16, color: isDark ? Colors.white : cs.primary),
                                      label: Text(
                                        gu 
                                          ? (data['actionTextGu']?.toString().isNotEmpty == true ? data['actionTextGu'] : 'વધુ જાણો')
                                          : (data['actionTextEn']?.toString().isNotEmpty == true ? data['actionTextEn'] : 'Learn More'),
                                        style: TextStyle(
                                          color: isDark ? Colors.white : cs.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? cs.onPrimaryContainer : Colors.white,
                                        foregroundColor: isDark ? Colors.white : cs.primary,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getRegionForMarket(int index, bool gu) {
    const north = {'en': 'North Gujarat', 'gu': 'ઉત્તર ગુજરાત'};
    const saurashtra = {'en': 'Saurashtra', 'gu': 'સૌરાષ્ટ્ર'};
    const central = {'en': 'Central Gujarat', 'gu': 'મધ્ય ગુજરાત'};
    const south = {'en': 'South Gujarat', 'gu': 'દક્ષિણ ગુજરાત'};
    const other = {'en': 'Other Region', 'gu': 'અન્ય પ્રદેશ'};

    final Map<int, Map<String, String>> mapping = {
      0: north, 1: north, 5: north, 6: north, 8: north, 9: north, 10: north, 11: north, 17: north, 24: north,
      3: saurashtra, 4: saurashtra, 12: saurashtra, 13: saurashtra, 14: saurashtra, 15: saurashtra, 16: saurashtra,
      19: saurashtra, 20: saurashtra, 21: saurashtra, 22: saurashtra, 23: saurashtra, 25: saurashtra,
      2: central,
      7: south,
    };

    final region = mapping[index] ?? other;
    return gu ? region['gu']! : region['en']!;
  }

  Widget _buildMarketBanner(BuildContext context, String marketName) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<void>(
      future: FirebaseInit.initialize(),
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('market_banners')
              .doc(marketName)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
            final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();
        final isVisible = data['isVisible'] as bool? ?? false;
        final imageUrl = data['imageUrl'] as String? ?? '';
        if (!isVisible || imageUrl.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageScreen(imageUrl: imageUrl),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (ctx, url) => Container(
                  height: 150,
                  color: cs.surfaceContainerHigh,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (ctx, url, err) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
      },
    );
  }

  Widget _buildDailyPricesSection(BuildContext context, bool gu) {
    final cs = Theme.of(context).colorScheme;
    final priceProvider = context.watch<CropPriceProvider>();
    final settings = context.watch<SettingsProvider>();

    final selectedIndex = priceProvider.selectedApmcIndex;
    final marketNames = ['Deesa', 'Palanpur', 'Ahmedabad', 'Junagadh', 'Rajkot', 'Dhanera', 'Amirgadh', 'Surat', 'Siddhpur', 'Radhanpur', 'Himatnagar', 'Unjha', 'Mahuva', 'Gondal', 'Botad', 'Amreli', 'Babra', 'Visnagar', 'Agra Potato', 'Bagasara', 'Jasdan', 'Jetpur', 'Jamnagar', 'Rajula', 'Patan', 'Savarkundla'];
    // Handle case where index might be out of range
    final safeSelectedIndex = selectedIndex >= marketNames.length ? 0 : selectedIndex;
    final selectedMarketName = marketNames[safeSelectedIndex];
    final isDeesa = safeSelectedIndex == 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showMarketPicker(context, gu, cs, priceProvider),
          child: Container(
            key: _marketCardKey,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [cs.surfaceContainerHighest, cs.surfaceContainerHigh]
                  : [cs.primaryContainer.withAlpha(180), Colors.white],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withAlpha(isDark ? 80 : 30), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withAlpha(isDark ? 30 : 15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: cs.shadow.withAlpha(isDark ? 20 : 10),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? cs.primaryContainer.withAlpha(100) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 40 : 10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.location_on_rounded, color: cs.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gu ? translateMarketName(selectedMarketName) : selectedMarketName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.map_outlined, size: 12, color: cs.primary.withAlpha(180)),
                          const SizedBox(width: 4),
                          Text(
                            _getRegionForMarket(selectedIndex, gu),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.primary.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: gu ? 14 : 12, vertical: gu ? 9 : 8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        gu ? 'માર્કેટ બદલો' : 'Change Market',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: gu ? 13 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: gu ? 5 : 4),
                      Icon(Icons.keyboard_arrow_down_rounded, color: cs.onPrimary, size: gu ? 18 : 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Market Banner (from admin-configured Firestore data) ──
        _buildMarketBanner(context, selectedMarketName),
        if (selectedIndex == 1 || selectedIndex == 2 || selectedIndex == 3 || selectedIndex == 4 || selectedIndex == 13) ...[
          const SizedBox(height: 12),
          _buildMarketDateSelector(context, selectedIndex, gu, cs, priceProvider),
        ],
        if (_getAvailableYards(priceProvider.apmcPrices).length > 2) ...[
          const SizedBox(height: 12),
          _buildDynamicYardChips(context, priceProvider.apmcPrices, gu, cs),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final isIncoming = animation.status == AnimationStatus.forward ||
                               animation.status == AnimationStatus.completed;

            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: isIncoming 
                    ? const Offset(0.06, 0.0)
                    : const Offset(-0.06, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: isIncoming ? Curves.easeOutBack : Curves.easeInCubic,
                )),
                child: child,
              ),
            );
          },
          child: _buildApmcContent(
            context, 
            gu, 
            priceProvider, 
            settings, 
            priceProvider.apmcPrices.where((p) {
              if (settings.hiddenApmcCrops.contains(p.name)) return false;
              // Apply dynamic yard/category filter if one is selected
              if (_selectedCategory != CropCategoryUtils.catAll) {
                 if (p.yardName != _selectedCategory) return false;
              }
              return true;
            }).toList(), 
            selectedMarketName, 
            isDeesa: isDeesa
          ),
        ),
      ],
    );
  }

  Widget _buildMarketDateSelector(
      BuildContext context, int selectedIndex, bool gu, ColorScheme cs, CropPriceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    DateTime? selectedDate;
    if (selectedIndex == 1) selectedDate = provider.selectedPalanpurDate;
    if (selectedIndex == 2) selectedDate = provider.selectedAhmedabadDate;
    if (selectedIndex == 3) selectedDate = provider.selectedJunagadhDate;
    if (selectedIndex == 4) selectedDate = provider.selectedRajkotDate;
    if (selectedIndex == 13) selectedDate = provider.selectedGondalDate;

    bool isManual = false;
    if (selectedIndex == 1) isManual = provider.isPalanpurDateManual;
    if (selectedIndex == 2) isManual = provider.isAhmedabadDateManual;
    if (selectedIndex == 3) isManual = provider.isJunagadhDateManual;
    if (selectedIndex == 4) isManual = provider.isRajkotDateManual;
    if (selectedIndex == 13) isManual = provider.isGondalDateManual;

    DateTime? displayDate = selectedDate;
    if (displayDate == null) {
      final prices = provider.apmcPrices;
      if (prices.isNotEmpty) {
        for (final p in prices) {
          if (p.date.isNotEmpty) {
            final parsed = CropPriceProvider.parseDate(p.date);
            if (parsed != null) {
              displayDate = parsed;
              break;
            }
          }
        }
      }
    }

    bool isToday = false;
    if (displayDate != null) {
      final now = DateTime.now();
      isToday = displayDate.year == now.year &&
                displayDate.month == now.month &&
                displayDate.day == now.day;
    }

    // Formatting display date
    String dateLabel;
    if (displayDate == null) {
      dateLabel = gu ? 'આજે' : 'Today';
    } else if (isToday && !isManual) {
      dateLabel = gu ? 'આજે' : 'Today';
    } else {
      final formatted = '${displayDate.day.toString().padLeft(2, '0')}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.year}';
      dateLabel = gu ? GujaratiNumberHelper.toGujarati(formatted) : formatted;
    }

    bool isDateEmpty(DateTime date) {
      if (selectedIndex == 1) return provider.isPalanpurDateEmpty(date);
      if (selectedIndex == 2) return provider.isAhmedabadDateEmpty(date);
      if (selectedIndex == 3) return provider.isJunagadhDateEmpty(date);
      if (selectedIndex == 4) return provider.isRajkotDateEmpty(date);
      if (selectedIndex == 13) return provider.isGondalDateEmpty(date);
      return false;
    }

    void setDate(DateTime? date) {
      if (selectedIndex == 1) provider.setPalanpurDate(date);
      if (selectedIndex == 2) provider.setAhmedabadDate(date);
      if (selectedIndex == 3) provider.setJunagadhDate(date);
      if (selectedIndex == 4) provider.setRajkotDate(date);
      if (selectedIndex == 13) provider.setGondalDate(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withAlpha(80), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_rounded, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gu ? 'તારીખ પસંદ કરો' : 'Select Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withAlpha(180),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (selectedDate != null) ...[
            IconButton(
              icon: Icon(Icons.close_rounded, color: cs.error, size: 20),
              tooltip: gu ? 'આજની તારીખ પર પાછા જાઓ' : 'Reset to Today',
              onPressed: () => setDate(null),
            ),
            const SizedBox(width: 4),
          ],
          FilledButton.tonal(
            onPressed: () async {
              // Fix 3: Limit backwards search to max 30 days to prevent infinite loop
              DateTime initialDatePickerDate = displayDate ?? DateTime.now();
              final earliest = DateTime.now().subtract(const Duration(days: 30));
              int safetyLimit = 30;
              while (isDateEmpty(initialDatePickerDate) &&
                  initialDatePickerDate.isAfter(earliest) &&
                  safetyLimit > 0) {
                initialDatePickerDate = initialDatePickerDate.subtract(const Duration(days: 1));
                safetyLimit--;
              }
              // If still empty after search, just reset to today
              if (isDateEmpty(initialDatePickerDate)) {
                initialDatePickerDate = DateTime.now();
              }

              final today = DateTime.now();
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: initialDatePickerDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: today,
                // Fix 5: Never block today regardless of empty-dates set
                selectableDayPredicate: (DateTime date) {
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  if (isToday) return true;
                  return !isDateEmpty(date);
                },
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: cs,
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setDate(picked);
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              gu ? 'બદલો' : 'Change',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getAvailableYards(List<CropPrice> prices) {
    if (prices.isEmpty) return [CropCategoryUtils.catAll];
    final yards = prices.map((p) => p.yardName).where((y) => y.isNotEmpty).toSet().toList();
    return [CropCategoryUtils.catAll, ...yards];
  }

  Widget _buildDynamicYardChips(BuildContext context, List<CropPrice> prices, bool gu, ColorScheme cs) {
    final yards = _getAvailableYards(prices);
    
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: yards.map((yard) {
        final isSelected = _selectedCategory == yard;
        
        String label = yard;
        if (yard == CropCategoryUtils.catAll) {
          label = gu ? 'બધા' : 'All';
        } else {
          // Clean up common long names for chip readability
          label = yard.replaceAll('Market Yard', '').replaceAll('માર્કેટ યાર્ડ', '').trim();
          if (label.length > 20) label = '${label.substring(0, 17)}...';
        }

        return ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          selected: isSelected,
          selectedColor: cs.primary,
          backgroundColor: cs.surfaceContainerHighest,
          showCheckmark: false,
          elevation: isSelected ? 4 : 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide.none,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedCategory = yard);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildCategoryChips(BuildContext context, bool gu, ColorScheme cs) {
    // Keep the old one for reference or other uses if needed, 
    // but we are using _buildDynamicYardChips now.
    return const SizedBox.shrink();
  }


  Widget _buildFacebookButton(bool gu) {
    return OutlinedButton.icon(
      onPressed: () async {
        final url = Uri.parse('https://www.facebook.com/APMCDHANERA/photos');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.facebook, color: Colors.blue),
      label: Text(gu ? 'ફેસબુક પર જુઓ' : 'View on Facebook'),
    );
  }

  Widget _buildApmcContent(
    BuildContext context, 
    bool gu, 
    CropPriceProvider priceProvider, 
    SettingsProvider settings,
    List<CropPrice> visibleApmcPrices,
    String selectedMarket,
    {required bool isDeesa}
  ) {
    if (priceProvider.isLoading && visibleApmcPrices.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
      final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
      return Column(
        key: const ValueKey('shimmer'),
        children: List.generate(5, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        )),
      );
    }
    
    if (priceProvider.apmcPrices.isNotEmpty && visibleApmcPrices.isEmpty) {
      return Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: _buildEmptyState(context, gu),
      );
    }
    
    if (priceProvider.apmcPrices.isEmpty && priceProvider.errorMessage.isEmpty) {
      return Container(
        key: const ValueKey('fetching'),
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: _buildEmptyState(context, gu, isFetching: true),
      );
    }

    if (visibleApmcPrices.isEmpty) return const SizedBox(key: ValueKey('none'));

    return Builder(
      key: ValueKey(selectedMarket),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;

        // Uses pre-processed data from provider (Optimization)
        final yardGroups = priceProvider.yardGroups;
        final groupedByName = priceProvider.groupedByName;
        final byDate = priceProvider.byDate;
        final sortedDates = priceProvider.sortedDates;

        // Ordered list of yards for consistent display
        List<String> orderedYards;
        if (isDeesa) {
          orderedYards = ['Deesa', 'V.J.Patel', 'Bhildi'];
        } else if (priceProvider.selectedApmcIndex == 3) {
          orderedYards = [ApmcCategory.grainsAndPulses, ApmcCategory.vegetables, ApmcCategory.fruits, ...yardGroups.keys.where((k) => k != ApmcCategory.grainsAndPulses && k != ApmcCategory.vegetables && k != ApmcCategory.fruits)];
        } else if (priceProvider.selectedApmcIndex == 4) {
          orderedYards = [ApmcCategory.grains, ApmcCategory.vegetables, ...yardGroups.keys.where((k) => k != ApmcCategory.grains && k != ApmcCategory.vegetables)];
        } else if (priceProvider.selectedApmcIndex == 13) {
          orderedYards = [ApmcCategory.grains, ApmcCategory.vegetables, ApmcCategory.fruits, ...yardGroups.keys.where((k) => k != ApmcCategory.grains && k != ApmcCategory.vegetables && k != ApmcCategory.fruits)];
        } else {
          orderedYards = [selectedMarket];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final yard in orderedYards) ...[
              if (yardGroups.containsKey(yard) && yardGroups[yard]!.any((p) => visibleApmcPrices.contains(p))) ...[
                Builder(
                  builder: (context) {
                    final yardPrices = yardGroups[yard]!;

                    // Get all visible prices for this yard across ALL dates
                    final yardVisiblePrices = yardPrices
                        .where((p) => visibleApmcPrices.contains(p))
                        .toList();

                    // Sort newest-first using the provider's already-sorted date index
                    yardVisiblePrices.sort((a, b) {
                      final ai = sortedDates.indexOf(a.date);
                      final bi = sortedDates.indexOf(b.date);
                      return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
                    });

                    // Deduplicate: keep only the LATEST price per crop name
                    // (first occurrence after sort = newest). No crop is missed
                    // even if it only appeared in older cached dates.
                    final seen = <String>{};
                    final deduped = <CropPrice>[];
                    for (final p in yardVisiblePrices) {
                      if (seen.add(p.name)) deduped.add(p);
                    }

                    // Sort: favorites first, preserve newest-first order otherwise
                    deduped.sort((a, b) {
                      final idA = '${yard}_${selectedMarket}_${a.name}';
                      final idB = '${yard}_${selectedMarket}_${b.name}';
                      final aFav = settings.isFavorite(idA);
                      final bFav = settings.isFavorite(idB);
                      if (aFav && !bFav) return -1;
                      if (!aFav && bFav) return 1;
                      return 0;
                    });
                    
                    Widget heading = Padding(
                      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  gu ? CropPriceService.translate(yard) : yard,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (priceProvider.selectedApmcIndex == 13 && yard == ApmcCategory.grains)
                                _GondalPdfButton(
                                  dateStr: deduped.isNotEmpty ? deduped.first.date : null,
                                  gu: gu,
                                  cs: cs,
                                ),
                            ],
                          ),
                          if (deduped.isNotEmpty && deduped.first.date.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Builder(builder: (context) {
                                String displayDate = deduped.first.date.replaceAll('/', '-');
                                try {
                                  final parts = displayDate.split(' ');
                                  if (parts.length == 3) {
                                    const monthMap = {
                                      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04', 'May': '05', 'Jun': '06',
                                      'Jul': '07', 'Aug': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
                                    };
                                    final m = monthMap[parts[1]] ?? parts[1];
                                    displayDate = '${parts[0].padLeft(2, '0')}-$m-${parts[2]}';
                                  }
                                } catch (_) {}
                                return Text(
                                  gu ? GujaratiNumberHelper.toGujarati(displayDate) : displayDate,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        _buildPriceGrid(
                          context,
                          deduped,
                          gu,
                          cs,
                          2,
                          groupedData: groupedByName,
                          showDateInCard: false,  // Hide date in card for all markets
                          isDeesa: isDeesa,
                          isPalanpur: selectedMarket == 'Palanpur',
                          marketSuffix: '${yard}_$selectedMarket',
                        ),
                      ],
                    );
                  }
                ),
              ]
            ]
          ],
        );
      },
    );
  }

  Widget _buildAgraButton(BuildContext context, bool gu) {
    final cs = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AgraPotatoPricesScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Hero(
                    tag: 'agra_location_icon',
                    child: Icon(Icons.location_on_rounded, color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gu ? 'બટાકા આગ્રા માર્કેટ' : 'Agra Potato Markets',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        gu ? 'બધા આગ્રા બજારના ભાવો જુઓ' : 'View all Agra market prices',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceGrid(
      BuildContext context, List<CropPrice> prices, bool gu, ColorScheme cs, int crossAxisCount,
      {bool showDateInCard = false, Map<String, List<CropPrice>>? groupedData, bool isDeesa = false, bool isPalanpur = false, String marketSuffix = ''}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: false,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1, // Single column for better readability
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.8, // Adjusted height for full-width rows (130px approx)
      ),
      itemCount: prices.length,
      itemBuilder: (context, index) {
        final price = prices[index];
        final history = groupedData?[price.name] ?? [price];

        String displayName = _getSmartDisplayName(price, gu);

        return _buildPriceItem(
          context, 
          price, 
          displayName, 
          history, 
          gu, 
          cs, 
          index, 
          showDateInCard: showDateInCard, 
          isDeesa: isDeesa, 
          isPalanpur: isPalanpur,
          marketId: '${marketSuffix}_${price.name}'
        );

      },
    );
  }

  String _getSmartDisplayName(CropPrice p, bool gu) {
    String name;
    if (gu) {
      final lowerName = p.name.toLowerCase();
      final lowerGName = p.gujaratiName.toLowerCase();
      
      if (lowerName.contains('suva') || lowerGName.contains('suva')) {
        name = 'સુવા';
      } else if (lowerName.contains('cauliflower') || lowerName.contains('cauli flower') || 
                 lowerName.contains('cauli-flower') || lowerName.contains('phool') ||
                 lowerName.contains('flower') || lowerGName.contains('cauliflower') ||
                 lowerGName.contains('cauli flower') || lowerGName.contains('cauli-flower')) {
        name = 'ફુલેવર';
      } else if (p.gujaratiName.isNotEmpty && p.gujaratiName != p.name) {
        name = CropTranslationUtils.translate(p.gujaratiName);
      } else {
        name = CropTranslationUtils.translate(p.name);
      }
    } else {
      if (p.name.startsWith('potato_agra_')) {
        final parts = p.name.split('_');
        if (parts.length >= 3) {
          final rawMandi = parts.sublist(2).join(' ');
          name = rawMandi.split(' ').map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1);
          }).join(' ');
        } else {
          name = p.name;
        }
      } else {
        name = p.name;
      }
    }

    if (p.variety.isEmpty) return name;

    // Smart Deduplication Logic
    final vLower = p.variety.toLowerCase();
    final nLower = name.toLowerCase();
    final pNameLower = p.name.toLowerCase();
    final yLower = p.yardName.toLowerCase();
    final gYardName = CropTranslationUtils.translate(p.yardName).toLowerCase();

    // Special Case: Castor Seed (Aeranda) - Always hide variety
    if (nLower.contains('એરંડા') || nLower.contains('castor') || pNameLower.contains('castor')) {
      return name;
    }

    // Step 1: THE SWITCH - If the name is exactly the city name, swap it with variety
    String currentName = name;
    String currentVariety = p.variety;

    if ((nLower == yLower || nLower == gYardName) && currentVariety.isNotEmpty) {
      currentName = CropTranslationUtils.translate(currentVariety);
      currentVariety = ''; // Consumed as name
    }

    // Step 2: Clean variety of market names (e.g. "Hybrid Palanpur" -> "Hybrid")
    String cleanVariety = currentVariety;
    if (yLower.isNotEmpty) {
      // 1. Remove the yard name with or without parentheses and extra spaces
      final patterns = [
        RegExp(r'\(\s*' + p.yardName + r'\s*\)', caseSensitive: false),
        RegExp(r'\s*' + p.yardName + r'\s*', caseSensitive: false),
        RegExp(r'\(\s*' + gYardName + r'\s*\)', caseSensitive: false),
        RegExp(r'\s*' + gYardName + r'\s*', caseSensitive: false),
      ];
      
      for (final pattern in patterns) {
        cleanVariety = cleanVariety.replaceAll(pattern, '').trim();
      }
      
      // Cleanup: remove empty parentheses if they were left behind
      cleanVariety = cleanVariety.replaceAll(RegExp(r'\(\s*\)'), '').trim();
    }
    
    String cvLower = cleanVariety.toLowerCase();

    // Step 3: Check for redundancy against crop name
    final cnLower = currentName.toLowerCase();
    bool isRedundant = cleanVariety.isEmpty || 
                      cvLower == 'other' || 
                      cvLower == 'all' || 
                      cvLower == 'general' ||
                      cvLower == cnLower || 
                      cnLower.contains(cvLower) || 
                      cvLower.contains(cnLower);
                      
    // Synonym & Context checks
    if (!isRedundant && (cnLower.contains('cumin') || cnLower.contains('jeera') || cnLower.contains('જીરું')) && 
        (cvLower.contains('jeera') || cvLower.contains('cumin'))) {
      isRedundant = true;
    }
    
    // If it's just repeating "Mustard" or "Cotton" etc
    if (!isRedundant && cvLower.length > 3 && (cnLower.startsWith(cvLower) || cvLower.startsWith(cnLower))) {
      isRedundant = true;
    }

    if (isRedundant) return currentName;

    final displayVariety = gu ? CropTranslationUtils.translateVariety(cleanVariety) : cleanVariety;
    return '$currentName ($displayVariety)';
  }

  Widget _buildPriceItem(BuildContext context, CropPrice price, String displayName, 
      List<CropPrice> history, bool gu, ColorScheme cs, int index, 
      {bool showDateInCard = true, bool isDeesa = false, bool isPalanpur = false, String marketId = ''}) {
    return RepaintBoundary(
      child: InkWell(
        onTap: () => _showCropHistoryDialog(
          context, 
          displayName, 
          history, 
          gu, 
          cs, 
          marketId,
          isPalanpur: isPalanpur,
          currentPrice: price,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Card(
          elevation: 0,
          color: cs.surfaceContainerHighest.withAlpha(150),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withAlpha(150), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 1. Icon Section (Left)
                Hero(
                  tag: 'crop_icon_${marketId}_$displayName',
                  child: CropIconUtils.getCropIcon(displayName, size: 64),
                ),
                const SizedBox(width: 16),
                
                // 2. Info Section (Middle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 3. Price & Trend Section (Right)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (context) {
                        final overrides = context.watch<PriceOverrideProvider>().overrides;
                        final override = overrides[marketId];
                        final minP = override?.minPrice ?? price.minPrice;
                        final maxP = override?.maxPrice ?? price.maxPrice;
                        final isOverride = override != null;
      
                        final yardHistory = history.where((p) => p.yardName == price.yardName).toList();
                        Widget? trendIcon;
                        if (yardHistory.length > 1) {
                          final currentVal = double.tryParse(maxP.replaceAll(',', '')) ?? 0;
                          final prevVal = double.tryParse(yardHistory[1].maxPrice.replaceAll(',', '')) ?? 0;
                          
                          if (currentVal > prevVal) {
                            trendIcon = const Icon(Icons.trending_up_rounded, color: Colors.green, size: 16);
                          } else if (currentVal < prevVal) {
                            trendIcon = const Icon(Icons.trending_down_rounded, color: Colors.red, size: 16);
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (trendIcon != null) ...[
                                  trendIcon,
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  gu
                                      ? '₹${GujaratiNumberHelper.toGujarati(minP)} - ${GujaratiNumberHelper.toGujarati(maxP)}'
                                      : '₹$minP - $maxP',
                                  style: TextStyle(
                                    color: isOverride ? Colors.orange : cs.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    ),
                    if (showDateInCard && price.date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        String displayDate = price.date.replaceAll('/', '-');
                        try {
                          final parts = displayDate.split(' ');
                          if (parts.length == 3) {
                            const monthMap = {
                              'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04', 'May': '05', 'Jun': '06',
                              'Jul': '07', 'Aug': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
                              'January': '01', 'February': '02', 'March': '03', 'April': '04', 'June': '06', 
                              'July': '07', 'August': '08', 'September': '09', 'October': '10', 'November': '11', 'December': '12'
                            };
                            final m = monthMap[parts[1]] ?? parts[1];
                            displayDate = '${parts[0].padLeft(2, '0')}-$m-${parts[2]}';
                          }
                        } catch (_) {}
                        return Text(
                          gu ? GujaratiNumberHelper.toGujarati(displayDate) : displayDate,
                          style: TextStyle(
                            color: cs.onSurfaceVariant.withAlpha(180),
                            fontSize: 11,
                          ),
                        );
                      }),
                    ] else if (isPalanpur && price.income.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        gu ? 'આવક: ${GujaratiNumberHelper.toGujarati(price.income)}' : 'Income: ${price.income}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCropHistoryDialog(
      BuildContext context, 
      String displayName, 
      List<CropPrice> history, 
      bool gu, 
      ColorScheme cs, 
      String marketId,
      {required bool isPalanpur, required CropPrice currentPrice}) {
    
    // Calculate initial sheet size based on number of entries
    double initialSize;
    if (isPalanpur) {
      initialSize = 0.78;
    } else {
      final int entryCount = history.length;
      if (entryCount <= 2) {
        initialSize = 0.50;
      } else if (entryCount <= 4) {
        initialSize = 0.62;
      } else if (entryCount <= 7) {
        initialSize = 0.78;
      } else if (entryCount <= 10) {
        initialSize = 0.88;
      } else {
        initialSize = 0.95;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: initialSize,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return CropHistoryDialogContent(
                displayName: displayName,
                initialHistory: history,
                gu: gu,
                cs: cs,
                marketId: marketId,
                isPalanpur: isPalanpur,
                scrollController: scrollController,
                currentPrice: currentPrice,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool gu, {bool isFetching = false}) {
    final cs = Theme.of(context).colorScheme;
    final catName = gu 
        ? (CropCategoryUtils.gujaratiCategories[_selectedCategory] ?? _selectedCategory)
        : _selectedCategory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(30),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cs.primary.withAlpha(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                isFetching ? Icons.sync_rounded : Icons.category_outlined,
                size: 54,
                color: cs.primary.withAlpha(200),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            isFetching 
                ? (gu ? 'બજાર ભાવ મેળવી રહ્યા છીએ...' : 'Fetching market prices...')
                : (gu ? '$catName માં કોઈ પાક મળ્યો નથી' : 'No $catName found'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isFetching
                ? (gu ? 'કૃપા કરીને થોડીવાર રાહ જુઓ' : 'Please wait a moment...')
                : (gu 
                    ? 'તમારા ફિલ્ટર સેટિંગ્સ તપાસો અથવા બધા પાક જોવા માટે નીચે ક્લિક કરો' 
                    : 'Check your filter settings or click below to see all crops'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant.withAlpha(180),
              height: 1.5,
            ),
          ),
          if (!isFetching && _selectedCategory != CropCategoryUtils.catAll)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: FilledButton.tonalIcon(
                onPressed: () => setState(() => _selectedCategory = CropCategoryUtils.catAll),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  gu ? 'બધા પાક બતાવો' : 'Show All Crops',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid(BuildContext context, int crossAxisCount) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 1 ? 3.6 : 1.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest.withOpacity(0.5),
        highlightColor: cs.surfaceContainerHighest.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  String _formatLastUpdated(DateTime dt, bool gu) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    
    if (difference.inMinutes < 1) {
      return gu ? 'હમણાં જ અપડેટ કર્યું' : 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return gu 
          ? '${GujaratiNumberHelper.toGujarati(mins.toString())} મિનિટ પહેલા' 
          : '$mins mins ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return gu 
          ? '${GujaratiNumberHelper.toGujarati(hours.toString())} કલાક પહેલા' 
          : '$hours hours ago';
    } else {
      return gu 
          ? GujaratiNumberHelper.toGujarati('${dt.day}/${dt.month}/${dt.year}') 
          : '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  void _showMarketPicker(BuildContext context, bool gu, ColorScheme cs, CropPriceProvider provider) {
    final markets = [
      {'index': 0, 'en': 'Deesa', 'gu': 'ડીસા', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 1, 'en': 'Palanpur', 'gu': 'પાલનપુર', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 5, 'en': 'Dhanera', 'gu': 'ધાનેરા', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 6, 'en': 'Amirgadh', 'gu': 'અમીરગઢ', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 8, 'en': 'Siddhpur', 'gu': 'સિદ્ધપુર', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 9, 'en': 'Radhanpur', 'gu': 'રાધનપુર', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 10, 'en': 'Himatnagar', 'gu': 'હિંમતનગર', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 11, 'en': 'Unjha', 'gu': 'ઉંઝા', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 17, 'en': 'Visnagar', 'gu': 'વિસનગર', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 19, 'en': 'Bagasara', 'gu': 'બગસરા', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 20, 'en': 'Jasdan', 'gu': 'જસદણ', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 21, 'en': 'Jetpur', 'gu': 'જેતપુર', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 22, 'en': 'Jamnagar', 'gu': 'જામનગર', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 23, 'en': 'Rajula', 'gu': 'રાજુલા', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 24, 'en': 'Patan', 'gu': 'પાટણ', 'region_en': 'North Gujarat', 'region_gu': 'ઉત્તર ગુજરાત'},
      {'index': 25, 'en': 'Savarkundla', 'gu': 'સાવરકુંડલા', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 3, 'en': 'Junagadh', 'gu': 'જૂનાગઢ', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 4, 'en': 'Rajkot', 'gu': 'રાજકોટ', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 12, 'en': 'Mahuva', 'gu': 'મહૂવા', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 13, 'en': 'Gondal', 'gu': 'ગોંડલ', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 14, 'en': 'Botad', 'gu': 'બોટાદ', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 15, 'en': 'Amreli', 'gu': 'અમરેલી', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 16, 'en': 'Babra', 'gu': 'બાબરા', 'region_en': 'Saurashtra', 'region_gu': 'સૌરાષ્ટ્ર'},
      {'index': 2, 'en': 'Ahmedabad', 'gu': 'અમદાવાદ', 'region_en': 'Central Gujarat', 'region_gu': 'મધ્ય ગુજરાત'},
      {'index': 7, 'en': 'Surat', 'gu': 'સુરત', 'region_en': 'South Gujarat', 'region_gu': 'દક્ષિણ ગુજરાત'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredMarkets = markets.where((m) {
              final q = searchQuery.toLowerCase();
              final en = (m['en'] as String).toLowerCase();
              final guName = m['gu'] as String;
              return en.contains(q) || guName.contains(q);
            }).toList();

            final flattenedList = <dynamic>[];
            
            // Recently Viewed section — only show when not actively searching
            if (searchQuery.isEmpty && _recentMarketIndices.isNotEmpty) {
              final recentMarkets = _recentMarketIndices
                  .map((idx) => markets.firstWhere((m) => m['index'] == idx, orElse: () => {}))
                  .where((m) => m.isNotEmpty)
                  .toList();
              if (recentMarkets.isNotEmpty) {
                flattenedList.add({'isHeader': true, 'en': 'Recently Viewed', 'gu': 'તાજેતરમાં જોયેલ', 'isRecent': true});
                flattenedList.addAll(recentMarkets);
              }
            }

            final orderedRegions = [
              {'en': 'North Gujarat', 'gu': 'ઉત્તર ગુજરાત'},
              {'en': 'Saurashtra', 'gu': 'સૌરાષ્ટ્ર'},
              {'en': 'Central Gujarat', 'gu': 'મધ્ય ગુજરાત'},
              {'en': 'South Gujarat', 'gu': 'દક્ષિણ ગુજરાત'},
            ];

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 20, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withAlpha(100),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(Icons.storefront_rounded, color: cs.primary),
                            const SizedBox(width: 12),
                            Text(
                              gu ? 'બજાર પસંદ કરો' : 'Select Market',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                              tooltip: gu ? 'બંધ કરો' : 'Close',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: gu ? 'શોધો...' : 'Search markets...',
                            prefixIcon: Icon(Icons.search, color: cs.primary),
                            filled: true,
                            fillColor: cs.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: CustomScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            // 1. Recently Viewed Carousel
                            if (searchQuery.isEmpty && _recentMarketIndices.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.history_rounded, size: 16, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 8),
                                      Text(
                                        gu ? 'તાજેતરમાં જોયેલ' : 'Recently Viewed',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurfaceVariant,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: _recentMarketIndices.length,
                                    itemBuilder: (ctx, idx) {
                                      final mIdx = _recentMarketIndices[idx];
                                      final m = markets.firstWhere((m) => m['index'] == mIdx, orElse: () => {});
                                      if (m.isEmpty) return const SizedBox.shrink();
                                      
                                      final isSelected = provider.selectedApmcIndex == m['index'];
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 12, bottom: 8),
                                        child: _buildMarketCard(ctx, m, gu, cs, provider, isSelected, isRecent: true),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],

                            // 2. Regional Grids
                            for (final r in orderedRegions) ...[
                              if (filteredMarkets.any((m) => m['region_en'] == r['en'])) ...[
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                                    child: Text(
                                      gu ? (r['gu'] as String) : (r['en'] as String),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: cs.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 2.2,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, idx) {
                                        final regionMarkets = filteredMarkets.where((m) => m['region_en'] == r['en']).toList();
                                        final m = regionMarkets[idx];
                                        final isSelected = provider.selectedApmcIndex == m['index'];
                                        return _buildMarketCard(ctx, m, gu, cs, provider, isSelected);
                                      },
                                      childCount: filteredMarkets.where((m) => m['region_en'] == r['en']).length,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            const SliverToBoxAdapter(child: SizedBox(height: 40)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMarketCard(BuildContext context, Map<String, dynamic> m, bool gu, ColorScheme cs, CropPriceProvider provider, bool isSelected, {bool isRecent = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          provider.setSelectedApmc(m['index'] as int);
          _saveRecentMarket(m['index'] as int);
          setState(() {
            _selectedCategory = CropCategoryUtils.catAll;
          });
          // Small delay to let the user see the selection feedback in the modal
          Future.delayed(const Duration(milliseconds: 150), () {
            if (context.mounted) Navigator.pop(context);
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: isRecent ? 140 : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant.withAlpha(50),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                gu ? (m['gu'] as String) : (m['en'] as String),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: isRecent ? 16 : 15,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle_rounded, color: cs.primary, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String translateMarketName(String name) {
    const translations = {
      'Deesa': 'ડીસા',
      'Palanpur': 'પાલનપુર',
      'Ahmedabad': 'અમદાવાદ',
      'Junagadh': 'જૂનાગઢ',
      'Rajkot': 'રાજકોટ',
      'Dhanera': 'ધાનેરા',
      'Amirgadh': 'અમીરગઢ',
      'Visnagar': 'વિસનગર',
      'Surat': 'સુરત',
      'Siddhpur': 'સિદ્ધપુર',
      'Radhanpur': 'રાધનપુર',
      'Himatnagar': 'હિંમતનગર',
      'Unjha': 'ઉંઝા',
      'Mahuva': 'મહૂવા',
      'Gondal': 'ગોંડલ',
      'Botad': 'બોટાદ',
      'Amreli': 'અમરેલી',
      'Babra': 'બાબરા',
      'Bagasara': 'બગસરા',
      'Jasdan': 'જસદણ',
      'Jetpur': 'જેતપુર',
      'Jamnagar': 'જામનગર',
      'Rajula': 'રાજુલા',
      'Patan': 'પાટણ',
      'Savarkundla': 'સાવરકુંડલા',
      'Agra Potato': 'આગ્રા બટાકા',
    };
    return translations[name] ?? name;
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String guLabel;
  final bool isGujarati;
  
  const _SectionLabel({
    required this.label, 
    required this.guLabel, 
    this.isGujarati = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      isGujarati ? guLabel : label,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _GondalPdfButton extends StatefulWidget {
  final String? dateStr;
  final bool gu;
  final ColorScheme cs;

  const _GondalPdfButton({
    required this.dateStr,
    required this.gu,
    required this.cs,
  });

  @override
  State<_GondalPdfButton> createState() => _GondalPdfButtonState();
}

class _GondalPdfButtonState extends State<_GondalPdfButton> {
  bool _isLoading = false;

  DateTime? _parseDate() {
    if (widget.dateStr == null || widget.dateStr!.isEmpty) return null;
    try {
      final parts = widget.dateStr!.split(' ');
      if (parts.length == 3) {
        const months = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        };
        final m = months[parts[1]] ?? 1;
        return DateTime(int.parse(parts[2]), m, int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: widget.cs.primary),
            ),
          )
        : FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              setState(() => _isLoading = true);
              final targetDate = _parseDate();
              final path = await GondalApmcService.downloadGondalPdf(targetDate);
              if (mounted) {
                setState(() => _isLoading = false);
                if (path != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        pdfPath: path,
                        title: widget.gu ? 'ગોંડલ માર્કેટ યાર્ડ ભાવો' : 'Gondal Market Rates',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.gu ? 'PDF ડાઉનલોડ કરવામાં નિષ્ફળ' : 'Failed to download PDF'),
                      backgroundColor: widget.cs.error,
                    ),
                  );
                }
              }
            },
            icon: Icon(Icons.picture_as_pdf_rounded, size: 18, color: widget.cs.primary),
            label: Text(
              widget.gu ? 'વધુ માહિતી મેળવો' : 'Get More Info',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: widget.cs.primary,
                fontSize: 13,
              ),
            ),
          );
  }
}

class CropHistoryDialogContent extends StatefulWidget {
  final String displayName;
  final List<CropPrice> initialHistory;
  final bool gu;
  final ColorScheme cs;
  final String marketId;
  final bool isPalanpur;
  final ScrollController scrollController;
  final CropPrice currentPrice;

  const CropHistoryDialogContent({
    super.key,
    required this.displayName,
    required this.initialHistory,
    required this.gu,
    required this.cs,
    required this.marketId,
    required this.isPalanpur,
    required this.scrollController,
    required this.currentPrice,
  });

  @override
  State<CropHistoryDialogContent> createState() => _CropHistoryDialogContentState();
}

class _CropHistoryDialogContentState extends State<CropHistoryDialogContent> {
  late List<CropPrice> _history;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _daysFetched = 7;
  String? _error;
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPalanpur) {
      _history = [widget.currentPrice];
      _isLoading = true;
      _fetchPalanpurHistory();
    } else {
      _history = List<CropPrice>.from(widget.initialHistory)..sort((a, b) {
        try {
          const months = {
            'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
            'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
          };
          
          final aParts = a.date.split(' ');
          final bParts = b.date.split(' ');
          
          if (aParts.length == 3 && bParts.length == 3) {
            final aDate = DateTime(
                int.parse(aParts[2]), months[aParts[1]] ?? 1, int.parse(aParts[0]));
            final bDate = DateTime(
                int.parse(bParts[2]), months[bParts[1]] ?? 1, int.parse(bParts[0]));
            return bDate.compareTo(aDate); // Descending
          }
          return b.date.compareTo(a.date);
        } catch (e) {
          return b.date.compareTo(a.date);
        }
      });
      _isLoading = false;
    }
  }

  Future<void> _fetchPalanpurHistory({bool loadMore = false, bool forceRefresh = false}) async {
    try {
      if (loadMore) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'palanpur_history_cache_${widget.currentPrice.name}';
      final timestampKey = 'palanpur_history_cache_time_${widget.currentPrice.name}';
      final daysKey = 'palanpur_history_cache_days_${widget.currentPrice.name}';

      if (!loadMore && !forceRefresh) {
        final cachedTimeMs = prefs.getInt(timestampKey);
        final cachedJson = prefs.getString(cacheKey);
        if (cachedTimeMs != null && cachedJson != null) {
          final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedTimeMs);
          final now = DateTime.now();
          if (now.difference(cachedTime) < const Duration(days: 1)) {
            final decoded = jsonDecode(cachedJson);
            if (decoded is List) {
              final List<CropPrice> cachedHistory = decoded
                  .map((item) => CropPrice.fromJson(item as Map<String, dynamic>))
                  .toList();
              if (cachedHistory.isNotEmpty) {
                if (mounted) {
                  setState(() {
                    _history = cachedHistory;
                    _isLoading = false;
                    _daysFetched = prefs.getInt(daysKey) ?? 7;
                  });
                }
                debugPrint('Loaded Palanpur history from 1-day cache for ${widget.currentPrice.name}');
                return;
              }
            }
          }
        }
      }

      final baseDate = CropPriceProvider.parseDate(widget.currentPrice.date) ?? DateTime.now();
      final offset = loadMore ? _daysFetched : 0;
      final dates = List.generate(7, (i) => baseDate.subtract(Duration(days: offset + i)));

      final results = await Future.wait(
        dates.map((date) => CropPriceService.fetchPalanpurPrices(date: date))
      );

      final List<CropPrice> fetchedHistory = [];
      for (final dayPrices in results) {
        if (dayPrices.isNotEmpty) {
          final matches = dayPrices.where((p) => p.name == widget.currentPrice.name);
          if (matches.isNotEmpty) {
            fetchedHistory.add(matches.first);
          }
        }
      }

      final seenDates = <String>{};
      final List<CropPrice> merged = [];
      
      final sourceList = loadMore ? [..._history, ...fetchedHistory] : fetchedHistory;
      for (final p in sourceList) {
        if (seenDates.add(p.date)) {
          merged.add(p);
        }
      }
      if (seenDates.add(widget.currentPrice.date)) {
        merged.add(widget.currentPrice);
      }

      // Sort descending by date
      merged.sort((a, b) {
        try {
          const months = {
            'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
            'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
          };
          
          final aParts = a.date.split(' ');
          final bParts = b.date.split(' ');
          
          if (aParts.length == 3 && bParts.length == 3) {
            final aDate = DateTime(
                int.parse(aParts[2]), months[aParts[1]] ?? 1, int.parse(aParts[0]));
            final bDate = DateTime(
                int.parse(bParts[2]), months[bParts[1]] ?? 1, int.parse(bParts[0]));
            return bDate.compareTo(aDate); // Descending
          }
          return b.date.compareTo(a.date);
        } catch (e) {
          return b.date.compareTo(a.date);
        }
      });

      if (mounted) {
        setState(() {
          _history = merged;
          if (loadMore) {
            _daysFetched += 7;
            _isLoadingMore = false;
          } else {
            _isLoading = false;
            _daysFetched = 7;
          }
        });
      }

      // Save to SharedPreferences cache
      try {
        await prefs.setString(cacheKey, jsonEncode(merged.map((e) => e.toJson()).toList()));
        await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setInt(daysKey, _daysFetched);
      } catch (e) {
        debugPrint('Error saving Palanpur history to cache: $e');
      }
    } catch (e) {
      debugPrint('Error fetching Palanpur history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = widget.gu ? 'ઇતિહાસ લોડ કરવામાં ભૂલ આવી' : 'Error loading history';
        });
      }
    }
  }

  Future<void> _shareCropHistoryScreenshot() async {
    setState(() {
      _isSharing = true;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/crop_history_$timestamp.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: widget.gu ? 'ખેતીબુક' : 'KhetiBook',
        text: '''🚜 ખેતીનો હિસાબ હવે સરળ – ખેતીબુક (KhetiBook) 
જૂની ડાયરી ભૂલો, હવે બધુ ડિજિટલ 👇
✅ લાઈવ બજાર ભાવ (ડીસા, પાલનપુર, રાજકોટ તથા અન્ય માર્કેટ)
✅ ખર્ચ-આવકનો સંપૂર્ણ હિસાબ
✅ મજૂરી અને લણણી મેનેજમેન્ટ
✅ ગુજરાતી + Offline ઉપયોગ
🌾 આજે જ ડાઉનલોડ કરો અને ખેતીને સ્માર્ટ બનાવો! 🚀
👉 https://play.google.com/store/apps/details?id=com.farmer.farmer_accounting''',
      );
    } catch (e) {
      debugPrint('Error sharing crop history screenshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.gu ? 'શેર કરવામાં ભૂલ આવી: $e' : 'Error sharing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Widget _buildHistoryCard(CropPrice item, {required bool isLatest, Widget? trendWidget}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isLatest ? LinearGradient(
          colors: [
            widget.cs.primaryContainer.withOpacity(0.4),
            widget.cs.primaryContainer.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        color: isLatest ? null : widget.cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest 
              ? widget.cs.primary.withOpacity(0.4) 
              : widget.cs.outlineVariant.withOpacity(0.2),
          width: isLatest ? 1.5 : 1.0,
        ),
        boxShadow: isLatest ? [
          BoxShadow(
            color: widget.cs.primary.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ] : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.gu ? GujaratiNumberHelper.toGujarati(item.date.replaceAll('/', '-')) : item.date,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isLatest ? 16 : 15,
                ),
              ),
              if (isLatest)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.gu ? 'તાજેતરના' : 'Latest',
                    style: TextStyle(
                      color: widget.cs.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.gu
                    ? '₹${GujaratiNumberHelper.toGujarati(item.minPrice)} - ${GujaratiNumberHelper.toGujarati(item.maxPrice)}'
                    : '₹$item.minPrice - $item.maxPrice',
                style: TextStyle(
                  color: isLatest ? widget.cs.primary : widget.cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: isLatest ? 18 : 16,
                ),
              ),
              if (trendWidget != null) ...[
                const SizedBox(height: 4),
                trendWidget,
              ],
              if (item.income.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.gu ? 'આવક: ${GujaratiNumberHelper.toGujarati(item.income)}' : 'Income: ${item.income}',
                  style: TextStyle(
                    color: widget.cs.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerHistoryList(ColorScheme cs) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 4,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHistoryCard(widget.currentPrice, isLatest: true, trendWidget: null);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: cs.surfaceContainerLow,
            highlightColor: cs.surfaceContainerHighest,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSparkline(List<CropPrice> history, ColorScheme cs) {
    if (history.length < 2) return const SizedBox.shrink();
    
    // Collect prices and reverse so they are chronological for chart (oldest to newest)
    final chronologicalHistory = history.reversed.toList();
    final points = chronologicalHistory.map((e) {
      double min = double.tryParse(e.minPrice.replaceAll(',', '')) ?? 0;
      double max = double.tryParse(e.maxPrice.replaceAll(',', '')) ?? 0;
      return (min + max) / 2;
    }).toList();

    if (points.every((p) => p == 0)) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => cs.surfaceContainerHigh.withOpacity(0.9),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = index < chronologicalHistory.length ? chronologicalHistory[index].date : '';
                // Format nicely: e.g. "20 Apr\n₹1200"
                final dateSplit = date.split(' ');
                final shortDate = dateSplit.length >= 2 ? '${dateSplit[0]} ${dateSplit[1]}' : date;
                
                return LineTooltipItem(
                  '$shortDate\n',
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                  children: [
                    TextSpan(
                      text: '₹${spot.y.toInt()}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: points.asMap().entries.where((e) => e.value > 0).map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: cs.primary.withOpacity(0.7),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(0.25),
                  cs.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: widget.cs.primary,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () => _fetchPalanpurHistory(loadMore: true),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: widget.cs.primary.withOpacity(0.5)),
          ),
          icon: Icon(Icons.add_rounded, color: widget.cs.primary),
          label: Text(
            widget.gu ? 'જુના ભાવ જોવો' : 'Load More History',
            style: TextStyle(
              color: widget.cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: Container(
        decoration: BoxDecoration(
          color: widget.cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.cs.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isSharing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CropIconUtils.getCropIcon(widget.displayName, size: 56),
                          const SizedBox(width: 16),
                          Text(
                            widget.displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Hero(
                            tag: 'crop_icon_${widget.marketId}_${widget.displayName}', 
                            child: CropIconUtils.getCropIcon(widget.displayName, size: 56),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _isSharing ? null : _shareCropHistoryScreenshot,
                            icon: const Icon(Icons.share_rounded),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
              const SizedBox(height: 20),
              Text(
                widget.gu ? 'પાછલા દિવસોના ભાવ' : 'Previous market rates',
                style: TextStyle(
                  color: widget.cs.onSurfaceVariant,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? _buildShimmerHistoryList(widget.cs)
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: TextStyle(color: widget.cs.error)),
                          const SizedBox(height: 16),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _fetchPalanpurHistory(forceRefresh: true);
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(widget.gu ? 'ફરીથી પ્રયાસ કરો' : 'Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: widget.isPalanpur ? _history.length + 1 : _history.length,
                      itemBuilder: (context, index) {
                        if (widget.isPalanpur && index == _history.length) {
                          return _buildLoadMoreButton();
                        }

                        final item = _history[index];
                        final isLatest = index == 0;
                        
                        // Calculate trend difference
                        double currentMax = double.tryParse(item.maxPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                        double prevMax = 0;
                        if (index < _history.length - 1) {
                          prevMax = double.tryParse(_history[index + 1].maxPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                        }
                        double diff = currentMax > 0 && prevMax > 0 ? (currentMax - prevMax) : 0;
                        
                        Widget? trendWidget;
                        if (diff != 0 && index < _history.length - 1) {
                          bool isUp = diff > 0;
                          trendWidget = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isUp ? Colors.green : Colors.red).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: isUp ? Colors.green : Colors.redAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.gu ? '₹${GujaratiNumberHelper.toGujarati(diff.abs().toStringAsFixed(0))}' : '₹${diff.abs().toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: isUp ? Colors.green : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return _buildHistoryCard(item, isLatest: isLatest, trendWidget: trendWidget);
                      },
                    ),
        ),
        if (!_isLoading && _error == null && _history.length > 2)
          Container(
            height: 80,
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: _buildSparkline(_history, widget.cs),
          )
        else
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
      ],
    ),),);
  }
}
