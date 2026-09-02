import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import 'admin_responses_screen.dart';

class AdminAnnouncementScreen extends StatefulWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  State<AdminAnnouncementScreen> createState() => _AdminAnnouncementScreenState();
}

class _AdminAnnouncementScreenState extends State<AdminAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleEnCtrl = TextEditingController();
  final _titleGuCtrl = TextEditingController();
  final _msgEnCtrl = TextEditingController();
  final _msgGuCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _actionEnCtrl = TextEditingController();
  final _actionGuCtrl = TextEditingController();
  bool _isActive = true;
  int _priority = 0;
  String _targetLanguage = 'gu'; // 'en', 'gu', 'both'

  // Interactive Features
  bool _hasPoll = false;
  bool _hasTextInput = false;
  bool _isMultipleChoice = false;
  final List<TextEditingController> _pollOptionCtrls = [];

  @override
  void dispose() {
    _titleEnCtrl.dispose();
    _titleGuCtrl.dispose();
    _msgEnCtrl.dispose();
    _msgGuCtrl.dispose();
    _urlCtrl.dispose();
    _actionEnCtrl.dispose();
    _actionGuCtrl.dispose();
    for (var ctrl in _pollOptionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<bool> _saveAnnouncement({String? docId}) async {
    if (!_formKey.currentState!.validate()) return false;

    final data = {
      'titleEn': _titleEnCtrl.text.trim(),
      'titleGu': _titleGuCtrl.text.trim(),
      'messageEn': _msgEnCtrl.text.trim(),
      'messageGu': _msgGuCtrl.text.trim(),
      'actionUrl': _urlCtrl.text.trim(),
      'actionTextEn': _actionEnCtrl.text.trim(),
      'actionTextGu': _actionGuCtrl.text.trim(),
      'isActive': _isActive,
      'priority': _priority,
      'targetLanguage': _targetLanguage,
      'hasPoll': _hasPoll,
      'hasTextInput': _hasTextInput,
      'isMultipleChoice': _isMultipleChoice,
      'pollOptions': _hasPoll
          ? _pollOptionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
          : [],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': 'thevijendrachaudhary@gmail.com',
    };

    if (docId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      if (docId != null) {
        await FirebaseFirestore.instance.collection('announcements').doc(docId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('announcements').add(data);
      }

      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement saved!'), behavior: SnackBarBehavior.floating),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  void _clearForm() {
    _titleEnCtrl.clear();
    _titleGuCtrl.clear();
    _msgEnCtrl.clear();
    _msgGuCtrl.clear();
    _urlCtrl.clear();
    _actionEnCtrl.clear();
    _actionGuCtrl.clear();
    setState(() {
      _isActive = true;
      _priority = 0;
      _targetLanguage = 'gu';
      _hasPoll = false;
      _hasTextInput = false;
      _isMultipleChoice = false;
      _pollOptionCtrls.clear();
    });
  }

  void _editAnnouncement(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    _titleEnCtrl.text = data['titleEn'] ?? '';
    _titleGuCtrl.text = data['titleGu'] ?? '';
    _msgEnCtrl.text = data['messageEn'] ?? '';
    _msgGuCtrl.text = data['messageGu'] ?? '';
    _urlCtrl.text = data['actionUrl'] ?? '';
    _actionEnCtrl.text = data['actionTextEn'] ?? '';
    _actionGuCtrl.text = data['actionTextGu'] ?? '';
    setState(() {
      _isActive = data['isActive'] ?? true;
      _priority = data['priority'] ?? 0;
      _targetLanguage = data['targetLanguage'] ?? 'gu';
      _hasPoll = data['hasPoll'] ?? false;
      _hasTextInput = data['hasTextInput'] ?? false;
      _isMultipleChoice = data['isMultipleChoice'] ?? false;

      _pollOptionCtrls.clear();
      final options = data['pollOptions'] as List<dynamic>? ?? [];
      for (var opt in options) {
        _pollOptionCtrls.add(TextEditingController(text: opt.toString()));
      }
    });

    _showAddDialog(docId: doc.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'જાહેરાત વ્યવસ્થાપન' : 'Announcement Management',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _clearForm();
          _showAddDialog();
        },
        icon: const Icon(Icons.add),
        label: Text(gu ? 'નવી જાહેરાત' : 'New Announcement'),
      ),
      body: _buildList(cs, gu),
    );
  }

  Widget _buildList(ColorScheme cs, bool gu) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('priority', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text(gu ? 'કોઈ જાહેરાત નથી' : 'No announcements yet'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final isActive = data['isActive'] ?? true;
            final priority = data['priority'] ?? 0;
            final lang = data['targetLanguage'] ?? 'both';

            return Material(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _editAnnouncement(docs[index]),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isActive ? cs.primary.withOpacity(0.1) : cs.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isActive ? Icons.campaign_rounded : Icons.campaign_outlined,
                          color: isActive ? cs.primary : cs.error,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (lang == 'gu' ? data['titleGu'] : data['titleEn']) ?? 'Untitled',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? (gu ? 'સક્રિય' : 'Active') : (gu ? 'નિષ્ક્રિય' : 'Inactive'),
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    lang.toString().toUpperCase(),
                                    style: TextStyle(color: cs.onSecondaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (priority > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'HIGH PRIORITY',
                                      style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.analytics_outlined, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminResponsesScreen(
                                announcementId: docs[index].id,
                                announcementTitle: (lang == 'gu' ? data['titleGu'] : data['titleEn']) ?? 'Announcement',
                              ),
                            ),
                          );
                        },
                        tooltip: gu ? 'પ્રતિસાદ જુઓ' : 'View Responses',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () => _deleteAnnouncement(docs[index].id),
                        tooltip: gu ? 'કાઢી નાખો' : 'Delete',
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddDialog({String? docId}) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.read<SettingsProvider>().isGujarati;

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
                  docId == null ? (gu ? 'નવી જાહેરાત' : 'New Announcement') : (gu ? 'ફેરફાર કરો' : 'Edit Announcement'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                Text(gu ? 'ભાષા પસંદ કરો:' : 'Target Language:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('English'),
                      selected: _targetLanguage == 'en',
                      onSelected: (s) {
                        if (s) {
                          setDialogState(() => _targetLanguage = 'en');
                          setState(() => _targetLanguage = 'en');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ગુજરાતી'),
                      selected: _targetLanguage == 'gu',
                      onSelected: (s) {
                        if (s) {
                          setDialogState(() => _targetLanguage = 'gu');
                          setState(() => _targetLanguage = 'gu');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Both'),
                      selected: _targetLanguage == 'both',
                      onSelected: (s) {
                        if (s) {
                          setDialogState(() => _targetLanguage = 'both');
                          setState(() => _targetLanguage = 'both');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_targetLanguage == 'en' || _targetLanguage == 'both') ...[
                        _buildField(_titleEnCtrl, 'Title (English)', Icons.title_rounded, cs, validator: (v) => (_targetLanguage == 'en' || _targetLanguage == 'both') && (v == null || v.isEmpty) ? 'Required' : null),
                        const SizedBox(height: 16),
                        _buildField(_msgEnCtrl, 'Message (English)', Icons.message_outlined, cs, minLines: 3, validator: (v) => (_targetLanguage == 'en' || _targetLanguage == 'both') && (v == null || v.isEmpty) ? 'Required' : null),
                        const SizedBox(height: 24),
                      ],
                      if (_targetLanguage == 'gu' || _targetLanguage == 'both') ...[
                        _buildField(_titleGuCtrl, 'Title (ગુજરાતી)', Icons.translate_rounded, cs, validator: (v) => (_targetLanguage == 'gu' || _targetLanguage == 'both') && (v == null || v.isEmpty) ? 'Required' : null),
                        const SizedBox(height: 16),
                        _buildField(_msgGuCtrl, 'Message (ગુજરાતી)', Icons.message_rounded, cs, minLines: 3, validator: (v) => (_targetLanguage == 'gu' || _targetLanguage == 'both') && (v == null || v.isEmpty) ? 'Required' : null),
                        const SizedBox(height: 24),
                      ],
                      _buildField(_urlCtrl, 'Action URL (Optional)', Icons.link_rounded, cs, validator: (v) => null),
                      const SizedBox(height: 16),
                      if (_targetLanguage == 'en' || _targetLanguage == 'both')
                        _buildField(_actionEnCtrl, 'Action Text (English)', Icons.ads_click_rounded, cs, validator: (v) => null),
                      if (_targetLanguage == 'en' || _targetLanguage == 'both') const SizedBox(height: 16),
                      if (_targetLanguage == 'gu' || _targetLanguage == 'both')
                        _buildField(_actionGuCtrl, 'Action Text (ગુજરાતી)', Icons.ads_click_rounded, cs, validator: (v) => null),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                 SwitchListTile(
                   contentPadding: EdgeInsets.zero,
                   title: Text(gu ? 'વપરાશકર્તાઓને દેખાશે' : 'Visible to users'),
                   value: _isActive,
                   activeThumbColor: cs.primary,
                   onChanged: (v) {
                     setDialogState(() => _isActive = v);
                     setState(() => _isActive = v);
                   },
                 ),
                 SwitchListTile(
                   contentPadding: EdgeInsets.zero,
                   title: Text(gu ? 'હાઈ પ્રાયોરિટી' : 'High Priority'),
                   value: _priority > 0,
                   activeThumbColor: Colors.orange,
                   onChanged: (v) {
                     setDialogState(() => _priority = v ? 1 : 0);
                     setState(() => _priority = v ? 1 : 0);
                   },
                 ),
                 const Divider(height: 32),
                 Text(gu ? 'ઇન્ટરેક્ટિવ ફીચર્સ' : 'Interactive Features', style: const TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 SwitchListTile(
                   contentPadding: EdgeInsets.zero,
                   title: Text(gu ? 'પોલ (ચૂંટણી) ઉમેરો' : 'Enable Poll'),
                   subtitle: Text(gu ? 'વપરાશકર્તા વિકલ્પ પસંદ કરી શકશે' : 'Users can select an option'),
                   value: _hasPoll,
                   activeThumbColor: cs.primary,
                   onChanged: (v) {
                     setDialogState(() {
                       _hasPoll = v;
                       if (v && _pollOptionCtrls.isEmpty) {
                         _pollOptionCtrls.add(TextEditingController());
                         _pollOptionCtrls.add(TextEditingController());
                       }
                     });
                     setState(() => _hasPoll = v);
                   },
                 ),
                 if (_hasPoll) ...[
                   const SizedBox(height: 8),
                   ..._pollOptionCtrls.asMap().entries.map((entry) {
                     final idx = entry.key;
                     final ctrl = entry.value;
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 8),
                       child: Row(
                         children: [
                           Expanded(child: _buildField(ctrl, '${gu ? 'વિકલ્પ' : 'Option'} ${idx + 1}', Icons.list_rounded, cs)),
                           if (_pollOptionCtrls.length > 2)
                             IconButton(
                               icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                               onPressed: () {
                                 setDialogState(() => _pollOptionCtrls.removeAt(idx));
                               },
                             ),
                         ],
                       ),
                     );
                   }).toList(),
                   if (_pollOptionCtrls.length < 5)
                     TextButton.icon(
                       onPressed: () {
                         setDialogState(() => _pollOptionCtrls.add(TextEditingController()));
                       },
                       icon: const Icon(Icons.add_circle_outline),
                       label: Text(gu ? 'વિકલ્પ ઉમેરો' : 'Add Option'),
                     ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(gu ? 'બહુવિધ પસંદગી (MSQ)' : 'Multiple Selections'),
                      subtitle: Text(gu ? 'વપરાશકર્તા એકથી વધુ વિકલ્પો પસંદ કરી શકશે' : 'Users can pick more than one option'),
                      value: _isMultipleChoice,
                      activeThumbColor: cs.primary,
                      onChanged: (v) {
                        setDialogState(() => _isMultipleChoice = v);
                        setState(() => _isMultipleChoice = v);
                      },
                    ),
                 ],
                 SwitchListTile(
                   contentPadding: EdgeInsets.zero,
                   title: Text(gu ? 'ટેક્સ્ટ ફીડબેક ઉમેરો' : 'Enable Text Feedback'),
                   subtitle: Text(gu ? 'વપરાશકર્તા કંઈક લખી શકશે' : 'Users can type a response'),
                   value: _hasTextInput,
                   activeThumbColor: cs.primary,
                   onChanged: (v) {
                     setDialogState(() => _hasTextInput = v);
                     setState(() => _hasTextInput = v);
                   },
                 ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final success = await _saveAnnouncement(docId: docId);
                      if (success && mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      gu ? 'સાચવો' : 'Save Announcement', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
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
    {int minLines = 1, String? Function(String?)? validator}
  ) {
    return TextFormField(
      controller: ctrl,
      minLines: minLines,
      maxLines: null,
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

  Future<void> _deleteAnnouncement(String id) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement?'),
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
      await FirebaseFirestore.instance.collection('announcements').doc(id).delete();
    }
  }
}
