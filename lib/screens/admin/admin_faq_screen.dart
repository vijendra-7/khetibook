import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class AdminFaqScreen extends StatefulWidget {
  const AdminFaqScreen({super.key});

  @override
  State<AdminFaqScreen> createState() => _AdminFaqScreenState();
}

class _AdminFaqScreenState extends State<AdminFaqScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qEnCtrl = TextEditingController();
  final _qGuCtrl = TextEditingController();
  final _aEnCtrl = TextEditingController();
  final _aGuCtrl = TextEditingController();
  int _priority = 0;

  void _clearForm() {
    _qEnCtrl.clear();
    _qGuCtrl.clear();
    _aEnCtrl.clear();
    _aGuCtrl.clear();
    _priority = 0;
  }

  Future<void> _saveFaq({String? docId}) async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'questionEn': _qEnCtrl.text.trim(),
      'questionGu': _qGuCtrl.text.trim(),
      'answerEn': _aEnCtrl.text.trim(),
      'answerGu': _aGuCtrl.text.trim(),
      'priority': _priority,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (docId != null) {
      await FirebaseFirestore.instance.collection('faqs').doc(docId).update(data);
    } else {
      await FirebaseFirestore.instance.collection('faqs').add(data);
    }
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'પ્રશ્નોત્તરી વ્યવસ્થાપન' : 'FAQ Management',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFaqDialog(),
        icon: const Icon(Icons.add),
        label: Text(gu ? 'નવો પ્રશ્ન' : 'New FAQ'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('faqs').orderBy('priority', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text(gu ? 'કોઈ પ્રશ્નો નથી' : 'No FAQs yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final priority = data['priority'] ?? 0;

              return Material(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => _showFaqDialog(doc: docs[index]),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.quiz_rounded, color: cs.primary, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['questionEn'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Priority: $priority',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                  ),
                                  if (priority > 7) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.star_rounded, color: Colors.orange, size: 14),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () => _deleteFaq(docs[index].id),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFaqDialog({DocumentSnapshot? doc}) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.read<SettingsProvider>().isGujarati;

    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _qEnCtrl.text = data['questionEn'] ?? '';
      _qGuCtrl.text = data['questionGu'] ?? '';
      _aEnCtrl.text = data['answerEn'] ?? '';
      _aGuCtrl.text = data['answerGu'] ?? '';
      _priority = data['priority'] ?? 0;
    } else {
      _clearForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  doc == null ? (gu ? 'નવો પ્રશ્ન' : 'Add FAQ') : (gu ? 'ફેરફાર કરો' : 'Edit FAQ'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildField(_qEnCtrl, 'Question (English)', Icons.help_outline_rounded, cs, validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 16),
                      _buildField(_qGuCtrl, 'Question (ગુજરાતી)', Icons.translate_rounded, cs, validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 16),
                      _buildField(_aEnCtrl, 'Answer (English)', Icons.note_alt_outlined, cs, maxLines: 3),
                      const SizedBox(height: 16),
                      _buildField(_aGuCtrl, 'Answer (ગુજરાતી)', Icons.note_alt_rounded, cs, maxLines: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(gu ? 'પ્રાયોરિટી:' : 'Priority:', style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _priority.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        activeColor: cs.primary,
                        onChanged: (v) {
                          setDialogState(() => _priority = v.toInt());
                          setState(() => _priority = v.toInt());
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                      child: Text('$_priority', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      _saveFaq(docId: doc?.id);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(gu ? 'સાચવો' : 'Save FAQ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl, 
    String label, 
    IconData icon, 
    ColorScheme cs, 
    {int maxLines = 1, String? Function(String?)? validator}
  ) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: validator,
    );
  }

  Future<void> _deleteFaq(String id) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete FAQ?'),
        content: const Text('This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('faqs').doc(id).delete();
    }
  }
}
