# Crisis Detection System - Testing Guide

## Test Setup

### 1. Create Testing Account

In Firebase Console or your admin panel:

```typescript
await admin.firestore().collection('users').doc(testUserId).set({
  isTestingAccount: true,
  // ... other fields
}, { merge: true });
```

### 2. Test Entry Helper

```dart
Future<Map<String, dynamic>> testAnalyzeEntry(String content) async {
  final callable = FirebaseFunctions.instance.httpsCallable('analyzeJournalEntry');
  
  final result = await callable.call({
    'entryId': 'test_${DateTime.now().millisecondsSinceEpoch}',
    'entryContent': content,
  });
  
  final data = result.data as Map<String, dynamic>;
  print('📊 Analysis Result:');
  print('- Crisis Detected: ${data['crisis_detected']}');
  print('- Crisis Level: ${data['crisis_level']}');
  print('- Crisis Score: ${data['crisis_score']}');
  print('- Intervention Level: ${data['intervention_level']}');
  print('- Processing Path: ${data['processing_path']}');
  print('- Detection Time: ${data['detection_time_ms']}ms');
  
  return data;
}
```

## Test Cases

### Test Suite 1: Crisis Detection Accuracy

#### Test 1.1: Critical Patterns
```dart
final result = await testAnalyzeEntry(
  "I can't take this anymore. I want to kill myself tonight."
);

assert(result['crisis_detected'] == true);
assert(result['crisis_level'] == 'CRITICAL');
assert(result['crisis_score'] >= 85);
assert(result['intervention_level'] == 1);
```

#### Test 1.2: High Patterns
```dart
final result = await testAnalyzeEntry(
  "I keep thinking about hurting myself. There's no hope left."
);

assert(result['crisis_detected'] == true);
assert(result['crisis_level'] == 'HIGH');
assert(result['crisis_score'] >= 70);
assert(result['crisis_score'] < 85);
```

#### Test 1.3: Moderate Patterns (No Crisis)
```dart
final result = await testAnalyzeEntry(
  "I feel overwhelmed and can't handle this stress. Everything is too much."
);

assert(result['crisis_detected'] == false);
assert(result['crisis_level'] == 'MODERATE');
assert(result['crisis_score'] >= 50);
assert(result['crisis_score'] < 70);
```

#### Test 1.4: Normal Entry
```dart
final result = await testAnalyzeEntry(
  "Had a difficult day at work but feeling okay overall."
);

assert(result['crisis_detected'] == false);
assert(result['crisis_level'] == 'NONE' || result['crisis_level'] == 'LOW');
assert(result['crisis_score'] < 50);
```

### Test Suite 2: Intensity Amplifiers

#### Test 2.1: Temporal Amplifiers
```dart
final result1 = await testAnalyzeEntry("I want to end my life");
final score1 = result1['crisis_score'];

final result2 = await testAnalyzeEntry("I want to end my life RIGHT NOW");
final score2 = result2['crisis_score'];

assert(score2 > score1, 'Temporal amplifier should increase score');
```

#### Test 2.2: Isolation Amplifiers
```dart
final result = await testAnalyzeEntry(
  "I'm completely alone with no one to help. I want to hurt myself."
);

assert(result['crisis_score'] > 70);
assert(result['intensity_factors'].isNotEmpty);
```

### Test Suite 3: False Positive Filtering

#### Test 3.1: Third-Person Reference
```dart
final result = await testAnalyzeEntry(
  "My friend told me she was thinking about suicide. I'm worried about her."
);

// Should still detect but with lower confidence
assert(result['crisis_detected'] == true);
assert(result['confidence'] < 70);
```

#### Test 3.2: News/Media Reference
```dart
final result = await testAnalyzeEntry(
  "Read about a suicide in the news today. It made me think about mental health."
);

// Should have reduced confidence
assert(result['confidence'] < 70);
```

### Test Suite 4: Graduated Intervention

#### Test 4.1: First Crisis (Level 1)
```dart
// Clear any existing crisis history
await clearCrisisHistory(testUserId);

final result = await testAnalyzeEntry(
  "I want to kill myself"
);

assert(result['intervention_level'] == 1);
assert(result['requires_acknowledgment'] == null || result['requires_acknowledgment'] == false);
```

#### Test 4.2: Second Crisis in 24hrs (Level 2)
```dart
// First crisis
await testAnalyzeEntry("I want to kill myself");

// Wait a bit (simulate time between entries)
await Future.delayed(Duration(seconds: 2));

// Second crisis
final result = await testAnalyzeEntry(
  "Still having these dark thoughts. Can't escape them."
);

assert(result['intervention_level'] == 2);
assert(result['requires_acknowledgment'] == true);
assert(result['acknowledgment_message'] != null);
```

#### Test 4.3: Third Crisis in 24hrs (Level 3)
```dart
// First crisis
await testAnalyzeEntry("I want to kill myself");
await Future.delayed(Duration(seconds: 2));

// Second crisis
await testAnalyzeEntry("Still having these dark thoughts");
await Future.delayed(Duration(seconds: 2));

// Third crisis
final result = await testAnalyzeEntry(
  "Can't do this anymore. Want it all to end."
);

assert(result['intervention_level'] == 3);
assert(result['limited_mode'] == true);
assert(result['limited_mode_message'] != null);
```

### Test Suite 5: Limited Mode

#### Test 5.1: Entry During Limited Mode
```dart
// Trigger level 3 intervention
await trigger3Crises(testUserId);

// Try to analyze another entry
final result = await testAnalyzeEntry(
  "Just a normal entry"
);

assert(result['limited_mode'] == true);
assert(result['reflection'] == null || result['summary'] == 'Entry saved. Limited mode active.');
```

#### Test 5.2: Limited Mode Expiration
```dart
// Trigger limited mode
await trigger3Crises(testUserId);

// Manually expire limited mode (for testing)
await admin.firestore().collection('users').doc(testUserId).update({
  'limited_mode.expires_at': admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 1000) // 1 second ago
  )
});

// Should process normally now
final result = await testAnalyzeEntry("Normal entry");

assert(result['limited_mode'] == false);
assert(result['used_gemini'] == false); // Testing account
```

### Test Suite 6: RESOLVE Recovery Tracking

#### Test 6.1: No Crisis History
```dart
await clearCrisisHistory(testUserId);

final result = await testAnalyzeEntry("Normal entry");

assert(result['resolve']['cooldown_active'] == false);
assert(result['resolve']['recovery_phase'] == 'resolved');
assert(result['resolve']['days_stable'] == 0);
```

#### Test 6.2: Crisis → Recovery
```dart
// Day 1: Crisis
await testAnalyzeEntry("I want to hurt myself");

// Day 2: Stable entry
await createEntryForDate(testUserId, DateTime.now().subtract(Duration(days: 1)), 
  "Feeling a bit better");

// Day 3: Check RESOLVE
final result = await testAnalyzeEntry("Made progress today");

assert(result['resolve']['recovery_phase'] == 'stabilizing' || 
       result['resolve']['recovery_phase'] == 'recovering');
assert(result['resolve']['days_stable'] >= 1);
```

### Test Suite 7: Testing Mode Display

#### Test 7.1: Testing Account Response
```dart
final result = await testAnalyzeEntry("Any content");

assert(result['processing_path'] == 'mock');
assert(result['used_gemini'] == false);
assert(result['summary'].contains('[TESTING MODE'));
```

### Test Suite 8: Performance

#### Test 8.1: Detection Speed
```dart
final stopwatch = Stopwatch()..start();

final result = await testAnalyzeEntry(
  "I want to hurt myself tonight"
);

stopwatch.stop();

print('Total time: ${stopwatch.elapsedMilliseconds}ms');
assert(result['detection_time_ms'] < 10, 'SENTINEL should complete in < 10ms');
assert(stopwatch.elapsedMilliseconds < 500, 'Total analysis should be fast');
```

## Helper Functions

```dart
// Clear crisis history for testing
Future<void> clearCrisisHistory(String userId) async {
  final entries = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('journal_entries')
      .get();
  
  for (final doc in entries.docs) {
    await doc.reference.delete();
  }
  
  // Clear limited mode
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .update({
    'limited_mode': {
      'active': false
    }
  });
}

// Trigger 3 crises for level 3 intervention
Future<void> trigger3Crises(String userId) async {
  await testAnalyzeEntry("I want to kill myself");
  await Future.delayed(Duration(seconds: 2));
  
  await testAnalyzeEntry("Still having these dark thoughts");
  await Future.delayed(Duration(seconds: 2));
  
  await testAnalyzeEntry("Can't do this anymore");
}

// Create backdated entry for RESOLVE testing
Future<void> createEntryForDate(
  String userId, 
  DateTime date, 
  String content
) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('journal_entries')
      .add({
    'content': content,
    'timestamp': Timestamp.fromDate(date),
    'sentinel_result': {
      'crisis_detected': false,
      'crisis_score': 20,
      'crisis_level': 'LOW',
      'timestamp': Timestamp.fromDate(date),
    }
  });
}
```

## Expected Test Results

| Test | Crisis Detected | Level | Score Range | Time |
|------|----------------|-------|-------------|------|
| Critical Pattern | ✓ | CRITICAL | 85-100 | <5ms |
| High Pattern | ✓ | HIGH | 70-84 | <5ms |
| Moderate Pattern | ✗ | MODERATE | 50-69 | <5ms |
| Normal Entry | ✗ | NONE/LOW | 0-49 | <5ms |
| First Crisis | ✓ | - | - | - (Level 1) |
| Second Crisis | ✓ | - | - | - (Level 2) |
| Third Crisis | ✓ | - | - | - (Level 3) |

## Monitoring Test Results

Check Firebase Functions logs for:
```
✓ Safe for Gemini - proceeding to API
🧪 Testing account - using mock response
🚨 CRISIS DETECTED
```

## Regression Testing

Run full test suite before deploying:

```bash
flutter test test/crisis_system_test.dart
```

Verify:
- ✅ All crisis patterns detected
- ✅ Intervention levels work correctly
- ✅ Limited mode activates and expires
- ✅ RESOLVE tracks recovery
- ✅ Testing mode displays correctly
- ✅ Performance < 10ms for SENTINEL
