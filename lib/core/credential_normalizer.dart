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
  static String sanitize(String input) {
    if (input.trim().isEmpty) return '';

    // Step 1 – Transliterate to English
    String s = VoiceUtils.normalizeToEnglish(input);

    // Step 2 – Collapse double vowels
    s = s.replaceAll('aa', 'a');
    s = s.replaceAll('ee', 'i');
    s = s.replaceAll('oo', 'u');

    // Step 3 – Normalise "sh" → "s" at word/string end
    // Covers cases like "password" → "pasword" and "baash" → "bas"
    s = s.replaceAllMapped(
      RegExp(r'sh(?=[^a-z]|$)'),
      (m) => 's',
    );

    // Step 4 – Drop terminal inherent vowel "a"
    if (s.length > 1 && s.endsWith('a')) {
      s = s.substring(0, s.length - 1);
    }

    // Step 5 – Lowercase + ASCII-only
    s = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    return s;
  }
}
