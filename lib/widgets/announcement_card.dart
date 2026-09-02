import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_init.dart';

class AnnouncementCard extends StatefulWidget {
  final bool gu;

  const AnnouncementCard({
    super.key,
    required this.gu,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  final _textController = TextEditingController();
  final Set<String> _selectedOptions = {};
  bool _isSubmitting = false;

  /// IDs of announcements the user has already responded to.
  /// Persisted in SharedPreferences so the card stays hidden across restarts.
  Set<String> _dismissedIds = {};
  static const _prefsKey = 'dismissed_announcements';

  @override
  void initState() {
    super.initState();
    _loadDismissed();
    // Rebuild when text changes so the submit button enables/disables live
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  // ── Persistence helpers ────────────────────────────────────────────────────

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) setState(() => _dismissedIds = list.toSet());
  }

  Future<void> _saveDismissed(String announcementId) async {
    _dismissedIds.add(announcementId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _dismissedIds.toList());
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submitResponse(String announcementId,
      {List<String>? instantSelections}) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final selections = instantSelections ?? _selectedOptions.toList();

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('announcement_responses')
          .add({
        'announcementId': announcementId,
        'userId': auth.user!.uid,
        'userName': auth.user!.displayName ?? 'Anonymous',
        'userEmail': auth.user!.email ?? 'No Email',
        'pollSelections': selections,
        'textResponse': _textController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _textController.clear();
        setState(() {
          _selectedOptions.clear();
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.gu
                ? 'આભાર! તમારો પ્રતિસાદ સાચવવામાં આવ્યો છે.'
                : 'Thank you! Your feedback has been saved.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Dismiss the card — persisted so it never reappears after submit
        await _saveDismissed(announcementId);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<void>(
      future: FirebaseInit.initialize(),
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink(); // Hide silently while Firebase boots (500ms)
        }
        
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('announcements')
              .snapshots(),
          builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allDocs = snapshot.data!.docs;

        // Filter: active + correct language + not already dismissed
        final activeDocs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['isActive'] != true) return false;
          if (_dismissedIds.contains(doc.id)) return false;
          final targetLang = d['targetLanguage'] ?? 'both';
          if (targetLang == 'both') return true;
          if (widget.gu && targetLang == 'gu') return true;
          if (!widget.gu && targetLang == 'en') return true;
          return false;
        }).toList();

        // Sort by priority desc
        activeDocs.sort((a, b) {
          final pa = (a.data() as Map<String, dynamic>)['priority'] ?? 0;
          final pb = (b.data() as Map<String, dynamic>)['priority'] ?? 0;
          return pb.compareTo(pa);
        });

        // AnimatedSwitcher allows fade+size collapse when the card disappears
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchOutCurve: Curves.easeIn,
          switchInCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: child,
            ),
          ),
          child: activeDocs.isEmpty
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : _buildCard(
                  context,
                  cs,
                  activeDocs.first,
                ),
        );
      },
    );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    ColorScheme cs,
    QueryDocumentSnapshot doc,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const lightBg = Color(0xFFC8E6C9);
    const darkText = Color(0xFF1B5E20); // used for borders, icons, accents
    // Text colour: black in light mode for readability, onPrimaryContainer in dark
    final textColor = isDark ? cs.onPrimaryContainer : Colors.black;

    final data = doc.data() as Map<String, dynamic>;
    final docId = doc.id;
    final title = widget.gu ? data['titleGu'] : data['titleEn'];
    final message = widget.gu ? data['messageGu'] : data['messageEn'];
    final url = data['actionUrl'] as String?;
    final hasPoll = data['hasPoll'] ?? false;
    final hasTextInput = data['hasTextInput'] ?? false;
    final isMSQ = data['isMultipleChoice'] ?? false;
    final pollOptions = (data['pollOptions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    // Text submit is only allowed when field is non-empty
    final hasText = _textController.text.trim().isNotEmpty;
    final canSubmitText = hasText && !_isSubmitting;

    return Container(
      key: ValueKey(docId),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? cs.primaryContainer : lightBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? cs.primary.withAlpha(80) : const Color(0xFF81C784),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(isDark ? 40 : 15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (isDark ? cs.onPrimaryContainer : darkText)
                                  .withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.campaign_rounded,
                              color: textColor,
                              size: 18,
                            ),
                          ),
                        ),
                        TextSpan(
                          text: title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (title != null && title.isNotEmpty && message != null && message.isNotEmpty)
                  const SizedBox(height: 8),
                if (message != null && message.isNotEmpty)
                  Text(
                    message,
                    style: TextStyle(
                      color: isDark
                          ? cs.onPrimaryContainer.withAlpha(180)
                          : Colors.black,
                      fontSize: 13,
                    ),
                  ),
                if (url != null && url.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Center(child: _buildActionLink(url, data, isDark, darkText, cs)),
                ],
              ],
            ),
          ),

          // ── Interactive: Poll + Text Input ───────────────────────────────
          if (hasPoll || hasTextInput)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 16),

                  // Poll options
                  if (hasPoll) ...[
                    ...pollOptions.map((opt) {
                      final isSelected = _selectedOptions.contains(opt);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            if (isMSQ) {
                              setState(() {
                                if (isSelected) {
                                  _selectedOptions.remove(opt);
                                } else {
                                  _selectedOptions.add(opt);
                                }
                              });
                            } else {
                              // Single-choice: instant submit
                              _submitResponse(docId,
                                  instantSelections: [opt]);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? darkText.withAlpha(25)
                                  : Colors.white.withAlpha(100),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    isSelected ? darkText : Colors.black12,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isMSQ
                                      ? (isSelected
                                          ? Icons.check_box_rounded
                                          : Icons
                                              .check_box_outline_blank_rounded)
                                      : (isSelected
                                          ? Icons
                                              .radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded),
                                  size: 20,
                                  color: isSelected
                                      ? darkText
                                      : darkText.withAlpha(100),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (hasTextInput) const SizedBox(height: 8),
                  ],

                  // Text input (no arrow button inside — submit button below)
                  if (hasTextInput) ...[
                    TextField(
                      controller: _textController,
                      style: TextStyle(color: darkText, fontSize: 14),
                      textInputAction: TextInputAction.done,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: widget.gu
                            ? 'તમારો પ્રતિસાદ...'
                            : 'Share your feedback...',
                        hintStyle: TextStyle(
                            color: darkText.withAlpha(100), fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withAlpha(150),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Submit button — disabled when field is empty
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canSubmitText ? () => _submitResponse(docId) : null,
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(widget.gu ? 'સબમિટ' : 'Submit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkText,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: darkText.withAlpha(isDark ? 80 : 40),
                          disabledForegroundColor: isDark ? Colors.white60 : Colors.black38,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                  ],

                  // MSQ submit button (shown only for multi-select polls)
                  if (hasPoll && isMSQ && !hasTextInput) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting || _selectedOptions.isEmpty
                            ? null
                            : () => _submitResponse(docId),
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Icon(Icons.done_all_rounded, size: 18),
                        label: Text(widget.gu ? 'સબમિટ કરો' : 'Submit Choices', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkText,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: darkText.withAlpha(isDark ? 80 : 40),
                          disabledForegroundColor: isDark ? Colors.white60 : Colors.black38,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionLink(String url, Map<String, dynamic> data, bool isDark,
      Color darkText, ColorScheme cs) {
    return ElevatedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      icon: const Icon(Icons.arrow_outward_rounded, size: 16, color: Colors.white),
      label: Text(
        widget.gu
            ? (data['actionTextGu']?.toString().isNotEmpty == true
                ? data['actionTextGu']
                : 'વધુ જાણો')
            : (data['actionTextEn']?.toString().isNotEmpty == true
                ? data['actionTextEn']
                : 'Learn More'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: darkText,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
