import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../../core/voice_utils.dart';
import '../../core/registration_feedback_formatter.dart';
import '../../core/credential_normalizer.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../widgets/mic_widget.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

enum RegStep {
  username,
  confirmUsername,
  password,
  biometric,
  confirmRegister,
  processing,
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final BiometricService _biometricService = BiometricService();

  RegStep _currentStep = RegStep.username;
  String _tempUsername = "";

  bool _isProcessing = false;
  bool _isBiometricPending = false;
  bool _biometricAuthenticated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _initVoiceFlow();
    });
  }

  void _initVoiceFlow() async {
    // Initial delay to let TTS service be ready
    await Future.delayed(const Duration(milliseconds: 500));
    _speakPromptForStep();
    _startPersistentListening();
  }

  void _startPersistentListening() {
    final voice = Provider.of<VoiceController>(context, listen: false);
    final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;

    // Set expectation: commands + fields at start
    voice.setInputExpectation(isCommand: true, isField: true);

    voice.startListening(
      languageCode: lang,
      onResult: (text) {
        // ALWAYS process intents, only block fields if speaking
        _handleVoiceInput(text);
      },
    );
  }

  Future<void> _speakPrompt(String message, String lang) async {
    if (!mounted) return;
    final voice = Provider.of<VoiceController>(context, listen: false);
    
    // VoiceController.speakWithGuard handles stopping mic, speaking, 
    // and restarting mic after completion.
    await voice.speakWithGuard(
      message, 
      lang, 
      onResult: (text) => _handleVoiceInput(text),
    );
  }

  Future<void> _speakPromptForStep() async {
    if (!mounted) return;

    final lang = Provider.of<LanguageService>(
      context,
      listen: false,
    ).currentLocale.languageCode;
    String prompt = "";

    switch (_currentStep) {
      case RegStep.username:
        prompt = "Please say your desired Username.";
        if (lang == 'hi') prompt = "कृपया अपना वांछित Username बोलें।";
        if (lang == 'mr') prompt = "कृपया आपले इच्छित Username बोला.";
        break;
      case RegStep.confirmUsername:
        prompt =
            "You said $_tempUsername. Say 'Next' to confirm, or 'Retry' to change.";
        if (lang == 'hi')
          prompt =
              "आपने कहा $_tempUsername. पुष्टि के लिए 'आगे' बोलें, या बदलने के लिए 'दोबारा' बोलें।";
        if (lang == 'mr')
          prompt =
              "तुम्ही म्हणालात $_tempUsername. पुष्टी करण्यासाठी 'पुढे' म्हणा, किंवा बदलण्यासाठी 'पुन्हा' म्हणा.";
        break;
      case RegStep.password:
        prompt = "Please say your Password, minimum six characters.";
        if (lang == 'hi')
          prompt =
              "कृपया अपना Password बोलें, कम से कम छह अक्षर का होना चाहिए।";
        if (lang == 'mr')
          prompt = "कृपया आपला Password बोला, किमान सहा अक्षरांचा असावा.";
        break;
      case RegStep.biometric:
        prompt =
            "Please authenticate with your fingerprint to secure your account.";
        if (lang == 'hi')
          prompt =
              "अपने खाते को सुरक्षित करने के लिए कृपया अपने फिंगरप्रिंट से प्रमाणित करें।";
        if (lang == 'mr')
          prompt =
              "आपले खाते सुरक्षित करण्यासाठी कृपया आपल्या फिंगरप्रिंट प्रमाणित करा.";
        break;
      case RegStep.confirmRegister:
        prompt =
            "All set. Say 'Register' to create your account, or 'Back' to start over.";
        if (lang == 'hi')
          prompt =
              "सब तैयार है। खाता बनाने के लिए 'नोंदणी' बोलें, या शुरू से शुरू करने के लिए 'पीछे' बोलें।";
        if (lang == 'mr')
          prompt =
              "सर्व सेट आहे. खाते तयार करण्यासाठी 'नोंदणी' म्हणा, किंवा पुन्हा सुरू करण्यासाठी 'मागे' म्हणा.";
        break;
      case RegStep.processing:
        return;
    }

    await _speakPrompt(prompt, lang);

    // Trigger biometric automatically after speak
    if (_currentStep == RegStep.biometric && mounted) {
      if (_isBiometricPending) return;
      final voice = Provider.of<VoiceController>(context, listen: false);
      // Wait for TTS to finish before biometric request
      // (The completion handler in VoiceController will set isTtsSpeaking = false)
      
      // Wait a bit for the prompt to finish if not already
      while (voice.isTtsSpeaking && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;
      await voice.stop(); // Ensure stopped for biometrics

      setState(() => _isBiometricPending = true);

      try {
        bool params = await _biometricService.authenticate();

        if (mounted) {
          // Reclaim audio focus after biometric
          await voice.resetSession();

          if (params) {
            setState(() {
              _biometricAuthenticated = true;
              _currentStep = RegStep.confirmRegister;
            });
            _speakPromptForStep();
          } else {
            setState(() {
              _biometricAuthenticated = false;
            });
            await _speakPrompt(
              "Biometric authentication failed. Please try again.",
              lang,
            );
            _speakPromptForStep();
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isBiometricPending = false);
        }
      }
    }
  }

  // Issue 3: Removed addPostFrameCallback wrapper — intent detection now runs
  // synchronously, matching LoginScreen. The 1200ms blackout in VoiceController
  // is the correct protection against TTS echo; the extra frame-deferral was
  // an unnecessary indirection that could mask ordering problems.
  void _handleVoiceInput(String text) async {
    if (!mounted) return;
    final voice = Provider.of<VoiceController>(context, listen: false);

    final intent = VoiceUtils.getIntent(text);
    print("RegIntent Trace: intent=$intent, Raw: $text");

    if (intent != VoiceIntent.unknown) {
      // Fix 6: Prioritize navigation intents by interrupting TTS
      if (intent == VoiceIntent.back || intent == VoiceIntent.retry || intent == VoiceIntent.repeat) {
        final tts = Provider.of<TtsService>(context, listen: false);
        await tts.stop();
        await voice.stop();
      }

      // Handling navigation/commands
      if (intent == VoiceIntent.back) {
        if (_currentStep == RegStep.username) {
          Navigator.pop(context); // Go back to Login
          return;
        }
        
        // Fix 9: Step-by-step back
        setState(() {
          if (_currentStep == RegStep.confirmUsername) {
            _currentStep = RegStep.username;
            _usernameController.clear();
          } else if (_currentStep == RegStep.password) {
            _currentStep = RegStep.confirmUsername;
          } else if (_currentStep == RegStep.biometric) {
            _currentStep = RegStep.password;
            _passwordController.clear();
          } else if (_currentStep == RegStep.confirmRegister) {
            _currentStep = RegStep.biometric;
          }
          _biometricAuthenticated = false;
        });
        await _speakPromptForStep();
        return;
      }

      if (intent == VoiceIntent.retry) {
        // Fix 10: Retry clears current field and goes back to input step
        setState(() {
          if (_currentStep == RegStep.confirmUsername) {
            _currentStep = RegStep.username;
            _usernameController.clear();
          } else if (_currentStep == RegStep.confirmRegister) {
            _currentStep = RegStep.password;
            _passwordController.clear();
          }
          _biometricAuthenticated = false;
        });
        await _speakPromptForStep();
        return;
      }

      if (intent == VoiceIntent.repeat) {
        await _speakPromptForStep();
        return;
      }

      if (intent == VoiceIntent.dashboard) {
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
        return;
      }

      // Context-specific next intent
      if (_currentStep == RegStep.confirmUsername && intent == VoiceIntent.next) {
        setState(() { _currentStep = RegStep.password; });
        await _speakPromptForStep();
        return;
      }

      if (_currentStep == RegStep.confirmRegister && intent == VoiceIntent.register) {
        if (_biometricAuthenticated) {
          setState(() { _currentStep = RegStep.processing; _isProcessing = true; });
          _performRegistration();
        }
        return;
      }
      
      return;
    }

    // 2. Field Capture (Priority 2)
    // Field capture IS blocked during TTS
    if (voice.isTtsSpeaking || _isProcessing) return;
    if (!voice.isAwaitingFieldInput) return;

    final normalized = VoiceUtils.normalizeToEnglish(text);

    // Issue 5: Command-word guard — prevent known commands from reaching field storage.
    final isPasswordStep = (_currentStep == RegStep.password);
    
    if (!isPasswordStep) {
      if (normalized.isEmpty) return; // Reject partials/Devanagari junk for usernames
      
      const commandWords = [
        'nondani', 'nond', 'register', 'registar', 'login',
        'back', 'mage', 'wapas', 'parat', 'punha',
        'retry', 'next', 'pudhe', 'aage',
      ];
      if (commandWords.any((w) => normalized == w || normalized.contains(w))) {
        debugPrint('[RegistrationScreen] Field capture rejected command word: $normalized');
        return;
      }
    }

    switch (_currentStep) {
      case RegStep.username:
        setState(() {
          _tempUsername = normalized;
          _usernameController.text = normalized;
          _currentStep = RegStep.confirmUsername;
        });
        _speakPromptForStep();
        break;

      case RegStep.password:
        // Issue 2: Use CredentialNormalizer for deterministic cross-language password
        final sanitizedPassword = CredentialNormalizer.sanitize(text);
        debugPrint('[CREDENTIAL] Stored password hash input: $sanitizedPassword');
        if (sanitizedPassword.length < 6) {
          final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
          _speakPrompt(RegistrationFeedbackFormatter.formatPasswordWeak(lang), lang);
          return;
        }
        setState(() {
          _passwordController.text = sanitizedPassword;
          _currentStep = RegStep.biometric;
        });
        _speakPromptForStep();
        break;

      default:
        // Ignore other steps for field capture
        break;
    }
  }

  Future<void> _performRegistration() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final voice = Provider.of<VoiceController>(context, listen: false);
    final lang = Provider.of<LanguageService>(
      context,
      listen: false,
    ).currentLocale.languageCode;

    bool exists = await auth.userExists(_usernameController.text);
    if (exists) {
      await _speakPrompt(
        RegistrationFeedbackFormatter.formatUsernameTaken(lang),
        lang,
      );
      setState(() {
        _currentStep = RegStep.username;
        _isProcessing = false;
        _usernameController.clear();
      });
      return;
    }

    try {
      bool success = await auth.register(
        _usernameController.text,
        _passwordController.text,
      );

      if (success) {
        await voice.stop();

        final tts = Provider.of<TtsService>(context, listen: false);
        await tts.speak(
          "Registration successful. Please log in.",
          languageCode: lang,
        );

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        await _speakPrompt(
          RegistrationFeedbackFormatter.formatRegistrationFailed(lang),
          lang,
        );
        setState(() {
          _currentStep = RegStep.username;
          _isProcessing = false;
          _usernameController.clear();
        });
      }
    } catch (e) {
      await _speakPrompt(
        RegistrationFeedbackFormatter.formatRegistrationFailed(lang),
        lang,
      );
      setState(() {
        _currentStep = RegStep.username;
        _isProcessing = false;
        _usernameController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Voice Registration")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 40),
              Text(
                _getStepInstruction(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (_currentStep == RegStep.username ||
                  _currentStep == RegStep.confirmUsername)
                Text(
                  _usernameController.text.isEmpty
                      ? "..."
                      : _usernameController.text,
                  style: const TextStyle(fontSize: 32, color: Colors.blue),
                ),
              if (_currentStep == RegStep.password ||
                  _currentStep == RegStep.biometric ||
                  _currentStep == RegStep.confirmRegister)
                Text(
                  _passwordController.text.isEmpty
                      ? "..."
                      : List.filled(
                          _passwordController.text.length,
                          "*",
                        ).join(),
                  style: const TextStyle(fontSize: 32, color: Colors.blue),
                ),
              if (_currentStep == RegStep.biometric)
                const Center(
                  child: Icon(Icons.fingerprint, size: 80, color: Colors.green),
                ),

              const SizedBox(height: 60),
              if (_isProcessing) const CircularProgressIndicator(),
              if (!_isProcessing)
                Consumer<VoiceController>(
                  builder: (context, voice, child) {
                    return MicWidget(
                      isListening: (voice.isListening && !_isProcessing),
                      isError: voice.state == VoiceState.error,
                      onTap: () {
                        // Manual restart?
                        if (voice.state == VoiceState.error) {
                          final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;
                          voice.init().then((_) {
                            if (voice.isAvailable) voice.startListening(
                              onResult: (text) => _handleVoiceInput(text),
                              languageCode: lang,
                            );
                          });
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepInstruction() {
    switch (_currentStep) {
      case RegStep.username:
        return "Speak Username";
      case RegStep.confirmUsername:
        return "Say 'Next' to confirm";
      case RegStep.password:
        return "Speak Password, Password should be 6 characters long";
      case RegStep.biometric:
        return "Authenticate Biometrics";
      case RegStep.confirmRegister:
        return "Say 'Register' to finish";
      case RegStep.processing:
        return "Creating Account...";
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(RegStep.username),
        _stepLine(),
        _stepDot(RegStep.password),
        _stepLine(),
        _stepDot(RegStep.biometric),
        _stepLine(),
        _stepDot(RegStep.confirmRegister),
      ],
    );
  }

  Widget _stepDot(RegStep step) {
    bool active = _currentStep.index >= step.index;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: active ? Colors.blue : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _stepLine() {
    return Container(width: 40, height: 4, color: Colors.grey[300]);
  }
}
