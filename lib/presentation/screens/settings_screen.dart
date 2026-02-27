import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../../services/auth_service.dart';
import '../../services/app_interaction_controller.dart';
import '../widgets/mic_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAskingLanguage = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final interaction = Provider.of<AppInteractionController>(
        context,
        listen: false,
      );
      interaction.setActiveFeature(ActiveFeature.settings);
      interaction.registerFeatureCallbacks(
        onCommand: _handleCustomVoiceCommand,
      );
      _announce();
    });
  }

  Future<void> _announce() async {
    final interaction = Provider.of<AppInteractionController>(
      context,
      listen: false,
    );
    await interaction.runExclusive(() async {
      final tts = Provider.of<TtsService>(context, listen: false);
      final lang = Provider.of<LanguageService>(
        context,
        listen: false,
      ).currentLocale.languageCode;
      String prompt = "What do you want to do? Change language, log out, or back.";
      if (lang == 'hi') prompt = "आप क्या करना चाहते हैं? भाषा बदलें, लॉग आउट करें, या वापस जाएं।";
      if (lang == 'mr') prompt = "तुम्हाला काय करायचे आहे? भाषा बदला, लॉग आउट करा, किंवा मागे जा.";
      
      await tts.speak(
        prompt,
        languageCode: lang,
      );
    });
  }

  Future<void> _speak(String text, String lang) async {
    final interaction = Provider.of<AppInteractionController>(
      context,
      listen: false,
    );
    await interaction.runExclusive(() async {
      await Provider.of<TtsService>(
        context,
        listen: false,
      ).speak(text, languageCode: lang);
    });
  }

  Future<void> _handleCustomVoiceCommand(String t) async {
    final langService = Provider.of<LanguageService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_isAskingLanguage) {
      if (t.contains("hindi") || t.contains("हिंदी")) {
        await langService.setLanguage("hi");
        await authService.updateUserLanguage("hi");
        await _speak("Language changed to Hindi", "hi");
        _isAskingLanguage = false;
      } else if (t.contains("marathi") || t.contains("मराठी")) {
        await langService.setLanguage("mr");
        await authService.updateUserLanguage("mr");
        await _speak("Language changed to Marathi", "mr");
        _isAskingLanguage = false;
      } else if (t.contains("english") || t.contains("अंग्रेजी") || t.contains("इंग्रजी")) {
        await langService.setLanguage("en");
        await authService.updateUserLanguage("en");
        await _speak("Language changed to English", "en");
        _isAskingLanguage = false;
      } else {
        final lang = langService.currentLocale.languageCode;
        String prompt = "Change to which language: English, Hindi, or Marathi?";
        if (lang == 'hi') prompt = "किस भाषा में बदलें: अंग्रेजी, हिंदी या मराठी?";
        if (lang == 'mr') prompt = "कोणत्या भाषेत बदलायचे: इंग्रजी, हिंदी किंवा मराठी?";
        await _speak(prompt, lang);
      }
      return;
    }

    if (t.contains("change") && t.contains("language") || t.contains("bhasha") || t.contains("भाषा")) {
      _isAskingLanguage = true;
      final lang = langService.currentLocale.languageCode;
      String prompt = "Change to which language: English, Hindi, or Marathi?";
      if (lang == 'hi') prompt = "किस भाषा में बदलें: अंग्रेजी, हिंदी या मराठी?";
      if (lang == 'mr') prompt = "कोणत्या भाषेत बदलायचे: इंग्रजी, हिंदी किंवा मराठी?";
      await _speak(prompt, lang);
    } else if (t.contains("log") && (t.contains("out") || t.contains("logout"))) {
      await _speak("Logging out...", langService.currentLocale.languageCode);
      await authService.logout();
      await langService.clearLanguage();
      await Provider.of<VoiceController>(context, listen: false).resetSession();
      final interaction = Provider.of<AppInteractionController>(
        context,
        listen: false,
      );
      if (mounted) {
        interaction.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } else if (t.contains("back") || t.contains("mage") || t.contains("wapas") || t.contains("maaghe")) {
      final interaction = Provider.of<AppInteractionController>(
        context,
        listen: false,
      );
      interaction.handleGlobalBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Basic settings UI
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ListTile(
              title: const Text("Change Language"),
              trailing: Consumer<LanguageService>(
                builder: (context, langService, child) {
                  return DropdownButton<String>(
                    value: langService.currentLocale.languageCode,
                    icon: const Icon(Icons.arrow_drop_down),
                    underline: Container(
                      height: 2,
                      color: Colors.blueAccent,
                    ),
                    onChanged: (String? newValue) async {
                      if (newValue != null) {
                        await langService.setLanguage(newValue);
                        if (context.mounted) {
                           await Provider.of<AuthService>(context, listen: false).updateUserLanguage(newValue);
                           
                           // Force STT hardware reset via AppInteractionController so the
                           // new locale takes effect identically to a voice language switch
                           final interaction = Provider.of<AppInteractionController>(context, listen: false);
                           interaction.setBusy(true);
                           await interaction.stopGlobalListening();
                           interaction.setBusy(false);
                           interaction.startGlobalListening();
                        }
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                      DropdownMenuItem(value: 'mr', child: Text('Marathi')),
                    ],
                  );
                },
              ),
            ),
            ListTile(
              title: const Text("Log Out"),
              trailing: const Icon(Icons.logout),
              onTap: () async {
                // Logic
                await Provider.of<AuthService>(context, listen: false).logout();
                await Provider.of<LanguageService>(
                  context,
                  listen: false,
                ).clearLanguage();
                await Provider.of<VoiceController>(
                  context,
                  listen: false,
                ).resetSession();
                
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/language',
                  (route) => false,
                );
              },
            ),
            const Spacer(),
            Consumer<AppInteractionController>(
              builder: (ctx, interaction, _) {
                final voice = Provider.of<VoiceController>(context);
                return MicWidget(
                  isListening: voice.isListening || interaction.isBusy,
                  onTap: () {
                    if (voice.isListening) {
                      interaction.stopGlobalListening();
                    } else {
                      interaction.startGlobalListening();
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
