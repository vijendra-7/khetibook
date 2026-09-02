import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'helper_person_selection_screen.dart';
class TransactionTypeSelectionScreen extends StatelessWidget {
  const TransactionTypeSelectionScreen({super.key});

  static const _types = [
    ('Upaad', 'ઉપાડ', Icons.arrow_upward_rounded, Color(0xFF1565C0)),
    ('Bhaag', 'ભાગ', Icons.pie_chart_rounded, Color(0xFF6A1B9A)),
    ('Majur', 'મજૂર', Icons.group_rounded, Color(0xFF2E7D32)),
    ('Tractor', 'ટ્રેક્ટર', Icons.agriculture_rounded, Color(0xFFE65100)),
  ];

  @override
  Widget build(BuildContext context) {
    final gu = context.watch<SettingsProvider>().isGujarati;
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(gu ? 'ભાગીદાર ખાતું' : 'Partner Account'),
        centerTitle: true,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.9,
        children: _types.asMap().entries.map((entry) {
          final i = entry.key;
          final (en, guName, icon, color) = entry.value;
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HelperPersonSelectionScreen(
                    transactionType: en,
                    typeIndex: i,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withAlpha(220),
                      color.withAlpha(160),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(60),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      gu ? guName : en,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
