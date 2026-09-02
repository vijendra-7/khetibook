import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../providers/settings_provider.dart';
import '../providers/global_options_provider.dart';
import '../utils/gujarati_number_helper.dart';
import '../utils/language_mapper.dart';
import '../utils/crop_icon_utils.dart';
import 'investment_screen.dart';
import 'output_screen.dart';
import 'add_helper_transaction_screen.dart';

class AllActivityScreen extends StatefulWidget {
  const AllActivityScreen({super.key});

  @override
  State<AllActivityScreen> createState() => _AllActivityScreenState();
}

class _AllActivityScreenState extends State<AllActivityScreen> {
  List<RecentActivity> _allItems = [];
  List<_RowEntry> _processedRows = [];
  bool _isLoading = true;
  bool _isFirstLoad = true;
  // 'all', 'investment', 'output', 'helper'
  String _filter = 'all';

  void _rebuildRows() {
    final filtered = _filter == 'all'
        ? _allItems
        : _allItems.where((i) => i.sourceTable == _filter).toList();

    // Group items by "Month Year" (yyyy-MM)
    final Map<String, List<RecentActivity>> grouped = {};
    for (final item in filtered) {
      final d = DateTime.fromMillisecondsSinceEpoch(item.date);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    // Build flat index list
    final List<_RowEntry> newRows = [];
    for (final key in grouped.keys) {
      newRows.add(_RowEntry.header(key));
      for (final item in grouped[key]!) {
        newRows.add(_RowEntry.activity(item));
      }
    }

    setState(() {
      _processedRows = newRows;
    });
  }

  @override
  void initState() {
    super.initState();
    // Delay loading briefly to ensure the screen transition animation is perfectly smooth
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (_isFirstLoad) {
      setState(() => _isLoading = true);
    }

    final items = await AppDatabase.instance.getRecentActivity(limit: 10000);
    if (mounted) {
      _allItems = items;
      _isLoading = false;
      _isFirstLoad = false;
      _rebuildRows();
    }
  }

  // Removed get _filtered as grouping is now done in _rebuildRows()

  Future<void> _onTap(RecentActivity item, bool gu) async {
    final db = AppDatabase.instance;
    if (item.sourceTable == 'investment') {
      final inv = await db.getInvestmentById(item.id);
      if (inv != null && mounted) {
        await Navigator.of(context).push<bool>(
          PageRouteBuilder(
            pageBuilder: (_, anim, __) =>
                InvestmentFormScreen(crop: inv.crop, investment: inv, isGujarati: gu),
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
        _load();
      }
    } else if (item.sourceTable == 'output') {
      final out = await db.getOutputById(item.id);
      if (out != null && mounted) {
        await Navigator.of(context).push<bool>(
          PageRouteBuilder(
            pageBuilder: (_, anim, __) =>
                OutputFormScreen(crop: out.crop, output: out, isGujarati: gu),
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
        _load();
      }
    } else if (item.sourceTable == 'helper') {
      final txn = await db.getTransactionById(item.id);
      if (txn != null && mounted) {
        final types = ['Upaad', 'Bhaag', 'Majur', 'Tractor'];
        final idx = types.indexOf(txn.transactionType).clamp(0, 3);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddHelperTransactionScreen(
              transactionType: txn.transactionType,
              typeIndex: idx,
              transaction: txn,
              isGujarati: gu,
            ),
          ),
        );
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;
    final globalCropMap =
        context.read<GlobalOptionsProvider>().getGlobalCropMap(gu);
    final globalInvMap =
        context.read<GlobalOptionsProvider>().getGlobalInvestmentTypeMap(gu);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: cs.surfaceContainerLowest,
            title: Text(
              gu ? 'તમામ પ્રવૃત્તિ' : 'All Activity',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // ── Filter chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterChip(
                      label: gu ? 'બધા' : 'All',
                      selected: _filter == 'all',
                      onTap: () {
                        _filter = 'all';
                        _rebuildRows();
                      },
                      cs: cs,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: gu ? 'ખર્ચ' : 'Investment',
                      selected: _filter == 'investment',
                      onTap: () {
                        _filter = 'investment';
                        _rebuildRows();
                      },
                      cs: cs,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: gu ? 'ઉત્પાદન' : 'Harvest',
                      selected: _filter == 'output',
                      onTap: () {
                        _filter = 'output';
                        _rebuildRows();
                      },
                      cs: cs,
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: gu ? 'ભાગીદાર' : 'Partner',
                      selected: _filter == 'helper',
                      onTap: () {
                        _filter = 'helper';
                        _rebuildRows();
                      },
                      cs: cs,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          if (_isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: cs.primary, strokeWidth: 2.5),
              ),
            )
          else if (_processedRows.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 64, color: cs.outlineVariant),
                    const SizedBox(height: 16),
                    Text(
                      gu ? 'કોઈ પ્રવૃત્તિ નથી' : 'No activity found',
                      style: TextStyle(color: cs.outline, fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    final row = _processedRows[idx];
                    if (row.isHeader) {
                      return _MonthHeader(label: row.headerLabel!, gu: gu);
                    }
                    return _ActivityTile(
                      item: row.item!,
                      gu: gu,
                      globalCropMap: globalCropMap,
                      globalInvMap: globalInvMap,
                      onTap: () => _onTap(row.item!, gu),
                    );
                  },
                  childCount: _processedRows.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Simple data class to unify headers and items in one flat list ──
class _RowEntry {
  final bool isHeader;
  final String? headerLabel;
  final RecentActivity? item;

  const _RowEntry.header(String label)
      : isHeader = true,
        headerLabel = label,
        item = null;

  const _RowEntry.activity(RecentActivity act)
      : isHeader = false,
        headerLabel = null,
        item = act;
}

// ── Filter chip ──
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withAlpha(28) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : cs.outlineVariant.withAlpha(80),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? c : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Month group header ──
class _MonthHeader extends StatelessWidget {
  /// Sortable key in 'yyyy-MM' format, e.g. '2026-04'
  final String label;
  final bool gu;
  const _MonthHeader({required this.label, required this.gu});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final parts = label.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final String headerText;
    if (gu) {
      const gujaratiMonths = [
        'જાન્યુઆરી', 'ફેબ્રુઆરી', 'માર્ચ',    'એપ્રિલ',
        'મે',         'જૂન',        'જુલાઈ',    'ઓગસ્ટ',
        'સપ્ટેમ્બર',  'ઓક્ટોબર',   'નવેમ્બર',  'ડિસેમ્બર',
      ];
      final monthName = gujaratiMonths[month - 1];
      final gujaratiYear = GujaratiNumberHelper.toGujarati(year.toString());
      headerText = '$monthName $gujaratiYear';
    } else {
      headerText = DateFormat('MMMM yyyy').format(DateTime(year, month)).toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        headerText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: cs.primary,
          letterSpacing: gu ? 0.3 : 1.2,
        ),
      ),
    );
  }
}

// ── Activity tile (mirrors the design in accounting_screen) ──
class _ActivityTile extends StatelessWidget {
  final RecentActivity item;
  final bool gu;
  final Map<String, String> globalCropMap;
  final Map<String, String> globalInvMap;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.item,
    required this.gu,
    required this.globalCropMap,
    required this.globalInvMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ── Icon & colour ──
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
      iconColor = const Color(0xFF2E7D32);
    } else {
      icon = Icons.people_alt_rounded;
      iconColor = Colors.blue;
    }

    // ── Date string ──
    final d = DateTime.fromMillisecondsSinceEpoch(item.date);
    String dateStr;
    if (!gu) {
      dateStr = DateFormat('dd MMM').format(d);
    } else {
      const monthsGu = [
        'જાન્યુ', 'ફેબ્રુ', 'માર્ચ', 'એપ્રિલ', 'મે', 'જૂન',
        'જુલાઈ', 'ઓગ', 'સપ્ટે', 'ઓક્ટો', 'નવે', 'ડિસે',
      ];
      final dayGu = GujaratiNumberHelper.toGujarati(
          d.day.toString().padLeft(2, '0'));
      dateStr = '$dayGu ${monthsGu[d.month - 1]}';
    }

    // ── Display labels ──
    final String displayTitle;
    final String displaySubtitle;
    if (item.sourceTable == 'investment') {
      displayTitle = LanguageMapper.localizedCrop(item.title, gu, globalCropMap);
      displaySubtitle =
          LanguageMapper.localizedInvestmentType(item.subtitle, gu, globalInvMap);
    } else if (item.sourceTable == 'output') {
      displayTitle = LanguageMapper.localizedCrop(item.title, gu, globalCropMap);
      displaySubtitle = gu ? 'ઉત્પાદન' : 'Harvest';
    } else {
      displayTitle = LanguageMapper.localizedServiceProvider(item.title, gu);
      displaySubtitle = LanguageMapper.localizedTransactionType(item.subtitle, gu);
    }

    final amountColor = item.sourceTable == 'output'
        ? const Color(0xFF2E7D32)
        : const Color(0xFFB71C1C);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withAlpha(110)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Coloured left accent strip
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: iconColor),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.only(left: 19, right: 16, top: 8, bottom: 8),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: iconColor.withAlpha(30),
                    child: (item.sourceTable == 'investment' ||
                            item.sourceTable == 'output')
                        ? CropIconUtils.getCropIcon(item.title, size: 40)
                        : Icon(icon, color: iconColor, size: 20),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      // ↑↓ arrow + amount
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.sourceTable == 'output'
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 13,
                            color: amountColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            gu
                                ? GujaratiNumberHelper.formatCurrency(
                                    item.amount,
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
                    ],
                  ),
                  subtitle: Text(
                    displaySubtitle,
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  trailing: Text(
                    dateStr,
                    style: TextStyle(color: cs.outline, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
