import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_service.dart';

class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onResult;
  final String localeId;

  const VoiceInputButton({
    super.key,
    required this.controller,
    this.onResult,
    this.localeId = 'gu_IN',
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  bool _isListening = false;
  final VoiceService _voiceService = VoiceService();

  void _toggleListening() async {
    HapticFeedback.mediumImpact();
    
    if (_isListening) {
      await _voiceService.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    
    await _voiceService.listen(
      localeId: widget.localeId,
      onResult: (text) {
        if (text.isNotEmpty) {
          widget.controller.text = text;
          if (widget.onResult != null) widget.onResult!();
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          key: ValueKey(_isListening),
          color: _isListening ? cs.error : cs.primary,
          size: 20,
        ),
      ),
      onPressed: _toggleListening,
      tooltip: _isListening ? 'Listening...' : 'Voice Input',
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}
