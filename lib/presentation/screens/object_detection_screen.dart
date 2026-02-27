import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import '../../services/app_interaction_controller.dart';
import '../../services/onnx_model_service.dart';
import '../../services/obstacle_alert_service.dart';
import '../../services/obstacle_voice_service.dart';
import '../../models/detection.dart';
import '../widgets/detection_painter.dart';
import '../../services/voice_controller.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../widgets/mic_widget.dart';

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  State<ObjectDetectionScreen> createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  late CameraController _cameraController;
  final OnnxModelService _modelService = OnnxModelService();
  final ObstacleAlertService _alertService = ObstacleAlertService();
  final ObstacleVoiceService _voiceService = ObstacleVoiceService();

  bool _isCameraInitialized = false;
  bool _isScanning = false;
  
  // FIX 4: Processing Guard
  bool _isProcessing = false;
  List<Detection> _currentDetections = [];
  
  // Temporal Smoothing / Stability
  List<Detection> _previousDetections = [];
  int _stableFrameCount = 0;
  static const int _stabilityThreshold = 0;

  // FIX 2: Announcement Throttling
  String _lastAnnouncedLabel = '';
  DateTime _lastAnnouncedTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _announceGapMs = 3000; 

  // Performance throttling
  int _lastFrameTime = 0;
  final int _frameThrottleMs = 600; 

  int _lastVibrationTime = 0;
  final int _vibrationCooldownMs = 800;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _modelService.initModel();
    await _alertService.init();
    
    _alertService.onTtsComplete = () {
      if (_isScanning) {
        _voiceService.resumeListening();
      }
    };
    
    _alertService.pauseListening = () {
      _voiceService.pauseListening();
    };

    _voiceService.onCommandReceived = (command) async {
      if (command == VoiceCommand.back) {
        _stopScanning();
        if (mounted) {
          final interaction = Provider.of<AppInteractionController>(context, listen: false);
          await interaction.handleGlobalBack();
        }
      } else if (command == VoiceCommand.stop) {
        _stopScanning();
        if (mounted) {
          final interaction = Provider.of<AppInteractionController>(context, listen: false);
          final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
          final tts = Provider.of<TtsService>(context, listen: false);
          
          String prompt = "Detection stopped. Say detect to resume or say back.";
          if (lang == 'hi') prompt = "डिटेक्शन रोक दिया गया है। फिर से शुरू करने के लिए 'डिटेक्ट' बोलें या 'वापस' बोलें।";
          if (lang == 'mr') prompt = "डिटेक्शन थांबवले आहे. पुन्हा सुरू करण्यासाठी 'डिटेक्ट' म्हणा किंवा 'मागे' म्हणा।";
          
          await tts.speak(prompt, languageCode: lang);
          interaction.startGlobalListening(languageCode: lang);
        }
      }
    };

    Future.microtask(() async {
      if (mounted) {
        final interaction = Provider.of<AppInteractionController>(context, listen: false);
        final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
        final tts = Provider.of<TtsService>(context, listen: false);
        
        interaction.setActiveFeature(ActiveFeature.objectDetection);
        
        interaction.registerFeatureCallbacks(
          onDetect: () {
            interaction.stopGlobalListening();
            if (!_isScanning) _startScanning();
          },
          onBack: () async {
            _stopScanning();
            await interaction.handleGlobalBack();
          }
        );

        String prompt = "Say detect to start detection or say back.";
        if (lang == 'hi') prompt = "डिटेक्शन शुरू करने के लिए 'डिटेक्ट' बोलें या वापस जाने के लिए 'वापस' बोलें।";
        if (lang == 'mr') prompt = "डिटेक्शन सुरू करण्यासाठी 'डिटेक्ट' म्हणा किंवा मागे जाण्यासाठी 'मागे' म्हणा।";
        
        await tts.speak(prompt, languageCode: lang);
        interaction.startGlobalListening(languageCode: lang);
      }
    });

    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      // FIX: Select BACK camera explicitly
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // FIX: Use NV21
      );

      await _cameraController.initialize();
      
      try {
        await _cameraController.setFocusMode(FocusMode.auto);
        await _cameraController.setExposureMode(ExposureMode.auto);
        debugPrint('CAMERA: Auto focus and exposure set');
      } catch (e) {
        debugPrint('CAMERA: Focus/exposure not supported: $e');
      }
      
      // FIX 3: Set exposure to avoid overexposure
      try {
        final minExposure = await _cameraController.getMinExposureOffset();
        await _cameraController.setExposureOffset(minExposure * 0.3);
        debugPrint('CAMERA: Exposure set to ${minExposure * 0.3}');
      } catch (e) {
        debugPrint('CAMERA: Exposure control not supported: $e');
      }

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    }
  }

  void _startScanning() {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    _voiceService.resumeListening();
    
    _cameraController.startImageStream((image) {
      if (!_isProcessing && _isScanning) {
        // Use Future.microtask to prevent blocking camera pipeline
        Future.microtask(() => _processFrame(image));
      }
    });
  }

  void _stopScanning() {
    setState(() => _isScanning = false);
    if (_cameraController.value.isStreamingImages) {
      _cameraController.stopImageStream();
    }
    _alertService.stop();
    _voiceService.pauseListening();
  }

  Future<void> _processFrame(CameraImage image) async {
    // FIX 4: Correct _isProcessing block
    if (_isProcessing || !_isScanning) {
       if (_isProcessing) debugPrint('FRAME BLOCKED: still processing');
       return;
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final bool passedThrottle = nowMs - _lastFrameTime >= _frameThrottleMs;
    // FIX 6: Throttle Check
    debugPrint('THROTTLE CHECK: elapsed=${nowMs - _lastFrameTime}ms threshold=$_frameThrottleMs passed=$passedThrottle');
    
    if (!passedThrottle) return;

    _isProcessing = true;
    _lastFrameTime = nowMs;

    try {
      List<Detection> detections = await _modelService.detect(image);
      
      // DIAGNOSE: Frame processing debug
      debugPrint('═══ FRAME PROCESSED ═══');
      debugPrint('Detections: ${detections.length}');
      debugPrint('isSpeaking: ${_alertService.isSpeaking}');
      debugPrint('isListening: ${_voiceService.isListening}');
      debugPrint('stableFrameCount: $_stableFrameCount');
      for (var d in detections) {
        debugPrint('  → ${d.label} ${(d.confidence*100).toStringAsFixed(1)}% zone=${d.zone} dist=${d.distanceTier}');
      }

      if (mounted && _isScanning) {
        bool isSimilar = _isSimilarToLastFrame(detections, _previousDetections);
        if (isSimilar) {
          _stableFrameCount++;
        } else {
          _stableFrameCount = 0;
        }
        _previousDetections = detections;

        if (_stableFrameCount >= _stabilityThreshold) {
          setState(() {
            _currentDetections = detections;
          });

          if (detections.isNotEmpty) {
            detections.sort((a, b) => b.urgency.compareTo(a.urgency));
            final Detection topThreat = detections.first;

            if (topThreat.urgency >= 3) {
              if (nowMs - _lastVibrationTime > _vibrationCooldownMs) {
                _lastVibrationTime = nowMs;
                final bool hasVibrator = await Vibration.hasVibrator() ?? false;
                if (hasVibrator) {
                  Vibration.vibrate(duration: 300, amplitude: topThreat.urgency == 4 ? 255 : 128);
                }
              }
            }

            // FIX 2: Announcement logic with gap tracking
            final now = DateTime.now();
            final sameLabel = topThreat.label == _lastAnnouncedLabel;
            final tooSoon = now.difference(_lastAnnouncedTime).inMilliseconds < _announceGapMs;

            // FIX 4: Lower TTS confidence gate
            if (topThreat.confidence >= 0.15 && !_alertService.isSpeaking && !(sameLabel && tooSoon)) {
              _lastAnnouncedLabel = topThreat.label;
              _lastAnnouncedTime = now;
              _voiceService.pauseListening();
              final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
              await _alertService.announceDetection(topThreat, lang);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Process frame error: $e");
    } finally {
      _isProcessing = false;
      debugPrint('FRAME DONE: _isProcessing reset');
    }
  }

  bool _isSimilarToLastFrame(List<Detection> current, List<Detection> previous) {
    if (current.isEmpty && previous.isEmpty) return true;
    if (current.isEmpty || previous.isEmpty) return false;
    final currentLabels = current.map((d) => '${d.label}-${d.zone}').toSet();
    final previousLabels = previous.map((d) => '${d.label}-${d.zone}').toSet();
    return currentLabels.intersection(previousLabels).isNotEmpty;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _modelService.dispose();
    _alertService.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Virtual Walking Stick"),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_cameraController)),
          Positioned.fill(
            child: CustomPaint(
              painter: DetectionPainter(
                detections: _currentDetections,
                previewSize: _cameraController.value.previewSize!,
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(_isScanning ? Icons.radar : Icons.stop_circle, color: _isScanning ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text(_isScanning ? "Scanning Active" : "Scanning Paused", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
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
                    String promptText = "Say 'Detect' to start or 'Back'";
                    if (lang == 'hi') promptText = "शुरू करने के लिए 'डिटेक्ट' या 'वापस' बोलें";
                    if (lang == 'mr') promptText = "सुरू करण्यासाठी 'डिटेक्ट' किंवा 'मागे' म्हणा";

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
