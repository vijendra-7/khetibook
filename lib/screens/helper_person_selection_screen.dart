import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/helper_transaction.dart';
import '../providers/settings_provider.dart';
import '../utils/language_mapper.dart';
import '../utils/gujarati_number_helper.dart';
import '../widgets/empty_state_widget.dart';
import '../utils/custom_options_manager.dart';
import 'helper_account_screen.dart';

class HelperPersonSelectionScreen extends StatefulWidget {
  final String transactionType;
  final int typeIndex;
  
  const HelperPersonSelectionScreen({
    super.key,
    required this.transactionType,
    required this.typeIndex,
  });

  @override
  State<HelperPersonSelectionScreen> createState() => _HelperPersonSelectionScreenState();
}

class _HelperPersonSelectionScreenState extends State<HelperPersonSelectionScreen> {
  bool _loading = true;
  List<HelperTransaction> _allItems = [];
  List<String> _customNames = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await AppDatabase.instance.getTransactionsByType(widget.transactionType);
    final category = widget.transactionType == 'Tractor' 
        ? CustomOptionsManager.categoryDrivers 
        : CustomOptionsManager.categoryHelpers;
    final customNames = await CustomOptionsManager.getAllOptions(category);
    
    if (mounted) {
      setState(() {
        _allItems = items;
        _customNames = customNames;
        _loading = false;
      });
    }
  }

  // Group items by person and summarize
  List<Map<String, dynamic>> get _personSummaries {
    final Map<String, Map<String, dynamic>> map = {};
    
    // First, initialize with custom names to ensure they appear even with 0 transactions
    for (final name in _customNames) {
      map[name] = {
        'name': name,
        'totalAmount': 0.0,
        'totalHours': 0.0,
      };
    }

    for (final t in _allItems) {
      final name = t.helperName.isEmpty 
          ? LanguageMapper.localizedTransactionType(widget.transactionType, false)
          : t.helperName;
      
      if (!map.containsKey(name)) {
        map[name] = {
          'name': name,
          'totalAmount': 0.0,
          'totalHours': 0.0,
        };
      }
      map[name]!['totalAmount'] += t.totalAmount;
      map[name]!['totalHours'] += t.hours;
    }
    
    final list = map.values.toList();
    // Sort alphabetically
    list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return list;
  }

  Future<void> _openPerson(String personName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HelperAccountScreen(
          transactionType: widget.transactionType,
          typeIndex: widget.typeIndex,
          personName: personName,
        ),
      ),
    );
    // Reload items when returning in case a transaction was added/deleted
    _load();
  }

  void _addNewPerson(bool gu) {
    final cs = Theme.of(context).colorScheme;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gu ? 'નવો વ્યક્તિ' : 'New Person'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: gu ? 'નામ દાખલ કરો' : 'Enter Name',
            border: const OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(gu ? 'રદ કરો' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                // Save name to custom options immediately so it persists even if no transaction is added
                final category = widget.transactionType == 'Tractor' 
                    ? CustomOptionsManager.categoryDrivers 
                    : CustomOptionsManager.categoryHelpers;
                await CustomOptionsManager.addCustomOption(category, val);
                
                if (mounted) {
                  Navigator.pop(ctx);
                  _openPerson(val);
                }
              }
            },
            child: Text(gu ? 'આગળ' : 'Next'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final typeName = LanguageMapper.localizedTransactionType(widget.transactionType, gu);
    
    final summaries = _personSummaries;

    return Scaffold(
      appBar: AppBar(
        title: Text('${gu ? 'ભાગીદાર' : 'Partner'} • $typeName'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewPerson(gu),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(gu ? 'નવો વ્યક્તિ' : 'New Person'),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : summaries.isEmpty 
            ? EmptyStateWidget(
                icon: Icons.group_add_rounded,
                title: gu ? 'કોઈ વ્યક્તિ નથી' : 'No People Found',
                message: gu ? 'ઉમેરવા માટે + બટન દબાવો' : 'Tap the + button to add someone',
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: summaries.length,
                itemBuilder: (ctx, i) {
                  final sum = summaries[i];
                  final name = sum['name'] as String;
                  final totalAmount = sum['totalAmount'] as double;
                  final totalHours = sum['totalHours'] as double;
                  
                  return _PersonCard(
                    name: name,
                    totalAmount: totalAmount,
                    totalHours: totalHours,
                    transactionType: widget.transactionType,
                    isGujarati: gu,
                    onTap: () => _openPerson(name),
                  );
                },
              ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String name;
  final double totalAmount;
  final double totalHours;
  final String transactionType;
  final bool isGujarati;
  final VoidCallback onTap;

  const _PersonCard({
    required this.name,
    required this.totalAmount,
    required this.totalHours,
    required this.transactionType,
    required this.isGujarati,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    String subLabel = '';
    if (transactionType == 'Tractor' && totalHours > 0) {
      subLabel = isGujarati 
          ? '${GujaratiNumberHelper.toGujarati(totalHours.toStringAsFixed(1))} કલાક'
          : '${totalHours.toStringAsFixed(1)} hours';
    }
    
    final amountStr = isGujarati
        ? GujaratiNumberHelper.formatCurrency(totalAmount, gujarati: true)
        : '₹${totalAmount.toStringAsFixed(0)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withAlpha(120), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primaryContainer.withAlpha(150),
                  foregroundColor: cs.primary,
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (subLabel.isNotEmpty) ...[
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  amountStr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
