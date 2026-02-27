//services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';
import '../core/constants.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  Function()? _onCompletion;

  Future<void> init() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setCompletionHandler(() {
      if (_onCompletion != null) {
        _onCompletion!();
      }
    });
  }

  void setCompletionHandler(Function() handler) {
    _onCompletion = handler;
  }

  Future<void> speak(String text, {String? languageCode}) async {
    String activeLang = languageCode ?? 'en';
    
    // Override local TTS accent if text is strictly English to prevent robotic/broken accent
    if (activeLang == 'hi' || activeLang == 'mr') {
       bool hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(text);
       bool hasEnglishLetters = RegExp(r'[a-zA-Z]').hasMatch(text);
       if (!hasDevanagari && hasEnglishLetters) {
           activeLang = 'en';
       }
    }

    await _configureVoice(activeLang);
    await _flutterTts.speak(text);
  }

  Future<void> _configureVoice(String languageCode) async {
    final ttsLocale = AppConstants.ttsLocales[languageCode] ?? 'en-US';
    await _flutterTts.setLanguage(ttsLocale);

    // Attempt to prefer specific engines if available (Android)
    try {
      final voices = await _flutterTts.getVoices;
      // print("Available voices: $voices"); // Debugging
    } catch (e) {
      print("Error getting voices: $e");
    }

    // Per-language tuning for clarity & naturalness
    if (languageCode == AppConstants.langHi) {
      await _flutterTts.setPitch(1.0); // Balanced
      await _flutterTts.setSpeechRate(0.4); // Slower for clear pronunciation
    } else if (languageCode == AppConstants.langMr) {
      await _flutterTts.setPitch(1.0); // Natural
      await _flutterTts.setSpeechRate(
        0.35,
      ); // Even slower for distinct syllables
    } else {
      // English
      await _flutterTts.setPitch(1.1); // Slightly higher/clearer
      await _flutterTts.setSpeechRate(0.5); // Moderate standard rate
    }
  }

  Future<void> speakSequentially(List<Map<String, String>> prompts) async {
    for (var prompt in prompts) {
      final text = prompt['text']!;
      final lang = prompt['lang']!;
      await _configureVoice(lang);
      await _flutterTts.speak(text);
      // awaitCompletion is verified in init(), so loop waits for each
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
