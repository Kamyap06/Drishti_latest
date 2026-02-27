import 'voice_utils.dart';

/// Provides a single, canonical credential sanitization pipeline used at
/// BOTH registration and login time so the stored and compared passwords
/// are always produced by exactly the same transformations.
class CredentialNormalizer {
  CredentialNormalizer._(); // prevent instantiation

  /// Sanitize a raw STT string into a stable credential token.
  ///
  /// Steps (applied in strict order):
  ///  1. Transliterate Devanagari → ASCII via [VoiceUtils.normalizeToEnglish]
  ///  2. Collapse double-vowels: aa→a, ee→i, oo→u
  ///  3. Replace "sh" at a word boundary / end-of-string with "s"
  ///  4. Trim any trailing "a" from the whole string (inherent vowel deletion)
  ///  5. [toLowerCase] and strip any remaining non-ASCII characters
  static const Map<String, String> _numberWordMap = {
    'zero':'0','one':'1','two':'2','three':'3','four':'4',
    'five':'5','six':'6','seven':'7','eight':'8','nine':'9',
    'शून्य':'0','एक':'1','दो':'2','तीन':'3','चार':'4',
    'पाँच':'5','पांच':'5','छह':'6','सात':'7','आठ':'8','नौ':'9',
    'दोन':'2','पाच':'5','सहा':'6','नऊ':'9',
  };

  static const Map<String, String> _devanagariToLatin = {
    'अ':'a','आ':'aa','इ':'i','ई':'ee','उ':'u','ऊ':'oo',
    'ए':'e','ऐ':'ai','ओ':'o','औ':'au',
    'क':'k','ख':'kh','ग':'g','घ':'gh','च':'ch','छ':'chh',
    'ज':'j','झ':'jh','ट':'t','ड':'d','त':'t','द':'d',
    'न':'n','प':'p','फ':'f','ब':'b','भ':'bh','म':'m',
    'य':'y','र':'r','ल':'l','व':'v','श':'sh','स':'s',
    'ह':'h','ळ':'l','क्ष':'ksh','ज्ञ':'gya',
    'ा':'a','ि':'i','ी':'ee','ु':'u','ू':'oo',
    'े':'e','ै':'ai','ो':'o','ौ':'au',
    '्':'','ं':'n','ः':'h','ँ':'n',
  };

  static String sanitize(String raw) {
    String text = raw.trim().toLowerCase();
    // Step 1: Replace number words with digits
    _numberWordMap.forEach((word, digit) {
      text = text.replaceAll(word, digit);
    });
    // Step 2: Transliterate Devanagari to Latin
    _devanagariToLatin.forEach((deva, latin) {
      text = text.replaceAll(deva, latin);
    });
    // Step 3: Remove spaces, keep only alphanumeric
    text = text.replaceAll(' ', '');
    text = text.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return text;
  }
}
