// lib/lumara/profile/lumara_preferences_model.dart
// Phase 6: LUMARA Preferences (how to call user, communication style, challenge, tone).

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefKey = 'lumara_preferences';

class LumaraPreferences {
  final String preferredName;
  final String communicationStyle; // 'short', 'balanced', 'long'
  final String challengeStyle;     // 'direct', 'gentle', 'support'
  final String tone;               // 'casual', 'professional'

  const LumaraPreferences({
    this.preferredName = '',
    this.communicationStyle = 'balanced',
    this.challengeStyle = 'gentle',
    this.tone = 'casual',
  });

  Map<String, dynamic> toJson() => {
    'preferredName': preferredName,
    'communicationStyle': communicationStyle,
    'challengeStyle': challengeStyle,
    'tone': tone,
  };

  factory LumaraPreferences.fromJson(Map<String, dynamic> json) {
    return LumaraPreferences(
      preferredName: json['preferredName'] as String? ?? '',
      communicationStyle: json['communicationStyle'] as String? ?? 'balanced',
      challengeStyle: json['challengeStyle'] as String? ?? 'gentle',
      tone: json['tone'] as String? ?? 'casual',
    );
  }

  LumaraPreferences copyWith({
    String? preferredName,
    String? communicationStyle,
    String? challengeStyle,
    String? tone,
  }) {
    return LumaraPreferences(
      preferredName: preferredName ?? this.preferredName,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      challengeStyle: challengeStyle ?? this.challengeStyle,
      tone: tone ?? this.tone,
    );
  }
}

class LumaraPreferencesStore {
  LumaraPreferencesStore._();
  static final LumaraPreferencesStore instance = LumaraPreferencesStore._();

  Future<void> save(LumaraPreferences prefs) async {
    final prefsInstance = await SharedPreferences.getInstance();
    await prefsInstance.setString(_prefKey, jsonEncode(prefs.toJson()));
  }

  Future<LumaraPreferences> load() async {
    final prefsInstance = await SharedPreferences.getInstance();
    final raw = prefsInstance.getString(_prefKey);
    if (raw == null || raw.isEmpty) return const LumaraPreferences();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      return map != null ? LumaraPreferences.fromJson(map) : const LumaraPreferences();
    } catch (_) {
      return const LumaraPreferences();
    }
  }
}
