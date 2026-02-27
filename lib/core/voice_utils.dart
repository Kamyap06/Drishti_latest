enum VoiceIntent {
  next,
  back,
  retry,
  confirm,
  login,
  register,
  repeat,

  languageEnglish,
  languageHindi,
  languageMarathi,
  dashboard,
  objectDetection,
  currencyDetection,
  readText,
  expiryDetection,
  openSettings,
  unknown,
}

enum VoiceState {
  initializing,
  listening,
  processing,
  idle,
  error,
}

class VoiceUtils {
  static VoiceIntent getIntent(String text) {
    // Fix 4: Strip Devanagari danda, zero-width characters, and trailing punctuation
    // before ANY matching — Hindi/Marathi STT injects these invisibly.
    String t = text
        .replaceAll('।', '')   // Devanagari danda
        .replaceAll('\u200B', '') // zero-width space
        .replaceAll('\u200D', '') // zero-width joiner
        .replaceAll('\uFEFF', '') // BOM / zero-width no-break space
        .replaceAll('\u200E', '') // left-to-right mark
        .replaceAll('\u200F', '') // right-to-left mark
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?]'), '')
        .trim();

    // Fix 2 – Back / Cancel (expanded for Hindi & Marathi STT output)
    if (t.contains("back") ||
        t.contains("piche") ||
        t.contains("pishe") ||
        t.contains("wapas") ||
        t.contains("vapasi") ||
        t.contains("maghe") ||
        t.contains("parat") ||
        t.contains("cancel") ||
        t.contains("radd") ||
        t.contains("go back") ||
        t.contains("mage") ||
        t.contains("maga") ||
        t.contains("wapas jao") ||
        t.contains("wapas ja") ||
        t.contains("parat ja") ||
        t.contains("nako") ||
        t.contains("band karo") ||
        t.contains("band kara") ||
        t.contains("cancel karo") ||
        t.contains("cancel kara") ||
        t.contains("radd karo") ||
        t.contains("radd kara") ||
        t.contains("परत") ||
        t.contains("परत जा") ||
        t.contains("मागे") ||
        t.contains("मागे जा") ||
        t.contains("वापस") ||
        t.contains("वापस जाओ") ||
        t.contains("वापस जा") ||
        t.contains("रद्द") ||
        t.contains("रद्द करा") ||
        t.contains("रद्द करो") ||
        t.contains("नको") ||
        t.contains("बंद करा") ||
        t.contains("बंद करो") ||
        t.contains("nahi chahiye")) {
      return VoiceIntent.back;
    }

    // Next / Confirm / Yes / Proceed
    if (t.contains("next") ||
        t.contains("yes") ||
        t.contains("confirm") ||
        t.contains("haan") ||
        t.contains("thik") ||
        t.contains("sahi") ||
        t.contains("aage") ||
        t.contains("ho") ||
        t.contains("pudhe") ||
        t.contains("chala") ||
        t.contains("पुढे") ||      // Marathi: forward/next (Devanagari — STT returns this in mr_IN)
        t.contains("नेक्स्ट") ||
        t.contains("नेक्ट") ||
        t.contains("हाँ") ||
        t.contains("हां") ||
        t.contains("ठीक") ||
        t.contains("बरोबर") ||
        t.contains("चला")) {
      return VoiceIntent.next;
    }

    // Fix 3 – Retry / No / Change / Try Again (expanded for Hindi & Marathi STT output)
    if (t.contains("retry") ||
        t.contains("change") ||
        t.contains("no") ||
        t.contains("nahi") ||
        t.contains("badal") ||
        t.contains("dobara") ||
        t.contains("phir se") ||
        t.contains("punha") ||
        t.contains("try again") ||
        t.contains("फिर से") ||
        t.contains("फिर से बोलो") ||
        t.contains("पुन्हा") ||
        t.contains("पुन्हा सांग") ||
        t.contains("पुन्हा करा") ||
        t.contains("दोबारा") ||
        t.contains("दोबारा बोलो") ||
        t.contains("बदल") ||
        t.contains("बदला") ||
        t.contains("चुकला") ||
        t.contains("नाही") ||
        t.contains("नाहीं") ||
        t.contains("nahin") ||
        t.contains("nai") ||
        t.contains("galat") ||
        t.contains("chukla") ||
        t.contains("badle") ||
        t.contains("badlun") ||
        t.contains("punha kara") ||
        t.contains("phir se bolo") ||
        t.contains("dobara karo") ||
        t.contains("dusra") ||
        t.contains("change karo") ||
        t.contains("phirse")) {
      return VoiceIntent.retry;
    }

    // Login
    if (t.contains("login") ||
        t.contains("sign in") ||
        t.contains("pravesh") ||
        t.contains("shuru")) {
      return VoiceIntent.login;
    }

    // Register / Create Account
    if (t.contains("register") ||
        t.contains("registar") ||
        t.contains("nondani") ||
        t.contains("nondni") ||
        t.contains("nond") ||
        t.contains("khata") ||
        t.contains("banva") ||
        t.contains("banao") ||
        t.contains("khata banao") ||
        t.contains("register karo") ||
        t.contains("register kar") ||
        t.contains("नोंदणी") ||
        t.contains("नोंद करा") ||
        t.contains("नोंद") ||
        t.contains("रजिस्टर") ||
        t.contains("बनावा")) {
      return VoiceIntent.register;
    }

    // Dashboard navigation
    if (t.contains("dashboard") ||
        t.contains("main") ||
        t.contains("home") ||
        t.contains("shuruat") ||
        t.contains("mukhya")) {
      return VoiceIntent.dashboard;
    }

    // Repeat
    if (t.contains("repeat") ||
        t.contains("again") ||
        t.contains("fir se") ||
        t.contains("bola") ||
        t.contains("sanga")) {
      return VoiceIntent.repeat;
    }

    /// ================= DASHBOARD FEATURE INTENTS =================
    if (t.contains("object detection") ||
        t.contains("object") ||
        t.contains("वस्तु पहचान") ||
        t.contains("वस्तू ओळख") ||
        t.contains("cheez pahchan") ||
        t.contains("vastu") ||
        t.contains("chiz") ||
        t.contains("cheez") ||
        t.contains("चीज़") ||
        t.contains("वस्तु") ||
        t.contains("वस्तू") ||
        t.contains("ऑब्जेक्ट") ||
        t.contains("ऑब्जेक्ट डिटेक्शन")) {
      return VoiceIntent.objectDetection;
    }

    if (t.contains("currency") ||
        t.contains("currency check") ||
        t.contains("पैसे") ||
        t.contains("नोट") ||
        t.contains("not") ||
        t.contains("paisa") ||
        t.contains("paise") ||
        t.contains("note") ||
        t.contains("पैसे तपासणे") ||
        t.contains("note dekho") ||
        t.contains("paisa dekho") ||
        t.contains("करन्सी") ||
        t.contains("करन्सी डिटेक्शन")) {
      return VoiceIntent.currencyDetection;
    }

    if (t.contains("read text") ||
        t.contains("text") ||
        t.contains("read") ||
        t.contains("padho") ||
        t.contains("padh") ||
        t.contains("vacha") ||
        t.contains("वाचा") ||
        t.contains("वाच") ||
        t.contains("टेक्स्ट") ||
        t.contains("मजकूर") ||
        t.contains("लिखा") ||
        t.contains("likha padhna") ||
        t.contains("text padho") ||
        t.contains("majkur") ||
        t.contains("रीड") ||
        t.contains("इमेज टू स्पीच")) {
      return VoiceIntent.readText;
    }

    if (t.contains("expiry") ||
        t.contains("date") ||
        t.contains("validity") ||
        t.contains("tariq") ||
        t.contains("tarikh") ||
        t.contains("तारीख") ||
        t.contains("एक्सपायरी") ||
        t.contains(" expired") ||
        t.contains("kab tak") ||
        t.contains("kharaab") ||
        t.contains("एक्सपायरी डेट") ||
        t.contains("एक्सपायर")) {
      return VoiceIntent.expiryDetection;
    }

    if (t.contains("settings") ||
        t.contains("setting") ||
        t.contains("सेटिंग्स") ||
        t.contains("सेटिंग्ज") ||
        t.contains("settings kholo")) {
      return VoiceIntent.openSettings;
    }

    /// ================= LANGUAGE SELECTION INTENTS =================
    // Normalize string to handle common STT misinterpretations
    String n = t.replaceAll(" ", "").replaceAll(".", "");

    // English
    if (n.contains("english") ||
        n.contains("angrezi") ||
        n.contains("angreji") ||
        n.contains("ingraji")) {
      return VoiceIntent.languageEnglish;
    }

    // Hindi
    if (n.contains("hindi") ||
        n.contains("hindee") ||
        n.contains("हिंदी") ||
        n.contains("हिन्दी")) {
      return VoiceIntent.languageHindi;
    }

    // Marathi
    if (n.contains("marathi") ||
        n.contains("marati") ||
        n.contains("मराठी")) {
      return VoiceIntent.languageMarathi;
    }

    return VoiceIntent.unknown;
  }

  static String normalizeToEnglish(String input) {
    if (input.isEmpty) return "";

    // 1. Phonetic Mapping Dictionary (Deterministic)
    final phoneticMap = {
      'नोंदणी': 'nondani',
      'नोंद': 'nond',
      'करा': 'kara',
      'बनावा': 'banava',
      'खाते': 'khate',
      'सह्याद्रि': 'sahyadri',
    };

    // Strip ALL spaces first to avoid formatting differences between STT engines
    String p = input.replaceAll(' ', '').trim();
    if (phoneticMap.containsKey(p)) return phoneticMap[p]!;

    // 2. Remove invisible unicode characters
    p = p.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u200E\u200F]'), '');

    // 3. Convert Devanagari numerals to ASCII
    const devanagariDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    for (int i = 0; i < devanagariDigits.length; i++) {
      p = p.replaceAll(devanagariDigits[i], i.toString());
    }

    // 4. Transliteration logic (Improved Schwa Deletion)
    final consonants = {
      'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'n',
      'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'n',
      'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
      'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
      'प': 'p', 'फ': 'f', 'ब': 'b', 'भ': 'bh', 'म': 'm',
      'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh', 
      'ष': 'sh', 'स': 's', 'ह': 'h', 'ळ': 'l'
    };

    final vowels = {
      'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo', 
      'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'ऋ': 'ri'
    };

    final vowelMarks = {
      'ा': 'a', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo', 
      'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ृ': 'ri', 'ं': 'n'
    };

    const virama = '्';
    const suppressedMarks = 'ािीुूेैोौृ्';

    String result = "";
    for (int i = 0; i < p.length; i++) {
      String char = p[i];

      if (vowels.containsKey(char)) {
        result += vowels[char]!;
      } else if (consonants.containsKey(char)) {
        result += consonants[char]!;
        
        bool nextIsMark = false;
        bool nextIsPunctOrSpace = false;
        
        if (i + 1 < p.length) {
          String nextChar = p[i + 1];
          if (suppressedMarks.contains(nextChar)) nextIsMark = true;
          if (nextChar == ' ' || nextChar == '.' || nextChar == ',') nextIsPunctOrSpace = true;
        }

        // Schwa Deletion Rule:
        // 1. Don't add 'a' if followed by a vowel mark or virama.
        // 2. Don't add 'a' if it's the terminal character (Terminal Schwa Deletion).
        // 3. Add 'a' only for internal consonants without marks (Internal Schwa).
        bool isTerminal = (i + 1 == p.length) || nextIsPunctOrSpace;
        
        if (!nextIsMark && !isTerminal) {
          result += 'a';
        }
      } else if (vowelMarks.containsKey(char)) {
        result += vowelMarks[char]!;
      } else if (char != virama) {
        result += char;
      }
    }

    // 5. Final Sanitization: Lowercase + A-Z/0-9 only
    String finalResult = result.toLowerCase();
    
    // Strict Filter: Keep ONLY lowercase English letters and digits
    finalResult = finalResult.replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Security check: if there's any Devanagari or non-ASCII left, reject entirely
    if (RegExp(r'[^\x00-\x7F]').hasMatch(finalResult) || 
        RegExp(r'[\u0900-\u097F]').hasMatch(finalResult)) {
      return ""; // Reprocess required
    }

    return finalResult;
  }

  static String sanitizePassword(String normalized) {
    if (normalized.isEmpty) return "";
    String s = normalized.toLowerCase();
    
    // Strip double vowels mapping
    s = s.replaceAll('aa', 'a');
    s = s.replaceAll('ee', 'i');
    s = s.replaceAll('oo', 'u');
    
    // Normalize "sh" and "s" collisions
    s = s.replaceAll('sh', 's');
    
    // Strict Filter: Keep ONLY lowercase English letters and digits
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    // Trim any trailing "a"
    if (s.endsWith('a') && s.length > 1) {
      s = s.substring(0, s.length - 1);
    }
    
    return s;
  }
}
