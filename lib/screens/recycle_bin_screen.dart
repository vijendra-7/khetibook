import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/investment.dart';
import '../models/output.dart';
import '../models/helper_transaction.dart';
import '../providers/settings_provider.dart';
import '../widgets/empty_state_widget.dart';
import '../services/sync_service.dart';
import '../utils/language_mapper.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final SyncService _syncService = SyncService();
  List<Investment> _investments = [];
  List<Output> _outputs = [];
  List<HelperTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final inv = await AppDatabase.instance.getDeletedInvestments();
    final out = await AppDatabase.instance.getDeletedOutputs();
    final txns = await AppDatabase.instance.getDeletedTransactions();
    if (mounted) setState(() { _investments = inv; _outputs = out; _transactions = txns; });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(gu ? 'રિસાઈકલ બિન' : 'Recycle Bin'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          tabs: [
            Tab(text: gu ? 'ખર્ચો' : 'Investments'),
            Tab(text: gu ? 'ઉત્પાદન' : 'Harvests'),
            Tab(text: gu ? 'સહાયક' : 'Helpers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildInvestmentList(gu, cs),
          _buildOutputList(gu, cs),
          _buildTransactionList(gu, cs),
        ],
      ),
    );
  }

  Widget _buildInvestmentList(bool gu, ColorScheme cs) {
    if (_investments.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.agriculture_outlined,
        title: gu ? 'ખર્ચો ખાલી' : 'No Deleted Investments',
        message: gu ? 'ડિલીટ કરેલ ખર્ચો અહીં દેખાશે' : 'Deleted investment entries will appear here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _investments.length,
      itemBuilder: (_, i) {
        final inv = _investments[i];
        return _DeletedCard(
          title: inv.displayInvestmentType,
          subtitle: inv.crop,
          amount: inv.totalAmount,
          date: inv.date,
          icon: Icons.agriculture_rounded,
          iconColor: cs.error,
          isGujarati: gu,
          onRestore: () => _restoreInvestment(inv),
          onDelete: () => _deleteInvestment(inv),
        );
      },
    );
  }

  Widget _buildOutputList(bool gu, ColorScheme cs) {
    if (_outputs.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.grass_outlined,
        title: gu ? 'ઉત્પાદન ખાલી' : 'No Deleted Harvests',
        message: gu ? 'ડિલીટ કરેલ ઉત્પાદન અહીં દેખાશે' : 'Deleted harvest entries will appear here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _outputs.length,
      itemBuilder: (_, i) {
        final out = _outputs[i];
        return _DeletedCard(
          title: out.field.isEmpty ? (gu ? 'ઉત્પાદન' : 'Harvest') : out.field,
          subtitle: '${out.crop} • ${out.bharati} ${LanguageMapper.localizedQuantityUnit(out.crop, gu)}',
          amount: out.revenue,
          date: out.date,
          icon: Icons.grass_rounded,
          iconColor: Colors.green.shade700,
          isGujarati: gu,
          onRestore: () => _restoreOutput(out),
          onDelete: () => _deleteOutput(out),
        );
      },
    );
  }

  Widget _buildTransactionList(bool gu, ColorScheme cs) {
    if (_transactions.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_alt_outlined,
        title: gu ? 'સહાયક ખાતુ ખાલી' : 'No Deleted Transactions',
        message: gu ? 'ડિલીટ કરેલ વ્યવહારો અહીં દેખાશે' : 'Deleted helper transactions will appear here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (_, i) {
        final txn = _transactions[i];
        return _DeletedCard(
          title: txn.transactionType,
          subtitle: txn.helperName,
          amount: txn.totalAmount,
          date: txn.date,
          icon: Icons.person_outlined,
          iconColor: Colors.blue.shade700,
          isGujarati: gu,
          onRestore: () => _restoreTxn(txn),
          onDelete: () => _deleteTxn(txn),
        );
      },
    );
  }

  Future<void> _restoreInvestment(Investment inv) async {
    await AppDatabase.instance.restoreInvestment(inv.id!);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✅ Investment restored'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
      ));
    }
  }

  Future<void> _deleteInvestment(Investment inv) async {
    final ok = await _confirmPermanentDelete();
    if (ok) { 
      await AppDatabase.instance.permanentDeleteInvestment(inv.id!); 
      await _syncService.deleteRemote('investments', inv.uuid);
      _load(); 
    }
  }

  Future<void> _restoreOutput(Output out) async {
    await AppDatabase.instance.restoreOutput(out.id!);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✅ Harvest restored'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
      ));
    }
  }

  Future<void> _deleteOutput(Output out) async {
    final ok = await _confirmPermanentDelete();
    if (ok) { 
      await AppDatabase.instance.permanentDeleteOutput(out.id!); 
      await _syncService.deleteRemote('outputs', out.uuid);
      _load(); 
    }
  }

  Future<void> _restoreTxn(HelperTransaction txn) async {
    await AppDatabase.instance.restoreTransaction(txn.id!);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✅ Transaction restored'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
      ));
    }
  }

  Future<void> _deleteTxn(HelperTransaction txn) async {
    final ok = await _confirmPermanentDelete();
    if (ok) { 
      await AppDatabase.instance.permanentDeleteTransaction(txn.id!); 
      await _syncService.deleteRemote('helper_transactions', txn.uuid);
      _load(); 
    }
  }

  Future<bool> _confirmPermanentDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permanent Delete'),
        content: const Text('This action cannot be undone. Delete forever?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _DeletedCard extends StatelessWidget {
  final String title, subtitle;
  final double amount;
  final int date;
  final IconData icon;
  final Color iconColor;
  final bool isGujarati;
  final VoidCallback onRestore, onDelete;

  const _DeletedCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.isGujarati,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = DateTime.fromMillisecondsSinceEpoch(date);
    final dateStr = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(80), width: 1),
        boxShadow: [
          BoxShadow(color: cs.shadow.withAlpha(12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 3),
            Text('$subtitle  •  $dateStr', style: TextStyle(color: cs.outline, fontSize: 12)),
          ])),
          const SizedBox(width: 8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface),
          ),
          const SizedBox(width: 10),
          Column(mainAxisSize: MainAxisSize.min, children: [
            _ActionBtn(
              icon: Icons.restore_rounded,
              color: Colors.green,
              onTap: onRestore,
              tooltip: isGujarati ? 'પુનઃ સ્થાપિત' : 'Restore',
            ),
            const SizedBox(height: 6),
            _ActionBtn(
              icon: Icons.delete_forever_rounded,
              color: cs.error,
              onTap: onDelete,
              tooltip: isGujarati ? 'કાઢી નાખો' : 'Delete',
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _ActionBtn({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      ),
    );
  }
}
