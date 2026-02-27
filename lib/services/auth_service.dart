import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../core/voice_utils.dart';

class AuthService {
  static const String _authKey = 'auth_token';
  final DatabaseService _dbService = DatabaseService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<void> init() async {}

  String _normalizeUsername(String username) {
    return VoiceUtils.normalizeToEnglish(username);
  }

  String _normalizePassword(String password) {
    return VoiceUtils.normalizeToEnglish(password);
  }

  Future<bool> userExists(String username) async {
    final normalized = _normalizeUsername(username);
    final db = await _dbService.database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [normalized],
    );
    return result.isNotEmpty;
  }

  Future<bool> hasUsers() async {
    final db = await _dbService.database;
    final users = await db.query('users');
    return users.isNotEmpty;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<bool> register(String username, String password) async {
    final normalizedPassword = _normalizePassword(password);
    final normalizedUsername = _normalizeUsername(username);
    final hashedPassword = _hashPassword(normalizedPassword);
    final safeEmail = '$normalizedUsername@drishti.app';

    _logger.i(
      "Attempting registration for: '$normalizedUsername', Password Length: ${normalizedPassword.length}",
    );

    // Guard against weak passwords before Firebase call
    if (normalizedPassword.length < 6) {
      _logger.w("Registration blocked: Password is less than 6 characters.");
      return false; // or throw Exception, but false fits the return signature
    }

    try {
      // 1. Await Firebase Auth Account Creation
      UserCredential credential;
      try {
        credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: safeEmail,
          password: normalizedPassword,
        );
        _logger.i(
          "Firebase Auth creation successful for: $normalizedUsername (UID: ${credential.user?.uid})",
        );
      } on FirebaseAuthException catch (e) {
        _logger.e("FirebaseAuthException: [${e.code}] ${e.message}");
        if (e.code == 'email-already-in-use') {
          _logger.w(
            "Firebase Auth user already exists. Attempting to login to sync local state.",
          );
          credential = await _firebaseAuth.signInWithEmailAndPassword(
            email: safeEmail,
            password: normalizedPassword,
          );
        } else {
          // e.g. weak-password, invalid-email
          rethrow;
        }
      }

      // 2. Force Token Refresh to ensure backend confirmation
      await credential.user?.getIdToken(true);
      _logger.i("Firebase Token refreshed successfully.");

      // 3. Deterministic Firestore Write
      final docRef = _firestore.collection('users').doc(credential.user!.uid);
      _logger.i("Writing to Firestore at path: ${docRef.path}");
      await docRef.set({
        'username': normalizedUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': 'drishti_voice',
      });
      _logger.i("Firestore user profile set() completed.");

      // 4. Verify snapshot exists to guarantee transaction success
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw Exception(
          "Registration Verification Failed: Firestore document was not created.",
        );
      }
      _logger.i("Firestore user profile confirmed written.");

      // 5. Local SQLite Persistence for Offline Fallback
      final db = await _dbService.database;
      await db.insert('users', {
        'username': normalizedUsername,
        'password_hash': hashedPassword,
      });
      _logger.i("Local SQLite insertion successful");

      return true;
    } catch (e) {
      _logger.e("🔥 REGISTRATION ERROR TYPE -> ${e.runtimeType}");
      _logger.e("🔥 REGISTRATION ERROR DATA -> $e");
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    final normalizedPassword = _normalizePassword(password);
    final normalizedUsername = _normalizeUsername(username);
    final hashedPassword = _hashPassword(normalizedPassword);
    final safeEmail = '$normalizedUsername@drishti.app';

    _logger.i("Attempting login for: $normalizedUsername");

    try {
      // 1. Firebase Auth Sign-In (Primary Source of Truth)
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: safeEmail,
          password: normalizedPassword,
        );
        await credential.user?.getIdToken(true);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_authKey, true);

        _logger.i(
          "Firebase cloud login successful! Token refreshed and persisted.",
        );
        return true;
      } on FirebaseAuthException catch (e) {
        _logger.w(
          "Firebase login failed (FirebaseAuthException): [${e.code}] ${e.message}",
        );
        _logger.w(
          "Proceeding to check local SQLite cache for offline verification.",
        );
      } catch (e) {
        _logger.w(
          "Firebase login failed (General Error): $e. Proceeding to check local cache.",
        );
      }

      // 2. Local Fallback Verification
      final db = await _dbService.database;
      final users = await db.query(
        'users',
        where: 'username = ? AND password_hash = ?',
        whereArgs: [normalizedUsername, hashedPassword],
      );

      if (users.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_authKey, true);
        _logger.i(
          "Offline fallback login verified successfully via SQLite cache.",
        );
        return true;
      }

      _logger.w(
        "Offline fallback login failed: Invalid credentials for $normalizedUsername",
      );
      return false;
    } catch (e, stackTrace) {
      _logger.e("Login Pipeline Error: $e", error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  Future<void> updateUserLanguage(String langCode) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'language': langCode,
        });
        _logger.i("Updated language to $langCode in Firebase");
      }
    } catch (e) {
      _logger.e("Failed to update language in Firebase: $e");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, false);
    await _firebaseAuth.signOut();
    _logger.i("User logged out");
  }
}
