import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/settings_provider.dart';

class AdminMarketBannerScreen extends StatefulWidget {
  const AdminMarketBannerScreen({super.key});

  @override
  State<AdminMarketBannerScreen> createState() => _AdminMarketBannerScreenState();
}

class _AdminMarketBannerScreenState extends State<AdminMarketBannerScreen> {
  static const List<String> _marketNames = [
    'Deesa', 'Palanpur', 'Ahmedabad', 'Junagadh', 'Rajkot',
    'Dhanera', 'Amirgadh', 'Surat', 'Siddhpur', 'Radhanpur',
    'Himatnagar', 'Unjha', 'Mahuva', 'Gondal', 'Botad',
    'Amreli', 'Babra', 'Visnagar', 'Agra Potato', 'Bagasara', 'Jasdan', 'Jetpur', 'Jamnagar', 'Rajula', 'Patan', 'Savarkundla',
  ];

  String? _selectedMarket;
  final _imageUrlController = TextEditingController();
  bool _isVisible = true;
  bool _saving = false;
  String? _previewUrl;

  @override
  void dispose() {
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadBannerForMarket(String market) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('market_banners')
          .doc(market)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _imageUrlController.text = data['imageUrl'] ?? '';
          _isVisible = data['isVisible'] ?? true;
          _previewUrl = _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null;
        });
      } else if (mounted) {
        setState(() {
          _imageUrlController.clear();
          _isVisible = true;
          _previewUrl = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading banner: $e');
    }
  }

  Future<void> _saveBanner() async {
    if (_selectedMarket == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('market_banners')
          .doc(_selectedMarket)
          .set({
        'marketName': _selectedMarket,
        'imageUrl': _imageUrlController.text.trim(),
        'isVisible': _isVisible,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner saved successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
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

  Future<void> _deleteBanner() async {
    if (_selectedMarket == null) return;
    final cs = Theme.of(context).colorScheme;
    final gu = context.read<SettingsProvider>().isGujarati;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gu ? 'બેનર દૂર કરો?' : 'Remove Banner?'),
        content: Text(
          gu
              ? 'શું તમે $_selectedMarket માટેનો બેનર કાઢી નાખવા માંગો છો?'
              : 'Remove the banner for $_selectedMarket?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(gu ? 'રદ' : 'Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(gu ? 'દૂર કરો' : 'Remove', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('market_banners').doc(_selectedMarket).delete();
      if (mounted) {
        setState(() {
          _imageUrlController.clear();
          _isVisible = true;
          _previewUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner removed.'), behavior: SnackBarBehavior.floating),
        );
      }
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
          gu ? 'માર્કેટ બેનર' : 'Market Banners',
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
            // ── Header Info ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_rounded, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gu
                          ? 'દરેક માર્કેટ માટે ઇમેજ URL સેટ કરો. ભાવ સૂચિ ઉપર આ ઇમેજ દેખાશે.'
                          : 'Set an image URL for each market. It will appear above the price list for that market.',
                      style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Market Selector ──
            _buildSectionTitle(gu ? 'માર્કેટ પસંદ કરો' : 'Select Market', Icons.store_rounded, cs),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMarket,
                  isExpanded: true,
                  hint: Text(gu ? 'માર્કેટ પસંદ કરો' : 'Choose a market'),
                  items: _marketNames
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedMarket = val;
                      _imageUrlController.clear();
                      _previewUrl = null;
                      _isVisible = true;
                    });
                    if (val != null) _loadBannerForMarket(val);
                  },
                ),
              ),
            ),

            if (_selectedMarket != null) ...[
              const SizedBox(height: 28),

              // ── Image URL Field ──
              _buildSectionTitle(gu ? 'ઇમેજ URL' : 'Image URL', Icons.link_rounded, cs),
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: gu ? 'ઇમેજ URL દાખલ કરો' : 'Enter image URL',
                  hintText: 'https://example.com/market-image.jpg',
                  prefixIcon: const Icon(Icons.image_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.preview_rounded),
                    tooltip: gu ? 'પ્રિવ્યૂ' : 'Preview',
                    onPressed: () {
                      setState(() {
                        _previewUrl = _imageUrlController.text.trim().isNotEmpty
                            ? _imageUrlController.text.trim()
                            : null;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.url,
                onChanged: (_) {
                  // Clear preview when URL changes
                  if (_previewUrl != null) setState(() => _previewUrl = null);
                },
              ),
              const SizedBox(height: 16),

              // ── Visibility Toggle ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  title: Text(
                    gu ? 'ઇમેજ દેખાડો' : 'Show Image',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    gu
                        ? 'ઓફ કરવા પર ઇમેજ છુપાઈ જશે'
                        : 'Turn off to hide the image from users',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isVisible
                          ? cs.primary.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: _isVisible ? cs.primary : Colors.grey,
                      size: 20,
                    ),
                  ),
                  value: _isVisible,
                  onChanged: (val) => setState(() => _isVisible = val),
                ),
              ),
              const SizedBox(height: 24),

              // ── Image Preview ──
              if (_previewUrl != null) ...[
                _buildSectionTitle(gu ? 'પ્રિવ્યૂ' : 'Preview', Icons.photo_outlined, cs),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: _previewUrl!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(
                      height: 180,
                      color: cs.surfaceContainerHigh,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (ctx, url, err) => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, color: cs.onErrorContainer, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            gu ? 'ઇમેજ લોડ થઈ શકી નહી' : 'Could not load image',
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Action Buttons ──
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveBanner,
                        icon: _saving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          gu ? 'સાચવો' : 'Save Banner',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _deleteBanner,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      label: Text(
                        gu ? 'ડિલીટ' : 'Delete',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            // ── All Configured Banners ──
            _buildSectionTitle(gu ? 'બધા સક્ષમ બેનર' : 'All Configured Banners', Icons.list_alt_rounded, cs),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('market_banners')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        gu ? 'કોઈ બેનર ઉમેરેલ નથી' : 'No banners configured yet',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final market = data['marketName'] ?? docs[i].id;
                    final isVis = data['isVisible'] ?? false;
                    final url = data['imageUrl'] ?? '';

                    return Material(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() => _selectedMarket = market);
                          _loadBannerForMarket(market);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: url.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: url,
                                        width: 56,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 56,
                                          height: 40,
                                          color: cs.errorContainer,
                                          child: Icon(Icons.broken_image_rounded, color: cs.onErrorContainer, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 56,
                                        height: 40,
                                        color: cs.surfaceContainerHighest,
                                        child: Icon(Icons.image_not_supported_rounded, color: cs.onSurfaceVariant, size: 20),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      market,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      url.isNotEmpty ? url : (gu ? 'URL નથી' : 'No URL'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              // Visibility badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isVis
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isVis ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      size: 14,
                                      color: isVis ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVis ? (gu ? 'ચાલુ' : 'ON') : (gu ? 'બંધ' : 'OFF'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isVis ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 18),
                            ],
                          ),
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

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
