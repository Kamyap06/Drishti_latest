import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import '../core/constants.dart';

class LanguageService extends ChangeNotifier {
  Locale _currentLocale = const Locale(AppConstants.langEn);
  static const String _prefKey = 'selected_language';
  bool _isLanguageSelected = false;
  final _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

  Locale get currentLocale => _currentLocale;
  bool get isLanguageSelected => _isLanguageSelected;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_prefKey);
    if (langCode != null) {
      _currentLocale = Locale(langCode);
      _isLanguageSelected = true;
    } else {
      _isLanguageSelected = false;
    }
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (!AppConstants.languageNames.containsKey(languageCode)) return;

    _currentLocale = Locale(languageCode);
    _isLanguageSelected = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageCode);
    notifyListeners();
  }

  Future<void> clearLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    _isLanguageSelected = false;
    notifyListeners();
  }

  // Adaptive Language Logic REMOVED for strict locking
  // Future<void> checkAndAdaptLanguage(String text) async { ... }

  @override
  void dispose() {
    _languageIdentifier.close();
    super.dispose();
  }
}
