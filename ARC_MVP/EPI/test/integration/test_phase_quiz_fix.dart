// test_phase_quiz_fix.dart
// Test script to verify phase quiz selection persistence

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/models/user_profile_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(UserProfileAdapter());
  
  print('🧪 Testing Phase Quiz Selection Persistence');
  print('=' * 50);
  
  // Test 1: Clear existing data
  print('\n1. Clearing existing data...');
  await _clearTestData();
  
  // Test 2: Simulate phase selection
  print('\n2. Simulating phase selection (Expansion)...');
  await _simulatePhaseSelection('Expansion');
  
  // Test 3: Verify phase persistence
  print('\n3. Verifying phase persistence...');
  final currentPhase = await UserPhaseService.getCurrentPhase();
  print('Current phase: $currentPhase');
  
  // Test 4: Validate phase selection
  print('\n4. Validating phase selection...');
  final isValid = await UserPhaseService.validatePhaseSelection('Expansion');
  print('Phase selection valid: $isValid');
  
  // Test 5: Test different phase
  print('\n5. Testing different phase (Discovery)...');
  await UserPhaseService.forceUpdatePhase('Discovery');
  final newPhase = await UserPhaseService.getCurrentPhase();
  print('New phase: $newPhase');
  
  print('\n✅ Phase quiz fix test completed!');
}

Future<void> _clearTestData() async {
  try {
    // Clear user profile
    if (Hive.isBoxOpen('user_profile')) {
      final userBox = Hive.box<UserProfile>('user_profile');
      await userBox.clear();
    }
    
    // Clear arcform snapshots
    if (Hive.isBoxOpen('arcform_snapshots')) {
      final snapshotBox = Hive.box('arcform_snapshots');
      await snapshotBox.clear();
    }
    
    print('  ✅ Test data cleared');
  } catch (e) {
    print('  ❌ Error clearing test data: $e');
  }
}

Future<void> _simulatePhaseSelection(String phase) async {
  try {
    // Create a test user profile with the selected phase
    final userProfile = UserProfile(
      id: 'test_user',
      name: 'Test User',
      email: 'test@example.com',
      createdAt: DateTime.now(),
      preferences: const {},
      onboardingCompleted: true,
      onboardingCurrentSeason: phase,
    );
    
    // Save to Hive
    Box<UserProfile> userBox;
    if (Hive.isBoxOpen('user_profile')) {
      userBox = Hive.box<UserProfile>('user_profile');
    } else {
      userBox = await Hive.openBox<UserProfile>('user_profile');
    }
    
    await userBox.put('profile', userProfile);
    print('  ✅ Phase selection saved: $phase');
  } catch (e) {
    print('  ❌ Error simulating phase selection: $e');
  }
}
