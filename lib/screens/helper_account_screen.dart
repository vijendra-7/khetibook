import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/helper_transaction.dart';
import '../providers/settings_provider.dart';
import '../utils/language_mapper.dart';
import '../utils/gujarati_number_helper.dart';
import '../widgets/empty_state_widget.dart';
import 'add_helper_transaction_screen.dart';

class HelperAccountScreen extends StatefulWidget {
  final String transactionType;
  final int typeIndex;
  final String personName;
  const HelperAccountScreen({
    super.key, 
    required this.transactionType, 
    required this.typeIndex, 
    required this.personName,
  });

  @override
  State<HelperAccountScreen> createState() => _HelperAccountScreenState();
}

class _HelperAccountScreenState extends State<HelperAccountScreen> {
  List<HelperTransaction> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.transactionType == 'Tractor') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboardingOverlay());
    }
  }

  Future<void> _checkOnboardingOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seenTractorOverlay') ?? false;
    if (!seen && mounted) {
      _showOnboardingOverlay();
      await prefs.setBool('seenTractorOverlay', true);
    }
  }

  void _showOnboardingOverlay() {
    final gu = context.read<SettingsProvider>().isGujarati;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.agriculture_rounded, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              gu ? 'ટ્રેક્ટર હિસાબ' : 'Tractor Accounts',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              gu 
                ? 'આ ટ્રેક્ટર વિકલ્પ તેઓ માટે છે જેમને પોતાનું ટ્રેક્ટર હોય અને જે ટ્રેક્ટર પોતે ચલાવે અથવા ડ્રાઇવરને આપે અને સમય તથા કામનો હિસાબ રાખવા માંગે છે'
                : 'The Tractor option is for those who own a tractor and drive it themselves or give it to a driver and want to keep track of time and work.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(gu ? 'સમજાયું' : 'Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final allItems = await AppDatabase.instance.getTransactionsByType(widget.transactionType);
    final items = allItems.where((t) => t.helperName == widget.personName).toList();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  double get _total => _items.fold(0, (s, t) => s + t.totalAmount);

  List<dynamic> get _groupedItems {
    final items = List<HelperTransaction>.from(_items);
    // Sort by date descending
    items.sort((a, b) => b.date.compareTo(a.date));
    
    final List<dynamic> grouped = [];
    String? currentGroup;
    for (final item in items) {
      final dateStr = _fmt(item.date);
      if (dateStr != currentGroup) {
        grouped.add(dateStr);
        currentGroup = dateStr;
      }
      grouped.add(item);
    }
    return grouped;
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

  Widget _buildHeaderCard(bool gu, ColorScheme cs) {
    final typeName = LanguageMapper.localizedTransactionType(widget.transactionType, gu);
    bool showListCard = widget.transactionType == 'Tractor' && _items.isEmpty;
    
    return Column(
      children: [
        if (showListCard) _buildOnboardingCard(gu, cs),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B5E20).withAlpha(60),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gu ? 'કુલ ખર્ચ' : 'Total Expense',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gu
                            ? GujaratiNumberHelper.formatCurrency(_total, gujarati: true)
                            : GujaratiNumberHelper.formatCurrency(_total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _headerInfoChip('${gu ? GujaratiNumberHelper.toGujaratiInt(_items.length) : _items.length} ${gu ? 'નોંધ' : 'entries'}', Icons.receipt_long_rounded),
                  const SizedBox(width: 8),
                  _headerInfoChip(typeName, Icons.category_rounded),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingCard(bool gu, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gu 
                ? 'આ ટ્રેક્ટર વિકલ્પ તેઓ માટે છે જેમને પોતાનું ટ્રેક્ટર હોય અને જે ટ્રેક્ટર પોતે ચલાવે અથવા ડ્રાઇવરને આપે અને સમય તથા કામનો હિસાબ રાખવા માંગે છે'
                : 'The Tractor option is for those who own a tractor and drive it themselves or give it to a driver and want to keep track of time and work.',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfoChip(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withAlpha(220), size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _miniChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(40),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final cs = Theme.of(context).colorScheme;
    final typeName = LanguageMapper.localizedTransactionType(widget.transactionType, gu);
    return Scaffold(
      appBar: AppBar(
        title: Text('${gu ? 'ભાગીદાર' : 'Partner'} • ${widget.personName}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null, gu, widget.typeIndex),
        icon: const Icon(Icons.add),
        label: Text(gu ? 'ઉમેરો' : 'Add'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderCard(gu, cs),
                Expanded(
                  child: _items.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.person_off_outlined,
                          title: gu ? 'કોઈ વ્યવહાર નથી' : 'No Transactions Found',
                          message: gu ? 'વ્યવહાર ઉમેરવા માટે + બટન દબાવો' : 'Tap the + button to add a partner transaction',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _groupedItems.length,
                          itemBuilder: (_, i) {
                            final item = _groupedItems[i];
                            if (item is String) {
                              return _buildDateHeader(item, gu, cs);
                            }
                            final txn = item as HelperTransaction;
                            return _HelperCard(
                              txn: txn,
                              isGujarati: gu,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _navigateToForm(txn, gu, widget.typeIndex);
                                },
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                _confirmDelete(txn, gu);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _confirmDelete(HelperTransaction txn, bool gu) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gu ? 'વ્યવહાર કાઢી નાખો?' : 'Delete Transaction?'),
        content: Text(gu 
            ? 'શું તમે ખરેખર આ ભાગીદારનો વ્યવહાર કાઢી નાખવા માંગો છો?' 
            : 'Are you sure you want to delete this partner transaction?'),
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
              await AppDatabase.instance.softDeleteTransaction(txn.id!);
              _load();
              if (mounted) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(gu ? 'વ્યવહાર કાઢી નાખ્યો' : 'Transaction deleted'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: gu ? 'પાછું લાવો' : 'Undo',
                      onPressed: () async {
                        await AppDatabase.instance.restoreTransaction(txn.id!);
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

  Future<void> _navigateToForm(HelperTransaction? txn, bool gu, int typeIdx) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddHelperTransactionScreen(
          transactionType: widget.transactionType,
          typeIndex: typeIdx,
          transaction: txn,
          isGujarati: gu,
          fixedPersonName: widget.personName,
        ),
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

class _HelperCard extends StatefulWidget {
  final HelperTransaction txn;
  final bool isGujarati;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _HelperCard({required this.txn, required this.isGujarati, required this.onTap, this.onLongPress});

  @override
  State<_HelperCard> createState() => _HelperCardState();
}

class _HelperCardState extends State<_HelperCard> {
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = widget.isGujarati;
    final d = DateTime.fromMillisecondsSinceEpoch(widget.txn.date);
    final dateStr = _fmt(widget.txn.date);
    String subtitle;
    switch (widget.txn.transactionType) {
      case 'Majur':
        subtitle = gu 
            ? '${GujaratiNumberHelper.toGujarati(widget.txn.workerCount.toString())} workers × ${GujaratiNumberHelper.formatCurrency(widget.txn.amountPerWorker, gujarati: true)}'
            : '${widget.txn.workerCount} workers × ₹${widget.txn.amountPerWorker.toInt()}';
        break;
      case 'Tractor':
        subtitle = widget.txn.equipmentType == 'Tola no Fero'
            ? widget.txn.field
            : gu 
                ? '${widget.txn.field} • ${GujaratiNumberHelper.toGujarati(widget.txn.hours.toStringAsFixed(1))}h × ${GujaratiNumberHelper.formatCurrency(widget.txn.pricePerHour, gujarati: true)}'
                : '${widget.txn.field} • ${widget.txn.hours.toStringAsFixed(1)}h × ₹${widget.txn.pricePerHour.toInt()}';
        break;
      default:
        subtitle = '';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: cs.outlineVariant.withAlpha(110),
          width: 1.2,
        ),
      ),
      child: RepaintBoundary(
        key: _cardKey,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withAlpha(140),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      widget.txn.transactionType == 'Majur' 
                          ? Icons.groups_rounded 
                          : widget.txn.transactionType == 'Tractor'
                              ? Icons.agriculture_rounded
                              : Icons.person_rounded,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.txn.helperName.isEmpty 
                              ? LanguageMapper.localizedTransactionType(widget.txn.transactionType, gu) 
                              : widget.txn.helperName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        gu
                            ? GujaratiNumberHelper.formatCurrency(widget.txn.totalAmount, gujarati: true)
                            : '₹${widget.txn.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
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

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final gu = widget.isGujarati;
    final res = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return gu ? GujaratiNumberHelper.toGujarati(res) : res;
  }
}


