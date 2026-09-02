import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/crop_image_widget.dart';
import '../../utils/color_helper.dart';

class AdminGlobalOptionsScreen extends StatefulWidget {
  const AdminGlobalOptionsScreen({super.key});

  @override
  State<AdminGlobalOptionsScreen> createState() => _AdminGlobalOptionsScreenState();
}

class _AdminGlobalOptionsScreenState extends State<AdminGlobalOptionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelEnController = TextEditingController();
  final _labelGuController = TextEditingController();
  final _imageUrlController = TextEditingController();
  double _imageScale = 1.0;
  double _imageOffsetX = 0.0;
  double _imageOffsetY = 0.0;
  String? _selectedColor;

  final List<Map<String, dynamic>> _agriPalette = [
    {'name': 'Moss', 'color': 0xFF388E3C},
    {'name': 'Forest', 'color': 0xFF1B5E20},
    {'name': 'Emerald', 'color': 0xFF00C853},
    {'name': 'Teal', 'color': 0xFF00796B},
    {'name': 'Terracotta', 'color': 0xFFBF360C},
    {'name': 'Autumn', 'color': 0xFFD84315},
    {'name': 'Harvest', 'color': 0xFFFBC02D},
    {'name': 'Mustard', 'color': 0xFFF9A825},
    {'name': 'Umber', 'color': 0xFF3E2723},
    {'name': 'Slate', 'color': 0xFF455A64},
    {'name': 'Indigo', 'color': 0xFF303F9F},
    {'name': 'Mint', 'color': 0xFFC8E6C9},
    {'name': 'Lemon', 'color': 0xFFFFF9C4},
    {'name': 'Lavender', 'color': 0xFFE1BEE7},
    {'name': 'Peach', 'color': 0xFFFFE0B2},
    {'name': 'Cloud', 'color': 0xFFF5F5F5},
    {'name': 'Sky', 'color': 0xFFE1F5FE},
  ];
  String _selectedType = 'crop';
  bool _isEditing = false;
  String? _editingId;

  @override
  void dispose() {
    _labelEnController.dispose();
    _labelGuController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _addOption() async {
    if (!_formKey.currentState!.validate()) return;

    final labelEn = _labelEnController.text.trim();
    final labelGu = _labelGuController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    final value = labelEn.toLowerCase().replaceAll(' ', '_');
    final data = {
      'type': _selectedType,
      'labelEn': labelEn,
      'labelGu': labelGu,
      'value': value,
      if (_selectedType == 'crop') 'imageUrl': imageUrl,
      if (_selectedType == 'crop') 'imageScale': _imageScale,
      if (_selectedType == 'crop') 'imageOffsetX': _imageOffsetX,
      if (_selectedType == 'crop') 'imageOffsetY': _imageOffsetY,
      if (_selectedType == 'crop') 'backgroundColor': _selectedColor,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!_isEditing) 'addedAt': FieldValue.serverTimestamp(),
      'addedBy': 'thevijendrachaudhary@gmail.com',
    };

    try {
      if (_isEditing && _editingId != null) {
        await FirebaseFirestore.instance.collection('global_metadata').doc(_editingId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('global_metadata').add(data);
      }

      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Option updated successfully' : 'Option added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _populateForEdit(String id, Map<String, dynamic> data) {
    setState(() {
      _isEditing = true;
      _editingId = id;
      _selectedType = data['type'] ?? 'crop';
      _labelEnController.text = data['labelEn'] ?? '';
      _labelGuController.text = data['labelGu'] ?? '';
      _imageUrlController.text = data['imageUrl'] ?? '';
      _imageScale = (data['imageScale'] as num?)?.toDouble() ?? 1.0;
      _imageOffsetX = (data['imageOffsetX'] as num?)?.toDouble() ?? 0.0;
      _imageOffsetY = (data['imageOffsetY'] as num?)?.toDouble() ?? 0.0;
      _imageOffsetY = (data['imageOffsetY'] as num?)?.toDouble() ?? 0.0;
      final rawColor = data['backgroundColor']?.toString();
      if (rawColor != null) {
        if (rawColor.startsWith('0x') || rawColor.startsWith('#')) {
          _selectedColor = rawColor.toUpperCase();
        } else {
          try {
            final val = int.parse(rawColor);
            _selectedColor = '0x${val.toRadixString(16).padLeft(8, '0').toUpperCase()}';
          } catch (_) {
            _selectedColor = rawColor.toUpperCase();
          }
        }
      } else {
        _selectedColor = null;
      }
    });
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _editingId = null;
      _labelEnController.clear();
      _labelGuController.clear();
      _imageUrlController.clear();
      _imageScale = 1.0;
      _imageOffsetX = 0.0;
      _imageOffsetY = 0.0;
      _selectedColor = null;
      _selectedType = 'crop';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gu = context.watch<SettingsProvider>().isGujarati;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          gu ? 'ગ્લોબલ વિકલ્પો' : 'Global Options',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildAddForm(cs, gu),
          const SizedBox(height: 32),
          Text(
            gu ? 'વર્તમાન વિકલ્પો' : 'Current Options',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          const SizedBox(height: 16),
          _buildOptionsList(cs, gu),
        ],
      ),
    );
  }

  Widget _buildAddForm(ColorScheme cs, bool gu) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_selectedType == 'crop') ...[
              _buildLivePreview(cs, gu),
              const SizedBox(height: 24),
            ],
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: _fieldDecoration(gu ? 'શ્રેણી' : 'Category', Icons.category_rounded, cs),
              items: [
                DropdownMenuItem(value: 'crop', child: Text(gu ? 'પાક' : 'Crop')),
                DropdownMenuItem(value: 'investment_type', child: Text(gu ? 'ખર્ચનો પ્રકાર' : 'Investment Type')),
              ],
              onChanged: (val) {
                setState(() => _selectedType = val!);
              },
            ),
            const SizedBox(height: 16),
            _buildField(_labelEnController, 'Label (English)', Icons.title_rounded, cs),
            const SizedBox(height: 16),
            _buildField(_labelGuController, 'Label (ગુજરાતી)', Icons.translate_rounded, cs),
            if (_selectedType == 'crop') ...[
              const SizedBox(height: 16),
              _buildField(_imageUrlController, 'Image URL', Icons.image_rounded, cs),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.zoom_in_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 12),
                  Text(gu ? 'ઇમેજ સ્કેલ: ${_imageScale.toStringAsFixed(1)}' : 'Image Scale: ${_imageScale.toStringAsFixed(1)}'),
                  Expanded(
                    child: Slider(
                      value: _imageScale,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      onChanged: (val) => setState(() => _imageScale = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Transform.rotate(
                    angle: 1.5708,
                    child: Icon(Icons.unfold_more_rounded, size: 20, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(gu ? 'હોરીઝોન્ટલ ઓફસેટ: ${_imageOffsetX.toStringAsFixed(1)}' : 'Horizontal Offset: ${_imageOffsetX.toStringAsFixed(1)}'),
                  Expanded(
                    child: Slider(
                      value: _imageOffsetX,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (val) => setState(() => _imageOffsetX = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.unfold_more_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 12),
                  Text(gu ? 'વર્તિકલ ઓફસેટ: ${_imageOffsetY.toStringAsFixed(1)}' : 'Vertical Offset: ${_imageOffsetY.toStringAsFixed(1)}'),
                  Expanded(
                    child: Slider(
                      value: _imageOffsetY,
                      min: -50.0,
                      max: 50.0,
                      divisions: 100,
                      onChanged: (val) => setState(() => _imageOffsetY = val),
                    ),
                  ),
                ],
              ),
            ],
            if (_selectedType == 'crop') ...[
              const SizedBox(height: 24),
              _buildColorSelector(cs, gu),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _addOption,
                icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                label: Text(
                  _isEditing ? (gu ? 'અપડેટ કરો' : 'Update Option') : (gu ? 'વિકલ્પ ઉમેરો' : 'Add Option'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditing ? Colors.orange : cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _clearForm,
                child: Text(gu ? 'રદ કરો' : 'Cancel Edit', style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, ColorScheme cs) {
    return TextFormField(
      controller: ctrl,
      decoration: _fieldDecoration(label, icon, cs),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon, ColorScheme cs) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildOptionsList(ColorScheme cs, bool gu) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('global_metadata').orderBy('addedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text(gu ? 'કોઈ વિકલ્પો નથી' : 'No global options yet'));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final isCrop = data['type'] == 'crop';

            return Material(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (data['backgroundColor'] != null 
                        ? ColorHelper.parseHex(data['backgroundColor'], cs.surfaceContainerHigh)
                        : (isCrop ? Colors.green : cs.primary)).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCrop
                        ? ClipOval(
                            child: CropImageWidget(
                              imageUrl: data['imageUrl'],
                              scale: (data['imageScale'] as num?)?.toDouble() ?? 1.0,
                              imageOffsetX: (data['imageOffsetX'] as num?)?.toDouble() ?? 0.0,
                              imageOffsetY: (data['imageOffsetY'] as num?)?.toDouble() ?? 0.0,
                              size: 28,
                              placeholder: Icon(Icons.eco_rounded, 
                                color: data['backgroundColor'] != null 
                                  ? ColorHelper.parseHex(data['backgroundColor'], cs.surfaceContainerHigh)
                                  : Colors.green, 
                                size: 28),
                            ),
                          )
                        : Icon(
                            Icons.settings_rounded,
                            color: cs.primary,
                            size: 28,
                          ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(data['labelEn'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(4)),
                      child: Text(data['type'] ?? '', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['labelGu'] ?? '', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    Text('Value: ${data['value'] ?? ''}', style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.5), fontSize: 10, fontFamily: 'monospace')),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _populateForEdit(id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _deleteOption(id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteOption(String id) async {
    final cs = Theme.of(context).colorScheme;
    final gu = context.read<SettingsProvider>().isGujarati;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(gu ? 'વિકલ્પ દૂર કરો?' : 'Delete Option?'),
        content: Text(gu 
          ? 'શું તમે ખરેખર આ વિકલ્પને દૂર કરવા માંગો છો? આ બધા વપરાશકર્તાઓ માટે દૂર થશે.' 
          : 'Are you sure you want to remove this option? It will be removed for all users.'),
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
      await FirebaseFirestore.instance.collection('global_metadata').doc(id).delete();
    }
  }

  Widget _buildColorSelector(ColorScheme cs, bool gu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette_rounded, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Text(gu ? 'કાર્ડનો રંગ પસંદ કરો' : 'Select Card Color', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_selectedColor != null)
              TextButton(
                onPressed: () => setState(() => _selectedColor = null),
                child: Text(gu ? 'દૂર કરો' : 'Clear', style: TextStyle(color: cs.error, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _agriPalette.length,
          itemBuilder: (context, i) {
            final item = _agriPalette[i];
            final colorHex = item['color'].toRadixString(16).padLeft(8, '0').toUpperCase();
            final currentSelectedHex = _selectedColor?.replaceAll('0x', '').toUpperCase().padLeft(8, '0');
            final isSelected = currentSelectedHex == colorHex;
            
            return GestureDetector(
              onTap: () {
                final hex = '0x${item['color'].toRadixString(16).padLeft(8, '0').toUpperCase()}';
                setState(() => _selectedColor = hex);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Color(item['color']),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? cs.primary : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(color: Color(item['color']).withOpacity(0.4), blurRadius: 8, spreadRadius: 1),
                  ],
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLivePreview(ColorScheme cs, bool gu) {
    final bgColor = _selectedColor != null ? ColorHelper.parseHex(_selectedColor!, cs.surfaceContainerHigh) : cs.surfaceContainerHigh;
    final isLight = _selectedColor != null ? ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light : false;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Column(
      children: [
        Text(
          gu ? 'લાઇવ પ્રિવ્યૂ' : 'Live Preview',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary),
        ),
        const SizedBox(height: 12),
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: bgColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Center(
                    child: CropImageWidget(
                      imageUrl: _imageUrlController.text.trim(),
                      scale: _imageScale,
                      imageOffsetX: _imageOffsetX,
                      imageOffsetY: _imageOffsetY,
                      size: 56,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _labelEnController.text.isEmpty ? 'Crop Name' : _labelEnController.text,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
