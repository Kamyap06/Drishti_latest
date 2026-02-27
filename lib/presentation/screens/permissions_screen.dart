import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../widgets/large_button.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _speakInitialPrompt();
    });
  }

  Future<void> _speakInitialPrompt() async {
    final tts = Provider.of<TtsService>(context, listen: false);
    await tts.speak(
      "Welcome. Before we begin, Drishti needs permission to use your camera and microphone for voice control and object detection. Please Grant By Clicking the button",
    );
  }

  Future<void> _requestPermissions() async {
    setState(() => _isProcessing = true);

    final tts = Provider.of<TtsService>(context, listen: false);

    // Request Camera and Microphone
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      await tts.speak("Permissions granted. Moving to language selection.");
      final voice = Provider.of<VoiceController>(context, listen: false);
      await voice.stop();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/language', (route) => false);
    } else {
      await tts.speak(
        "Some permissions were denied. The app may not function correctly. Please try again.",
      );
    }

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Permissions")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              const Text(
                "Access Required",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "Drishti requires access to your camera and microphone to function.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const Spacer(),
              if (_isProcessing)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    LargeButton(
                      label: "Grant Permissions",
                      onPressed: _requestPermissions,
                    ),
                  ],
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
