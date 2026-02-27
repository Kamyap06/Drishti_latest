class SpeechFormatter {
  static String formatGreeting(String locale) {
    if (locale == 'hi') return "पढ़ने के लिए 'डिटेक्ट' बोलें या वापस जाने के लिए 'वापस' बोलें।";
    if (locale == 'mr') return "वाचण्यासाठी 'डिटेक्ट' म्हणा किंवा मागे जाण्यासाठी 'मागे' म्हणा।";
    return "Say detect to read or say back.";
  }

  static String formatScanning(String locale) {
    if (locale == 'hi') return "पढ़ रहे हैं...";
    if (locale == 'mr') return "वाचत आहे...";
    return "Reading...";
  }

  static String formatNoText(String locale) {
    if (locale == 'hi') return "कोई टेक्स्ट नहीं मिला।";
    if (locale == 'mr') return "कोणताच मजकूर आढळला नाही.";
    return "No text found.";
  }

  static String formatError(String locale) {
    if (locale == 'hi') return "प्रोसेस करने में त्रुटि।";
    if (locale == 'mr') return "प्रक्रिया करण्यात त्रुटी.";
    return "Error processing.";
  }

  static String formatAskToTranslate(String locale) {
    if (locale == 'hi') {
      return "क्या आप टेक्स्ट का अनुवाद करना चाहते हैं?";
    } else if (locale == 'mr') {
      return "तुम्हाला मजकुराचे भाषांतर करायचे आहे का?";
    } else {
      return "Do you want to translate the text?";
    }
  }

  static String formatAskWhichLanguage(String locale) {
    if (locale == 'hi') {
      return "किस भाषा में: हिंदी, मराठी या अंग्रेज़ी?";
    } else if (locale == 'mr') {
      return "कोणत्या भाषेत: हिंदी, मराठी किंवा इंग्रजी?";
    } else {
      return "In which language: Hindi, Marathi, or English?";
    }
  }
}
