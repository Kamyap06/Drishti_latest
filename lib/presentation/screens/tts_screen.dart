//presentation/screen/tts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../widgets/large_button.dart';

class TtsScreen extends StatefulWidget {
  const TtsScreen({super.key});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _speak() async {
    if (_controller.text.isEmpty) return;
    final tts = Provider.of<TtsService>(context, listen: false);
    final lang = Provider.of<LanguageService>(
      context,
      listen: false,
    ).currentLocale.languageCode;
    await tts.speak(_controller.text, languageCode: lang);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Text to Speech")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: "Enter text to speak...",
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),
            LargeButton(
              label: "Speak",
              icon: Icons.volume_up,
              onPressed: _speak,
            ),
          ],
        ),
      ),
    );
  }
}
