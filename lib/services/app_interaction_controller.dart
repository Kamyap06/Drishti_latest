import 'package:flutter/material.dart';
import 'voice_controller.dart';
import 'tts_service.dart';
import 'language_service.dart';
import '../core/voice_utils.dart';

enum ActiveFeature {
  dashboard,
  objectDetection,
  currencyDetection,
  imageSpeech,
  expiryDetection,
  medicineReader,
  settings,
  none,
}

class AppInteractionController extends ChangeNotifier {
  ActiveFeature _activeFeature = ActiveFeature.dashboard;
  bool _isBusy = false;

  ActiveFeature get activeFeature => _activeFeature;
  bool get isBusy => _isBusy;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  VoidCallback? onDetectCommand;
  void Function(String)? onCommand;
  VoidCallback? onBackCommand;
  VoidCallback? onDisposeFeature;

  final VoiceController voiceController;
  final TtsService ttsService;
  final LanguageService languageService;

  AppInteractionController({
    required this.voiceController,
    required this.ttsService,
    required this.languageService,
  });

  void setActiveFeature(ActiveFeature feature) {
    _activeFeature = feature;
    _isBusy = false;
    onDetectCommand = null;
    onCommand = null;
    onBackCommand = null;
    onDisposeFeature = null;
    notifyListeners();
  }

  void registerFeatureCallbacks({
    VoidCallback? onDetect,
    void Function(String)? onCommand,
    VoidCallback? onBack,
    VoidCallback? onDispose,
  }) {
    onDetectCommand = onDetect;
    this.onCommand = onCommand;
    onBackCommand = onBack;
    onDisposeFeature = onDispose;
  }

  void unregisterFeature() {
    onDisposeFeature?.call();
    onDetectCommand = null;
    onCommand = null;
    onBackCommand = null;
    onDisposeFeature = null;
  }

  void setBusy(bool busy) {
    if (_isBusy == busy) return;
    _isBusy = busy;
    notifyListeners();
  }

  Future<void> runExclusive(Future<void> Function() action) async {
    if (_isBusy) return;
    setBusy(true);
    await stopGlobalListening();
    try {
      await action();
    } finally {
      setBusy(false);
      if (_activeFeature != ActiveFeature.none) {
        startGlobalListening();
      }
    }
  }

  Future<void> startGlobalListening({String? languageCode}) async {
    if (_isBusy || _activeFeature == ActiveFeature.none) return;
    String lang = languageCode ?? languageService.currentLocale.languageCode;
    
    // Fix 1: Always reset session when starting a "global" feature listen
    await voiceController.resetSession();
    
    voiceController.startListening(
      languageCode: lang,
      onResult: _handleVoiceResult,
    );
  }

  Future<void> stopGlobalListening() async {
    await voiceController.stop();
  }

  Future<void> handleGlobalBack() async {
    if (_activeFeature == ActiveFeature.dashboard) return; // already there
    setBusy(true);
    await ttsService.stop();
    await stopGlobalListening();

    unregisterFeature();
    _activeFeature = ActiveFeature.dashboard;

    navigatorKey.currentState?.pushNamedAndRemoveUntil('/dashboard', (route) => false);
    setBusy(false);
  }

  void _handleVoiceResult(String text) {
    debugPrint("AppInteractionController: Heard '$text'");

    // Unified Intent Mapping — called on RAW text before any normalization (Fix 1)
    final intent = VoiceUtils.getIntent(text);

    // Fix 5: Back must ALWAYS be processed unconditionally, even during TTS / busy.
    // Stop TTS + mic immediately so the user is never trapped by a spoken prompt.
    if (intent == VoiceIntent.back) {
      ttsService.stop();
      voiceController.stop();
      if (onBackCommand != null) {
        onBackCommand?.call();
      } else {
        handleGlobalBack();
      }
      return;
    }

    // All other commands respect the busy guard
    if (_isBusy) return;

    String t = text.toLowerCase();

    if (_activeFeature == ActiveFeature.dashboard) {
      _routeDashboardCommand(text, intent);
    } else {
      // Feature specific commands
      if (t.contains("detect") ||
          t.contains("scan") ||
          t.contains("स्कैन") ||
          t.contains("स्कैन करो") ||
          t.contains("capture") ||
          t.contains("dekho") ||
          t.contains("paisa dekho") ||
          t.contains("note scan karo") ||
          t.contains("kya") ||
          t.contains("baga") ||
          t.contains("kay") ||
          t.contains("तपासा") ||
          t.contains("ओळखा") ||
          t.contains("पहचानो") ||
          t.contains("शोधा") ||
          t.contains("नोट") ||
          t.contains("rupee") ||
          t.contains("read") ||
          t.contains("वाचा") ||
          t.contains("text") ||
          t.contains("डिटेक्ट") ||
          t.contains("स्कॅन") ||
          t.contains("चेक") ||
          t.contains("check") ||
          t.contains("तारीख") ||
          t.contains("tariq") ||
          t.contains("tarikh")) {
        onDetectCommand?.call();
      }
      onCommand?.call(t);
    }
  }

  Future<void> _routeDashboardCommand(String text, VoiceIntent intent) async {
    String route = '';
    String confirmEn = '';
    String confirmHi = '';
    String confirmMr = '';

    if (intent == VoiceIntent.login) {
      route = '/login';
      confirmEn = "Opening Login";
      confirmHi = "लॉगिन खोल रहे हैं";
      confirmMr = "लॉगिन उघडत आहे";
    } else if (intent == VoiceIntent.register) {
      route = '/registration';
      confirmEn = "Opening Registration";
      confirmHi = "पंजीकरण खोल रहे हैं";
      confirmMr = "नोंदणी उघडत आहे";
    } else if (intent == VoiceIntent.objectDetection) {
      route = '/object_detection';
      confirmEn = "Opening Object Detection";
      confirmHi = "वस्तु पहचान खोल रहे हैं";
      confirmMr = "वस्तू ओळख उघडत आहे";
    } else if (intent == VoiceIntent.currencyDetection) {
      route = '/currency_detection';
      confirmEn = "Opening Currency Check";
      confirmHi = "पैसे की जांच खोल रहे हैं";
      confirmMr = "पैसे तपासणे उघडत आहे";
    } else if (intent == VoiceIntent.readText) {
      route = '/image_to_speech';
      confirmEn = "Opening Text Reader";
      confirmHi = "टेक्स्ट पढ़ना खोल रहे हैं";
      confirmMr = "मजकूर वाचणे उघडत आहे";
    } else if (intent == VoiceIntent.openSettings) {
      route = '/settings';
      confirmEn = "Opening Settings";
      confirmHi = "सेटिंग्स खोल रहे हैं";
      confirmMr = "सेटिंग्ज उघडत आहे";
    } else if (intent == VoiceIntent.expiryDetection) {
      route = '/expiry_date';
      confirmEn = "Opening Expiry Date Reader";
      confirmHi = "तारीख जांच खोल रहे हैं";
      confirmMr = "तारीख तपासणी उघडत आहे";
    } else if (intent == VoiceIntent.medicineReader) {
      route = '/medicine_reader';
      confirmEn = "Opening Medicine Reader";
      confirmHi = "दवा जांच खोल रहे हैं";
      confirmMr = "औषध तपासणी उघडत आहे";
    }
    if (route.isNotEmpty) {
      setBusy(true);
      await stopGlobalListening();

      String lang = languageService.currentLocale.languageCode;
      String confirm = confirmEn;
      if (lang == 'hi') confirm = confirmHi;
      if (lang == 'mr') confirm = confirmMr;

      await ttsService.speak(confirm, languageCode: lang);

      // Issue 1: Release the busy lock BEFORE navigating so the feature
      // screen's startGlobalListening() is not blocked by isBusy=true
      setBusy(false);
      navigatorKey.currentState?.pushNamed(route);
    }
  }
}
