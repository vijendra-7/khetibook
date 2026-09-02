import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
class FullScreenImageScreen extends StatefulWidget {
  final String imageUrl;

  const FullScreenImageScreen({super.key, required this.imageUrl});

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen> {
  bool _isSharing = false;

  Future<void> _shareImage() async {
    setState(() {
      _isSharing = true;
    });
    try {
      final cachedFile = await DefaultCacheManager().getSingleFile(widget.imageUrl);
      final documentDirectory = await getTemporaryDirectory();
      
      // Use a unique name to avoid caching issues when sharing multiple times
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${documentDirectory.path}/market_banner_$timestamp.png');
      await cachedFile.copy(file.path);

      await Share.shareXFiles(
        [XFile(file.path)], 
        text: '''🚜 ખેતીનો હિસાબ હવે સરળ – ખેતીબુક (KhetiBook) 
જૂની ડાયરી ભૂલો, હવે બધુ ડિજિટલ 👇
✅ લાઈવ બજાર ભાવ (ડીસા, પાલનપુર, રાજકોટ તથા અન્ય માર્કેટ)
✅ ખર્ચ-આવકનો સંપૂર્ણ હિસાબ
✅ મજૂરી અને લણણી મેનેજમેન્ટ
✅ ગુજરાતી + Offline ઉપયોગ
🌾 આજે જ ડાઉનલોડ કરો અને ખેતીને સ્માર્ટ બનાવો! 🚀
👉 https://play.google.com/store/apps/details?id=com.farmer.farmer_accounting''',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.select<SettingsProvider, bool>((p) => p.isGujarati);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white, size: 50),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareImage,
                icon: _isSharing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.share),
                label: Text(gu ? 'ઇમેજ શેર કરો' : 'Share Image', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
