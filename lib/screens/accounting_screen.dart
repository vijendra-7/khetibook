import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../database/app_database.dart';
import 'crop_selection_screen.dart';
import 'transaction_type_selection_screen.dart';
import 'recycle_bin_screen.dart';
import 'statement_screen.dart';
import 'settings_screen.dart';
import '../providers/global_options_provider.dart';
import '../utils/gujarati_number_helper.dart';
import '../utils/language_mapper.dart';
import 'investment_screen.dart';
import 'output_screen.dart';
import 'add_helper_transaction_screen.dart';
import '../utils/crop_icon_utils.dart';
import '../widgets/announcement_card.dart';
import 'all_activity_screen.dart';

Route _smoothRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, anim, __) => page,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<RecentActivity> _recentItems = [];
  bool _isLoading = true;



  @override
  void initState() {
    super.initState();
    _loadRecent();
  }


  Future<void> _loadRecent() async {
    final items = await AppDatabase.instance.getRecentActivity(limit: 3);
    if (mounted) {
      setState(() {
        _recentItems = items;
        _isLoading = false;
      });
    }
  }


  void _onActivityTap(RecentActivity item, bool gu) async {
    final db = AppDatabase.instance;
    if (item.sourceTable == 'investment') {
      final inv = await db.getInvestmentById(item.id);
      if (inv != null && mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, anim, __) => InvestmentFormScreen(crop: inv.crop, investment: inv, isGujarati: gu),
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ).then((_) => _loadRecent());
      }
    } else if (item.sourceTable == 'output') {
      final out = await db.getOutputById(item.id);
      if (out != null && mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, anim, __) => OutputFormScreen(crop: out.crop, output: out, isGujarati: gu),
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ).then((_) => _loadRecent());
      }
    } else if (item.sourceTable == 'helper') {
      final txn = await db.getTransactionById(item.id);
      if (txn != null && mounted) {
        final types = ['Upaad', 'Bhaag', 'Majur', 'Tractor'];
        final idx = types.indexOf(txn.transactionType).clamp(0, 3);
        Navigator.push(
          context,
          _smoothRoute(
            AddHelperTransactionScreen(
              transactionType: txn.transactionType,
              typeIndex: idx,
              transaction: txn,
              isGujarati: gu,
            ),
          ),
        ).then((_) => _loadRecent());
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to SyncProvider for background refresh (listen: false because we handle updates manually via listener)
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    syncProvider.removeListener(_onSyncChange);
    syncProvider.addListener(_onSyncChange);
  }

  void _onSyncChange() {
    if (!context.read<SyncProvider>().isSyncing) {
      _loadRecent();
    }
  }

  @override
  void dispose() {
    // Avoid memory leaks
    try {
      context.read<SyncProvider>().removeListener(_onSyncChange);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final gu = context.select<SettingsProvider, bool>((p) => p.isGujarati);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: true,
          centerTitle: true,
          backgroundColor: cs.surfaceContainerLowest,
          title: const Text(
            'KhetiBook',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, _smoothRoute(const SettingsScreen()));
              },
              tooltip: 'Settings',
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnnouncementCard(gu: gu),
                  const SizedBox(height: 16),
                  // ── Section: Farm Management ──────────────────────────────
                  _SectionLabel(
                      label: 'Farm Management',
                      guLabel: 'ખેતી',
                      isGujarati: gu),
                  const SizedBox(height: 10),

                  // Row 1: Investment + Harvest (2-column)
                  Row(
                    children: [
                      Expanded(
                        child: _HomeCard(
                          imagePath: 'assets/icons/new4.webp',
                          imageScale: 1.3,
                          label: 'Investment',
                          sublabel: 'ખર્ચો',
                          circleColor: Colors.grey.shade200.withOpacity(0.5),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE65100), Color(0xFFBF360C)],
                          ),
                          shadowColor: const Color(0xFFBF360C).withAlpha(100),
                          isGujarati: gu,
                          aspectRatio: 1.05,
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await Navigator.push(
                              context,
                              _smoothRoute(const CropSelectionScreen(
                                  selectionType: SelectionType.investment)),
                            );
                            _loadRecent();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HomeCard(
                          imagePath: 'assets/icons/new3.webp',
                          imageScale: 1.4,
                          label: 'Harvest',
                          sublabel: 'ઉત્પાદન',
                          circleColor: const Color(0xFFBCCAA4).withOpacity(0.4), // Soft Sage Green
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                          ),
                          shadowColor: const Color(0xFF1B5E20).withAlpha(100),
                          isGujarati: gu,
                          aspectRatio: 1.05,
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await Navigator.push(
                              context,
                              _smoothRoute(const CropSelectionScreen(
                                  selectionType: SelectionType.output)),
                            );
                            _loadRecent();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Row 2: Helper Account (full width)
                  _HomeCard(
                    imagePath: 'assets/icons/helper_3d.webp',
                    imageScale: 2.0,
                    label: 'Partner Account',
                    sublabel: 'ભાગીદાર ખાતું',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    isGujarati: gu,
                    fullWidth: true,
                    aspectRatio: 4.2,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await Navigator.push(
                        context,
                        _smoothRoute(const TransactionTypeSelectionScreen()),
                      );
                      _loadRecent();
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Section: Recent Activity ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SectionLabel(
                          label: 'Recent Activity',
                          guLabel: 'તાજેતરની પ્રવૃત્તિ',
                          isGujarati: gu),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            _smoothRoute(const AllActivityScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          gu ? 'બધા જુઓ' : 'See All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  if (_isLoading)
                    Column(
                      children: List.generate(3, (index) => _buildItemShimmer(cs)),
                    )
                  else if (_recentItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          gu ? 'કોઈ પ્રવૃત્તિ નથી' : 'No recent activity',
                          style: TextStyle(color: cs.outline, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._recentItems.map((item) {
                      IconData icon;
                      Color iconColor;
                      if (item.sourceTable == 'investment') {
                        iconColor = Colors.orange;
                        switch (item.type) {
                          case 'Biyaran':
                            icon = Icons.grass_rounded;
                            break;
                          case 'Khatar':
                          case 'Dawa':
                            icon = Icons.inventory_2_outlined;
                            break;
                          case 'Khed':
                          case 'Shed':
                          case 'Rotavator':
                          case 'Peyani':
                          case 'Zero':
                          case 'Thresher':
                            icon = Icons.agriculture_rounded;
                            break;
                          default:
                            icon = Icons.eco_rounded;
                        }
                      } else if (item.sourceTable == 'output') {
                        icon = Icons.grass_rounded;
                        iconColor = Colors.green;
                      } else {
                        icon = Icons.people_alt_rounded;
                        iconColor = Colors.blue;
                      }
                      final d = DateTime.fromMillisecondsSinceEpoch(item.date);
                      String dateStr;
                      if (!gu) {
                        dateStr = DateFormat('dd MMM yyyy').format(d);
                      } else {
                        final monthsGu = [
                          'જાન્યુ',
                          'ફેબ્રુ',
                          'માર્ચ',
                          'એપ્રિલ',
                          'મે',
                          'જૂન',
                          'જુલાઈ',
                          'ઓગ',
                          'સપ્ટે',
                          'ઓક્ટો',
                          'નવે',
                          'ડિસે'
                        ];
                        final m = monthsGu[d.month - 1];
                        final formatted =
                            '${d.day.toString().padLeft(2, '0')} $m ${d.year}';
                        dateStr = GujaratiNumberHelper.toGujarati(formatted);
                      }

                      final globalCropMap = context.read<GlobalOptionsProvider>().getGlobalCropMap(gu);
                      final globalInvMap = context.read<GlobalOptionsProvider>().getGlobalInvestmentTypeMap(gu);

                      String displayTitle;
                      String displaySubtitle;

                      if (item.sourceTable == 'investment') {
                        displayTitle =
                            LanguageMapper.localizedCrop(item.title, gu, globalCropMap);
                        displaySubtitle =
                            LanguageMapper.localizedInvestmentType(
                                item.subtitle, gu, globalInvMap);
                      } else if (item.sourceTable == 'output') {
                        displayTitle =
                            LanguageMapper.localizedCrop(item.title, gu, globalCropMap);
                        displaySubtitle = gu ? 'ઉત્પાદન' : 'Harvest';
                      } else {
                        // helper account
                        displayTitle = LanguageMapper.localizedServiceProvider(
                            item.title, gu);
                        displaySubtitle =
                            LanguageMapper.localizedTransactionType(
                                item.subtitle, gu);
                      }

                      // Color: green for income, red for expense
                      final amountColor = item.sourceTable == 'output'
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFB71C1C);

                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: iconColor.withAlpha(15), // Highly performant simulated tint
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: iconColor.withAlpha(40), // Faint border of the same tint
                              width: 1.0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              children: [
                                // Colored left accent strip
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(width: 4, color: iconColor), // Slightly thicker stripe
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _onActivityTap(item, gu);
                                  },
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(
                                        left: 19, right: 16, top: 8, bottom: 8),
                                    leading: CircleAvatar(
                                      radius: 22, // Adjusted for larger icons
                                      backgroundColor: iconColor.withAlpha(30),
                                      child: (item.sourceTable == 'investment' || item.sourceTable == 'output')
                                          ? CropIconUtils.getCropIcon(item.title, size: 40)
                                          : Icon(icon, color: iconColor, size: 20),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(displayTitle,
                                              style: TextStyle(
                                                  color: cs.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15)),
                                        ),
                                        Text(
                                          gu
                                              ? GujaratiNumberHelper
                                                  .formatCurrency(item.amount,
                                                      gujarati: true)
                                              : '₹${item.amount.toInt()}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: amountColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      displaySubtitle,
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 13),
                                    ),
                                    trailing: Text(dateStr,
                                        style: TextStyle(
                                            color: cs.outline, fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),

                  // ── Section: Reports ──────────────────────────────────────
                  _SectionLabel(
                      label: 'Reports', guLabel: 'અહેવાલ', isGujarati: gu),
                  const SizedBox(height: 10),

                  // Statement — full width, taller featured card
                  _HomeCard(
                    icon: Icons.bar_chart_rounded,
                    label: 'Financial Statement',
                    sublabel: 'ખેતી ચોપડો',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A148C), Color(0xFFAB47BC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    isGujarati: gu,
                    fullWidth: true,
                    aspectRatio: 2.8,
                    trailingIcon: Icons.picture_as_pdf_rounded,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await Navigator.push(
                        context,
                        _smoothRoute(const StatementScreen()),
                      );
                      _loadRecent();
                    },
                  ),

                  const SizedBox(height: 36),

                  // ── Recycle Bin — small subtle link ───────────────────────
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await Navigator.push(
                          context,
                          _smoothRoute(const RecycleBinScreen()),
                        );
                        _loadRecent();
                      },
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: cs.outline),
                      label: Text(
                        gu ? 'રિસાઈકલ' : 'Recycle Bin',
                        style: TextStyle(
                          color: cs.outline,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildItemShimmer(ColorScheme cs) {
    return Shimmer.fromColors(
      baseColor: cs.outlineVariant.withAlpha(50),
      highlightColor: cs.outlineVariant.withAlpha(20),
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String guLabel;
  final bool isGujarati;
  const _SectionLabel(
      {required this.label, required this.guLabel, this.isGujarati = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          isGujarati ? guLabel : label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _HomeCard extends StatefulWidget {
  final IconData? icon;
  final String? imagePath;
  final double imageScale;
  final String label;
  final String sublabel;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final bool fullWidth;
  final double aspectRatio;
  final IconData? trailingIcon;
  final bool isGujarati;
  final Color? circleColor;
  final Color? shadowColor;

  const _HomeCard({
    this.icon,
    this.imagePath,
    this.imageScale = 1.0,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
    this.fullWidth = false,
    this.aspectRatio = 1.1,
    this.trailingIcon,
    this.isGujarati = false,
    this.circleColor,
    this.shadowColor,
  });

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(50), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: (widget.shadowColor ?? widget.gradient.colors.first)
                    .withAlpha(_isPressed ? 40 : 90),
                blurRadius: _isPressed ? 10 : 28,
                offset: Offset(0, _isPressed ? 2 : 8),
              ),
              BoxShadow(
                color: widget.gradient.colors.last.withAlpha(40),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.fullWidth ? _buildWide(context) : _buildSquare(context),
        ),
      ),
    );

    if (widget.fullWidth) return card;
    return AspectRatio(aspectRatio: widget.aspectRatio, child: card);
  }

  // Square / grid card (Investment, Harvest)
  Widget _buildSquare(BuildContext context) {
    final displayLabel = widget.isGujarati ? widget.sublabel : widget.label;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: widget.circleColor ?? Colors.white.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.imagePath != null
                    ? Transform.scale(
                        scale: widget.imageScale,
                        child: Image.asset(widget.imagePath!, width: 68, height: 68, fit: BoxFit.contain, gaplessPlayback: true),
                      )
                    : Icon(widget.icon ?? Icons.eco_rounded, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Wide / full-width card (Helper Account, Statement)
  Widget _buildWide(BuildContext context) {
    final displayLabel = widget.isGujarati ? widget.sublabel : widget.label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.circleColor ?? Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.imagePath != null
                ? Transform.scale(
                    scale: widget.imageScale,
                    child: Image.asset(widget.imagePath!, width: 52, height: 52, fit: BoxFit.contain, gaplessPlayback: true),
                  )
                : Icon(widget.icon ?? Icons.people_alt_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              displayLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (widget.trailingIcon != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.trailingIcon, color: Colors.white, size: 20),
            )
          else
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 24),
        ],
      ),
    );
  }
}
