//presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
// import '../../services/auth_service.dart'; // Future use if login state needed

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
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    // 1. Check Permissions
    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      Navigator.pushReplacementNamed(context, '/permissions');
      return;
    }

    // 2. Check Auth State
    if (await auth.isLoggedIn()) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } else {
      // Not logged in -> Always select language first
      Navigator.pushNamedAndRemoveUntil(context, '/language', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Drishti',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
                shadows: [
                  Shadow(
                    color: Colors.blueAccent,
                    blurRadius: 30,
                    offset: Offset(0, 0),
                  ),
                  Shadow(
                    color: Colors.cyanAccent,
                    blurRadius: 15,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // TODO: Place your college logo here!
            Image.asset(
              'assets/images/college_logo.png',
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      "Add Logo Here\n\nassets/images/\ncollege_logo.png",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
