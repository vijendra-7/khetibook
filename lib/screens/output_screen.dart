import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/output.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../utils/language_mapper.dart';
import '../utils/gujarati_number_helper.dart';
import '../utils/panchang_helper.dart';
import '../utils/custom_options_manager.dart';
import '../utils/summary_card_image_generator.dart';
import '../widgets/empty_state_widget.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/validation_helper.dart';
import '../utils/crop_icon_utils.dart';
import '../widgets/voice_input_button.dart';
import '../widgets/premium_autocomplete.dart';

bool _isStandardCrop(String crop) {
  return ['Bataka', 'Magfali', 'Bajari', 'Tarbuch', 'Ghau', 'Cauliflower', 'Gavar'].contains(crop);
}

class OutputScreen extends StatefulWidget {
  final String crop;
  const OutputScreen({super.key, required this.crop});

  @override
  State<OutputScreen> createState() => _OutputScreenState();
}

class _FieldHeader {
  final String fieldName;
  _FieldHeader(this.fieldName);
}

class _OutputScreenState extends State<OutputScreen> {
  List<Output> _outputs = [];
  bool _loading = true;
  bool _wasSyncing = false;
  List<dynamic> _cachedGroupedItems = [];

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
    final items = await AppDatabase.instance.getOutputsByCrop(widget.crop);
    if (mounted) {
      setState(() {
        _outputs = items;
        _loading = false;
        _updateGroupedItems();
      });
    }
  }

  void _updateGroupedItems() {
    final items = List<Output>.from(_outputs);
    // Sort by date descending, then field name ascending
    items.sort((a, b) {
      final dateComp = b.date.compareTo(a.date);
      if (dateComp != 0) return dateComp;
      return a.field.compareTo(b.field);
    });
    
    final List<dynamic> grouped = [];
    String? currentGroup;
    String? currentField;

    for (final item in items) {
      final dateStr = _fmt(item.date);
      final field = item.field.trim();
      
      if (dateStr != currentGroup) {
        grouped.add(dateStr);
        currentGroup = dateStr;
        currentField = null;
      }

      if (field != currentField) {
        grouped.add(_FieldHeader(field));
        currentField = field;
      }
      
      grouped.add(item);
    }
    _cachedGroupedItems = grouped;
  }

  double get _totalRevenue => _outputs.fold(0, (s, o) => s + o.revenue);


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
              color: cs.tertiaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: cs.tertiary),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.tertiary,
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

  Widget _buildHeaderCard(bool gu, ColorScheme cs) {
    final cropName = LanguageMapper.localizedCrop(widget.crop, gu);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1B5E20).withAlpha(60), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gu ? 'કુલ આવક' : 'Total Revenue',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  gu
                    ? GujaratiNumberHelper.formatCurrency(_totalRevenue, gujarati: true)
                    : GujaratiNumberHelper.formatCurrency(_totalRevenue),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26),
                ),
                if (_outputs.isNotEmpty) ...[ 
                  const SizedBox(height: 6),
                  Row(children: [
                    _miniChip('${gu ? GujaratiNumberHelper.toGujaratiInt(_outputs.length) : _outputs.length} ${gu ? 'ઉત્પાદન' : 'harvests'}', Colors.greenAccent),
                  ]),
                ],
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${gu ? GujaratiNumberHelper.toGujaratiInt(_outputs.length) : _outputs.length} ${gu ? 'નોંધ' : 'entries'}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ]),
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
    final cropName = LanguageMapper.localizedCrop(widget.crop, gu);

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
            Text('${gu ? 'ઉત્પાદન' : 'Harvest'} • $cropName'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null, gu),
        icon: const Icon(Icons.add),
        label: Text(gu ? 'ઉમેરો' : 'Add Harvest'),
      ),
      body: _loading
          ? _buildShimmerLoading(cs)
          : _outputs.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.grass_rounded,
                  title: gu ? 'કોઈ ઉત્પાદન નથી' : 'No Harvest Entries',
                  message: gu ? 'ઉત્પાદન ઉમેરવા માટે + બટન દબાવો' : 'Tap the + button to add a harvest entry',
                )
              : Column(
                  children: [
                    _buildHeaderCard(gu, cs),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _cachedGroupedItems.length,
                        itemBuilder: (_, i) {
                          final item = _cachedGroupedItems[i];
                          if (item is String) {
                            return _buildDateHeader(item, gu, cs);
                          }
                          if (item is _FieldHeader) {
                            return _buildFieldHeader(item.fieldName, gu, cs);
                          }
                          final out = item as Output;
                          return _OutputCard(
                            output: out,
                            isGujarati: gu,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _openForm(context, out, gu);
                            },
                            onLongPress: () {
                              HapticFeedback.heavyImpact();
                              _confirmDelete(out, gu);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _confirmDelete(Output out, bool gu) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gu ? 'ઇનપુટ કાઢી નાખો?' : 'Delete Output?'),
        content: Text(gu 
            ? 'શું તમે ખરેખર આ ઉત્પાદન નોંધ કાઢી નાખવા માંગો છો?' 
            : 'Are you sure you want to delete this specific output harvest?'),
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
              await AppDatabase.instance.softDeleteOutput(out.id!);
              _load();
              if (mounted) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(gu ? 'કાઢી નાખ્યું' : 'Deleted successfully'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: gu ? 'પાછું લાવો' : 'Undo',
                      onPressed: () async {
                        await AppDatabase.instance.restoreOutput(out.id!);
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

  Future<void> _openForm(BuildContext ctx, Output? out, bool gu) async {
    final result = await Navigator.of(ctx).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OutputFormScreen(
          crop: widget.crop,
          output: out,
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
    if (result == true) {
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
    } else if (result == 'deleted') {
      _load();
    }
  }
}

class _OutputCard extends StatefulWidget {
  final Output output;
  final bool isGujarati;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _OutputCard({required this.output, required this.isGujarati, required this.onTap, this.onLongPress});

  @override
  State<_OutputCard> createState() => _OutputCardState();
}

class _OutputCardState extends State<_OutputCard> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = widget.isGujarati;
    final d = DateTime.fromMillisecondsSinceEpoch(widget.output.date);
    final res = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    final dateStr = gu ? GujaratiNumberHelper.toGujarati(res) : res;
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
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.grass_rounded, color: cs.tertiary),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    (widget.output.field.isEmpty && widget.output.vigha.isEmpty)
                        ? (gu ? 'ઉત્પાદન' : 'Harvest')
                        : [widget.output.field, widget.output.vigha].where((e) => e.isNotEmpty).join(' / '),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      gu
                        ? (_isStandardCrop(widget.output.crop)
                            ? '${GujaratiNumberHelper.toGujarati(widget.output.bharati.toString())} ${LanguageMapper.localizedQuantityUnit(widget.output.crop, gu)} • ${GujaratiNumberHelper.formatCurrency(widget.output.pricePer20kg, gujarati: true)}/20kg'
                            : '${GujaratiNumberHelper.toGujarati(widget.output.bharati.toString())} ${LanguageMapper.localizedQuantityUnit(widget.output.crop, gu)} • ${GujaratiNumberHelper.formatCurrency(widget.output.pricePer20kg, gujarati: true)}/${LanguageMapper.localizedQuantityUnit(widget.output.crop, gu)}')
                        : (_isStandardCrop(widget.output.crop)
                            ? '${widget.output.bharati} ${LanguageMapper.localizedQuantityUnit(widget.output.crop, gu)} • ₹${widget.output.pricePer20kg.toInt()}/20kg'
                            : '${widget.output.bharati} ${LanguageMapper.localizedQuantityUnit(widget.output.crop, gu)} • ₹${widget.output.pricePer20kg.toInt()}/${LanguageMapper.localizedQuantityUnit(widget.output.crop, gu)}'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ])),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        gu
                            ? GujaratiNumberHelper.formatCurrency(widget.output.revenue, gujarati: true)
                            : '₹${widget.output.revenue.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.tertiary)),
                    const SizedBox(height: 12),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class OutputFormScreen extends StatefulWidget {
  final String crop;
  final Output? output;
  final bool isGujarati;
  const OutputFormScreen({super.key, required this.crop, this.output, required this.isGujarati});


  @override
  State<OutputFormScreen> createState() => _OutputFormScreenState();
}

class _OutputFormScreenState extends State<OutputFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _boundaryKey = GlobalKey();
  late TextEditingController _fieldCtrl, _vighaCtrl, _kataCtrl, _remainingCtrl, _priceCtrl, _soldToCtrl;
  late DateTime _date;
  bool _isPotato = false;
  bool _saving = false;
  bool _viewMode = false;
  bool _isSharingSummary = false;
  List<String> _buyers = [];
  List<String> _fields = [];

  final ValueNotifier<double> _calcRevenueNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    final o = widget.output;
    _viewMode = o != null;
    _fieldCtrl = TextEditingController(text: o?.field ?? '');
    _vighaCtrl = TextEditingController(text: o?.vigha ?? '');
    _kataCtrl = TextEditingController(text: o != null ? o.bharati.toString() : '');
    _remainingCtrl = TextEditingController(text: o != null && o.remainingKg != 0 ? o.remainingKg.toString() : '');
    _priceCtrl = TextEditingController(text: o != null ? o.pricePer20kg.toString() : '');
    _soldToCtrl = TextEditingController(text: o?.soldTo ?? '');
    _date = o != null ? DateTime.fromMillisecondsSinceEpoch(o.date) : DateTime.now();
    _isPotato = widget.crop == 'Bataka';
    _loadOptions();

    _kataCtrl.addListener(_updateCalcRevenue);
    _remainingCtrl.addListener(_updateCalcRevenue);
    _priceCtrl.addListener(_updateCalcRevenue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/logo.webp'), context);
  }


  void _updateCalcRevenue() {
    final k = int.tryParse(_kataCtrl.text) ?? 0;
    final r = double.tryParse(_remainingCtrl.text) ?? 0;
    final p = double.tryParse(_priceCtrl.text) ?? 0;

    if (!_isStandardCrop(widget.crop)) {
      _calcRevenueNotifier.value = k * p;
      return;
    }

    if (widget.crop == 'Tarbuch') {
      _calcRevenueNotifier.value = r * p;
      return;
    }
    final weightMultiplier = (widget.crop == 'Bajari' || widget.crop == 'Ghau')
        ? 99.0
        : (widget.crop == 'Bataka' ? 80.0 : 34.0);
    _calcRevenueNotifier.value = ((k * weightMultiplier) + r) / 20.0 * p;
  }

  Future<void> _loadOptions() async {
    final gu = widget.isGujarati;
    
    // Custom options
    final customBuyers = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryBuyers);
    final customFields = await CustomOptionsManager.getAllOptions(CustomOptionsManager.categoryFields);
    
    // DB entries
    final dbBuyers = await AppDatabase.instance.getUniqueValues('outputs', 'soldTo');
    final dbFields = await AppDatabase.instance.getUniqueValues('outputs', 'field');
    
    // Merge
    final b = {...customBuyers, ...dbBuyers}
        .map((e) => LanguageMapper.localizedBuyer(e, gu)).toList();
    final f = {...customFields, ...dbFields}.toList();
    
    if (mounted) setState(() { _buyers = b; _fields = f; });
  }

  @override
  void dispose() {
    for (final c in [_fieldCtrl, _vighaCtrl, _kataCtrl, _remainingCtrl, _priceCtrl, _soldToCtrl]) {
      c.dispose();
    }
    _calcRevenueNotifier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final kata = int.tryParse(_kataCtrl.text) ?? 0;
    final newOut = Output(
      id: widget.output?.id,
      uuid: widget.output?.uuid,
      crop: widget.crop,
      field: _fieldCtrl.text.trim(),
      vigha: _vighaCtrl.text.trim(),
      bharati: kata,
      remainingKg: double.tryParse(_remainingCtrl.text) ?? 0,
      pricePer20kg: double.tryParse(_priceCtrl.text) ?? 0,
      soldTo: _isPotato ? LanguageMapper.englishBuyer(_soldToCtrl.text.trim(), widget.isGujarati) : '',
      date: _date.millisecondsSinceEpoch,
    );
    if (widget.output == null) {
      await AppDatabase.instance.insertOutput(newOut);
    } else {
      await AppDatabase.instance.updateOutput(newOut);
    }

    // Save custom options
    if (_fieldCtrl.text.trim().isNotEmpty) {
      await CustomOptionsManager.addCustomOption(CustomOptionsManager.categoryFields, _fieldCtrl.text.trim());
    }
    if (_isPotato && _soldToCtrl.text.trim().isNotEmpty) {
      await CustomOptionsManager.addCustomOption(CustomOptionsManager.categoryBuyers, _soldToCtrl.text.trim());
    }

    if (mounted) Navigator.pop(context, true);
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(80), width: 1),
        boxShadow: [
          BoxShadow(color: cs.shadow.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(40),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
              ],
            ),
          ),
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

  Widget _lbl(String text, {double paddingBottom = 4}) => Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
      );

  Future<void> _delete() async {
    final gu = widget.isGujarati;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(gu ? 'કાઢી નાખો' : 'Delete'),
        content: Text(gu ? 'રિસાયકલ બિનમાં ખસેડવું?' : 'Move to Recycle Bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(gu ? 'રદ કરો' : 'Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(gu ? 'કાઢી નાખો' : 'Delete')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AppDatabase.instance.softDeleteOutput(widget.output!.id!);
      if (context.mounted) {
        Navigator.pop(context, 'deleted');
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gu ? 'ઉત્પાદન કાઢી નાખ્યું' : 'Harvest deleted'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: gu ? 'પાછું લાવો' : 'Undo',
              onPressed: () async {
                await AppDatabase.instance.restoreOutput(widget.output!.id!);
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = widget.isGujarati;
    final cs = Theme.of(context).colorScheme;

    final title = widget.output == null 
        ? (gu ? 'ઉત્પાદન ઉમેરો' : 'Add Harvest') 
        : (_viewMode ? (gu ? 'ઉત્પાદન વિગત' : 'Harvest Details') : (gu ? 'ઉત્પાદન સંપાદિત' : 'Edit Harvest'));

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: AppBar(
          title: Text(title),
          centerTitle: false,
          actions: [
            if (widget.output != null && _viewMode) ...[
            ],
            if (widget.output != null && !_viewMode)
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
      ),
      body: RepaintBoundary(
        key: _boundaryKey,
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _viewMode && widget.output != null
              ? _buildSummary(gu, cs)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCard(
                        title: gu ? 'ખેતરની માહિતી' : 'Field Information',
                        icon: Icons.landscape_rounded,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    PremiumAutocomplete(
                                      label: gu ? 'ખેતર' : 'Field',
                                      controller: _fieldCtrl,
                                      options: _fields,
                                      hint: gu ? 'ખેતરનું નામ' : 'Field name',
                                      isGujarati: gu,
                                      icon: Icons.landscape_outlined,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _lbl(gu ? 'વિઘા' : 'Vigha'),
                                    TextFormField(
                                      controller: _vighaCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: _inputDeco(gu ? 'વિઘા' : 'Vigha', prefixIcon: Icons.straighten_rounded),
                                      validator: (v) => ValidationHelper.validateAmount(v, gu),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _buildCard(
                        title: gu ? 'ઉત્પાદન વિગત' : 'Harvest Details',
                        icon: Icons.grass_rounded,
                        children: [
                          if (widget.crop == 'Tarbuch') ...[
                            _lbl(gu ? 'વજન (kg) *' : 'Weight (kg) *'),
                            TextFormField(
                              controller: _remainingCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco('0', prefixIcon: Icons.scale_rounded, prefixText: 'kg '),
                              validator: (v) => ValidationHelper.validateAmount(v, gu),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _lbl(widget.crop == 'Bataka' ? (gu ? 'ભરતી (82kg) *' : 'Bharati (82kg) *') : (widget.crop == 'Bajari' || widget.crop == 'Ghau') ? (gu ? 'ભરતી (100kg) *' : 'Bharati (100kg) *') : _isStandardCrop(widget.crop) ? (gu ? 'ભરતી (34kg bags) *' : 'Bharati (34kg bags) *') : (gu ? 'નંગ/કટા *' : 'Quantity/Kata *')),
                                      TextFormField(
                                        controller: _kataCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: _inputDeco('0', prefixIcon: Icons.inventory_2_outlined),
                                        validator: (v) => ValidationHelper.validateAmount(v, gu),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isStandardCrop(widget.crop)) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _lbl(gu ? 'બાકી kg' : 'Remaining kg'),
                                        TextFormField(
                                          controller: _remainingCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: _inputDeco('0', prefixIcon: Icons.more_horiz_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          _lbl(widget.crop == 'Tarbuch' ? (gu ? 'ભાવ/kg *' : 'Price per kg *') : widget.crop == 'Bataka' ? (gu ? 'ભાવ/20kg (80kg પર ગણતરી) *' : 'Price per 20kg (80kg base) *') : (widget.crop == 'Bajari' || widget.crop == 'Ghau') ? (gu ? 'ભાવ/20kg (99kg પર ગણતરી) *' : 'Price per 20kg (99kg base) *') : _isStandardCrop(widget.crop) ? (gu ? 'ભાવ/20kg *' : 'Price per 20kg *') : (gu ? 'ભાવ/${LanguageMapper.localizedQuantityUnit(widget.crop, gu)} *' : 'Price per ${LanguageMapper.localizedQuantityUnit(widget.crop, gu)} *')),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco('0', prefixIcon: Icons.currency_rupee_rounded, prefixText: '₹ '),
                            validator: (v) => ValidationHelper.validateAmount(v, gu),
                          ),
                        ],
                      ),
                      _buildCard(
                        title: gu ? 'આવકની માહિતી' : 'Revenue Information',
                        icon: Icons.account_balance_wallet_rounded,
                        children: [
                          ValueListenableBuilder<double>(
                            valueListenable: _calcRevenueNotifier,
                            builder: (context, revenue, child) {
                              if (revenue <= 0) return const SizedBox.shrink();
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: cs.tertiaryContainer.withAlpha(50),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.tertiary.withAlpha(50)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(gu ? 'અંદાજિત આવક' : 'Est. Revenue', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600)),
                                    Text(
                                      gu ? GujaratiNumberHelper.formatCurrency(revenue, gujarati: true) : GujaratiNumberHelper.formatCurrency(revenue),
                                      style: TextStyle(color: cs.tertiary, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (_isPotato) ...[
                            PremiumAutocomplete(
                              label: gu ? 'ક્યાં વેચ્યા' : 'Sold To',
                              controller: _soldToCtrl,
                              options: _buyers,
                              hint: gu ? 'ખરીદનાર નુ નામ' : 'Buyer Name',
                              isGujarati: gu,
                              icon: Icons.person_outline_rounded,
                              suffix: VoiceInputButton(
                                controller: _soldToCtrl,
                                onResult: () => setState(() {}),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _lbl(gu ? 'તારીખ' : 'Date'),
                          InkWell(
                            onTap: () async {
                              final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
                              if (p != null) setState(() => _date = p);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withAlpha(50),
                                border: Border.all(color: cs.outlineVariant.withAlpha(80)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                                  const SizedBox(width: 12),
                                  Builder(
                                    builder: (ctx) {
                                      final res = '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
                                      return Text(
                                        gu ? GujaratiNumberHelper.toGujarati(res) : res,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF1B5E20).withAlpha(60), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  _save();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _saving
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      gu ? 'સાચવો' : 'Save Harvest',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}


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

  Widget _buildSummary(bool gu, ColorScheme cs) {
    final o = widget.output!;
    final d = DateTime.fromMillisecondsSinceEpoch(o.date);
    final res = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    final dateStr = gu ? GujaratiNumberHelper.toGujarati(res) : res;
    final panchangKey = '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';
    final panchang = PanchangHelper.getPanchangForDate(panchangKey, gujarati: gu);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_isSharingSummary) _buildBrandedHeader(),
        // ── Amount Banner ─────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
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
                      gu ? 'આવક • ${LanguageMapper.localizedCrop(o.crop, gu)}' : 'Revenue from ${LanguageMapper.localizedCrop(o.crop, gu)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                gu
                    ? GujaratiNumberHelper.formatCurrency(o.revenue, gujarati: true)
                    : GujaratiNumberHelper.formatCurrency(o.revenue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(dateStr, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Secondary Groups ─────────────────────────────
        if (o.field.isNotEmpty || o.vigha.isNotEmpty)
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
                        '${o.field.isNotEmpty ? (gu ? GujaratiNumberHelper.toGujarati(o.field) : o.field) : (gu ? 'નામ નથી' : 'No Name')}${o.vigha.isNotEmpty ? " • ${gu ? GujaratiNumberHelper.toGujarati(o.vigha) : o.vigha} ${gu ? 'વિઘા' : 'Vigha'}" : ""}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_isPotato && o.soldTo.isNotEmpty)
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
                        gu ? 'ક્યાં વેચ્યા' : 'Sold To',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        o.soldTo,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ── Detail rows ───────────────────────────────────
        
        // Quantity (or Weight) / Remaining kg (Side-by-side if standard crop)
        if (o.crop == 'Tarbuch')
          _summaryTile(
            context,
            icon: Icons.scale_rounded,
            label: gu ? 'વજન' : 'Weight',
            value: '${GujaratiNumberHelper.formatNumber(o.remainingKg, gujarati: gu)} kg',
          )
        else
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  context,
                  icon: Icons.inventory_2_rounded,
                  label: _isStandardCrop(o.crop) ? (gu ? 'ભરતી' : 'Bharati') : (gu ? 'નંગ/કટા' : 'Quantity'),
                  value: '${GujaratiNumberHelper.formatNumber(o.bharati.toDouble(), gujarati: gu)} ${LanguageMapper.localizedQuantityUnit(o.crop, gu)}',
                ),
              ),
              if (_isStandardCrop(o.crop)) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryTile(
                    context,
                    icon: Icons.add_circle_rounded,
                    label: gu ? 'બાકી kg' : 'Remaining',
                    value: '${GujaratiNumberHelper.formatNumber(o.remainingKg, gujarati: gu)} kg',
                  ),
                ),
              ],
            ],
          ),

        // Price
        _summaryTile(
          context,
          icon: Icons.sell_rounded,
          label: o.crop == 'Tarbuch' ? (gu ? 'ભાવ/kg' : 'Price per kg') : (_isStandardCrop(o.crop) ? (gu ? 'ભાવ/20kg' : 'Price per 20kg') : (gu ? 'ભાવ/કટા' : 'Price per Kata')),
          value: '₹${GujaratiNumberHelper.formatNumber(o.pricePer20kg.toDouble(), gujarati: gu)}/${o.crop == 'Tarbuch' ? (gu ? 'kg' : 'kg') : (_isStandardCrop(o.crop) ? (gu ? '20kg' : '20kg') : (gu ? 'કટા' : 'kata'))}',
        ),

        const SizedBox(height: 24),
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

  Widget _srow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 13))),
    ]),
  );
}
