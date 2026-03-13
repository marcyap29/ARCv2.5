// lib/lumara/profile/user_profile_service.dart
// Phase 6: On-device encrypted storage for LUMARA user profile (form pre-fill).

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _storageKey = 'lumara_user_profile';

/// Sensitive profile keys: always require PRISM full modal when used in form pre-fill; never stored in Outputs contentJson.
const Set<String> _sensitiveKeys = {
  'emergency_contact_name',
  'emergency_contact_phone',
  'health_insurance_number',
};

class UserProfileService {
  UserProfileService._();
  static final UserProfileService instance = UserProfileService._();

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  /// Save the full profile map. Encrypts the whole JSON.
  Future<void> saveProfile(Map<String, String> fields) async {
    final json = jsonEncode(fields);
    await _secure.write(key: _storageKey, value: json);
  }

  /// Get all stored fields.
  Future<Map<String, String>> getProfile() async {
    final raw = await _secure.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>?;
      if (decoded == null) return {};
      return decoded.map((k, v) => MapEntry(k as String, (v as Object?).toString()));
    } catch (_) {
      return {};
    }
  }

  /// Get a single field value, null if not set.
  Future<String?> getField(String key) async {
    final profile = await getProfile();
    return profile[key];
  }

  /// Returns true if profile has been filled out (at least full_name present).
  Future<bool> hasProfile() async {
    final name = await getField('full_name');
    return name != null && name.trim().isNotEmpty;
  }

  /// Delete all profile data.
  Future<void> deleteProfile() async {
    await _secure.delete(key: _storageKey);
  }

  /// Returns true if this field is flagged sensitive.
  bool isSensitive(String key) => _sensitiveKeys.contains(key);
}
