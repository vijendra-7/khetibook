import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/faq_provider.dart';

class UserHelpScreen extends StatelessWidget {
  const UserHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;
    final faqProvider = context.watch<FaqProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(gu ? 'મદદ અને માર્ગદર્શન' : 'Help & Support'),
      ),
      body: faqProvider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSupportCard(cs, gu),
              const SizedBox(height: 24),
              Text(
                gu ? 'વારંવાર પૂછાતા પ્રશ્નો' : 'Frequently Asked Questions',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...faqProvider.faqs.map((faq) => _buildFaqTile(faq, cs, gu)),
            ],
          ),
    );
  }

  Widget _buildSupportCard(ColorScheme cs, bool gu) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_agent_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          Text(
            gu ? 'કોઈ પ્રશ્ન છે?' : 'Have a Question?',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            gu 
              ? 'અમારા એડમિન સાથે સંપર્ક કરો: thevijendrachaudhary@gmail.com' 
              : 'Contact our admin at: thevijendrachaudhary@gmail.com',
            style: TextStyle(color: Colors.white.withAlpha(200)),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(FaqItem faq, ColorScheme cs, bool gu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: ExpansionTile(
          shape: const Border(),
          title: Text(
            gu ? faq.questionGu : faq.questionEn,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                gu ? faq.answerGu : faq.answerEn,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
