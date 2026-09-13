import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages locally cached user authentication credentials, profile data,
/// verification status, and offline session state.
class AuthCacheService {
  static final AuthCacheService _instance = AuthCacheService._internal();
  factory AuthCacheService() => _instance;
  AuthCacheService._internal();

  static const String _keyUid = 'cached_user_uid';
  static const String _keyEmail = 'cached_user_email';
  static const String _keyName = 'cached_user_name';
  static const String _keyPasswordHash = 'cached_password_hash';
  static const String _keyPasswordSalt = 'cached_password_salt';
  static const String _keyVerificationStatus = 'cached_verification_status';
  static const String _keyProfileImage = 'cached_profile_image';
  static const String _keyHasFarm = 'cached_has_farm';
  static const String _keyHasFields = 'cached_has_fields';
  static const String _keyActiveFarmId = 'cached_active_farm_id';
  static const String _keyActiveFarmName = 'cached_active_farm_name';
  static const String _keyHasCachedSession = 'has_cached_session';

  SharedPreferences? _prefs;
  bool isOfflineSessionActive = false;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _safePrefs {
    if (_prefs == null) {
      throw StateError('AuthCacheService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  /// Hashes a password with a unique salt using SHA-256.
  String _generateHash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password:visaia_offline_security_salt_2026');
    return sha256.convert(bytes).toString();
  }

  /// Caches the user session and credentials after a successful online login.
  Future<void> cacheUserSession({
    required String uid,
    required String email,
    required String password,
    String? name,
    String? verificationStatus,
    String? profileImage,
    bool? hasFarm,
    bool? hasFields,
    String? activeFarmId,
    String? activeFarmName,
  }) async {
    await init();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final passwordHash = _generateHash(password.trim(), salt);

    await _safePrefs.setString(_keyUid, uid);
    await _safePrefs.setString(_keyEmail, email.trim().toLowerCase());
    await _safePrefs.setString(_keyPasswordHash, passwordHash);
    await _safePrefs.setString(_keyPasswordSalt, salt);
    await _safePrefs.setBool(_keyHasCachedSession, true);

    if (name != null) await _safePrefs.setString(_keyName, name);
    if (verificationStatus != null) {
      await _safePrefs.setString(_keyVerificationStatus, verificationStatus);
    }
    if (profileImage != null) {
      await _safePrefs.setString(_keyProfileImage, profileImage);
    }
    if (hasFarm != null) await _safePrefs.setBool(_keyHasFarm, hasFarm);
    if (hasFields != null) await _safePrefs.setBool(_keyHasFields, hasFields);
    if (activeFarmId != null) {
      await _safePrefs.setString(_keyActiveFarmId, activeFarmId);
    }
    if (activeFarmName != null) {
      await _safePrefs.setString(_keyActiveFarmName, activeFarmName);
    }

    debugPrint('💾 User session securely cached for offline authentication ($email)');
  }

  /// Verifies if entered credentials match the cached account when offline.
  Future<bool> verifyOfflineCredentials(String email, String password) async {
    await init();
    final cachedEmail = _safePrefs.getString(_keyEmail);
    final cachedHash = _safePrefs.getString(_keyPasswordHash);
    final cachedSalt = _safePrefs.getString(_keyPasswordSalt);

    if (cachedEmail == null || cachedHash == null || cachedSalt == null) {
      return false;
    }

    final normalizedInputEmail = email.trim().toLowerCase();
    if (cachedEmail != normalizedInputEmail) {
      return false;
    }

    final inputHash = _generateHash(password.trim(), cachedSalt);
    final isValid = inputHash == cachedHash;

    if (isValid) {
      isOfflineSessionActive = true;
    }

    return isValid;
  }

  /// Updates profile metadata in local cache.
  Future<void> updateProfile({
    String? name,
    String? verificationStatus,
    String? profileImage,
  }) async {
    await init();
    if (name != null) await _safePrefs.setString(_keyName, name);
    if (verificationStatus != null) {
      await _safePrefs.setString(_keyVerificationStatus, verificationStatus);
    }
    if (profileImage != null) {
      await _safePrefs.setString(_keyProfileImage, profileImage);
    }
  }

  /// Updates farm setup status and active farm in local cache.
  Future<void> updateFarmData({
    bool? hasFarm,
    bool? hasFields,
    String? activeFarmId,
    String? activeFarmName,
  }) async {
    await init();
    if (hasFarm != null) await _safePrefs.setBool(_keyHasFarm, hasFarm);
    if (hasFields != null) await _safePrefs.setBool(_keyHasFields, hasFields);
    if (activeFarmId != null) {
      await _safePrefs.setString(_keyActiveFarmId, activeFarmId);
    }
    if (activeFarmName != null) {
      await _safePrefs.setString(_keyActiveFarmName, activeFarmName);
    }
  }

  /// Reactivates session for the currently cached/saved account.
  Future<bool> continueSavedSession() async {
    await init();
    if (hasSavedAccount) {
      isOfflineSessionActive = true;
      await _safePrefs.setBool(_keyHasCachedSession, true);
      debugPrint('⚡ Fast session restored for $cachedEmail ($cachedName)');
      return true;
    }
    return false;
  }

  /// Removes the saved account credentials from device.
  Future<void> removeSavedAccount() async {
    await clearCache();
  }

  /// Clears only the active session flag while keeping cached credentials
  /// so the user can re-authenticate or use 'Continue as [Name]'.
  Future<void> clearActiveSession() async {
    await init();
    isOfflineSessionActive = false;
    await _safePrefs.setBool(_keyHasCachedSession, false);
    debugPrint('🔒 Active session cleared (saved profile preserved).');
  }

  /// Clears cached session when user explicitly resets all data.
  Future<void> clearCache() async {
    await init();
    isOfflineSessionActive = false;
    await _safePrefs.remove(_keyUid);
    await _safePrefs.remove(_keyEmail);
    await _safePrefs.remove(_keyName);
    await _safePrefs.remove(_keyPasswordHash);
    await _safePrefs.remove(_keyPasswordSalt);
    await _safePrefs.remove(_keyVerificationStatus);
    await _safePrefs.remove(_keyProfileImage);
    await _safePrefs.remove(_keyHasFarm);
    await _safePrefs.remove(_keyHasFields);
    await _safePrefs.remove(_keyActiveFarmId);
    await _safePrefs.remove(_keyActiveFarmName);
    await _safePrefs.setBool(_keyHasCachedSession, false);
    debugPrint('🧹 Offline auth cache completely cleared.');
  }

  // Getters for cached properties
  bool get hasCachedSession =>
      _safePrefs.getBool(_keyHasCachedSession) ?? false;
  bool get hasSavedAccount =>
      cachedUid != null && cachedEmail != null;
  String? get cachedUid => _safePrefs.getString(_keyUid);
  String? get cachedEmail => _safePrefs.getString(_keyEmail);
  String? get cachedName => _safePrefs.getString(_keyName);
  String? get cachedVerificationStatus =>
      _safePrefs.getString(_keyVerificationStatus);
  String? get cachedProfileImage => _safePrefs.getString(_keyProfileImage);
  bool? get cachedHasFarm => _safePrefs.getBool(_keyHasFarm);
  bool? get cachedHasFields => _safePrefs.getBool(_keyHasFields);
  String? get cachedActiveFarmId => _safePrefs.getString(_keyActiveFarmId);
  String? get cachedActiveFarmName => _safePrefs.getString(_keyActiveFarmName);
}
