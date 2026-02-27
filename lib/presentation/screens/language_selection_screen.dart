//presentation/screens/language_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/voice_utils.dart'; // Unified Intents
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../widgets/mic_widget.dart';
import '../widgets/large_button.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final String _statusToSpeak =
      "Welcome to Drishti. Please select your language. English, Hindi, or Marathi.";

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _speakPrompt();
    });
  }

  Future<void> _speakPrompt() async {
    final voice = Provider.of<VoiceController>(context, listen: false);

    // Set expectation: commands only
    voice.setInputExpectation(isCommand: true, isField: false);

    // Speak prompt sequentially
    await voice.speakWithGuard(
      "Welcome to Drishti. Please select your language. English, Hindi, or Marathi.",
      'en',
      onResult: _handleVoiceInput,
    );
  }

  void _startListening() {
    final voice = Provider.of<VoiceController>(context, listen: false);

    // Single continuous session
    voice.startListening(
      languageCode: 'en', // Start with English locale
      onResult: (text) {
        if (!mounted) return;
        _handleVoiceInput(text);
      },
    );
  }

  void _handleVoiceInput(String text) {
    print("LANG DETECT RAW: $text");
    final intent = VoiceUtils.getIntent(text);
    print("LANG INTENT: $intent");

    if (intent == VoiceIntent.languageEnglish) {
      _selectLanguage(AppConstants.langEn);
    } else if (intent == VoiceIntent.languageHindi) {
      _selectLanguage(AppConstants.langHi);
    } else if (intent == VoiceIntent.languageMarathi) {
      _selectLanguage(AppConstants.langMr);
    }
  }

  Future<void> _selectLanguage(String langCode) async {
    final voice = Provider.of<VoiceController>(context, listen: false);
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );
    final tts = Provider.of<TtsService>(context, listen: false);

    await voice.stop();
    await languageService.setLanguage(langCode);

    String confirmation = "Language selected.";
    if (langCode == AppConstants.langHi)
      confirmation = "भाषा चुनी गई (Hindi)";
    if (langCode == AppConstants.langMr)
      confirmation = "भाषा निवडली (Marathi)";

    await tts.speak(confirmation, languageCode: langCode);

    if (!mounted) return;
    
    // Resume listening for the next screen's intents
    voice.startListening(
      languageCode: langCode,
      onResult: (text) {
        // This will be re-bound by the next screen, but we ensure it's active
      },
    );

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Language")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LargeButton(
              label: "English",
              onPressed: () => _selectLanguage(AppConstants.langEn),
            ),
            const SizedBox(height: 20),
            LargeButton(
              label: "हिंदी (Hindi)",
              onPressed: () => _selectLanguage(AppConstants.langHi),
            ),
            const SizedBox(height: 20),
            LargeButton(
              label: "मराठी (Marathi)",
              onPressed: () => _selectLanguage(AppConstants.langMr),
            ),
            const Spacer(),
            Consumer<VoiceController>(
              builder: (context, voice, child) {
                return MicWidget(
                  isListening: voice.isListening,
                  onTap: () {
                    if (voice.isListening) {
                      voice.stop();
                    } else {
                      _startListening();
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
