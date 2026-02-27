import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../services/tts_service.dart';
import '../../services/voice_controller.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../widgets/mic_widget.dart';
import '../../core/voice_utils.dart';
import '../../core/credential_normalizer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthMode { login, register }

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final BiometricService _biometricService = BiometricService();

  // Login Steps: 0=User, 1=Pass, 2=Biometric
  int _step = 0;
  final AuthMode _mode = AuthMode.login;
  bool _isSpeaking = false;
  bool _isBiometricPending = false;
  bool _biometricAuthenticated = false;
  DateTime? _lastListeningStartTime;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _initVoiceFlow();
    });
  }

  void _initVoiceFlow() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    if (!mounted) return;
    _speakPromptForStep();
    _startPersistentListening();
  }

  void _startPersistentListening() {
    final voice = Provider.of<VoiceController>(context, listen: false);
    final lang = Provider.of<LanguageService>(context, listen: false).currentLocale.languageCode;

    // Start by expecting a command (navigation) or field input
    voice.setInputExpectation(isCommand: true, isField: true);
    
    // Fix 3: Reset listening start time
    _lastListeningStartTime = DateTime.now();

    voice.startListening(
      languageCode: lang,
      onResult: (text) {
        // Fix 3: Update listening start time if it was null (e.g. first result)
        if (_lastListeningStartTime == null) _lastListeningStartTime = DateTime.now();
        
        // ALWAYS process intents, only block fields if speaking
        _handleVoiceInput(text);
      },
    );
  }

  Future<void> _speakPrompt(String message, String lang) async {
    if (!mounted) return;
    final voice = Provider.of<VoiceController>(context, listen: false);

    // Use VoiceGuard to handle mic lifecycle
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

    if (_mode == AuthMode.login) {
      if (_step == 0) {
        prompt =
            "Please say your Username to login, or say 'Register' to create an account.";
        if (lang == 'hi')
          prompt =
              "लॉगिन करने के लिए अपना Username बोलें, या नया खाता बनाने के लिए 'Register' कहें।";
        if (lang == 'mr')
          prompt =
              "लॉगिन करण्यासाठी आपले Username बोला, किंवा नवीन खाते तयार करण्यासाठी 'Register' म्हणा.";
      } else if (_step == 1) {
        prompt = "Please say your Password.";
        if (lang == 'hi') prompt = "कृपया अपना Password बोलें।";
        if (lang == 'mr') prompt = "कृपया आपला Password बोला.";
      } else if (_step == 2) {
        prompt = "Please authenticate with biometrics to complete login.";
        if (lang == 'hi')
          prompt =
              "लॉगिन पूरा करने के लिए कृपया बायोमेट्रिक्स के साथ प्रमाणित करें।";
        if (lang == 'mr')
          prompt = "लॉगिन पूर्ण करण्यासाठी कृपया बायोमेट्रिक्ससह प्रमाणित करा.";
      }
    } else if (_mode == AuthMode.register) {
      prompt = "No users found. Redirecting to registration.";
    }

    await _speakPrompt(prompt, lang);

    if (_mode == AuthMode.register) {
      Navigator.pushNamed(context, '/registration');
      return;
    }

    // Trigger biometric
    if (_mode == AuthMode.login && _step == 2 && mounted) {
      if (_isBiometricPending) return;

      final voice = Provider.of<VoiceController>(context, listen: false);
      
      // Wait for TTS to finish
      while (voice.isTtsSpeaking && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (!mounted) return;
      await voice.stop(); // Ensure stopped for biometrics
      
      setState(() => _isBiometricPending = true);

      try {
        bool authenticated = await _biometricService.authenticate();
        if (mounted) {
          // Reclaim audio focus after biometric
          await voice.resetSession();
          
          if (authenticated) {
            setState(() {
              _biometricAuthenticated = true;
            });
            _processLogin();
          } else {
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
      return;
    }
  }

  void _handleVoiceInput(String text) async {
    final voice = Provider.of<VoiceController>(context, listen: false);
    
    final intent = VoiceUtils.getIntent(text);
    debugPrint("LoginIntent Trace: step=$_step, intent=$intent, Raw: $text");

    if (intent != VoiceIntent.unknown) {
      // Fix 6: Prioritize navigation intents by interrupting TTS
      if (intent == VoiceIntent.back || intent == VoiceIntent.retry || intent == VoiceIntent.repeat) {
        final tts = Provider.of<TtsService>(context, listen: false);
        await tts.stop();
        await voice.stop();
      }

      if (intent == VoiceIntent.dashboard) {
        await Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
        return;
      }

      if (intent == VoiceIntent.back) {
        if (_step == 0) {
          // Fix 9: Step 0 back goes to language selection
          await Navigator.pushNamedAndRemoveUntil(context, '/language_selection', (route) => false);
          await voice.resetSession();
        } else {
          // Fix 9: Step-by-step back
          setState(() {
            _step--;
            if (_step == 0) _usernameController.clear();
            if (_step == 1) _passwordController.clear();
            _biometricAuthenticated = false;
          });
          await _speakPromptForStep();
        }
        return;
      }

      if (intent == VoiceIntent.retry) {
        // Fix 10: Retry clears current field and stays/goes back
        setState(() {
          if (_step == 1) {
            _step = 0;
            _usernameController.clear();
          } else if (_step == 2) {
            _step = 1;
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

      // Register switch
      if (intent == VoiceIntent.register && _step == 0) {
        // Issue 4: Removed 500ms confidence window guard — the 1200ms blackout
        // in VoiceController is the correct echo prevention mechanism.
        // An explicit return is here so code can never fall through to field capture.
        await Navigator.pushNamed(context, '/registration');
        _checkInitialState();
        return;
      }

      if (intent == VoiceIntent.login) return;
      return;
    }

    // 2. Field Capture (Priority 2)
    // Field capture IS blocked during TTS
    if (voice.isTtsSpeaking || _isSpeaking) return;
    if (!voice.isAwaitingFieldInput) return;

    // Normalize for storage
    final normalized = VoiceUtils.normalizeToEnglish(text);
    if (normalized.isEmpty) return; // Strict rejection of junk/Devanagari

    // Issue 5: Command-word guard — second line of defence.
    // These words must never be stored as field values regardless of intent detection.
    const commandWords = [
      'nondani', 'nond', 'register', 'registar', 'login',
      'back', 'mage', 'wapas', 'parat', 'punha',
      'retry', 'next', 'pudhe', 'aage',
    ];
    if (commandWords.any((w) => normalized == w || normalized.contains(w))) {
      debugPrint('[LoginScreen] Field capture rejected command word: $normalized');
      return;
    }

    if (_mode == AuthMode.login) {
      if (_step == 0) {
        setState(() {
          _usernameController.text = normalized;
          _step = 1;
        });
        _speakPromptForStep();
      } else if (_step == 1) {
        // Issue 2: Use CredentialNormalizer for deterministic cross-language password
        final sanitizedPassword = CredentialNormalizer.sanitize(text);
        debugPrint('[CREDENTIAL] Compared password hash input: ${CredentialNormalizer.sanitize(text)}');
        setState(() {
          _passwordController.text = sanitizedPassword;
          _step = 2;
        });
        _speakPromptForStep();
      }
    }
  }

  Future<void> _processLogin() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final voice = Provider.of<VoiceController>(context, listen: false);
    final lang = Provider.of<LanguageService>(
      context,
      listen: false,
    ).currentLocale.languageCode;

    // Speak status
    await _speakPrompt("Checking credentials...", lang);

    // At this point voice is RESUMED by _speakPrompt, which might be risky if we navigate immediately.
    // However, navigation usually disposes the screen/service listeners.
    // For strictness, let's pause before async work if we want.
    // But "Checking credentials" is short.

    final success = await auth.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (success) {
      await voice.stop(); // Clean stop before nav

      String msg = "Login successful, welcome";
      if (lang == 'hi') msg = "लॉगिन सफल रहा, आपका स्वागत है";
      if (lang == 'mr') msg = "लॉगिन यशस्वी झाले, आपले स्वागत आहे";

      // Direct speak (VoiceGuard logic not needed as we are leaving) 
      // AWAIT the completion before moving to dashboard
      final tts = Provider.of<TtsService>(context, listen: false);
      await tts.speak(msg, languageCode: lang);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } else {
      String error = "Login failed. Invalid username or password.";
      if (lang == 'hi') error = "लॉगिन विफल। अमान्य Username या Password.";
      if (lang == 'mr')
        error = "लॉगिन अयशस्वी. अमान्य Username किंवा Password.";

      // Use Guard for retry prompt
      await _speakPrompt(error, lang);

      setState(() {
        _step = 0; // Reset
        _passwordController.clear();
        _biometricAuthenticated = false;
      });
      _speakPromptForStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_step < 2)
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 24),
              ),
            if (_step < 2) const SizedBox(height: 16),
            if (_step < 2)
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                style: const TextStyle(fontSize: 24),
              ),
            if (_step < 2) const SizedBox(height: 20),
            if (_step < 2)
              Consumer<LanguageService>(
                builder: (context, langService, child) {
                  final lang = langService.currentLocale.languageCode;
                  String btnText = "Login";
                  if (lang == 'hi') btnText = "लॉगिन करें";
                  if (lang == 'mr') btnText = "लॉगिन करा";
                  return ElevatedButton(
                    onPressed: () async {
                      if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
                        setState(() => _step = 2);
                        final voice = Provider.of<VoiceController>(context, listen: false);
                        await voice.stop();
                        _speakPromptForStep();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(btnText, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  );
                }
              ),
            if (_step == 2)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 80, color: Colors.blue),
                    const SizedBox(height: 20),
                    Text(
                      _biometricAuthenticated
                          ? "Authenticated"
                          : "Waiting for Biometrics...",
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            if (_step < 2) const Spacer(),

            if (_step < 2)
              Consumer<VoiceController>(
                builder: (context, voice, child) {
                  return MicWidget(
                    isListening: (voice.isListening && !_isSpeaking),
                    isError: voice.state == VoiceState.error,
                    onTap: () {
                      if (voice.state == VoiceState.error) {
                        voice.init().then((_) {
                          if (voice.isAvailable) _startPersistentListening();
                        });
                      }
                    },
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
