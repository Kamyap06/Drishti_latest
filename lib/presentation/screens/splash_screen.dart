//presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final languageService = Provider.of<LanguageService>(context, listen: false);

    // 1. Check Permissions
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      Navigator.pushReplacementNamed(context, '/permissions');
      return;
    }

    // 2. Check Auth State
    if (await auth.isLoggedIn()) {
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/language', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // TOP SPACER
              const Spacer(flex: 2),

              // Drishti AI — BLUE GLOWING
              const Text(
                'Drishti AI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42, // ✅ REDUCED from 64
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                  shadows: [
                    Shadow(
                      color: Colors.blueAccent,
                      blurRadius: 8,
                      offset: Offset(0, 0),
                    ),
                    Shadow(
                      color: Colors.cyanAccent,
                      blurRadius: 4,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // App Logo below Drishti AI — CENTERED
              Image.asset(
                'assets/icon/app_logo.png',
                height: 130,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/icon/app_icon.jpeg', // Fallback to launcher icon
                    height: 130,
                    errorBuilder: (c, e, s) => const SizedBox(height: 130), // silent fallback
                  );
                },
              ),

              // BOTTOM SPACER
              const Spacer(flex: 3),

              // College Logo ONLY at bottom — NO TEXT
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Image.asset(
                  'assets/images/college_logo.png',
                  height: 100, // ✅ BIGGER college logo
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(height: 70); // invisible if missing
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}