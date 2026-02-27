import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../widgets/mic_widget.dart';
import '../../services/app_interaction_controller.dart';

class ExpiryDateScreen extends StatefulWidget {
  const ExpiryDateScreen({super.key});

  @override
  State<ExpiryDateScreen> createState() => _ExpiryDateScreenState();
}

class _ExpiryDateScreenState extends State<ExpiryDateScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _initCamera();
    Future.delayed(Duration.zero, () {
      final interaction = Provider.of<AppInteractionController>(
        context,
        listen: false,
      );
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;

      interaction.setActiveFeature(ActiveFeature.expiryDetection);
      interaction.registerFeatureCallbacks(
        onDetect: _captureAndProcess,
        onBack: () async {
          final interaction = Provider.of<AppInteractionController>(context, listen: false);
          await interaction.handleGlobalBack();
        },
        onDispose: () {
          _textRecognizer.close();
        },
      );
      interaction.startGlobalListening(languageCode: lang);
      _announce();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first),
          ResolutionPreset.high, // Better resolution for reading small expiry text
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
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
      
      String prompt = "Expiry detector. Say detect to check the expiry date of a product.";
      if (lang == 'hi') prompt = "एक्सपायरी डेट चेकर। प्रोडक्ट की एक्सपायरी चेक करने के लिए 'डिटेक्ट' बोलें।";
      if (lang == 'mr') prompt = "एक्सपायरी डेट चेकर. उत्पादनाची एक्सपायरी तपासण्यासाठी 'डिटेक्ट' म्हणा.";
      
      await tts.speak(prompt, languageCode: lang);
    });
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    if (mounted) {
      setState(() => _isProcessing = true);
    }
    
    final voice = Provider.of<VoiceController>(context, listen: false);
    await voice.stop();

    try {
      final XFile file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      _evaluateExpiry(recognizedText.text);
      
    } catch (e) {
      debugPrint("OCR Error: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      Provider.of<AppInteractionController>(context, listen: false).startGlobalListening();
    }
  }

  void _evaluateExpiry(String extractedText) {
    if (extractedText.isEmpty) {
      _speakResult(null, false, "Could not find any text.");
      return;
    }

    // Try to find an expiry date
    final datePattern = RegExp(
      r'(?:(?:EXP|EXPIRY|BEST\s*BEFORE|USE\s*BY|BB|MFG|MFG\s*DATE|MFD)[^\w\d]*)?((?:0[1-9]|[12]\d|3[01])[/\-\.](?:0[1-9]|1[0-2])[/\-\.]\d{2,4}|(?:0[1-9]|1[0-2])[/\-\.]\d{2,4}|(?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*[\s,\-]+\d{2,4})',
      caseSensitive: false,
    );
    
    // Check multiple matches and prioritize those combined with keywords
    final matches = datePattern.allMatches(extractedText);
    String? foundDateStr;
    DateTime? parsedDate;
    
    for (final match in matches) {
      String fullMatchStr = match.group(0)!;
      String group1 = match.group(1)!; // This avoids matching plain words, strictly groups the date
      
      // Attempt parsing
      parsedDate = _parseDateString(group1);
      if (parsedDate != null) {
        foundDateStr = group1;
        
        // If it specifically mentions EXP/BB, favor it immediately
        if (fullMatchStr.toUpperCase().contains('EXP') ||
            fullMatchStr.toUpperCase().contains('BB') ||
            fullMatchStr.toUpperCase().contains('BEST') ||
            fullMatchStr.toUpperCase().contains('USE')) {
          break;
        }
      }
    }

    if (parsedDate == null) {
      _speakResult(null, false, null);
      return;
    }

    final isExpired = DateTime.now().isAfter(parsedDate);
    _speakResult(parsedDate, isExpired, null);
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      String cleanDate = dateStr.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Cases:
      // DD/MM/YYYY or DD-MM-YYYY
      if (RegExp(r'^\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}$').hasMatch(cleanDate)) {
        List<String> parts = cleanDate.split(RegExp(r'[/\-\.]'));
        int d = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        int y = int.parse(parts[2]);
        if (y < 100) y += 2000;
        return DateTime(y, m, d);
      }
      
      // MM/YYYY or MM-YY
      if (RegExp(r'^\d{1,2}[/\-\.]\d{2,4}$').hasMatch(cleanDate)) {
        List<String> parts = cleanDate.split(RegExp(r'[/\-\.]'));
        int m = int.parse(parts[0]);
        int y = int.parse(parts[1]);
        if (y < 100) y += 2000;
        // Last day of the month for just MM/YYYY
        return DateTime(y, m + 1, 0);
      }
      
      // MMM YYYY (e.g. JAN 2025)
      if (RegExp(r'^[A-Z]{3,}[,\-\s]+\d{2,4}$').hasMatch(cleanDate)) {
        List<String> parts = cleanDate.split(RegExp(r'[,\-\s]+'));
        String mStr = parts[0].substring(0, 3);
        int y = int.parse(parts[1]);
        if (y < 100) y += 2000;
        
        int m = _monthToInt(mStr);
        if (m > 0) return DateTime(y, m + 1, 0);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  int _monthToInt(String m) {
    switch (m) {
      case 'JAN': return 1;
      case 'FEB': return 2;
      case 'MAR': return 3;
      case 'APR': return 4;
      case 'MAY': return 5;
      case 'JUN': return 6;
      case 'JUL': return 7;
      case 'AUG': return 8;
      case 'SEP': return 9;
      case 'OCT': return 10;
      case 'NOV': return 11;
      case 'DEC': return 12;
      default: return 0;
    }
  }

  Future<void> _speakResult(DateTime? date, bool isExpired, String? failReason) async {
    final interaction = Provider.of<AppInteractionController>(
      context,
      listen: false,
    );
    await interaction.runExclusive(() async {
      final tts = Provider.of<TtsService>(context, listen: false);
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;

      String message = "";

      if (date == null) {
        if (lang == 'hi') message = "एक्सपायरी डेट नहीं मिल सकी। कृपया फिर से कोशिश करें।";
        else if (lang == 'mr') message = "एक्सपायरी डेट सापडली नाही. कृपया पुन्हा प्रयत्न करा.";
        else message = "Could not find expiry date. Please try again.";
      } else {
        String formattedDate = DateFormat.yMMMM().format(date); // e.g., January 2025
        
        if (isExpired) {
          if (lang == 'hi') message = "यह प्रोडक्ट $formattedDate को एक्सपायर हो चुका है।";
          else if (lang == 'mr') message = "हे उत्पादन $formattedDate ला एक्सपायर झाले आहे.";
          else message = "This product has expired on $formattedDate.";
        } else {
          if (lang == 'hi') message = "यह प्रोडक्ट $formattedDate तक वैध है।";
          else if (lang == 'mr') message = "हे उत्पादन $formattedDate पर्यंत वैध आहे.";
          else message = "This product is valid until $formattedDate.";
        }
      }

      await tts.speak(message, languageCode: lang);
    });

    if (mounted) {
      setState(() => _isProcessing = false);
      Provider.of<AppInteractionController>(context, listen: false).startGlobalListening();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Expiry Date Reader"),
      ),
      body: Stack(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_controller!),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Consumer2<AppInteractionController, LanguageService>(
                  builder: (ctx, interaction, langService, _) {
                    final voice = Provider.of<VoiceController>(context);
                    final lang = langService.currentLocale.languageCode;
                    String promptText = "Say 'Detect' to check or 'Back'";
                    if (lang == 'hi') promptText = "चेक करने के लिए 'डिटेक्ट' या 'वापस' बोलें";
                    if (lang == 'mr') promptText = "तपासण्यासाठी 'डिटेक्ट' किंवा 'मागे' म्हणा";

                    return Column(
                      children: [
                        MicWidget(
                          isListening: voice.isListening || interaction.isBusy,
                          onTap: () {
                            if (voice.isListening) {
                              interaction.stopGlobalListening();
                            } else {
                              interaction.startGlobalListening();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(153),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.cyanAccent.withAlpha(128)),
                          ),
                          child: Text(
                            promptText,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
