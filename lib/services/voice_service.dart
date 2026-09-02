import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speechToText.isListening;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (e) => debugPrint('Speech Error: $e'),
        onStatus: (s) => debugPrint('Speech Status: $s'),
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Speech Init Exception: $e');
      return false;
    }
  }

  Future<void> listen({
    required Function(String) onResult,
    required VoidCallback onDone,
    String localeId = 'gu_IN',
  }) async {
    final ok = await init();
    if (!ok) return;

    if (_speechToText.isListening) {
      await _speechToText.stop();
      onDone();
      return;
    }

    await _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onDone();
        }
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> stop() async {
    await _speechToText.stop();
  }
}
