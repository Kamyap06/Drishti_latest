import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../widgets/mic_widget.dart';
import '../../services/app_interaction_controller.dart';
import '../../services/translation_manager.dart';
import '../../services/speech_formatter.dart';
import 'dart:io';

class ImageToSpeechScreen extends StatefulWidget {
  const ImageToSpeechScreen({Key? key}) : super(key: key);

  @override
  State<ImageToSpeechScreen> createState() => _ImageToSpeechScreenState();
}

class _ImageToSpeechScreenState extends State<ImageToSpeechScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);
  
  // Conversation State
  bool _askingToTranslate = false;
  bool _askingLanguage = false;
  String _lastExtractedText = "";
  String _detectedLangCode = "";

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
    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _announce() async {
    final interaction = Provider.of<AppInteractionController>(context, listen: false);
    interaction.setActiveFeature(ActiveFeature.imageSpeech);
    interaction.registerFeatureCallbacks(
      onDetect: _captureAndProcess,
      onCommand: _handleVoiceCommand,
      onBack: () async {
        await interaction.handleGlobalBack();
      },
      onDispose: () {
        _textRecognizer.close();
        TranslationManager().dispose();
      },
    );

    await interaction.runExclusive(() async {
      final tts = Provider.of<TtsService>(context, listen: false);
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
      String prompt = "Image to Speech. Say Detect to read text.";
      if (lang == 'hi') prompt = "इमेज टू स्पीच। स्कैन करने के लिए 'डिटेक्ट' बोलें।";
      if (lang == 'mr') prompt = "इमेज टू स्पीच। स्कॅन करण्यासाठी 'डिटेक्ट' म्हणा.";
      await tts.speak(prompt, languageCode: lang);
    });
    
    final langService = Provider.of<LanguageService>(context, listen: false);
    interaction.startGlobalListening(languageCode: langService.currentLocale.languageCode);
  }

  void _handleVoiceCommand(String text) {
    String t = text.toLowerCase();
    
    if (t.contains("back")) {
      final tts = Provider.of<TtsService>(context, listen: false);
      final interaction = Provider.of<AppInteractionController>(context, listen: false);
      tts.stop();
      interaction.handleGlobalBack();
      return;
    }

    if (_askingToTranslate) {
      if (t.contains("yes") || t.contains("haan") || t.contains("ho") || t.contains("हाँ") || t.contains("हो") || t.contains("होय") || t.contains("ha") || t.contains("हा")) {
        _askingToTranslate = false;
        _askingLanguage = true;
        _askWhichLanguage();
      } else if (t.contains("no") || t.contains("nahi") || t.contains("nako") || t.contains("ना") || t.contains("नहीं") || t.contains("नाही")) {
         _askingToTranslate = false;
         _reset();
      }
    } else if (_askingLanguage) {
      _handleTranslationRequest(t);
    } else {
         if (t.contains("detect") || t.contains("read")) {
           _captureAndProcess();
         }
    }
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    
    final interaction = Provider.of<AppInteractionController>(context, listen: false);

    await interaction.runExclusive(() async {
      setState(() => _isProcessing = true);
      final tts = Provider.of<TtsService>(context, listen: false);
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
      String reading = "Reading...";
      if (lang == 'hi') reading = "पढ़ रहा हूँ...";
      if (lang == 'mr') reading = "वाचत आहे...";
      await tts.speak(reading, languageCode: lang);

      try {
        final image = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        
        _lastExtractedText = recognizedText.text;
        
        if (_lastExtractedText.isEmpty || _lastExtractedText.trim().isEmpty) {
          String noText = "No text found.";
          if (lang == 'hi') noText = "कोई लिखावट नहीं मिली।";
          if (lang == 'mr') noText = "कोणतीही माहिती आढळली नाही.";
          await tts.speak(noText, languageCode: lang);
          _reset();
        } else {
          _detectedLangCode = await TranslationManager().identifyLanguage(_lastExtractedText);

          String announcement = "Captured information: "; 
          if (lang == 'hi') announcement = "कैप्चर की गई जानकारी: ";
          if (lang == 'mr') announcement = "कॅप्चर केलेली माहिती: ";
          
          await tts.speak(announcement, languageCode: lang);
          await Future.delayed(const Duration(milliseconds: 300));
          await tts.speak(_lastExtractedText, languageCode: _detectedLangCode.isNotEmpty ? _detectedLangCode : lang);
          
          setState(() => _askingToTranslate = true);
          String prompt = "Do you want to translate it? Say yes or no.";
          if (lang == 'hi') prompt = "क्या आप इसे ट्रांसलेट करना चाहते हैं? हाँ या ना बोलें।";
          if (lang == 'mr') prompt = "तुम्हाला हे ट्रांसलेट करायचे आहे का? होय किंवा नाही सांगा.";
          
          await tts.speak(prompt, languageCode: lang);
        }

      } catch (e) {
        debugPrint('OCR Error: $e');
        String err = "Error processing.";
        if (lang == 'hi') err = "प्रक्रिया में त्रुटि।";
        if (lang == 'mr') err = "प्रक्रियेत त्रुटी.";
        await tts.speak(err, languageCode: lang);
        _reset();
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }



  Future<void> _askWhichLanguage() async {
    final interaction = Provider.of<AppInteractionController>(context, listen: false);
    await interaction.runExclusive(() async {
      final tts = Provider.of<TtsService>(context, listen: false);
      final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
      
      String prompt = "Which language do you want to translate to?";
      if (_detectedLangCode == 'en') {
        prompt = "Which language? Hindi or Marathi?";
        if (lang == 'hi') prompt = "आप किस भाषा में ट्रांसलेट करना चाहते हैं? हिंदी या मराठी?";
        if (lang == 'mr') prompt = "तुम्हाला कोणत्या भाषेत ट्रांसलेट करायचे आहे? हिंदी की मराठी?";
      } else if (_detectedLangCode == 'hi') {
        prompt = "Which language? English or Marathi?";
        if (lang == 'hi') prompt = "आप किस भाषा में ट्रांसलेट करना चाहते हैं? इंग्लिश या मराठी?";
        if (lang == 'mr') prompt = "तुम्हाला कोणत्या भाषेत ट्रांसलेट करायचे आहे? इंग्रजी की मराठी?";
      } else if (_detectedLangCode == 'mr') {
        prompt = "Which language? English or Hindi?";
        if (lang == 'hi') prompt = "आप किस भाषा में ट्रांसलेट करना चाहते हैं? इंग्लिश या हिंदी?";
        if (lang == 'mr') prompt = "तुम्हाला कोणत्या भाषेत ट्रांसलेट करायचे आहे? इंग्रजी की हिंदी?";
      } else {
        prompt = "Which language? English, Hindi or Marathi?";
        if (lang == 'hi') prompt = "आप किस भाषा में ट्रांसलेट करना चाहते हैं? इंग्लिश, हिंदी या मराठी?";
        if (lang == 'mr') prompt = "तुम्हाला कोणत्या भाषेत ट्रांसलेट करायचे आहे? इंग्रजी, हिंदी की मराठी?";
      }

      await tts.speak(prompt, languageCode: lang);
    });
  }

  Future<void> _handleTranslationRequest(String text) async {
    final interaction = Provider.of<AppInteractionController>(context, listen: false);
    
    await interaction.runExclusive(() async {
       setState(() => _isProcessing = true);
       final tts = Provider.of<TtsService>(context, listen: false);
       String t = text.toLowerCase();
       String targetLangCode = 'hi'; // Default

       if (t.contains("marathi") || t.contains("मराठी")) {
         targetLangCode = 'mr';
       } else if (t.contains("english") || t.contains("अंग्रेज़ी") || t.contains("इंग्रजी")) { 
         targetLangCode = 'en';
       } else if (t.contains("hindi") || t.contains("हिंदी") || t.contains("हिन्दी")) {
         targetLangCode = 'hi';
       } else {
         final langService = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
         targetLangCode = langService;
       }

       final activeLang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
       String loading = "Translating...";
       if (activeLang == 'hi') loading = "ट्रांसलेट कर रहा हूँ, कृपया प्रतीक्षा करें...";
       if (activeLang == 'mr') loading = "ट्रांसलेट करत आहे, कृपया प्रतीक्षा करा...";
       await tts.speak(loading, languageCode: activeLang);

       try {
         final detectedLang = _detectedLangCode.isNotEmpty ? _detectedLangCode : await TranslationManager().identifyLanguage(_lastExtractedText);
         final translated = await TranslationManager().translate(
           _lastExtractedText, 
           detectedLang, 
           targetLangCode
         );
         
         await tts.speak(translated, languageCode: targetLangCode);
       } catch (e) {
          debugPrint("Translation error: $e");
          final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
          await tts.speak("Error translating text.", languageCode: lang);
       } finally {
         if (mounted) setState(() => _isProcessing = false);
         _reset();
       }
    });
  }

  void _reset() {
    _askingToTranslate = false;
    _askingLanguage = false;
    _lastExtractedText = "";
    _detectedLangCode = "";
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Scan Text")),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          if (_isProcessing) const Center(child: CircularProgressIndicator()),
          Positioned(
             bottom: 20, left: 0, right: 0,
             child: Column(
               children: [
                 Consumer2<AppInteractionController, LanguageService>(
                   builder: (ctx, interaction, langService, _) {
                     final voice = Provider.of<VoiceController>(context);
                     final lang = langService.currentLocale.languageCode;
                     String promptText = "Say 'Detect' to read or 'Back'";
                     if (lang == 'hi') promptText = "पढ़ने के लिए 'डिटेक्ट' या 'वापस' बोलें";
                     if (lang == 'mr') promptText = "वाचण्यासाठी 'डिटेक्ट' किंवा 'मागे' म्हणा";

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
                   }
                 )
               ]
             )
          )
        ],
      ),
    );
  }
}

