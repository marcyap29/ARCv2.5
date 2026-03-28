// Emergency script to bypass onboarding
// Run with: flutter run -t reset_onboarding.dart

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/models/user_profile_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(UserProfileAdapter());

  try {
    final userBox = await Hive.openBox<UserProfile>('user_profile');
    UserProfile? profile = userBox.get('profile');

    if (profile == null) {
      profile = UserProfile(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: 'User',
        email: '',
        createdAt: DateTime.now(),
        preferences: const {},
        onboardingCompleted: true,
        currentPhase: 'Discovery',
        lastPhaseChangeAt: DateTime.now(),
      );
    } else {
      profile = profile.copyWith(onboardingCompleted: true);
    }

    await userBox.put('profile', profile);

    // ignore: avoid_print
    print('Onboarding marked complete. Restart the main app.');
    await userBox.close();
  } catch (e, st) {
    // ignore: avoid_print
    print('Error: $e\n$st');
  }
}
