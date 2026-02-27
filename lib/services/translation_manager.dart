import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'tts_service.dart';
import 'language_service.dart';

class TranslationManager {
  static final TranslationManager _instance = TranslationManager._internal();
  factory TranslationManager() => _instance;
  TranslationManager._internal();

  final Map<String, OnDeviceTranslator> _translators = {};
  final LanguageIdentifier _languageIdentifier = LanguageIdentifier(
    confidenceThreshold: 0.5,
  );

  void init() {
    // Optionally pre-load models or initialize anything if needed
  }

  /// Maps standard language codes to BCP-47 identifiers used by ML Kit Translator
  TranslateLanguage _getTranslateLanguage(String code) {
    switch (code.toLowerCase()) {
      case 'hi':
      case 'hin':
        return TranslateLanguage.hindi;
      case 'mr':
      case 'mar':
        return TranslateLanguage.marathi;
      case 'en':
      case 'eng':
      default:
        return TranslateLanguage.english;
    }
  }

  String _getTranslatorKey(String source, String target) {
    final List<String> codes = [source, target]..sort();
    return "${codes[0]}_${codes[1]}";
  }

  Future<OnDeviceTranslator> _getTranslator(
    String sourceCode,
    String targetCode,
  ) async {
    final key = _getTranslatorKey(sourceCode, targetCode);
    if (!_translators.containsKey(key)) {
      _translators[key] = OnDeviceTranslator(
        sourceLanguage: _getTranslateLanguage(sourceCode),
        targetLanguage: _getTranslateLanguage(targetCode),
      );
    }
    // Update translator direction if it's cached in reverse logic
    // Wait, OnDeviceTranslator requires explicit source/target.
    // It's better to cache per exact source->target map
    return OnDeviceTranslator(
      sourceLanguage: _getTranslateLanguage(sourceCode),
      targetLanguage: _getTranslateLanguage(targetCode),
    );
  }

  // Caching per exact pair for safety
  Future<OnDeviceTranslator> _getExactTranslator(
    String sourceCode,
    String targetCode,
  ) async {
    final key = "${sourceCode}_$targetCode";
    if (!_translators.containsKey(key)) {
      _translators[key] = OnDeviceTranslator(
        sourceLanguage: _getTranslateLanguage(sourceCode),
        targetLanguage: _getTranslateLanguage(targetCode),
      );
    }
    return _translators[key]!;
  }

  Future<String> identifyLanguage(String text) async {
    try {
      final String language = await _languageIdentifier.identifyLanguage(text);
      if (language == 'und') return 'en'; // default to english if unknown
      if (language == 'hin') return 'hi';
      if (language == 'mar') return 'mr';
      if (language == 'eng') return 'en';
      return language;
    } catch (e) {
      debugPrint("Language ID error: $e");
      return 'en';
    }
  }

  Future<String> translate(
    String text,
    String sourceCode,
    String targetCode,
  ) async {
    if (sourceCode == targetCode) return text;
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      
      final sourceLang = _getTranslateLanguage(sourceCode);
      final targetLang = _getTranslateLanguage(targetCode);

      final isSourceDownloaded = await modelManager.isModelDownloaded(sourceLang.bcpCode);
      if (!isSourceDownloaded) {
        debugPrint("Downloading source model: ${sourceLang.bcpCode}");
        await modelManager.downloadModel(sourceLang.bcpCode);
      }

      final isTargetDownloaded = await modelManager.isModelDownloaded(targetLang.bcpCode);
      if (!isTargetDownloaded) {
        debugPrint("Downloading target model: ${targetLang.bcpCode}");
        await modelManager.downloadModel(targetLang.bcpCode);
      }

      final translator = await _getExactTranslator(sourceCode, targetCode);
      return await translator.translateText(text);
    } catch (e) {
      debugPrint("Translation error: $e");
      return text;
    }
  }

  void dispose() {
    _languageIdentifier.close();
    for (var translator in _translators.values) {
      translator.close();
    }
    _translators.clear();
  }
}
