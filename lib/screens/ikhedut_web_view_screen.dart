import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class IkhedutWebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const IkhedutWebViewScreen({super.key, required this.title, required this.url});

  @override
  State<IkhedutWebViewScreen> createState() => _IkhedutWebViewScreenState();
}

class _IkhedutWebViewScreenState extends State<IkhedutWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'IkhedutChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'ready' && mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            // We DO NOT set _isLoading = false here anymore!
            // We wait for the Javascript to clean the page and send the 'ready' message.
            
            // Smart CSS Injection: Hide everything above the "Schemes" (યોજનાઓ) section!
            _controller.runJavaScript('''
              try {
                // 0. Force Mobile Viewport! Many desktop sites forget this.
                let meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                  meta = document.createElement('meta');
                  meta.name = 'viewport';
                  document.head.appendChild(meta);
                }
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

                // 1. Inject a GLOBAL stylesheet so React can't delete our display: none styles
                const style = document.createElement('style');
                style.type = 'text/css';
                style.innerHTML = `
                  header, footer, nav { display: none !important; }
                  .hidden-by-flutter { display: none !important; }
                  
                  /* Force mobile responsiveness */
                  body, html { 
                    max-width: 100vw !important; 
                    overflow-x: hidden !important; 
                  }
                  
                  /* Make scheme cards stack nicely if they use flex/grid */
                  .row { display: flex !important; flex-direction: column !important; }
                  .col, [class*="col-"] { width: 100% !important; max-width: 100% !important; padding: 10px !important; }
                `;
                document.head.appendChild(style);
                
                // 2. Use a continuous interval to re-hide things if React re-draws them
                setInterval(function() {
                  
                  // Safe and foolproof way to hide everything BEFORE the "યોજનાઓ" (Schemes) section
                  const allElements = document.querySelectorAll('h1, h2, h3, h4, h5, span, div, b, strong, p');
                  let yojanaNode = null;
                  for (let i = 0; i < allElements.length; i++) {
                    if (allElements[i].children.length === 0 && allElements[i].textContent.trim() === 'યોજનાઓ') {
                      yojanaNode = allElements[i];
                      break;
                    }
                  }
                  
                  if (yojanaNode) {
                    // Find the ancestor that is a direct child of body or #root
                    let ancestor = yojanaNode;
                    while (ancestor.parentElement && 
                           ancestor.parentElement.tagName !== 'BODY' && 
                           ancestor.parentElement.tagName !== 'HTML' && 
                           ancestor.parentElement.id !== 'root' && 
                           ancestor.parentElement.id !== 'app' &&
                           ancestor.parentElement.tagName !== 'MAIN') {
                      ancestor = ancestor.parentElement;
                    }
                    
                    // Now ancestor is the main top-level section containing 'યોજનાઓ'.
                    // Hide all its previous siblings (Hero image, About us, etc.)!
                    let sibling = ancestor.previousElementSibling;
                    while (sibling) {
                      if (!sibling.classList.contains('hidden-by-flutter')) {
                        sibling.classList.add('hidden-by-flutter');
                      }
                      sibling = sibling.previousElementSibling;
                    }
                  }
                  
                  // Ensure header/footer are hidden just in case the stylesheet was bypassed
                  document.querySelectorAll('header, footer, nav').forEach(e => e.classList.add('hidden-by-flutter'));
                
                // 3. Aggressively close or DESTROY the popup modal!
                let popupCheckCount = 0;
                let isReadySent = false;
                
                const popupInterval = setInterval(function() {
                  
                  // Method A: Dispatch ESC key (closes many modern modals automatically)
                  document.dispatchEvent(new KeyboardEvent('keydown', { 'key': 'Escape' }));
                  document.dispatchEvent(new KeyboardEvent('keyup', { 'key': 'Escape' }));

                  // Method B: Find standard close buttons, ARIA labels, or 'X' text
                  const closeButtons = document.querySelectorAll('.modal .close, .modal-header button, button.btn-close, [data-dismiss="modal"], button[aria-label="Close"], button[title="Close"], button[aria-label="બંધ કરો"]');
                  let clicked = false;
                  
                  for (let i = 0; i < closeButtons.length; i++) {
                    closeButtons[i].click();
                    clicked = true;
                  }
                  
                  const allButtons = document.querySelectorAll('button');
                  for (let i = 0; i < allButtons.length; i++) {
                    const txt = allButtons[i].textContent.trim();
                    // Check for the "×" symbol or just the letter X
                    if (txt === '×' || txt === 'X' || txt === 'x' || txt.includes('બંધ કરો')) {
                      allButtons[i].click();
                      clicked = true;
                    }
                  }
                  
                  // Method C: BRUTE FORCE CSS DESTRUCTION (If clicking fails, just hide the damn thing)
                  // Method C: BRUTE FORCE CSS DESTRUCTION (If clicking fails, just hide the damn thing)
                  document.querySelectorAll('.modal, .modal-backdrop, [role="dialog"]').forEach(e => {
                    e.style.setProperty('display', 'none', 'important');
                  });
                  // Re-enable scrolling on the body just in case the modal locked it
                  document.body.style.setProperty('overflow', 'auto', 'important');
                  document.body.classList.remove('modal-open');
                  
                  // Stop checking after 5 seconds
                  if (clicked || popupCheckCount > 10) {
                    clearInterval(popupInterval);
                  }
                  
                  // Tell Flutter to drop the Loading Screen after the first 2 intervals (1 second total)
                  // This gives React enough time to mount, and our script enough time to hide the messy parts
                  if (popupCheckCount >= 2 && !isReadySent) {
                    try {
                      IkhedutChannel.postMessage('ready');
                      isReadySent = true;
                    } catch(e) {}
                  }
                  
                  popupCheckCount++;
                }, 500);

                // Close the outer continuous interval that hides sections (runs forever every 500ms)
                }, 500);

              } catch(e) {}
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: cs.surfaceContainerLowest,
        foregroundColor: cs.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
              ),
            ),
        ],
      ),
    );
  }
}
