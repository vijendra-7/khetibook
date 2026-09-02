import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/investment.dart';
import '../models/investment_item.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../utils/language_mapper.dart';
import '../utils/panchang_helper.dart';
import '../utils/custom_options_manager.dart';
import '../utils/summary_card_image_generator.dart';
import '../utils/gujarati_number_helper.dart';
import '../widgets/empty_state_widget.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/global_options_provider.dart';
import '../utils/crop_icon_utils.dart';
import '../utils/validation_helper.dart';
import '../widgets/voice_input_button.dart';
import '../widgets/premium_select.dart';
import '../widgets/premium_autocomplete.dart';

class InvestmentScreen extends StatefulWidget {
  final String crop;
  const InvestmentScreen({super.key, required this.crop});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _FieldHeader {
  final String fieldName;
  _FieldHeader(this.fieldName);
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  List<Investment> _investments = [];
  double _total = 0;
  bool _loading = true;
  bool _wasSyncing = false;
  final bool _isSharingSummary = false;

  // Filter state
  int? _selectedYear;
  int? _selectedMonth;
  List<dynamic> _cachedGroupedItems = [];

  List<int> get _years {
    final set = <int>{};
    for (final inv in _investments) {
      set.add(DateTime.fromMillisecondsSinceEpoch(inv.date).year);
    }
    final sorted = set.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<int> get _monthsForYear {
    if (_selectedYear == null) return [];
    final set = <int>{};
    for (final inv in _investments) {
      final d = DateTime.fromMillisecondsSinceEpoch(inv.date);
      if (d.year == _selectedYear) set.add(d.month);
    }
    final sorted = set.toList()..sort();
    return sorted;
  }

  List<Investment> get _filtered {
    return _investments.where((inv) {
      final d = DateTime.fromMillisecondsSinceEpoch(inv.date);
      if (_selectedYear != null && d.year != _selectedYear) return false;
      if (_selectedMonth != null && d.month != _selectedMonth) return false;
      return true;
    }).toList();
  }

  void _updateGroupedItems() {
    final filtered = _filtered;
    // Sort by date descending, then by field name ascending
    filtered.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return a.fieldName.compareTo(b.fieldName);
    });
    
    final List<dynamic> items = [];
    String? currentGroup;
    String? currentField;
    
    // We get 'gu' once here to avoid context.read in a loop if possible, 
    // although _fmt already uses context.read.
    for (final inv in filtered) {
      final dateStr = _fmt(inv.date);
      final field = inv.fieldName.trim();
      
      // New Date Group
      if (dateStr != currentGroup) {
        items.add(dateStr);
        currentGroup = dateStr;
        currentField = null; // Reset field when date changes
      }
      
      // New Field Sub-group within Date
      if (field != currentField) {
        items.add(_FieldHeader(field));
        currentField = field;
      }
      
      items.add(inv);
    }
    _cachedGroupedItems = items;
  }


  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final gu = context.read<SettingsProvider>().isGujarati;
    final res = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return gu ? GujaratiNumberHelper.toGujarati(res) : res;
  }

  Widget _buildDateHeader(String date, bool gu, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: cs.outlineVariant.withAlpha(50))),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String field, bool gu, ColorScheme cs) {
    if (field.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
      child: Row(
        children: [
          Icon(Icons.landscape_outlined, size: 14, color: cs.secondary),
          const SizedBox(width: 8),
          Text(
            field,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: cs.outlineVariant.withAlpha(30), thickness: 0.5)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isSyncing = context.watch<SyncProvider>().isSyncing;
    if (_wasSyncing && !isSyncing) {
      _load();
    }
    _wasSyncing = isSyncing;
  }

  Future<void> _load() async {
    final items = await AppDatabase.instance.getInvestmentsByCrop(widget.crop);
    final total = await AppDatabase.instance.getTotalInvestmentByCrop(widget.crop);
    if (mounted) {
      setState(() {
        _investments = items;
        _total = total;
        _loading = false;
        _updateGroupedItems();
      });
    }
  }

  Widget _buildHeaderCard(bool gu, ColorScheme cs) {
    final paidCount = _investments.where((i) => i.isPaid).length;
    final pendingCount = _investments.length - paidCount;
    final cropName = LanguageMapper.localizedCrop(widget.crop, gu);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1B5E20).withAlpha(80), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gu ? 'કુલ ખર્ચો' : 'Total Investment',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gu
                        ? GujaratiNumberHelper.formatCurrency(_total, gujarati: true)
                        : GujaratiNumberHelper.formatCurrency(_total),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${gu ? GujaratiNumberHelper.toGujaratiInt(_investments.length) : _investments.length} ${gu ? 'નોંધ' : 'entries'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          if (_investments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Paid stat
                _statToken(
                  icon: Icons.check_circle_outline_rounded,
                  value: '${gu ? GujaratiNumberHelper.toGujaratiInt(paidCount) : paidCount}',
                  label: gu ? 'ચૂ.' : 'Paid',
                  color: Colors.greenAccent,
                ),
                const SizedBox(width: 8),
                // Pending stat
                if (pendingCount > 0)
                  _statToken(
                    icon: Icons.schedule_rounded,
                    value: '${gu ? GujaratiNumberHelper.toGujaratiInt(pendingCount) : pendingCount}',
                    label: gu ? 'બા.' : 'Due',
                    color: Colors.orangeAccent,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statToken({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _buildCropIcon(String crop) {
    return CropIconUtils.getCropIcon(crop, size: 28);
  }

  Widget _buildShimmerLoading(ColorScheme cs) {
    final isDark = cs.brightness == ui.Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        child: Container(
          height: 85,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.select<SettingsProvider, bool>((p) => p.isGujarati);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'crop_icon_${widget.crop}',
              child: Material(
                color: Colors.transparent,
                child: _buildCropIcon(widget.crop),
              ),
            ),
            const SizedBox(width: 8),
            Text('${gu ? 'ખર્ચો' : 'Investment'} • ${LanguageMapper.localizedCrop(widget.crop, gu)}'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null, gu),
        icon: const Icon(Icons.add),
        label: Text(gu ? 'ઉમેરો' : 'Add'),
      ),
      body: _loading
          ? _buildShimmerLoading(cs)
          : _investments.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.agriculture_outlined,
                  title: gu ? 'કોઈ ખર્ચો નથી' : 'No Investments Yet',
                  message: gu ? 'ખર્ચો ઉમેરવા માટે + બટન દબાવો' : 'Tap the + button to add an investment',
                )
              : Column(
                  children: [
                    // ── Total header card ────────────────────────────
                    _buildHeaderCard(gu, cs),
                    // ── Year filter chips ────────────────────────
                    if (_years.isNotEmpty)
                      _FilterRow(
                        chips: [
                          (null, gu ? 'બધા' : 'All'),
                          ..._years.map((y) => (y as int?, y.toString())),
                        ],
                        selected: _selectedYear,
                        onSelect: (y) {
                          setState(() {
                            _selectedYear = y;
                            _selectedMonth = null; // reset month when year changes
                            _updateGroupedItems();
                          });
                        },
                      ),
                    // ── Month filter chips ──────────────────────
                    if (_selectedYear != null && _monthsForYear.isNotEmpty)
                      _FilterRow(
                        chips: [
                          (null, gu ? 'બધા' : 'All'),
                          ..._monthsForYear.map((m) => (m as int?, _monthLabel(m, gu))),
                        ],
                        selected: _selectedMonth,
                        onSelect: (m) {
                          setState(() {
                            _selectedMonth = m;
                            _updateGroupedItems();
                          });
                        },
                      ),
                    // ── List ─────────────────────────────
                    Expanded(
                      child: _filtered.isEmpty
                          ? EmptyStateWidget(
                              icon: Icons.search_off_rounded,
                              title: gu ? 'કોઈ નોંધ નથી' : 'No Records',
                              message: gu ? 'આ માસ/વર્ષ માટે કોઈ નોંધ નથી' : 'No records for this period',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: _cachedGroupedItems.length,
                              itemBuilder: (_, i) {
                                final item = _cachedGroupedItems[i];
                                if (item is String) {
                                  return _buildDateHeader(item, gu, cs);
                                }
                                if (item is _FieldHeader) {
                                  return _buildFieldHeader(item.fieldName, gu, cs);
                                }
                                final inv = item as Investment;
                                return _InvestmentCard(
                                  investment: inv,
                                  isGujarati: gu,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _openForm(context, inv, gu);
                                  },
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    _confirmDelete(inv, gu);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  void _confirmDelete(Investment inv, bool gu) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gu ? 'ખર્ચો કાઢી નાખો?' : 'Delete Expense?'),
        content: Text(gu 
            ? 'શું તમે ખરેખર આ ખર્ચો કાઢી નાખવા માંગો છો?' 
            : 'Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(gu ? 'રદ કરો' : 'Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AppDatabase.instance.softDeleteInvestment(inv.id!);
              _load();
              if (mounted) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(gu ? 'ખર્ચો કાઢી નાખ્યો' : 'Expense deleted'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: gu ? 'પાછું લાવો' : 'Undo',
                      onPressed: () async {
                        await AppDatabase.instance.restoreInvestment(inv.id!);
                        _load();
                      },
                    ),
                  ),
                );
              }
            },
            child: Text(gu ? 'કાઢી નાખો' : 'Delete', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [Investment? inv, bool gu = false]) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => InvestmentFormScreen(
          crop: widget.crop,
          investment: inv,
          isGujarati: gu,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
    if (result == true && mounted) {
      _load();
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gu ? 'સચવાઈ ગયું! ✅' : 'Entry saved! ✅'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (result == 'deleted' && mounted) {
      _load();
    }
  }
}

class _InvestmentCard extends StatefulWidget {
  final Investment investment;
  final bool isGujarati;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _InvestmentCard({required this.investment, required this.isGujarati, required this.onTap, this.onLongPress});

  @override
  State<_InvestmentCard> createState() => _InvestmentCardState();
}

class _InvestmentCardState extends State<_InvestmentCard> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = widget.isGujarati;
    final globalMetadata = context.watch<GlobalOptionsProvider>();
    final typeName = LanguageMapper.localizedInvestmentType(
      widget.investment.displayInvestmentType,
      gu,
      globalMetadata.getGlobalInvestmentTypeMap(gu),
    );
    final dateStr = _fmt(widget.investment.date);
    final d = DateTime.fromMillisecondsSinceEpoch(widget.investment.date);
    final panchangKey = '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';
    final panchang = PanchangHelper.getPanchangForDate(panchangKey, gujarati: gu);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(50), width: 1),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: RepaintBoundary(
        key: _cardKey,
        child: Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_getIconForType(widget.investment.investmentType), color: cs.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(typeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (widget.investment.fieldName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.investment.fieldName,
                              style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 6),
                        if (widget.investment.serviceProvider.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline, size: 12, color: cs.outline),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    LanguageMapper.localizedServiceProvider(widget.investment.serviceProvider, gu),
                                    style: TextStyle(color: cs.outline, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (panchang != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Text('🌙', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    panchang,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF8D6E63)),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if ((widget.investment.investmentType == 'Dawa' || widget.investment.investmentType == 'Khatar') && widget.investment.vigha.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...() {
                                  final names = widget.investment.investmentTypeOther.split(',').map((e) => e.trim()).toList();
                                  final details = widget.investment.vigha.split('|');
                                  final List<Widget> children = [];
                                  for (int i = 0; i < names.length; i++) {
                                    if (i < details.length && details[i].contains(':')) {
                                      final parts = details[i].split(':');
                                      final qty = parts[0];
                                      final price = parts[1];
                                      if (qty.isNotEmpty || price.isNotEmpty) {
                                        children.add(
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Text(
                                              '• ${names[i]}: ${LanguageMapper.localizedQuantityUnit(widget.investment.crop, gu)} : ${qty.isEmpty ? "0" : qty} , ${gu ? "કિંમત" : "Price"} : ${price.isEmpty ? "0" : price}',
                                              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withAlpha(180)),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                  return children;
                                }(),
                              ],
                            ),
                          ),
                        if (!widget.investment.isPaid)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFFF8F00)),
                                  const SizedBox(width: 4),
                                  Text(
                                    gu ? 'બાકી' : 'Pending',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE65100),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        gu
                            ? GujaratiNumberHelper.formatCurrency(widget.investment.totalAmount, gujarati: true)
                            : GujaratiNumberHelper.formatCurrency(widget.investment.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  IconData _getIconForType(String type) {
    switch (type) {
      case 'Biyaran':
        return Icons.grass_rounded;
      case 'Dawa':
      case 'Khatar':
        return Icons.inventory_2_outlined;
      case 'Khed':
      case 'Shed':
      case 'Rotavator':
      case 'Peyani':
      case 'Zero':
      case 'Thresher':
      case 'Digger':
        return Icons.agriculture_rounded;
      default:
        return Icons.eco_rounded;
    }
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final res = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return widget.isGujarati ? GujaratiNumberHelper.toGujarati(res) : res;
  }
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

class InvestmentFormScreen extends StatefulWidget {
  final String crop;
  final Investment? investment;
  final bool isGujarati;
  const InvestmentFormScreen({super.key, required this.crop, this.investment, required this.isGujarati});

  @override
  State<InvestmentFormScreen> createState() => _InvestmentFormScreenState();
}

class _InvestmentFormScreenState extends State<InvestmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSharingSummary = false;
  late String _type;
  late TextEditingController _customTypeCtrl;
  late TextEditingController _seedTypeCtrl;
  late TextEditingController _seedOtherCtrl;
  late TextEditingController _kataCtrl;
  late TextEditingController _pricePerKataCtrl;
  late TextEditingController _vighaCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _serviceProviderCtrl;
  late TextEditingController _biyaranCompanyCtrl;
  late TextEditingController _fieldNameCtrl;
  late TextEditingController _pendingCtrl;
  late bool _isPaid;
  late DateTime _date;
  late bool _isEdit;
  bool _saving = false;
  bool _viewMode = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  final ValueNotifier<double> _calcBiyaranTotal = ValueNotifier(0);
  final ValueNotifier<double> _calcPendingTotal = ValueNotifier(0);

  final Map<String, TextEditingController> _dawaQtyCtrls = {};
  final Map<String, TextEditingController> _dawaPriceCtrls = {};

  List<String> _investmentTypes = [];
  List<String> _serviceProviders = [];
  List<String> _tractorProviders = [];
  List<String> _batakaSeeds = [];
  List<String> _fields = [];
  List<String> _dawas = [];
  List<String> _selectedDawas = [];
  bool _isBatakaSeeds = false;

  @override
  void initState() {
    super.initState();
    final inv = widget.investment;
    _isEdit = inv != null;
    _viewMode = _isEdit;
    _type = inv?.investmentType ?? '';
    _customTypeCtrl = TextEditingController(text: inv?.investmentTypeOther ?? '');
    _biyaranCompanyCtrl = TextEditingController(text: inv?.biyaranCompany ?? '');
    _fieldNameCtrl = TextEditingController(text: inv?.fieldName ?? '');
    
    // For Bataka, seed is stored as-is (a variety name like Pukhraj); for others it may be a generic seed type
    _seedTypeCtrl = TextEditingController(
      text: inv != null
          ? (widget.crop == 'Bataka'
              ? LanguageMapper.localizedBatakaSeed(inv.seedType, widget.isGujarati)
              : LanguageMapper.localizedSeedType(inv.seedType, widget.isGujarati))
          : '',
    );
    _seedOtherCtrl = TextEditingController();
    _isBatakaSeeds = widget.crop == 'Bataka';

    if ((_isKhatar || _isDawa) && ((inv?.items.isNotEmpty ?? false) || (inv?.investmentTypeOther ?? '').isNotEmpty)) {
      if (inv?.items.isNotEmpty ?? false) {
        _selectedDawas = inv!.items.map((e) => e.itemName).toList();
        for (final item in inv.items) {
          final d = item.itemName;
          _dawaQtyCtrls[d] = TextEditingController(text: item.quantity == 0 ? '' : item.quantity.toString());
          _dawaPriceCtrls[d] = TextEditingController(text: item.pricePerUnit == 0 ? '' : item.pricePerUnit.toString());
          _dawaQtyCtrls[d]!.addListener(_updateCalcTotal);
          _dawaPriceCtrls[d]!.addListener(_updateCalcTotal);
        }
      } else {
        // Legacy piped-string fallback
        _selectedDawas = (inv?.investmentTypeOther ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final dawaDetails = (inv?.vigha ?? '').split('|');
        for (int i = 0; i < _selectedDawas.length; i++) {
          final d = _selectedDawas[i];
          String qtyStr = '';
          String priceStr = '';
          if (i < dawaDetails.length && dawaDetails[i].contains(':')) {
            final parts = dawaDetails[i].split(':');
            qtyStr = parts[0];
            priceStr = parts[1];
          } else {
            qtyStr = (inv != null && inv.kataQuantity != 0) ? inv.kataQuantity.toString() : '';
            priceStr = (inv != null && inv.pricePerKata != 0) ? inv.pricePerKata.toString() : '';
          }
          _dawaQtyCtrls[d] = TextEditingController(text: qtyStr);
          _dawaPriceCtrls[d] = TextEditingController(text: priceStr);
          _dawaQtyCtrls[d]!.addListener(_updateCalcTotal);
          _dawaPriceCtrls[d]!.addListener(_updateCalcTotal);
        }
      }
    }
    _kataCtrl = TextEditingController(text: inv != null && inv.kataQuantity != 0 ? inv.kataQuantity.toString() : '');
    _pricePerKataCtrl = TextEditingController(text: inv != null ? inv.pricePerKata.toString() : '');
    _vighaCtrl = TextEditingController(text: inv?.vigha ?? '');
    _costCtrl = TextEditingController(text: inv != null ? inv.cost.toString() : '');
    _serviceProviderCtrl = TextEditingController(text: inv != null ? LanguageMapper.localizedServiceProvider(inv.serviceProvider, widget.isGujarati) : '');
    _pendingCtrl = TextEditingController(text: inv != null ? inv.pendingAmount.toInt().toString() : '0');
    _isPaid = inv?.isPaid ?? true;
    _date = inv != null ? DateTime.fromMillisecondsSinceEpoch(inv.date) : DateTime.now();
    _loadOptions();

    _kataCtrl.addListener(_updateCalcTotal);
    _pricePerKataCtrl.addListener(_updateCalcTotal);
    _costCtrl.addListener(_updateCalcPending);

    // Ensure calculation is initialized to avoid reset-to-zero bug when editing non-price fields
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateCalcTotal();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/logo.webp'), context);
  }

  void _updateCalcTotal() {
    if (_isBiyaran) {
      final k = double.tryParse(_kataCtrl.text) ?? 0;
      final p = double.tryParse(_pricePerKataCtrl.text) ?? 0;
      _calcBiyaranTotal.value = k * p;
    } else if (_isKhatar) {
      double t = 0;
      for (final d in _selectedDawas) {
        final k = double.tryParse(_dawaQtyCtrls[d]?.text ?? '') ?? 0;
        final p = double.tryParse(_dawaPriceCtrls[d]?.text ?? '') ?? 0;
        t += k * p;
      }
      _calcBiyaranTotal.value = t;
    }
    _updateCalcPending();
  }

  void _updateCalcPending() {
    final cost = (_isBiyaran || _isKhatar) ? _calcBiyaranTotal.value : (double.tryParse(_costCtrl.text) ?? 0);
    _calcPendingTotal.value = cost;
  }
  Future<void> _loadOptions() async {
    final types = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryInvestmentTypes);
    final globalTypes = context.read<GlobalOptionsProvider>().getGlobalInvestmentTypes();
    for (var gt in globalTypes) {
      if (!types.contains(gt.value)) {
        types.add(gt.value);
      }
    }
    final gu = widget.isGujarati;
    
    // Group 1 providers (Biyaran, Dawa, Others)
    final customGroup1 = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryServiceProviders);
    final dbGroup1 = await AppDatabase.instance.getUniqueValues(
      'investments', 'serviceProvider', 
      where: 'investmentType IN (?, ?, ?)', whereArgs: ['Biyaran', 'Dawa', 'Others']
    );
    final group1Total = {...customGroup1, ...dbGroup1};

    // Group 2 providers (Equipment types: Khed, Rotavator, Peyani, Zero, Thresher, Digger)
    final customGroup2 = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryTractorProviders);
    final dbGroup2 = await AppDatabase.instance.getUniqueValues(
      'investments', 'serviceProvider', 
      where: 'investmentType IN (?, ?, ?, ?, ?, ?, ?, ?)', 
      whereArgs: ['Khed', 'Shed', 'Rotavator', 'Peyani', 'Plough', 'Zero', 'Thresher', 'Digger']
    );
    final group2Total = {...customGroup2, ...dbGroup2};

    // Strict exclusion: if a name is strictly a Tractor provider (Custom or mostly used there), 
    // it shouldn't show in Group 1.
    final group1Filtered = group1Total.where((e) => !customGroup2.contains(e)).map((e) => LanguageMapper.localizedServiceProvider(e, gu)).toList();
    final group2Filtered = group2Total.where((e) => !customGroup1.contains(e)).map((e) => LanguageMapper.localizedServiceProvider(e, gu)).toList();

    // Seeds
    final seedCategory = CustomOptionsManager.seedCategoryForCrop(widget.crop);
    final seeds = seedCategory != null
        ? (await CustomOptionsManager.getAllOptions(seedCategory))
            .map((e) => LanguageMapper.localizedSeedForCrop(widget.crop, e, gu)).toList()
        : <String>[];
        
    final khatars = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryKhatar);
    final dawas = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryDawa);

    // Fields suggestions
    final customFields = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryFields);
    final dbFields = await AppDatabase.instance.getUniqueValues('investments', 'fieldName');
    final fields = {...customFields, ...dbFields}.where((e) => e.isNotEmpty).toList();

    if (mounted) {
      setState(() {
      final updatedTypes = [...types];
      if (widget.crop == 'Bataka' && !updatedTypes.contains('Digger')) {
        updatedTypes.add('Digger');
      }
      if (widget.crop == 'Bataka' || widget.crop == 'Tarbuch') {
        updatedTypes.remove('Thresher');
      }
      if (updatedTypes.contains('Others')) {
        updatedTypes.remove('Others');
        updatedTypes.add('Others');
      }
      _investmentTypes = updatedTypes;
      _serviceProviders = group1Filtered;
      _tractorProviders = group2Filtered;
      _batakaSeeds = seeds;
      _fields = fields;

      final otherLabel = gu ? 'અન્ય' : 'Other';
      if (!_batakaSeeds.contains(otherLabel)) _batakaSeeds.add(otherLabel);
      
      _dawas = _isKhatar ? khatars : dawas; 
      for (final d in _selectedDawas) {
        if (!_dawas.contains(d)) _dawas.add(d);
      }
    });
    }
  }

  void _onDawaSelected(String dawa, bool selected) {
    setState(() {
      if (selected) {
        _selectedDawas.add(dawa);
        _dawaQtyCtrls[dawa] = TextEditingController();
        _dawaPriceCtrls[dawa] = TextEditingController();
        _dawaQtyCtrls[dawa]!.addListener(_updateCalcTotal);
        _dawaPriceCtrls[dawa]!.addListener(_updateCalcTotal);
      } else {
        _selectedDawas.remove(dawa);
        _dawaQtyCtrls[dawa]?.dispose();
        _dawaPriceCtrls[dawa]?.dispose();
        _dawaQtyCtrls.remove(dawa);
        _dawaPriceCtrls.remove(dawa);
      }
      _customTypeCtrl.text = _selectedDawas.join(', ');
      _updateCalcTotal();
    });
  }

  Future<void> _showAddCustomDawaDialog(bool gu) async {
    final ctrl = TextEditingController();
    final isK = _isKhatar;
    final titleGu = isK ? 'નવું ખાતર ઉમેરો' : 'નવી દવા ઉમેરો';
    final titleEn = isK ? 'Add Custom Fertilizer' : 'Add Custom Dawa';
    final hintGu = isK ? 'ખાતરનું નામ' : 'દવાનું નામ';
    final hintEn = isK ? 'Fertilizer name' : 'Dawa name';

    final newItem = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gu ? titleGu : titleEn),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: gu ? hintGu : hintEn),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(gu ? 'રદ કરો' : 'Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(gu ? 'ઉમેરો' : 'Add')),
        ],
      )
    );
    if (newItem != null && newItem.isNotEmpty) {
      if (!_dawas.contains(newItem)) {
        setState(() => _dawas.add(newItem));
      }
      _onDawaSelected(newItem, true);
    }
  }

  @override
  void dispose() {
    for (final c in [_customTypeCtrl, _seedTypeCtrl, _seedOtherCtrl, _kataCtrl, _pricePerKataCtrl, _vighaCtrl, _costCtrl, _serviceProviderCtrl, _biyaranCompanyCtrl, _fieldNameCtrl, _pendingCtrl]) {
      c.dispose();
    }
    for (final c in _dawaQtyCtrls.values) { c.dispose(); }
    for (final c in _dawaPriceCtrls.values) { c.dispose(); }
    _calcBiyaranTotal.dispose();
    _calcPendingTotal.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    if (_isBiyaran || _isKhatar) {
      return _calcBiyaranTotal.value;
    }
    return double.tryParse(_costCtrl.text) ?? 0;
  }

  bool get _isBiyaran => _type == 'Biyaran';
  bool get _isKhatar => _type == 'Khatar';
  bool get _isDawa => _type == 'Dawa';
  bool get _isOthers => _type == 'Others';
  bool get _isSeedOther => _seedTypeCtrl.text == (widget.isGujarati ? 'અન્ય' : 'Other');
  bool get _isEquipment => ['Khed', 'Shed', 'Rotavator', 'Peyani', 'Plough', 'Zero', 'Thresher', 'Digger'].contains(_type);
  List<String> get _currentProviders => _isEquipment ? _tractorProviders : _serviceProviders;

  Widget _buildBrandedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.webp', height: 40),
          const SizedBox(width: 12),
          const Text(
            'KhetiBook',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final inv = widget.investment!;
    final gu = widget.isGujarati;
    String dateStr = '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    if (gu) dateStr = GujaratiNumberHelper.toGujarati(dateStr);
    final panchangKey = '${_date.day.toString().padLeft(2, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.year}';
    final panchang = PanchangHelper.getPanchangForDate(panchangKey, gujarati: gu);
    final cs = Theme.of(context).colorScheme;
    String typeName = LanguageMapper.localizedInvestmentType(inv.displayInvestmentType, gu);
    if (inv.investmentType == 'Dawa') {
      typeName = gu ? 'દવાનો ખર્ચ' : 'Expense for Medicine';
    } else if (inv.investmentType == 'Khatar') {
      typeName = gu ? 'ખાતરનો ખર્ચ' : 'Expense for Fertilizer';
    } else if (inv.investmentType == 'Biyaran') {
      typeName = gu ? 'બીજનો ખર્ચ' : 'Expense for Seeds';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isSharingSummary) _buildBrandedHeader(),
        // ── Amount Banner ─────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1B5E20),
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF1B5E20).withAlpha(60), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      typeName,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: inv.isPaid ? Colors.green : Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          inv.isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          inv.isPaid ? (gu ? 'ચૂકવ્યા' : 'Paid') : (gu ? 'બાકી' : 'Pending'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                gu
                    ? GujaratiNumberHelper.formatCurrency(inv.totalAmount, gujarati: true)
                    : GujaratiNumberHelper.formatCurrency(inv.totalAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
                if (!inv.isPaid && inv.pendingAmount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${gu ? 'બાકી:' : 'Due:'} ₹${gu ? GujaratiNumberHelper.toGujaratiInt(inv.pendingAmount.toInt()) : inv.pendingAmount.toInt()}',
                  style: TextStyle(color: Colors.orange.shade200, fontSize: 13),
                ),
              ],
              const SizedBox(height: 6),
              Text(dateStr, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Secondary Groups ─────────────────────────────
        if (inv.fieldName.isNotEmpty || inv.vigha.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withAlpha(50)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withAlpha(30), shape: BoxShape.circle),
                  child: Icon(Icons.landscape_rounded, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gu ? 'ખેતરની માહિતી' : 'Farm Details', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${inv.fieldName.isNotEmpty ? (gu ? GujaratiNumberHelper.toGujarati(inv.fieldName) : inv.fieldName) : (gu ? 'નામ નથી' : 'No Name')}${inv.vigha.isNotEmpty ? " • ${gu ? GujaratiNumberHelper.toGujarati(inv.vigha) : inv.vigha} ${gu ? 'વિઘા' : 'Vigha'}" : ""}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (inv.serviceProvider.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withAlpha(50)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.withAlpha(30), shape: BoxShape.circle),
                  child: Icon(Icons.storefront_rounded, color: Colors.amber.shade800, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (inv.investmentType == 'Biyaran' || inv.investmentType == 'Dawa' || inv.investmentType == 'Khatar')
                            ? (gu ? 'વેચનાર' : 'Seller')
                            : (gu ? 'સ્રોત' : 'Source'),
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LanguageMapper.localizedServiceProvider(inv.serviceProvider, gu),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ── Seed Details ──────────────────────────────────
        if (inv.investmentType == 'Biyaran') ...[
          _summaryTile(context, icon: Icons.grass_rounded, label: gu ? 'બીજ / જાત' : 'Seed Variety', value: LanguageMapper.localizedSeedType(inv.seedType, gu)),
          if (inv.biyaranCompany.isNotEmpty)
            _summaryTile(context, icon: Icons.business_rounded, label: gu ? 'બીજની કંપની' : 'Company', value: inv.biyaranCompany),
          if (inv.kataQuantity > 0 || inv.pricePerKata > 0)
            Row(
              children: [
                Expanded(child: _summaryTile(context, icon: Icons.inventory_2_rounded, label: gu ? 'ક્વોન્ટિટી' : 'Quantity', value: '${GujaratiNumberHelper.formatNumber(inv.kataQuantity, gujarati: gu)} ${LanguageMapper.localizedQuantityUnit(widget.crop, gu)}')),
                const SizedBox(width: 8),
                Expanded(child: _summaryTile(context, icon: Icons.sell_rounded, label: gu ? 'ભાવ (૧ એકમ)' : 'Rate', value: '₹${GujaratiNumberHelper.formatNumber(inv.pricePerKata, gujarati: gu)}')),
              ],
            ),
          const SizedBox(height: 12),
        ],

        // ── Itemized Table for Khatar / Dawa ──────────────
        if ((inv.investmentType == 'Khatar' || inv.investmentType == 'Dawa') && (inv.items.isNotEmpty || inv.vigha.contains(':'))) ...[
          _label(inv.investmentType == 'Khatar' ? (gu ? 'ખાતરની વિગત' : 'Fertilizer Details') : (gu ? 'દવાની વિગત' : 'Medicine Details')),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withAlpha(100)),
              boxShadow: [BoxShadow(color: cs.shadow.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: IntrinsicColumnWidth(),
                  2: IntrinsicColumnWidth(),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                  verticalInside: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(100)),
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text(gu ? 'આઇટમ' : 'Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurfaceVariant))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text(gu ? 'માત્રા' : 'Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurfaceVariant))),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text(gu ? 'ભાવ' : 'Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurfaceVariant))),
                    ],
                  ),
                  ...() {
                    final rows = <TableRow>[];
                    if (inv.items.isNotEmpty) {
                      for (final item in inv.items) {
                        rows.add(TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text('${GujaratiNumberHelper.formatNumber(item.quantity, gujarati: gu)} ${LanguageMapper.localizedQuantityUnit(widget.crop, gu)}', style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500))),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text('₹${GujaratiNumberHelper.formatNumber(item.pricePerUnit, gujarati: gu)}', style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500))),
                          ],
                        ));
                      }
                    } else {
                      // Legacy logic
                      final names = inv.investmentTypeOther.split(',').map((e) => e.trim()).toList();
                      final details = inv.vigha.split('|');
                      for (int i = 0; i < names.length; i++) {
                        if (i < details.length && details[i].contains(':')) {
                          final parts = details[i].split(':');
                          final qty = parts[0];
                          final price = parts[1];
                          rows.add(TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(names[i], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text('${GujaratiNumberHelper.formatNumber(double.tryParse(qty) ?? 0, gujarati: gu)} ${LanguageMapper.localizedQuantityUnit(widget.crop, gu)}', style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500))),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text('₹${GujaratiNumberHelper.formatNumber(double.tryParse(price) ?? 0, gujarati: gu)}', style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500))),
                            ],
                          ));
                        }
                      }
                    }
                    return rows;
                  }(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Payment Status ──────────────────────────────────
        if (!inv.isPaid)
          Row(
            children: [
              Expanded(child: _summaryTile(context, icon: Icons.pending_actions_rounded, label: gu ? 'બદલો' : 'Status', value: gu ? 'બાકી' : 'Pending', highlight: true)),
              const SizedBox(width: 8),
              Expanded(child: _summaryTile(context, icon: Icons.money_off_rounded, label: gu ? 'બાકી રકમ' : 'Pending', value: '₹${GujaratiNumberHelper.formatNumber(inv.pendingAmount, gujarati: gu)}', highlight: true)),
            ],
          ),

        // ── Panchang ──────────────────────────────────────
        if (panchang != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🌙 ', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                  Expanded(
                    child: Text(panchang, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),
        if (!_isSharingSummary)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isSharingSummary = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await SummaryCardImageGenerator.shareScreenshot(_boundaryKey, isGujarati: gu);
                      if (mounted) setState(() => _isSharingSummary = false);
                    });
                  },
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                  label: Text(gu ? 'વોટ્સએપ' : 'WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    foregroundColor: const Color(0xFF25D366),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _viewMode = false);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(gu ? 'સંપાદિત કરો' : 'Edit'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _summaryTile(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: highlight ? cs.errorContainer.withAlpha(100) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: highlight ? cs.error : cs.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(
                  fontSize: 15,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                  color: highlight ? cs.error : cs.onSurface,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: Text(value,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final inv = widget.investment;

    final typeEn = LanguageMapper.englishInvestmentType(_type, widget.isGujarati);
    final providerEn = LanguageMapper.englishServiceProvider(_serviceProviderCtrl.text.trim(), widget.isGujarati);
    final isPaid = _isPaid;
    final totalPending = isPaid ? 0.0 : (double.tryParse(_pendingCtrl.text) ?? 0);
    final totalCalcCost = _calculatedTotal;

    final List<InvestmentItem> itemsToSave = [];
    if (_isKhatar || _isDawa) {
      if (_selectedDawas.isEmpty) {
        final msg = widget.isGujarati 
            ? (_isKhatar ? 'ઓછામાં ઓછું એક ખાતર પસંદ કરો' : 'ઓછામાં ઓછી એક દવા પસંદ કરો') 
            : (_isKhatar ? 'Please select at least one Fertilizer' : 'Please select at least one Medicine');
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
        setState(() => _saving = false);
        return;
      }
      final names = _selectedDawas.join(', ');
      final category = _isKhatar ? CustomOptionsManager.categoryKhatar : CustomOptionsManager.categoryDawa;
      final allOptions = await CustomOptionsManager.getAllOptions(category);
      for (final itemRaw in _selectedDawas) {
        if (!allOptions.contains(itemRaw)) {
          await CustomOptionsManager.addCustomOption(category, itemRaw);
        }
      }

      for (final d in _selectedDawas) {
        final qty = double.tryParse(_dawaQtyCtrls[d]?.text ?? '') ?? 0;
        final price = double.tryParse(_dawaPriceCtrls[d]?.text ?? '') ?? 0;
        itemsToSave.add(InvestmentItem(
          investmentUuid: inv?.uuid ?? '', 
          itemName: d,
          quantity: qty,
          pricePerUnit: price,
        ));
      }

      final newInv = Investment(
        id: inv?.id,
        uuid: inv?.uuid,
        crop: widget.crop,
        investmentType: typeEn,
        investmentTypeOther: names,
        seedType: '',
        biyaranCompany: _biyaranCompanyCtrl.text.trim(),
        fieldName: _fieldNameCtrl.text.trim(),
        kataQuantity: 0,
        pricePerKata: 0,
        vigha: _vighaCtrl.text.trim(), 
        cost: totalCalcCost,
        serviceProvider: providerEn,
        isPaid: isPaid,
        pendingAmount: totalPending,
        date: _date.millisecondsSinceEpoch,
        items: itemsToSave,
      );

      if (inv == null) {
        await AppDatabase.instance.insertInvestment(newInv);
      } else {
        await AppDatabase.instance.updateInvestment(newInv);
      }
    } else {
      final rawSeed = _seedTypeCtrl.text.trim();
      final isOtherSeed = rawSeed == (widget.isGujarati ? 'અન્ય' : 'Other');
      final seedEn = isOtherSeed 
          ? _seedOtherCtrl.text.trim() 
          : LanguageMapper.englishSeedForCrop(widget.crop, rawSeed, widget.isGujarati);
      
      final seedCategory = CustomOptionsManager.seedCategoryForCrop(widget.crop);
      if (seedCategory != null && (isOtherSeed ? _seedOtherCtrl.text.isNotEmpty : rawSeed.isNotEmpty)) {
        final actualSeedToSave = isOtherSeed ? _seedOtherCtrl.text.trim() : seedEn;
        final allSeeds = await CustomOptionsManager.getAllOptions(seedCategory);
        final allSeedsEn = allSeeds.map((s) => LanguageMapper.englishSeedForCrop(widget.crop, s, false)).toList();
        if (!allSeedsEn.contains(actualSeedToSave) && actualSeedToSave.isNotEmpty) {
          await CustomOptionsManager.addCustomOption(seedCategory, actualSeedToSave);
        }
      }

      final newInv = Investment(
        id: inv?.id,
        uuid: inv?.uuid,
        crop: widget.crop,
        investmentType: typeEn,
        investmentTypeOther: _isOthers ? _customTypeCtrl.text.trim() : '',
        seedType: _isBiyaran ? seedEn : '',
        biyaranCompany: _isBiyaran ? _biyaranCompanyCtrl.text.trim() : '',
        fieldName: _fieldNameCtrl.text.trim(),
        kataQuantity: _isBiyaran ? (double.tryParse(_kataCtrl.text) ?? 0) : 0,
        pricePerKata: _isBiyaran ? (double.tryParse(_pricePerKataCtrl.text) ?? 0) : 0,
        vigha: _vighaCtrl.text.trim(),
        cost: !_isBiyaran ? (double.tryParse(_costCtrl.text) ?? 0) : 0,
        serviceProvider: providerEn,
        isPaid: _isPaid,
        pendingAmount: _isPaid ? 0 : (double.tryParse(_pendingCtrl.text) ?? 0),
        date: _date.millisecondsSinceEpoch,
        items: const [],
      );

      if (inv == null) {
        await AppDatabase.instance.insertInvestment(newInv);
      } else {
        await AppDatabase.instance.updateInvestment(newInv);
      }
    }

    // Save field name as custom option
    if (_fieldNameCtrl.text.trim().isNotEmpty) {
      await CustomOptionsManager.addCustomOption(CustomOptionsManager.categoryFields, _fieldNameCtrl.text.trim());
    }

    // Save service provider as custom option for all types
    if (_serviceProviderCtrl.text.trim().isNotEmpty) {
      final category = _isEquipment 
          ? CustomOptionsManager.categoryTractorProviders 
          : CustomOptionsManager.categoryServiceProviders;
      await CustomOptionsManager.addCustomOption(category, _serviceProviderCtrl.text.trim());
    }
    
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final gu = widget.isGujarati;
    final inv = widget.investment!;
    await AppDatabase.instance.softDeleteInvestment(inv.id!);
    if (!mounted) return;
    Navigator.pop(context, 'deleted');
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(gu ? 'એન્ટ્રી ડિલીટ કરી' : 'Entry deleted'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: gu ? 'પાછું લાવો' : 'Undo', 
          onPressed: () async {
            await AppDatabase.instance.restoreInvestment(inv.id!);
            // We refresh the parent via the 'deleted' pop result if they don't undo,
            // but if they DO undo here, we might need a way to tell the parent.
            // Since the snackbar is on the ScaffoldMessenger, it persists.
          }
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (p != null) setState(() => _date = p);
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
        boxShadow: [
          BoxShadow(color: cs.shadow.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, {IconData? prefixIcon, String? prefixText, Widget? suffixIcon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: hint,
      labelStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(220), fontSize: 14),
      floatingLabelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 15),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: cs.onSurfaceVariant) : null,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withAlpha(150)),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withAlpha(50),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outlineVariant.withAlpha(80), width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outlineVariant.withAlpha(80), width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = widget.isGujarati;
    final cs = Theme.of(context).colorScheme;
    final isNew = !_isEdit;

    final title = isNew
        ? (gu ? 'ખર્ચો ઉમેરો' : 'Add Investment')
        : (_viewMode
            ? (gu ? 'ખર્ચો વિગત' : 'Investment Details')
            : (gu ? 'ખર્ચો સંપાદિત' : 'Edit Investment'));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        actions: [
          if (_isEdit && _viewMode) ...[
          ],
          if (_isEdit && !_viewMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: cs.error,
              tooltip: gu ? 'ડિલીટ કરો' : 'Delete',
              onPressed: () {
                HapticFeedback.lightImpact();
                _delete();
              },
            ),
        ],
      ),
      body: RepaintBoundary(
        key: _boundaryKey,
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _viewMode
              ? _buildSummary()
              : Form(
                              key: _formKey,
                              autovalidateMode: _autovalidateMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCard(
                                    title: gu ? 'પ્રાથમિક માહિતી' : 'Basic Details',
                                    icon: Icons.info_outline_rounded,
                                    children: [
                                      PremiumSelect(
                                        label: gu ? 'ખર્ચનો પ્રકાર *' : 'Investment Type *',
                                        value: _type.isEmpty ? null : LanguageMapper.localizedInvestmentType(_type, gu),
                                        items: _investmentTypes.map((e) => LanguageMapper.localizedInvestmentType(e, gu)).toList(),
                                        hint: gu ? 'પ્રકાર પસંદ કરો' : 'Select type',
                                        isGujarati: gu,
                                        icon: Icons.info_outline_rounded,
                                        onChanged: (v) {
                                          final newType = LanguageMapper.englishInvestmentType(v, gu);
                                          if (_type == newType) return;
                                          
                                          setState(() {
                                            _type = newType;
                                            // Manual validation trigger if needed, but PremiumSelect handles UI
                                            
                                            // Clear all category-specific fields except fieldName and vigha
                                            _seedTypeCtrl.clear();
                                            _seedOtherCtrl.clear();
                                            _biyaranCompanyCtrl.clear();
                                            _kataCtrl.clear();
                                            _pricePerKataCtrl.clear();
                                            _costCtrl.clear();
                                            _customTypeCtrl.clear();
                                            _serviceProviderCtrl.clear();
                                            _pendingCtrl.text = '0';
                                            
                                            // Clear Dawa/Khatar selections and controllers
                                            for (var ctrl in _dawaQtyCtrls.values) {
                                              ctrl.dispose();
                                            }
                                            for (var ctrl in _dawaPriceCtrls.values) {
                                              ctrl.dispose();
                                            }
                                            _dawaQtyCtrls.clear();
                                            _dawaPriceCtrls.clear();
                                            _selectedDawas.clear();
                                            
                                            _autovalidateMode = AutovalidateMode.disabled;
                                            _loadOptions();
                                            _updateCalcTotal();
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: PremiumAutocomplete(
                                              label: gu ? 'ખેતરનું નામ' : 'Field Name',
                                              controller: _fieldNameCtrl,
                                              options: _fields,
                                              hint: gu ? 'ખેતર' : 'Field',
                                              isGujarati: gu,
                                              icon: Icons.landscape_rounded,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _label(gu ? 'વિઘા / વિગત' : 'Vigha / Detail'),
                                                TextFormField(
                                                  controller: _vighaCtrl,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: _inputDeco(gu ? 'વિઘા' : 'Details', prefixIcon: Icons.aspect_ratio_rounded),
                                                  validator: (v) => ValidationHelper.validateOptionalAmount(v, gu),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (_isOthers) ...[
                                    _buildCard(
                                      title: gu ? 'અન્ય વિગતો' : 'Other Details',
                                      icon: Icons.notes_rounded,
                                      children: [
                                        _label(gu ? 'વિગત' : 'Detail'),
                                        TextFormField(
                                          controller: _customTypeCtrl,
                                          decoration: _inputDeco(gu ? 'વિગત દાખલ કરો' : 'Enter detail', prefixIcon: Icons.edit_note_rounded),
                                        ),
                                      ],
                                    ),
                                  ],
                                  _buildCard(
                                    title: gu ? 'ખર્ચ વિગતો' : 'Expense Details',
                                    icon: Icons.receipt_long_rounded,
                                    children: [
                                      if (_isKhatar || _isDawa) ...[
                                        _label(_isKhatar ? (gu ? 'ખાતર *' : 'Fertilizer Type *') : (gu ? 'દવા *' : 'Dawa Type *')),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            ...(_dawas).map((dawa) {
                                              final isSelected = _selectedDawas.contains(dawa);
                                              return FilterChip(
                                                label: Text(LanguageMapper.localizedAgriItem(dawa, gu)),
                                                selected: isSelected,
                                                onSelected: (selected) => _onDawaSelected(dawa, selected),
                                                selectedColor: cs.primaryContainer,
                                                checkmarkColor: cs.primary,
                                              );
                                            }),
                                            ActionChip(
                                              avatar: Icon(Icons.add, size: 16, color: cs.primary),
                                              label: Text(gu ? 'ઉમેરો' : 'Add Custom'),
                                              onPressed: () => _showAddCustomDawaDialog(gu),
                                            ),
                                          ],
                                        ),
                                        if (_selectedDawas.isEmpty && _autovalidateMode != AutovalidateMode.disabled)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              _isKhatar
                                                ? (gu ? 'ઓછામાં ઓછું એક ખાતર પસંદ કરો' : 'Select at least one fertilizer')
                                                : (gu ? 'ઓછામાં ઓછી એક દવા પસંદ કરો' : 'Select at least one medicine'),
                                              style: TextStyle(color: cs.error, fontSize: 12),
                                            ),
                                          ),
                                        if (_selectedDawas.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(flex: 3, child: _label(_isKhatar ? (gu ? 'ખાતર' : 'Fertilizer') : (gu ? 'દવા' : 'Dawa'), paddingBottom: 4)),
                                              const SizedBox(width: 8),
                                              Expanded(flex: 2, child: _label(_isDawa ? (gu ? 'સંખ્યા' : 'Quantity') : LanguageMapper.localizedQuantityUnit(widget.crop, gu), paddingBottom: 4)),
                                              const SizedBox(width: 8),
                                              Expanded(flex: 3, child: _label(_isKhatar ? (gu ? 'એક કટાનો ભાવ' : (gu ? 'ભાવ/એકમ' : 'Price/Unit')) : (gu ? 'ભાવ/એકમ' : 'Price/Unit'), paddingBottom: 4)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        ..._selectedDawas.map((dawa) {
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(dawa, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  flex: 2,
                                                  child: TextFormField(
                                                    controller: _dawaQtyCtrls[dawa],
                                                    keyboardType: TextInputType.number,
                                                    decoration: _inputDeco(LanguageMapper.localizedQuantityUnit(widget.crop, gu)),
                                                    validator: (v) => ValidationHelper.validateAmount(v, gu),
                                                    onChanged: (v) {
                                                      if (_type.isEmpty) setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  flex: 3,
                                                  child: TextFormField(
                                                    controller: _dawaPriceCtrls[dawa],
                                                    keyboardType: TextInputType.number,
                                                    decoration: _inputDeco(gu ? 'ભાવ' : 'Price', prefixText: '₹ '),
                                                    validator: (v) => ValidationHelper.validateAmount(v, gu),
                                                    onChanged: (v) {
                                                      if (_type.isEmpty) setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 8),
                                      ],
                                      if (_isBiyaran) ...[
                                        PremiumAutocomplete(
                                          label: gu ? 'બીજ/જાત *' : 'Seed Variety *',
                                          controller: _seedTypeCtrl,
                                          options: LanguageMapper.localizedSeedsForCrop(widget.crop, _batakaSeeds, gu),
                                          hint: gu ? 'જાત પસંદ કરો અથવા લખો' : 'Select or type variety',
                                          isGujarati: gu,
                                          icon: Icons.grass_rounded,
                                          onChanged: (v) {
                                            if (_autovalidateMode == AutovalidateMode.disabled) {
                                              setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _label(gu ? 'બીજની કંપની' : 'Biyaran Company'),
                                        TextFormField(
                                          controller: _biyaranCompanyCtrl,
                                          decoration: _inputDeco(gu ? 'કંપનીનું નામ દાખલ કરો' : 'Enter company name', prefixIcon: Icons.business_rounded),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(children: [
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            _label('${LanguageMapper.localizedQuantityUnit(widget.crop, gu)} *'),
                                            TextFormField(
                                              controller: _kataCtrl,
                                              keyboardType: TextInputType.number,
                                              decoration: _inputDeco(LanguageMapper.localizedQuantityUnit(widget.crop, gu), prefixIcon: Icons.inventory_2_rounded),
                                              validator: (v) => ValidationHelper.validateAmount(v, gu),
                                              onChanged: (v) {
                                                if (_type.isEmpty) setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
                                              },
                                            ),
                                          ])),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            _label(gu ? 'એક કટાનો ભાવ' : 'Price/Unit *'),
                                            TextFormField(
                                              controller: _pricePerKataCtrl,
                                              keyboardType: TextInputType.number,
                                              decoration: _inputDeco(gu ? 'ભાવ' : 'Price', prefixText: '₹ '),
                                              validator: (v) => ValidationHelper.validateAmount(v, gu),
                                              onChanged: (v) {
                                                if (_type.isEmpty) setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
                                              },
                                            ),
                                          ])),
                                        ]),
                                      ],
                                      if (!_isBiyaran && !_isKhatar && !_isDawa) ...[
                                        _label(_type == 'Others' ? (gu ? 'કિંમત *' : 'Price *') : (gu ? 'ખર્ચ *' : 'Cost *')),
                                        TextFormField(
                                          controller: _costCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: _inputDeco(gu ? 'રકમ દાખલ કરો' : 'Enter amount', prefixText: '₹ '),
                                          validator: (v) => ValidationHelper.validateAmount(v, gu),
                                          onChanged: (v) {
                                            if (_type.isEmpty) setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                  _buildCard(
                                    title: gu ? 'ચૂકવણી વિગતો' : 'Payment Details',
                                    icon: Icons.payments_rounded,
                                    children: [
                                      if (_isBiyaran || _isKhatar || _isDawa)
                                        ValueListenableBuilder<double>(
                                          valueListenable: _calcBiyaranTotal,
                                          builder: (context, total, child) {
                                            if (total <= 0) return const SizedBox.shrink();
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 16),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                decoration: BoxDecoration(color: cs.primaryContainer.withAlpha(150), borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.primary.withAlpha(60))),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(gu ? 'કુલ ખર્ચ:' : 'Total Cost:', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 15)),
                                                    Text('₹${total.toStringAsFixed(0)}', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900, fontSize: 18)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      PremiumAutocomplete(
                                        label: _isEquipment ? LanguageMapper.localizedPersonForWork(_type, gu) : (_isBiyaran || _isDawa || _isKhatar) ? (gu ? 'વેચનારનું નામ' : 'Vechnaar nu naam') : (gu ? 'સ્રોત' : 'Service Provider'),
                                        controller: _serviceProviderCtrl,
                                        options: _currentProviders,
                                        hint: _isEquipment ? LanguageMapper.localizedPersonForWork(_type, gu) : (_isBiyaran || _isDawa || _isKhatar) ? (gu ? 'વેચનારનું નામ' : 'Vechnaar nu naam') : (gu ? 'પ્રદાતા' : 'Provider'),
                                        isGujarati: gu,
                                        icon: Icons.storefront_rounded,
                                        suffix: VoiceInputButton(
                                          controller: _serviceProviderCtrl,
                                          onResult: () => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _label(gu ? 'ચૂકવણી' : 'Payment Status'),
                                      Container(
                                        height: 42,
                                        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(100), borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () { HapticFeedback.lightImpact(); setState(() => _isPaid = true); },
                                                child: Container(
                                                  decoration: BoxDecoration(color: _isPaid ? Colors.green : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: _isPaid ? [BoxShadow(color: Colors.green.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))] : null),
                                                  alignment: Alignment.center,
                                                  child: Text(gu ? 'ચૂકવ્યા' : 'Paid', style: TextStyle(color: _isPaid ? Colors.white : cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () { HapticFeedback.lightImpact(); setState(() => _isPaid = false); },
                                                child: Container(
                                                  decoration: BoxDecoration(color: !_isPaid ? Colors.orange : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: !_isPaid ? [BoxShadow(color: Colors.orange.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))] : null),
                                                  alignment: Alignment.center,
                                                  child: Text(gu ? 'બાકી' : 'Pending', style: TextStyle(color: !_isPaid ? Colors.white : cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!_isPaid) ...[
                                        const SizedBox(height: 16),
                                        _label(gu ? 'બાકી રકમ' : 'Pending Amount'),
                                        TextFormField(
                                          controller: _pendingCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: _inputDeco(gu ? 'રકમ દાખલ કરો' : 'Enter amount', prefixText: '₹ '),
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      _label(gu ? 'તારીખ' : 'Date'),
                                      InkWell(
                                        onTap: _pickDate,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant.withAlpha(80)), borderRadius: BorderRadius.circular(8), color: cs.surfaceContainerHighest.withAlpha(50)),
                                          child: Row(
                                            children: [
                                              Icon(Icons.calendar_month_rounded, size: 20, color: cs.primary),
                                              const SizedBox(width: 12),
                                              Text(
                                                gu ? GujaratiNumberHelper.toGujarati('${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}') : '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _PanchangTile(date: _date, isGujarati: gu),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))],
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                        onPressed: _saving ? null : () {
                                          HapticFeedback.lightImpact();
                                          _save();
                                        },
                                        child: _saving
                                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                                                  const SizedBox(width: 8),
                                                  Text(gu ? 'વિગતો સાચવો' : 'Save Details', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                                ]
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ),
              ),
    );
  }



  Widget _label(String text, {double paddingBottom = 4}) => Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
      );
}

// \u2500\u2500\u2500 Filter Row \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

/// A horizontally scrollable row of filter chips.
/// [chips] is a list of (value, label) pairs; value=null means "All".
class _FilterRow<T> extends StatelessWidget {
  final List<(T?, String)> chips;
  final T? selected;
  final ValueChanged<T?> onSelect;

  const _FilterRow({
    required this.chips,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (val, label) = chips[i];
          final isSelected = selected == val;
          return GestureDetector(
            onTap: () => onSelect(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _monthLabel(int month, bool gujarati) {
  const en = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const gu = ['\u0a9c\u0abe\u0aa8\u0acd\u0aaf\u0ac1','\u0aab\u0ac7\u0aac\u0acd\u0ab0\u0ac1','\u0aae\u0abe\u0ab0\u0acd\u0a9a','\u0a8f\u0aaa\u0acd\u0ab0\u0abf\u0ab2','\u0aae\u0ac7','\u0a9c\u0ac2\u0aa8','\u0a9c\u0ac1\u0ab2\u0abe\u0a88','\u0a93\u0a97\u0ab8\u0acd\u0a9f','\u0ab8\u0a82\u0aa4\u0ac7','\u0a93\u0a95\u0acd\u0a9f\u0acb','\u0aa8\u0ab5\u0ac7','\u0aa1\u0abf\u0ab8\u0ac7'];
  return gujarati ? gu[month - 1] : en[month - 1];
}


// ─── Panchang Tile ────────────────────────────────────────────────────────────

/// Shows Gujarati panchang info for [date] below the date picker in the form.
/// Displays a tap-to-expand amber tile if panchang data is available.
class _PanchangTile extends StatefulWidget {
  final DateTime date;
  final bool isGujarati;
  const _PanchangTile({required this.date, this.isGujarati = false});

  @override
  State<_PanchangTile> createState() => _PanchangTileState();
}

class _PanchangTileState extends State<_PanchangTile> {
  bool _expanded = false;

  @override
  void didUpdateWidget(_PanchangTile old) {
    super.didUpdateWidget(old);
    // Auto-expand when date changes so user sees panchang
    if (old.date != widget.date) _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final key = '${widget.date.day.toString().padLeft(2, '0')}-'
        '${widget.date.month.toString().padLeft(2, '0')}-${widget.date.year}';
    final panchang = PanchangHelper.getPanchangForDate(key, gujarati: widget.isGujarati);
    if (panchang == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withAlpha(120),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: _expanded
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🌙 ', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                    Expanded(
                      child: Text(
                        panchang,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 18, color: cs.outline),
                  ],
                )
              : Row(
                  children: [
                    Text('🌙 ', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                    Expanded(
                      child: Text(
                        widget.isGujarati ? 'ગુજરાત પંચાંગ — જોવા ટેપ કરો' : 'Gujarati Panchang — tap to view',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: cs.outline),
                    ],
          ),
        ),
      ),
    );
  }
}




