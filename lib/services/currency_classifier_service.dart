//currency_classifier_service.dart
import 'dart:async';

class CurrencyResult {
  final String type; // 'note', 'coin', 'unknown'
  final int value;
  final double confidence;
  final String locale;

  const CurrencyResult({
    required this.type,
    required this.value,
    required this.confidence,
    required this.locale,
  });

  bool get isValid => value > 0;
}

class MultilingualCurrencyPipeline {
  final CurrencyClassifierService _classifier = CurrencyClassifierService();

  Future<CurrencyResult> process(String rawOcrText, String locale) async {
    String normalized = normalize(rawOcrText);
    return await _classifier.classify(normalized, locale);
  }

  String normalize(String text) {
    String t = text.toLowerCase();

    // Normalize RBI variations
    t = t.replaceAll(
      RegExp(
        r'भारतीय रिज़र्व बैंक|भारतीय रिजर्व बैंक|रिज़र्व बैंक ऑफ इंडिया|reserve bank of india|rbi',
      ),
      'rbi_marker',
    );

    // Normalize numerals and symbols
    t = t.replaceAll('₹', ' rs ');
    t = t.replaceAll('रुपये', ' rs ');
    t = t.replaceAll('रुपया', ' rs ');
    t = t.replaceAll('rupees', ' rs ');
    t = t.replaceAll('rupee', ' rs ');

    // Hindi/Marathi numbers mapping to numeric values
    Map<String, String> synonyms = {
      'एक': '1',
      'one': '1',
      'दो': '2',
      'दोन': '2',
      'two': '2',
      'पांच': '5',
      'पाच': '5',
      'five': '5',
      'दस': '10',
      'दहा': '10',
      'ten': '10',
      'बीस': '20',
      'वीस': '20',
      'twenty': '20',
      'पचास': '50',
      'पन्नास': '50',
      'fifty': '50',
      'सौ': '100',
      'शंभर': '100',
      'hundred': '100',
      'एक सौ': '100',
      'one hundred': '100',
      'दो सौ': '200',
      'दोनशे': '200',
      'two hundred': '200',
      'पांच सौ': '500',
      'पाचशे': '500',
      'five hundred': '500',
      'दो हजार': '2000',
      'दोन हजार': '2000',
      'two thousand': '2000',
    };

    synonyms.forEach((key, value) {
      if (RegExp(r'[a-z]').hasMatch(key)) {
        t = t.replaceAll(RegExp(r'\b' + key + r'\b'), value);
      } else {
        t = t.replaceAll(key, value);
      }
    });

    // Remove extra whitespace
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    return t;
  }
}

class CurrencyClassifierService {
  Future<CurrencyResult> classify(String normalizedText, String locale) async {
    int detectedValue = 0;
    String type = 'unknown';
    double confidence = 0.0;

    // Logic based on User's explicit request
    String t = normalizedText.toUpperCase();

    // Heuristic for Indian Currency
    bool isIndian =
        t.contains("RESERVE BANK OF INDIA") ||
        t.contains("RUPEES") ||
        t.contains("₹") ||
        t.contains("RBI_MARKER") ||
        t.contains("RS");

    // Numbers (Exact substring matches as per user logic)
    if (t.contains("2000"))
      detectedValue = 2000;
    else if (t.contains("500"))
      detectedValue = 500;
    else if (t.contains("200"))
      detectedValue = 200;
    else if (t.contains("100"))
      detectedValue = 100;
    else if (t.contains("50"))
      detectedValue = 50;
    else if (t.contains("20"))
      detectedValue = 20;
    else if (t.contains("10"))
      detectedValue = 10;

    if (detectedValue > 0) {
      type = 'note';
      confidence = 0.95; // Confident we found a number
    } else if (isIndian) {
      type = 'note';
      confidence = 0.5; // Indian currency detected but value unclear
    }

    return CurrencyResult(
      type: type,
      value: detectedValue,
      confidence: confidence,
      locale: locale,
    );
  }
}

class CurrencySpeechFormatter {
  static String formatGreeting(String locale) {
    if (locale == 'hi')
      return "स्कैनिंग शुरू करने के लिए 'डिटेक्ट' बोलें या वापस जाने के लिए 'वापस' बोलें।";
    if (locale == 'mr')
      return "स्कॅनिंग सुरू करण्यासाठी 'डिटेक्ट' म्हणा किंवा मागे जाण्यासाठी 'मागे' म्हणा।";
    return "Say detect to start scanning or say back.";
  }

  static String formatScanning(String locale) {
    if (locale == 'hi') return "स्कैन कर रहा हूँ...";
    if (locale == 'mr') return "स्कॅन करत आहे...";
    return "Scanning...";
  }

  static String formatError(String locale) {
    if (locale == 'hi') return "माफ़ करना, स्कैन नहीं हो पाया।";
    if (locale == 'mr') return "माफ़ करा, स्कॅन होऊ शकले नाही।";
    return "Sorry, couldn't scan properly.";
  }

  static String formatResult(CurrencyResult result) {
    if (!result.isValid) {
      if (result.type == 'note' && result.confidence == 0.5) {
        if (result.locale == 'hi')
          return "पैसा दिख रहा है, पर कितने का है समझ नहीं आया।";
        if (result.locale == 'mr')
          return "पैसे दिसत आहेत, पण किती रुपयाचे आहे ते कळलं नाही।";
        return "I see money, but can't read the value.";
      }
      if (result.locale == 'hi') return "मुझे कोई पैसा नहीं दिखा।";
      if (result.locale == 'mr') return "मला कोणतेही पैसे दिसले नाहीत।";
      return "I didn't detect any currency.";
    }

    Map<int, String> hiNums = {
      2000: 'दो हजार',
      500: 'पांच सौ',
      200: 'दो सौ',
      100: 'एक सौ',
      50: 'पचास',
      20: 'बीस',
      10: 'दस',
      5: 'पांच',
      2: 'दो',
      1: 'एक',
    };
    Map<int, String> mrNums = {
      2000: 'दोन हजार',
      500: 'पाचशे',
      200: 'दोनशे',
      100: 'शंभर',
      50: 'पन्नास',
      20: 'वीस',
      10: 'दहा',
      5: 'पाच',
      2: 'दोन',
      1: 'एक',
    };

    if (result.locale == 'hi') {
      return "यह ${hiNums[result.value] ?? result.value} रुपये का नोट है।";
    } else if (result.locale == 'mr') {
      return "ही ${mrNums[result.value] ?? result.value} रुपयाची नोट आहे।";
    }

    return "This is a ${result.value} rupee note.";
  }
}
