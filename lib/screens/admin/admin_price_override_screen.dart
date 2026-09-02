import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/crop_price_provider.dart';

class AdminPriceOverrideScreen extends StatefulWidget {
  const AdminPriceOverrideScreen({super.key});

  @override
  State<AdminPriceOverrideScreen> createState() => _AdminPriceOverrideScreenState();
}

class _AdminPriceOverrideScreenState extends State<AdminPriceOverrideScreen> {
  String? _selectedMarket;
  String? _selectedCrop;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  int _expiryHours = 24;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;
    final priceProvider = context.watch<CropPriceProvider>();

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'ભાવ ઓવરરાઈડ' : 'Price Overrides',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(gu ? 'નવો ઓવરરાઈડ' : 'New Price Override', cs),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: _fieldDecoration('Market', Icons.store_rounded, cs, gu),
                    initialValue: _selectedMarket,
                    items: ['Deesa', 'Palanpur', 'Panthawada', 'Agra'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() { _selectedMarket = v; _selectedCrop = null; }),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedMarket != null) ...[
                    DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Crop', Icons.agriculture_rounded, cs, gu),
                      initialValue: _selectedCrop,
                      items: _getCropsForMarket(_selectedMarket!, priceProvider).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCrop = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          decoration: _fieldDecoration('Min', Icons.arrow_downward_rounded, cs, gu),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          decoration: _fieldDecoration('Max', Icons.arrow_upward_rounded, cs, gu),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gu ? 'સમયમર્યાદા: $_expiryHours કલાક' : 'Expiry: $_expiryHours Hours',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                            Slider(
                              value: _expiryHours.toDouble(),
                              min: 1, max: 72, divisions: 71,
                              activeColor: cs.primary,
                              onChanged: (v) => setState(() => _expiryHours = v.toInt()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_selectedMarket == null || _selectedCrop == null) ? null : _saveOverride,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(gu ? 'સાચવો' : 'Save Price Override', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildSectionHeader(gu ? 'સક્રિય ઓવરરાઈડ્સ' : 'Active Overrides', cs),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('price_overrides').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return Center(child: Text(gu ? 'કોઈ સક્રિય ઓવરરાઈડ નથી' : 'No active overrides'));
                
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docIdParts = docs[index].id.split('_');
                    final market = docIdParts.isNotEmpty ? docIdParts[0] : 'Unknown';
                    final crop = docIdParts.length > 1 ? docIdParts[1] : 'Unknown';

                    return Material(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.flash_on_rounded, color: cs.primary, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$market - $crop', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(
                                    '₹${data['minPrice']} - ${data['maxPrice']}',
                                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () => _deleteOverride(context, docs[index].id, gu),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteOverride(BuildContext context, String id, bool gu) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(gu ? 'ઓવરરાઈડ દૂર કરો?' : 'Delete Override?'),
        content: Text(gu ? 'શું તમે ખરેખર આ ભાવ ઓવરરાઈડને કાયમી માટે દૂર કરવા માંગો છો?' : 'Are you sure you want to permanently remove this price override?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(gu ? 'રદ કરો' : 'Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(gu ? 'દૂર કરો' : 'Delete', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('price_overrides').doc(id).delete();
    }
  }

  Widget _buildSectionHeader(String title, ColorScheme cs) {
    return Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface));
  }

  InputDecoration _fieldDecoration(String label, IconData icon, ColorScheme cs, bool gu) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  List<String> _getCropsForMarket(String market, CropPriceProvider provider) {
    if (market == 'Deesa') return provider.apmcPrices.map((e) => e.name).toSet().toList();
    if (market == 'Agra') return provider.agraPrices.map((e) => e.name).toSet().toList();
    return provider.apmcPrices.map((e) => e.name).toSet().toList();
  }

  Future<void> _saveOverride() async {
    final docId = '${_selectedMarket}_$_selectedCrop';
    await FirebaseFirestore.instance.collection('price_overrides').doc(docId).set({
      'minPrice': _minCtrl.text.trim(),
      'maxPrice': _maxCtrl.text.trim(),
      'expiry': Timestamp.fromDate(DateTime.now().add(Duration(hours: _expiryHours))),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _minCtrl.clear();
    _maxCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Override Saved!')));
  }
}
