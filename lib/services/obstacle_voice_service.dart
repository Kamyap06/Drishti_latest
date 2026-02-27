import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/voice_utils.dart';

enum VoiceCommand { start, stop, whatIsAroundMe, back, unknown }

class ObstacleVoiceService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _shouldAutoRestart = false;
  bool _isListening = false;
  
  Function(VoiceCommand)? onCommandReceived;
  Function(bool)? onListeningStateChanged;
  
  bool get isListening => _isListening;

  Future<void> init() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint("ObstacleVoiceService Error: ${error.errorMsg}");
          _isListening = false;
          if (_shouldAutoRestart) {
            _restartListening();
          }
        },
        onStatus: (status) {
          debugPrint("ObstacleVoiceService Status: $status");
          _isListening = _speech.isListening;
          if (status == 'notListening' && _shouldAutoRestart) {
            _restartListening();
          }
          onListeningStateChanged?.call(_isListening);
        },
      );
      debugPrint("ObstacleVoiceService Initialization: $_isInitialized");
    } catch (e) {
      debugPrint("ObstacleVoiceService init exception: $e");
    }
  }

  Future<void> resumeListening() async {
    _shouldAutoRestart = true;
    if (_speech.isListening) return;
    
    if (!_isInitialized) {
      await init();
    }
    
    try {
      debugPrint("ObstacleVoiceService: resumeListening()");
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      debugPrint("ObstacleVoiceService listen error: $e");
    }
  }

  Future<void> pauseListening() async {
    debugPrint("ObstacleVoiceService: pauseListening()");
    _shouldAutoRestart = false;
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      debugPrint("ObstacleVoiceService pause error: $e");
    }
  }

  Future<void> stopListening() async {
    debugPrint("ObstacleVoiceService: stopListening()");
    _shouldAutoRestart = false;
    try {
      await _speech.cancel();
      _isListening = false;
    } catch (e) {
      debugPrint("ObstacleVoiceService cancel error: $e");
    }
  }

  void _restartListening() {
    debugPrint("ObstacleVoiceService: _restartListening()");
    if (_shouldAutoRestart && !_speech.isListening) {
      // FIX: Increase delay to 800ms
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_shouldAutoRestart && !_speech.isListening) {
          resumeListening();
        }
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      String words = result.recognizedWords.toLowerCase().trim();
      
      // DIAGNOSE: Mic output debug
      debugPrint('MIC HEARD: "$words"');
      
      VoiceCommand command = _parseCommand(words);
      debugPrint('MIC PARSED: $command');
      
      if (command != VoiceCommand.unknown && onCommandReceived != null) {
        debugPrint("ObstacleVoiceService command detected: $command");
        onCommandReceived!(command);
      }
    }
  }

  VoiceCommand _parseCommand(String text) {
    if (VoiceUtils.getIntent(text) == VoiceIntent.back) {
      return VoiceCommand.back;
    }

    // Removed short fragment heuristic to support 1-word commands fully

    if (text.contains('start') || text.contains('go') || text.contains('on ') || text.contains('begin')) {
      return VoiceCommand.start;
    } else if (text.contains('stop') || text.contains('off') || text.contains('halt') || text.contains('pause')) {
      return VoiceCommand.stop;
    } else if (text.contains('what') || text.contains('around') || text.contains('describe') || text.contains('scan') || text.contains('look')) {
      return VoiceCommand.whatIsAroundMe;
    }
    
    return VoiceCommand.unknown;
  }

  void dispose() {
    debugPrint("ObstacleVoiceService: dispose() called");
    _shouldAutoRestart = false;
    _speech.cancel();
  }
}
