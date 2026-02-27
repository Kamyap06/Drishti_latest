//presentation/screen/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../widgets/mic_widget.dart';
import '../../services/app_interaction_controller.dart';
import '../../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Re-initialize state when returning to Dashboard via back button
    Future.delayed(Duration.zero, () {
      final interaction = Provider.of<AppInteractionController>(context, listen: false);
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
      interaction.setActiveFeature(ActiveFeature.dashboard);
      interaction.startGlobalListening(languageCode: lang);
      _speakOptions();
    });
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final interaction = Provider.of<AppInteractionController>(
        context,
        listen: false,
      );
      // Issue 1: Forward the current locale so STT runs in Hindi/Marathi
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
      interaction.setActiveFeature(ActiveFeature.dashboard);
      interaction.startGlobalListening(languageCode: lang);
      _speakOptions();
    });
  }

  Future<void> _speakOptions() async {
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

      String prompt = "Please say a command. You can scan objects, check money, read text, check expiry, or open settings.";
      if (lang == 'hi') prompt = "कृपया कमांड बोलें। आप चीज़ें पहचान सकते हैं, नोट की जाँच कर सकते हैं, लिखा हुआ पढ़ सकते हैं, एक्सपायरी डेट चेक कर सकते हैं, या सेटिंग्स खोल सकते हैं।";
      if (lang == 'mr') prompt = "कृपया कमांड सांगा. तुम्ही वस्तू ओळखू शकता, नोट तपासू शकता, मजकूर वाचू शकता, एक्सपायरी डेट तपासू शकता, किंवा सेटिंग्ज उघडू शकता.";

      await tts.speak(prompt, languageCode: lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            // Place your small college logo here!
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withOpacity(0.9), // Add a slight background in case logo is dark
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                'assets/images/college_logo_small.jpg',
                height: 40, 
                width: 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.school, size: 40, color: Colors.blueAccent);
                },
              ),
            ),
            const SizedBox(width: 16),
            const Text("Drishti", style: TextStyle(letterSpacing: 2, fontSize: 26, fontWeight: FontWeight.bold)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF141E30), const Color(0xFF243B55)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      _buildGridCard(
                        context,
                        "Object\nDetection",
                        Icons.adf_scanner,
                        [Colors.blueAccent, Colors.cyanAccent],
                        () =>
                            Provider.of<AppInteractionController>(
                              context,
                              listen: false,
                            ).navigatorKey.currentState?.pushNamed(
                              '/object_detection',
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildGridCard(
                        context,
                        "Currency\nCheck",
                        Icons.attach_money,
                        [Colors.green, Colors.tealAccent],
                        () =>
                            Provider.of<AppInteractionController>(
                              context,
                              listen: false,
                            ).navigatorKey.currentState?.pushNamed(
                              '/currency_detection',
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildGridCard(
                        context,
                        "Read\nText",
                        Icons.text_fields,
                        [Colors.deepPurpleAccent, Colors.purpleAccent],
                        () =>
                            Provider.of<AppInteractionController>(
                              context,
                              listen: false,
                            ).navigatorKey.currentState?.pushNamed(
                              '/image_to_speech',
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildGridCard(
                        context,
                        "Expiry\nDate",
                        Icons.event_busy,
                        [Colors.redAccent, Colors.pinkAccent],
                        () =>
                            Provider.of<AppInteractionController>(
                              context,
                              listen: false,
                            ).navigatorKey.currentState?.pushNamed(
                              '/expiry_date',
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildGridCard(
                        context,
                        "Settings",
                        Icons.settings_suggest,
                        [Colors.orangeAccent, Colors.amber],
                        () => Provider.of<AppInteractionController>(
                          context,
                          listen: false,
                        ).navigatorKey.currentState?.pushNamed('/settings'),
                      ),
                    ],
                  ),
                ),
              ),
              // Mic Area
              Container(
                padding: const EdgeInsets.only(bottom: 40, top: 20),
                child: Center(
                  child: Consumer<AppInteractionController>(
                    builder: (context, interaction, child) {
                      final voice = Provider.of<VoiceController>(context);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MicWidget(
                            isListening:
                                voice.isListening || interaction.isBusy,
                            onTap: () {
                              if (voice.isListening) {
                                interaction.stopGlobalListening();
                              } else {
                                interaction.startGlobalListening();
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          AnimatedOpacity(
                            opacity: voice.isListening ? 1.0 : 0.5,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              voice.isListening
                                  ? "Listening..."
                                  : "Tap to Speak",
                              style: const TextStyle(
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Color> gradients,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85, // Reduced to fit 6 buttons
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: gradients),
          boxShadow: [
            BoxShadow(
              color: gradients.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 100,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14, // Reduced font
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
