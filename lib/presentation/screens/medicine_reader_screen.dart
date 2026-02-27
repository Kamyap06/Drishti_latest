import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';

import '../../services/app_interaction_controller.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../widgets/mic_widget.dart';

class MedicineReaderScreen extends StatefulWidget {
  const MedicineReaderScreen({Key? key}) : super(key: key);

  @override
  State<MedicineReaderScreen> createState() => _MedicineReaderScreenState();
}

class _MedicineReaderScreenState extends State<MedicineReaderScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  String _uiName = "";
  String _uiWarning = "";
  
  String _lastSpokenText = "";
  String _lastSpokenLang = "en";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announce();
    });
  }

  void _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    // Attempting to prioritize back camera for better text reading
    CameraDescription? selectedCamera;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        selectedCamera = camera;
        break;
      }
    }
    selectedCamera ??= cameras.first;

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _announce() async {
    final interaction = Provider.of<AppInteractionController>(context, listen: false);
    interaction.setActiveFeature(ActiveFeature.medicineReader);
    interaction.registerFeatureCallbacks(
      onDetect: _captureAndScan,
      onCommand: _handleCustomVoiceCommand,
      onBack: () async {
        await interaction.handleGlobalBack();
      },
      onDispose: () {
        _textRecognizer.close();
      },
    );

    final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
    String prompt = "Medicine reader. Say Detect to scan medicine label.";
    if (lang == 'hi') prompt = "मेडिसिन रीडर। दवा स्कैन करने के लिए डिटेक्ट बोलें।";
    if (lang == 'mr') prompt = "मेडिसिन रीडर. औषध स्कॅन करण्यासाठी डिटेक्ट म्हणा.";

    await interaction.runExclusive(() async {
      final tts = Provider.of<TtsService>(context, listen: false);
      await tts.speak(prompt, languageCode: lang);
    });

    interaction.startGlobalListening(languageCode: lang);
  }

  void _handleCustomVoiceCommand(String text) {
    final lower = text.toLowerCase().trim();
    final interaction = Provider.of<AppInteractionController>(context, listen: false);

    // Explicit multilingual back detection
    if (lower.contains('वापस') || lower.contains('मागे') || lower.contains('back') || lower.contains('go back')) {
      final tts = Provider.of<TtsService>(context, listen: false);
      tts.stop();
      interaction.handleGlobalBack();
      return;
    }

    // Repeat detection
    if (lower.contains('repeat') || lower.contains('दोहराएं') || lower.contains('पुन्हा') || lower.contains('फिर')) {
      if (_lastSpokenText.isNotEmpty) {
        interaction.runExclusive(() async {
          final tts = Provider.of<TtsService>(context, listen: false);
          await tts.speak(_lastSpokenText, languageCode: _lastSpokenLang);
        });
      }
      return;
    }

    // Detect detection
    if (lower.contains('detect') || lower.contains('डिटेक्ट') || lower.contains('तपासा') || lower.contains('scan') || lower.contains('स्कैन')) {
      _captureAndScan();
    }
  }

  Future<void> _captureAndScan() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    
    final interaction = Provider.of<AppInteractionController>(context, listen: false);
    
    await interaction.runExclusive(() async {
      setState(() => _isProcessing = true);
      final tts = Provider.of<TtsService>(context, listen: false);
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
      
      String scanningMsg = "Scanning medicine...";
      if (lang == 'hi') scanningMsg = "दवा स्कैन कर रहा हूँ...";
      if (lang == 'mr') scanningMsg = "औषध स्कॅन करत आहे...";
      await tts.speak(scanningMsg, languageCode: lang);

      try {
        final image = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        
        _evaluateMedicineInfo(recognizedText, lang, tts);
      } catch (e) {
        debugPrint('Medicine Reader Error: $e');
        String errMsg = "Error scanning medicine.";
        if (lang == 'hi') errMsg = "स्कैन करने में त्रुटि।";
        if (lang == 'mr') errMsg = "स्कॅन करण्यात त्रुटी.";
        await tts.speak(errMsg, languageCode: lang);
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    });
  }

  bool _isQuantityOrGeneric(String word) {
    if (RegExp(r'^\d+\s*[xX*]\s*\d+.*').hasMatch(word)) return true;
    if (RegExp(r'^\d+\s*(mg|ml|mcg|g|kg|tablets|capsules|tabs|caps|pack|strips)', caseSensitive: false).hasMatch(word)) return true;
    
    final lower = word.toLowerCase().trim();
    if (lower == 'tablet' || lower == 'tablets' || lower == 'capsule' || lower == 'capsules') return true;
    if (lower == 'ip' || lower == 'bp') return true;
    
    return false;
  }

  bool _isValidLine(String text) {
    if (text.trim().length < 2) return false; // skip single chars
    if (RegExp(r'^[^a-zA-Z]+$').hasMatch(text.trim())) return false; // skip lines with no letters
    if (RegExp(r'^[A-Z\s]{1}$').hasMatch(text.trim())) return false; // skip lone capital letters
    return true;
  }

  void _evaluateMedicineInfo(RecognizedText text, String lang, TtsService tts) async {
    String medicineName = "not found";
    String warningText = "not found";

    // Priority 1: "Name:" or "Brand:"
    for (var block in text.blocks) {
      for (var line in block.lines) {
        if (!_isValidLine(line.text)) continue;
        String t = line.text;
        final match = RegExp(r'(name|brand)\s*:\s*(.*)', caseSensitive: false).firstMatch(t);
        if (match != null && match.groupCount >= 2 && match.group(2) != null && match.group(2)!.trim().isNotEmpty) {
          medicineName = match.group(2)!.trim();
          break;
        }
      }
      if (medicineName != "not found") break;
    }

    // Priority 2: Title Case or ALL CAPS short brand words via Regex
    if (medicineName == "not found") {
      double maxArea = 0;
      String bestMatch = "not found";
      final regex2 = RegExp(r'^[A-Z][a-zA-Z\-]{2,15}(\s\d+)?$');
      for (var block in text.blocks) {
        for (var line in block.lines) {
          if (!_isValidLine(line.text)) continue;
          String txt = line.text.trim();
          if (regex2.hasMatch(txt)) {
            double area = line.boundingBox.width * line.boundingBox.height;
            if (area > maxArea) {
              maxArea = area;
              bestMatch = txt;
            }
          }
        }
      }
      if (bestMatch != "not found") medicineName = bestMatch;
    }

    // Priority 3: Largest bounding box with filters
    if (medicineName == "not found") {
      double maxArea = 0;
      String bestMatch = "not found";
      for (var block in text.blocks) {
        for (var line in block.lines) {
          if (!_isValidLine(line.text)) continue;
          String txt = line.text.trim();
          int wordCount = txt.split(RegExp(r'\s+')).length;
          if (wordCount <= 2 && !_isQuantityOrGeneric(txt)) {
            double area = line.boundingBox.width * line.boundingBox.height;
            if (area > maxArea) {
              maxArea = area;
              bestMatch = txt;
            }
          }
        }
      }
      if (bestMatch != "not found") medicineName = bestMatch;
    }

    // Warning Detection
    final warningKeywords = ["warning", "caution", "do not", "avoid", "side effect", "schedule h", "prescription", "not for children", "keep out of reach"];
    for (var block in text.blocks) {
      String lowerBlock = block.text.toLowerCase();
      bool found = false;
      for (var kw in warningKeywords) {
        if (lowerBlock.contains(kw)) {
          found = true;
          break;
        }
      }
      if (found) {
        // Collect only valid lines for the warning text
        List<String> validWarningLines = [];
        for (var line in block.lines) {
          if (_isValidLine(line.text)) {
            validWarningLines.add(line.text.trim());
          }
        }
        String wText = validWarningLines.join(' ').trim();
        
        if (wText.isNotEmpty) {
          if (wText.length > 150) {
            warningText = wText.substring(0, 150) + "...";
          } else {
            warningText = wText;
          }
          break;
        }
      }
    }

    // Update UI
    setState(() {
      _uiName = medicineName == "not found" ? "Not Found" : medicineName;
      _uiWarning = warningText == "not found" ? "No Warnings Detected" : warningText;
    });

    // Formulate TTS output
    String ttsOutput = "";
    
    if (medicineName == "not found") {
      if (lang == 'hi') ttsOutput = "लेबल पर दवाई का नाम नहीं मिला। ";
      else if (lang == 'mr') ttsOutput = "लेबलवर औषधाचे नाव सापडले नाही. ";
      else ttsOutput = "Medicine name not found on label. ";
    } else {
      if (lang == 'hi') ttsOutput = "दवाई का नाम है $medicineName. ";
      else if (lang == 'mr') ttsOutput = "औषधाचे नाव आहे $medicineName. ";
      else ttsOutput = "Medicine name is $medicineName. ";
    }

    if (warningText != "not found") {
      if (lang == 'hi') ttsOutput += "चेतावनी: $warningText.";
      else if (lang == 'mr') ttsOutput += "इशारा: $warningText.";
      else ttsOutput += "Warning: $warningText.";
    }

    _lastSpokenText = ttsOutput.trim();
    _lastSpokenLang = lang;

    await tts.speak(_lastSpokenText, languageCode: lang);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Medicine Reader", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black54,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.cyanAccent),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay_circle_filled, color: Colors.cyanAccent, size: 28),
            onPressed: () => _handleCustomVoiceCommand("repeat"),
            tooltip: 'Repeat Output',
          )
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          
          if (_isProcessing) 
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            ),
            
          if (!_isProcessing && (_uiName.isNotEmpty || _uiWarning.isNotEmpty))
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Brand Name:",
                      style: TextStyle(color: Colors.cyanAccent.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _uiName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Warning / Precaution:",
                      style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _uiWarning,
                      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            
          // Mic Button Area
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Consumer2<AppInteractionController, LanguageService>(
              builder: (ctx, interaction, langService, _) {
                final voice = Provider.of<VoiceController>(context);
                final lang = langService.currentLocale.languageCode;
                String promptText = "Say 'Detect' to Scan";
                if (lang == 'hi') promptText = "स्कैन करने के लिए 'डिटेक्ट' बोलें";
                if (lang == 'mr') promptText = "स्कॅन करण्यासाठी 'डिटेक्ट' म्हणा";

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
                      }
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        promptText,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                );
              }
            ),
          )
        ],
      ),
    );
  }
}
