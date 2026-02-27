class RegistrationFeedbackFormatter {
  static String formatUsernameEmpty(String locale) {
    if (locale == 'hi')
      return "यूज़रनेम खाली नहीं हो सकता। कृपया दोबारा बोलें।";
    if (locale == 'mr') return "यूजरनेम रिक्त असू शकत नाही. कृपया पुन्हा बोला.";
    return "Username cannot be empty. Please say it again.";
  }

  static String formatPasswordMissing(String locale) {
    if (locale == 'hi') return "पासवर्ड खाली नहीं हो सकता। कृपया दोबारा बोलें।";
    if (locale == 'mr') return "पासवर्ड रिक्त असू शकत नाही. कृपया पुन्हा बोला.";
    return "Password cannot be empty. Please say it again.";
  }

  static String formatPasswordWeak(String locale) {
    if (locale == 'hi')
      return "पासवर्ड कम से कम छह अक्षर का होना चाहिए। कृपया दोबारा बोलें।";
    if (locale == 'mr')
      return "पासवर्ड किमान सहा अक्षरांचा असावा. कृपया पुन्हा बोला.";
    return "Password must be at least six characters. Please say it again.";
  }

  static String formatUsernameTaken(String locale) {
    if (locale == 'hi') return "यह यूज़रनेम पहले से मौजूद है, कोई और आज़माएँ।";
    if (locale == 'mr') return "हा यूजरनेम आधीच वापरात आहे, दुसरा प्रयत्न करा.";
    return "This username is already taken, try another.";
  }

  static String formatRegistrationFailed(String locale) {
    if (locale == 'hi') return "पंजीकरण विफल रहा। कृपया फिर से प्रयास करें।";
    if (locale == 'mr') return "नोंदणी अयशस्वी. कृपया पुन्हा प्रयत्न करा.";
    return "Registration failed. Please try again.";
  }
}
