import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../core/voice_utils.dart';
import 'tts_service.dart';
import 'dart:io';

class VoiceController with ChangeNotifier {
  static final VoiceController _instance = VoiceController._internal();
  factory VoiceController() => _instance;
  VoiceController._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  VoiceState _state = VoiceState.idle;
  
  String _currentLocaleId = 'en_IN';
  Function(String)? _onResultCallback;
  TtsService? _ttsService;
  
  bool _isTtsSpeaking = false;
  bool _shouldBeListening = false;
  bool _isAwaitingCommand = true;
  bool _isAwaitingFieldInput = false;
  
  bool _isRestarting = false; // Guard against concurrent restarts
  
  Timer? _keepAliveTimer;
  DateTime? _lastResultTime;
  DateTime? _inputBlackoutUntil;
  DateTime? _partialResultThrottle;

  VoiceState get state => _state;
  bool get isListening => _state == VoiceState.listening;
  bool get isAvailable => _isAvailable;
  bool get isTtsSpeaking => _isTtsSpeaking;
  bool get isAwaitingCommand => _isAwaitingCommand;
  bool get isAwaitingFieldInput => _isAwaitingFieldInput;

  void setInputExpectation({required bool isCommand, required bool isField}) {
    _isAwaitingCommand = isCommand;
    _isAwaitingFieldInput = isField;
    notifyListeners();
  }

  bool _micPermissionGranted = false;

  void _updateState(VoiceState newState) {
    if (_state == newState) return;
    debugPrint('VoiceController: STATE TRANSITION: $_state -> $newState');
    _state = newState;
    notifyListeners();

    // Auto-restart on error after delay
    if (newState == VoiceState.error && _shouldBeListening) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_shouldBeListening && _state == VoiceState.error) {
          debugPrint('VoiceController: Attempting auto-restart after error...');
          _resumeListening();
        }
      });
    }
  }

  void setTtsService(TtsService tts) {
    _ttsService = tts;
    _ttsService?.setCompletionHandler(() {
      debugPrint('VoiceController: TTS Completed');
      _isTtsSpeaking = false;
      
      // Fix 1: Add blackout window after TTS
      _inputBlackoutUntil = DateTime.now().add(const Duration(milliseconds: 1200));
      
      notifyListeners();
      
      if (_shouldBeListening) {
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (_shouldBeListening && !_isTtsSpeaking) {
            if (Platform.isIOS) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
            _resumeListening();
          }
        });
      }
    });
  }

  Future<bool> init() async {
    if (_isAvailable && _micPermissionGranted) return true;
    _updateState(VoiceState.initializing);

    // Initial permission check (request only once)
    if (!_micPermissionGranted) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      _micPermissionGranted = status.isGranted;
    }

    if (!_micPermissionGranted) {
      _updateState(VoiceState.error);
      return false;
    }

    try {
      _isAvailable = await _speech.initialize(
        onError: (error) async {
          debugPrint('VoiceController: Error: $error');
          _isAvailable = false;
          _updateState(VoiceState.error);
          
          // Force cancel on error to reset session
          await _speech.cancel();
          _handleStreamDrop();
        },
        onStatus: (status) {
          debugPrint('VoiceController: Status: $status');
          if (status == 'listening') {
            _isRestarting = false;
            _updateState(VoiceState.listening);
            _lastResultTime = DateTime.now();
          } else if (status == 'notListening') {
            if (_state != VoiceState.processing) {
              _updateState(VoiceState.idle);
            }
            _handleStreamDrop();
          }
        },
      );
    } catch (e) {
      debugPrint('VoiceController: Init exception: $e');
      _isAvailable = false;
      _updateState(VoiceState.error);
    }
    return _isAvailable;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required String languageCode,
  }) async {
    _onResultCallback = onResult;
    _currentLocaleId = AppConstants.ttsLocales[languageCode] ?? 'en_IN';
    _shouldBeListening = true;

    if (_isTtsSpeaking) return;

    await _resumeListening();
    _startKeepAlive();
  }

  Future<void> _resumeListening() async {
    if (_isRestarting && _speech.isListening) return;
    
    if (!_isAvailable || !_micPermissionGranted) {
      await init();
      if (!_isAvailable || !_micPermissionGranted) return;
    }

    if (_speech.isListening) return;
    _isRestarting = true;

    try {
      // Fix 3: Variable durations
      Duration pauseFor = _isAwaitingFieldInput 
          ? const Duration(seconds: 5) 
          : const Duration(seconds: 3);
      
      await _speech.listen(
        onResult: (result) {
          // Fix 5: Throttle partial results
          if (!result.finalResult) {
            final now = DateTime.now();
            if (_partialResultThrottle != null && 
                now.difference(_partialResultThrottle!).inMilliseconds < 300) {
              return;
            }
            _partialResultThrottle = now;
            // We still don't notifyListeners or call callback for partials to prevent jank
            return; 
          }

          // Fix 1: Check blackout window — but NEVER discard back/retry (Fix 5).
          // Back/retry must interrupt TTS unconditionally; they bypass the blackout.
          if (_inputBlackoutUntil != null && DateTime.now().isBefore(_inputBlackoutUntil!)) {
            final intent = VoiceUtils.getIntent(result.recognizedWords);
            if (intent != VoiceIntent.back && intent != VoiceIntent.retry) {
              debugPrint('VoiceController: Discarding STT result during blackout window');
              return;
            }
            debugPrint('VoiceController: Back/Retry bypasses blackout — forwarding immediately');
          }

          _lastResultTime = DateTime.now();
          _updateState(VoiceState.processing);
          debugPrint('VoiceController: Heard Final: ${result.recognizedWords}');
          
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!_shouldBeListening) return;
            _onResultCallback?.call(result.recognizedWords);
            
            if (_shouldBeListening && !_isTtsSpeaking) {
              _resumeListening();
            }
          });
        },
        localeId: _currentLocaleId,
        listenFor: const Duration(seconds: 30),
        pauseFor: pauseFor,
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      _isRestarting = false;
      debugPrint('VoiceController: Listen Error: $e');
      _handleStreamDrop();
    }
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_shouldBeListening && !_isTtsSpeaking && !_speech.isListening && !_isRestarting) {
        debugPrint('VoiceController: Keep-alive triggering restart...');
        _isRestarting = true;
        // Systematically stop before resume to avoid engine state conflicts
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 300));
        await _resumeListening();
        _isRestarting = false;
      }
    });
  }

  void _handleStreamDrop() {
    if (_shouldBeListening && !_isTtsSpeaking) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_shouldBeListening && !_isTtsSpeaking && !_speech.isListening) {
          _resumeListening();
        }
      });
    }
  }

  Future<void> stop() async {
    _shouldBeListening = false;
    _keepAliveTimer?.cancel();
    await _speech.stop();
    _updateState(VoiceState.idle);
  }

  Future<void> resetSession() async {
    debugPrint('VoiceController: performing FULL SESSION RESET');
    _shouldBeListening = false;
    _keepAliveTimer?.cancel();
    
    await _speech.cancel();
    await Future.delayed(const Duration(milliseconds: 400));
    await _speech.stop();

    _isAvailable = false;
    _isRestarting = false;
    _onResultCallback = null;
    _isTtsSpeaking = false;
    _isAwaitingCommand = true;
    _isAwaitingFieldInput = false;
    _lastResultTime = null;
    
    _updateState(VoiceState.idle);
    await init();
  }

  Future<void> speakWithGuard(
    String text,
    String languageCode,
    {Function(String)? onResult}
  ) async {
    if (_ttsService == null) return;

    _shouldBeListening = true; // Still want to listen after TTS finishes
    if (onResult != null) _onResultCallback = onResult;

    // Explicitly force mic OFF while speaking to prevent echoing
    await _speech.stop();
    _updateState(VoiceState.idle);

    int retryCount = 0;
    while (_speech.isListening && retryCount < 10) {
      debugPrint('VoiceController: Waiting for mic to stop... (attempt ${retryCount + 1})');
      await Future.delayed(const Duration(milliseconds: 200));
      retryCount++;
    }

    _isTtsSpeaking = true;
    notifyListeners();

    await _ttsService!.speak(text, languageCode: languageCode);
  }
}
