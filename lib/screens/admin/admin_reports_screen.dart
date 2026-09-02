import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/settings_provider.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _loading = true;
  double _totalInvestments = 0;
  double _totalOutputs = 0;
  int _userCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAggregates();
  }

  Future<void> _fetchAggregates() async {
    setState(() => _loading = true);
    try {
      // Note: In a production app with many users, this should be a Cloud Function aggregation.
      // For now, we perform a basic scan since admin has read permissions.
      final users = await FirebaseFirestore.instance.collection('users_profiles').get();
      final userDocs = users.docs;
      _userCount = userDocs.length;

      double invSum = 0;
      double outSum = 0;

      for (var user in userDocs) {
        // Sample recent investments across all users
        final invs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('investments')
            .get();
        final invDocs = invs.docs;
        for (var inv in invDocs) {
          invSum += (inv.data()['totalCost'] ?? 0).toDouble();
        }

        final outs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('outputs')
            .get();
        final outDocs = outs.docs;
        for (var out in outDocs) {
          final qty = (out.data()['quantity'] ?? 0).toDouble();
          final price = (out.data()['pricePerUnit'] ?? 0).toDouble();
          outSum += (qty * price);
        }
      }

      setState(() {
        _totalInvestments = invSum;
        _totalOutputs = outSum;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Aggregation error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'રિપોર્ટ અને વિશ્લેષણ' : 'Reports & Analytics',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading 
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: cs.primary, strokeWidth: 3),
              const SizedBox(height: 24),
              Text(
                gu ? 'ડેટા એકઠો કરી રહ્યા છીએ...' : 'Aggregating app-wide data...',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
            ],
          ))
        : RefreshIndicator(
            onRefresh: _fetchAggregates,
            color: cs.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _buildInsightHeader(gu ? 'નાણાકીય સારાંશ' : 'Financial Summary', cs),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        gu ? 'કુલ રોકાણ' : 'Total Investment',
                        '₹${_totalInvestments.toStringAsFixed(0)}',
                        Icons.trending_up_rounded,
                        Colors.orange,
                        cs,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        gu ? 'કુલ આવક' : 'Total Revenue',
                        '₹${_totalOutputs.toStringAsFixed(0)}',
                        Icons.payments_rounded,
                        Colors.green,
                        cs,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  gu ? 'કુલ વપરાશકર્તાઓ' : 'User Base',
                  '$_userCount ${gu ? 'ખેડૂતો' : 'Farmers'}',
                  Icons.groups_rounded,
                  Colors.blue,
                  cs,
                ),
                const SizedBox(height: 32),
                _buildInsightHeader(gu ? 'તુલનાત્મક વિશ્લેષણ' : 'Revenue vs Investment', cs),
                const SizedBox(height: 24),
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: [
                              PieChartSectionData(
                                value: _totalInvestments,
                                color: Colors.orange,
                                title: '',
                                radius: 25,
                              ),
                              PieChartSectionData(
                                value: _totalOutputs,
                                color: Colors.green,
                                title: '',
                                radius: 25,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(Colors.orange, gu ? 'કુલ રોકાણ' : 'Investments', cs),
                            const SizedBox(height: 12),
                            _buildLegendItem(Colors.green, gu ? 'કુલ આવક' : 'Revenue', cs),
                            const SizedBox(height: 16),
                            Divider(color: cs.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              gu ? 'ચોખ્ખો નફો' : 'Estimated Profit',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            Text(
                              '₹${(_totalOutputs - _totalInvestments).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: (_totalOutputs - _totalInvestments) >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildInsightHeader(String title, ColorScheme cs) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.onSurface)),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, ColorScheme cs) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }
}
