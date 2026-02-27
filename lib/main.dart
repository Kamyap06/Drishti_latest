import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // NEW
import 'core/theme.dart';
import 'services/language_service.dart';
import 'services/tts_service.dart';
import 'services/voice_controller.dart';
import 'services/auth_service.dart';
import 'services/app_interaction_controller.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/language_selection_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/object_detection_screen.dart';
import 'presentation/screens/currency_detection_screen.dart';
import 'presentation/screens/image_to_speech_screen.dart';
import 'presentation/screens/expiry_date_screen.dart';
import 'presentation/screens/medicine_reader_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/registration_screen.dart';
import 'presentation/screens/permissions_screen.dart';
import 'services/camera_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // NEW

  final authService = AuthService();
  await authService.init();

  final languageService = LanguageService();
  await languageService.init();

  final ttsService = TtsService();
  await ttsService.init();

  final voiceController = VoiceController();
  voiceController.setTtsService(ttsService);
  await voiceController.init();

  final appInteractionController = AppInteractionController(
    voiceController: voiceController,
    ttsService: ttsService,
    languageService: languageService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageService),
        Provider.value(value: ttsService),
        ChangeNotifierProvider.value(value: voiceController),
        ChangeNotifierProvider.value(value: appInteractionController),
        Provider.value(value: authService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final interactionController = Provider.of<AppInteractionController>(
      context,
      listen: false,
    );

    return MaterialApp(
      title: 'Drishti',
      navigatorKey: interactionController.navigatorKey,
      navigatorObservers: [routeObserver],
      theme: AppTheme.pTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/': page = const SplashScreen(); break;
          case '/permissions': page = const PermissionsScreen(); break;
          case '/language': page = const LanguageSelectionScreen(); break;
          case '/login': page = const LoginScreen(); break;
          case '/dashboard': page = const DashboardScreen(); break;
          case '/object_detection': page = const ObjectDetectionScreen(); break;
          case '/currency_detection': page = const CurrencyDetectionScreen(); break;
          case '/image_to_speech': page = const ImageToSpeechScreen(); break;
          case '/expiry_date': page = const ExpiryDateScreen(); break;
          case '/medicine_reader': page = const MedicineReaderScreen(); break;
          case '/settings': page = const SettingsScreen(); break;
          case '/registration': page = const RegistrationScreen(); break;
          default: page = const SplashScreen();
        }
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 180),
        );
      },
    );
  }
}
