import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/settings_provider.dart';
import '../../providers/system_config_provider.dart';

class AdminSystemControlsScreen extends StatefulWidget {
  const AdminSystemControlsScreen({super.key});

  @override
  State<AdminSystemControlsScreen> createState() => _AdminSystemControlsScreenState();
}

class _AdminSystemControlsScreenState extends State<AdminSystemControlsScreen> {
  final _minVersionCtrl = TextEditingController();
  final _updateUrlCtrl = TextEditingController();
  final _updateImageUrlCtrl = TextEditingController();
  final _newsHeroYoutubeUrlCtrl = TextEditingController();
  String _newsHeroMode = 'news';
  bool _maintenance = false;
  bool _checkOfficialUpdate = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<SystemConfigProvider>();
    _minVersionCtrl.text = config.minVersion;
    _updateUrlCtrl.text = config.updateUrl;
    _updateImageUrlCtrl.text = config.updateImageUrl;
    _newsHeroYoutubeUrlCtrl.text = config.newsHeroYoutubeUrl;
    _newsHeroMode = config.newsHeroMode;
    _maintenance = config.isMaintenance;
    _checkOfficialUpdate = config.checkOfficialUpdate;
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('system_controls').doc('app_config').set({
        'minVersion': _minVersionCtrl.text.trim(),
        'updateUrl': _updateUrlCtrl.text.trim(),
        'updateImageUrl': _updateImageUrlCtrl.text.trim(),
        'isMaintenance': _maintenance,
        'checkOfficialUpdate': _checkOfficialUpdate,
        'newsHeroMode': _newsHeroMode,
        'newsHeroYoutubeUrl': _newsHeroYoutubeUrlCtrl.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
          gu ? 'સિસ્ટમ કંટ્રોલ' : 'System Controls',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(gu ? 'મેન્ટેનન્સ મોડ' : 'Maintenance Mode', Icons.engineering_rounded, cs, gu),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SwitchListTile(
                title: Text(gu ? 'મેન્ટેનન્સ સક્રિય કરો' : 'Enable Maintenance', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text(
                  gu ? 'વપરાશકર્તાઓ એપ વાપરી શકશે નહીં' : 'Users will be blocked from using the app',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _maintenance ? Colors.orange.withOpacity(0.1) : cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_maintenance ? Icons.warning_rounded : Icons.check_circle_rounded, color: _maintenance ? Colors.orange : cs.primary, size: 20),
                ),
                value: _maintenance,
                onChanged: (val) => setState(() => _maintenance = val),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SwitchListTile(
                title: Text(gu ? 'પ્લે સ્ટોર અપડેટ ચેક' : 'Play Store Update Check', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text(
                  gu ? 'ગૂગલ પ્લે સ્ટોર પરથી ઓફિશિયલ અપડેટ નોટિફિકેશન બતાવશે' : 'Shows official update dialog from Google Play Store',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _checkOfficialUpdate ? cs.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.shop_rounded, color: _checkOfficialUpdate ? cs.primary : Colors.grey, size: 20),
                ),
                value: _checkOfficialUpdate,
                onChanged: (val) => setState(() => _checkOfficialUpdate = val),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle(gu ? 'ફોર્સ અપડેટ' : 'Force Update', Icons.system_update_rounded, cs, gu),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildField(_minVersionCtrl, 'Minimum App Version', Icons.info_outline_rounded, cs, hint: 'e.g. 1.0.5'),
                  const SizedBox(height: 16),
                  _buildField(_updateUrlCtrl, 'Update Link', Icons.link_rounded, cs, hint: 'Play Store URL'),
                  const SizedBox(height: 16),
                  _buildField(_updateImageUrlCtrl, 'Update Guide Image URL', Icons.image_rounded, cs, hint: 'Optional image to show on update screen'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle(gu ? 'સમાચાર હેડલાઇન કંટ્રોલ' : 'News Hero Section', Icons.newspaper_rounded, cs, gu),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gu ? 'મોડ પસંદ કરો:' : 'Select Mode:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'news', label: Text('News Carousel'), icon: Icon(Icons.view_carousel_rounded)),
                      ButtonSegment(value: 'video', label: Text('YouTube Video'), icon: Icon(Icons.play_circle_fill_rounded)),
                      ButtonSegment(value: 'hidden', label: Text('Hidden'), icon: Icon(Icons.visibility_off_rounded)),
                    ],
                    selected: {_newsHeroMode},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _newsHeroMode = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) return cs.primary;
                          return cs.surface;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) return cs.onPrimary;
                          return cs.onSurface;
                        },
                      ),
                    ),
                  ),
                  if (_newsHeroMode == 'video') ...[
                    const SizedBox(height: 24),
                    _buildField(_newsHeroYoutubeUrlCtrl, 'YouTube Video URL', Icons.ondemand_video_rounded, cs, hint: 'e.g. https://youtu.be/...'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveConfig,
                icon: _saving 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary)) 
                    : const Icon(Icons.save_rounded),
                label: Text(
                  gu ? 'સેવ કરો' : 'Save System Configuration', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, ColorScheme cs, {String? hint}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme cs, bool gu) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
