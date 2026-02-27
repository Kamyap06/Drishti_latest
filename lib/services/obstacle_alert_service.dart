import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/detection.dart';

class ObstacleAlertService {
  final FlutterTts _tts = FlutterTts();
  
  VoidCallback? onTtsComplete;
  VoidCallback? pauseListening;
  
  final Map<String, int> _lastAnnouncedLabelTime = {};
  int _lastAnyAnnouncementTime = 0;
  String _lastAlertMessage = '';
  
  static const int _perLabelCooldownMs = 2000;
  static const int _dangerCooldownMs = 600;
  static const int _normalCooldownMs = 1500;
  
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  
  Future<void> init() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.6);
      await _tts.setPitch(1.0);
      
      // FIX 1: Delay resume of microphone after TTS
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint("ObstacleAlertService: TTS Complete");
        Future.delayed(const Duration(milliseconds: 1500), () {
          onTtsComplete?.call();
        });
      });
      
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        debugPrint("ObstacleAlertService: TTS Cancelled");
        Future.delayed(const Duration(milliseconds: 1500), () {
          onTtsComplete?.call();
        });
      });
      
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint("ObstacleAlertService: TTS Error: $msg");
        onTtsComplete?.call();
      });
    } catch (e) {
      debugPrint("ObstacleAlertService init error: $e");
    }
  }

  Future<void> announceDetection(Detection detection, String lang) async {
    int nowMs = DateTime.now().millisecondsSinceEpoch;
    bool isDanger = detection.urgency >= 3;
    int cooldown = isDanger ? _dangerCooldownMs : _normalCooldownMs;
    int elapsed = nowMs - _lastAnyAnnouncementTime;
    String message = detection.toAlertMessage(lang);

    // DIAGNOSE: Alert debug logs
    debugPrint('ALERT: trying to speak "$message"');
    debugPrint('ALERT: isSpeaking=$_isSpeaking elapsed=${elapsed}ms cooldown=${cooldown}ms');
    debugPrint('ALERT: lastMessage="$_lastAlertMessage"');

    if (_isSpeaking) return;
    if (elapsed < cooldown) return; 
    
    int labelLastTime = _lastAnnouncedLabelTime[detection.label] ?? 0;
    if (nowMs - labelLastTime < _perLabelCooldownMs && !isDanger) {
      return;
    }
    
    _lastAnyAnnouncementTime = nowMs;
    _lastAnnouncedLabelTime[detection.label] = nowMs;
    _lastAlertMessage = message;
    
    await speakImmediate(message, lang: lang);
  }
  
  Future<void> speakImmediate(String text, {String lang = 'en'}) async {
    try {
      debugPrint("ObstacleAlertService: Speaking: $text");
      if (pauseListening != null) {
        pauseListening!();
      }
      
      _isSpeaking = true;
      String ttsLang = 'en-US';
      if (lang == 'hi') ttsLang = 'hi-IN';
      if (lang == 'mr') ttsLang = 'mr-IN';
      await _tts.setLanguage(ttsLang);
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      debugPrint("ObstacleAlertService speak error: $e");
      onTtsComplete?.call();
    }
  }

  // FIX: Complete stop and dispose implementation
  Future<void> stop() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('stop error: $e');
    }
  }

  void dispose() {
    debugPrint("ObstacleAlertService: dispose() called");
    _tts.stop();
    _isSpeaking = false;
    onTtsComplete = null;
    pauseListening = null;
  }
}
