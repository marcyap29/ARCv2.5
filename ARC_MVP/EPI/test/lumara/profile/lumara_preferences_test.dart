// test/lumara/profile/lumara_preferences_test.dart
// Phase 6: LumaraPreferences model and store.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/lumara/profile/lumara_preferences_model.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('LumaraPreferences', () {
    test('defaults applied when no preference stored', () async {
      final store = LumaraPreferencesStore.instance;
      final prefs = await store.load();
      expect(prefs.preferredName, '');
      expect(prefs.communicationStyle, 'balanced');
      expect(prefs.challengeStyle, 'gentle');
      expect(prefs.tone, 'casual');
    });

    test('preferences saved and retrieved correctly', () async {
      final store = LumaraPreferencesStore.instance;
      const saved = LumaraPreferences(
        preferredName: 'Alex',
        communicationStyle: 'short',
        challengeStyle: 'direct',
        tone: 'professional',
      );
      await store.save(saved);
      final loaded = await store.load();
      expect(loaded.preferredName, 'Alex');
      expect(loaded.communicationStyle, 'short');
      expect(loaded.challengeStyle, 'direct');
      expect(loaded.tone, 'professional');
    });

    test('toJson and fromJson round-trip', () {
      const p = LumaraPreferences(
        preferredName: 'J',
        communicationStyle: 'long',
        challengeStyle: 'support',
        tone: 'professional',
      );
      final map = p.toJson();
      final restored = LumaraPreferences.fromJson(map);
      expect(restored.preferredName, p.preferredName);
      expect(restored.communicationStyle, p.communicationStyle);
      expect(restored.challengeStyle, p.challengeStyle);
      expect(restored.tone, p.tone);
    });
  });
}
