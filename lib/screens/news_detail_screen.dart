import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/news.dart';
import 'package:share_plus/share_plus.dart';

class NewsDetailScreen extends StatefulWidget {
  final News news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            final adDomains = [
              'doubleclick.net', 'googleadservices.com', 'googlesyndication.com', 
              'adsystem.com', 'adnxs.com', 'taboola.com', 'outbrain.com', 
              'criteo.com', 'pubmatic.com', 'rubiconproject.com', 'amazon-adsystem.com'
            ];
            
            for (final domain in adDomains) {
              if (url.contains(domain)) {
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            final String adBlockJs = '''
              var style = document.createElement('style');
              style.innerHTML = '.adsbygoogle, .ad-container, .ad-wrapper, [id^="div-gpt-ad"], [class*="adBox"], [id*="google_ads"], [class*="google_ads"], .outbrain, .taboola, .ad-banner, .advertisement { display: none !important; }';
              document.head.appendChild(style);
            ''';
            _controller.runJavaScript(adBlockJs);
          },
          onWebResourceError: (WebResourceError error) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.news.link));
  }

  void _shareNews() {
    Share.share(
      '${widget.news.title}\n\nRead more at: ${widget.news.link}\n\nShared via Farmer Accounting App',
      subject: widget.news.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.news.source?.toUpperCase() ?? 'NEWS ARTICLE',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            Text(
              widget.news.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: _shareNews,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: cs.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
