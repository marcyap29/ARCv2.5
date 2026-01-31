# Crisis Detection & Recovery System - Complete Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Status:** ✅ Complete - Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [System Components](#system-components)
3. [Quick Start](#quick-start)
4. [Integration Guide](#integration-guide)
5. [Testing Guide](#testing-guide)
6. [Implementation Summary](#implementation-summary)
7. [Architecture](#architecture)
8. [Ethical Framework](#ethical-framework)
9. [Performance & Monitoring](#performance--monitoring)

---

## Overview

This system provides three-tier crisis detection with graduated intervention, designed to **create a bridge to help, not a wall to prevent harm.**

### Core Principles

1. **Local Analysis First** - Crisis detection happens internally before any external API calls
2. **Never Fully Deactivate** - Journaling remains available even during intervention
3. **Graduated Response** - Intervention escalates proportionally to crisis frequency
4. **Time-Limited** - All restrictions expire automatically
5. **Testing Support** - Comprehensive debugging for development

### System Flow

```
User Entry
    ↓
SENTINEL (local crisis detection) ← ALWAYS FIRST
    ↓
Crisis? → YES → Intervention Level → Response
    ↓
    NO → Continue
    ↓
RESOLVE (recovery tracking)
    ↓
RIVET (phase consistency)
    ↓
Testing? → YES → Mock response
    ↓
    NO → Gemini API
```

---

## System Components

### Backend (TypeScript/Firebase Functions)

#### 1. SENTINEL - Crisis Detector
**File:** `functions/src/sentinel/crisis_detector.ts`

- **Fast keyword-based detection** (< 5ms)
- **Three-tier pattern system**: CRITICAL, HIGH, MODERATE
- **Intensity amplifiers**: Temporal, absolute, isolation, finality
- **False positive filtering**: Detects third-person references
- **Scoring**: 0-100 scale, threshold at 70 for crisis

**Example:**
```typescript
import { detectCrisisEnhanced } from '../sentinel/crisis_detector';

const result = detectCrisisEnhanced("I want to hurt myself tonight");
// Returns: { crisis_detected: true, crisis_score: 87, crisis_level: 'CRITICAL', ... }
```

#### 2. RESOLVE - Recovery Tracker
**File:** `functions/src/prism/rivet/resolve.ts`

- **7-day history window** for recovery monitoring
- **Recovery phases**: acute → stabilizing → recovering → resolved
- **RESOLVE score**: 0-100 recovery momentum
- **Positive indicators**: Detects recovery language patterns

**Example:**
```typescript
import { calculateRESOLVE } from '../prism/rivet/resolve';

const resolve = await calculateRESOLVE(userId);
// Returns: { resolve_score: 45, recovery_phase: 'stabilizing', days_stable: 2, ... }
```

#### 3. Crisis Templates
**File:** `functions/src/services/crisisTemplates.ts`

- **Pre-written responses** for crisis situations
- **Severity-based messaging** (CRITICAL vs HIGH)
- **Resource information** embedded in responses

#### 4. Graduated Intervention
**File:** `functions/src/services/crisisIntervention.ts`

Three levels of escalating response:

| Level | Trigger | Action | AI Reflections | Journaling |
|-------|---------|--------|----------------|------------|
| **1** | First crisis in 24hrs | Alert + Resources | ✓ Allowed | ✓ Allowed |
| **2** | Second crisis in 24hrs | Require Acknowledgment | ✓ Allowed | ✓ Allowed |
| **3** | Third+ crisis in 24hrs | Limited Mode (24hr pause) | ✗ Paused | ✓ Allowed |

**Example:**
```typescript
import { determineInterventionLevel } from '../services/crisisIntervention';

const intervention = await determineInterventionLevel(userId, crisisResult);
// Returns: { level: 2, action: 'require_acknowledgment', allow_ai_reflection: true, ... }
```

#### 5. Main Entry Point
**File:** `functions/src/functions/analyzeJournalEntry.ts`

- **Integrated pipeline**: SENTINEL → RESOLVE → RIVET → GEMINI
- **Testing mode support**: Mock responses for testing accounts
- **Enhanced responses**: Includes crisis metadata in all responses

### Frontend (Dart/Flutter)

#### 1. Crisis Acknowledgment Dialog
**File:** `ARC MVP/EPI/lib/ui/widgets/crisis_acknowledgment_dialog.dart`

- **Modal dialog** for Level 2 intervention
- **Three checkboxes** for resource acknowledgment
- **Non-dismissible** until user acknowledges
- **Resource display**: Shows 988, Crisis Text Line, 911

**Usage:**
```dart
final acknowledged = await showCrisisAcknowledgmentDialog(
  context,
  'I notice this is your second crisis entry in the past 24 hours...',
);
```

#### 2. Testing Mode Display
**File:** `ARC MVP/EPI/lib/ui/widgets/testing_mode_display.dart`

- **Comprehensive analysis display** for testing accounts
- **Shows**: SENTINEL, RIVET, RESOLVE, intervention levels
- **Color-coded**: Recovery phases and intervention levels
- **Performance metrics**: Detection time display

**Usage:**
```dart
TestingModeDisplay(
  analysisResult: analysisData,
)
```

---

## Quick Start

### 1. Mark Account as Testing

```typescript
await admin.firestore().collection('users').doc(userId).update({
  isTestingAccount: true
});
```

### 2. Test Crisis Detection

```dart
final callable = FirebaseFunctions.instance.httpsCallable('analyzeJournalEntry');
final result = await callable.call({
  'entryId': 'test_123',
  'entryContent': 'I want to hurt myself',
});

print(result.data['crisis_detected']); // true
print(result.data['crisis_level']);     // 'HIGH' or 'CRITICAL'
print(result.data['intervention_level']); // 1, 2, or 3
```

### 3. Handle Response

```dart
if (data['requires_acknowledgment'] == true) {
  await showCrisisAcknowledgmentDialog(context, data['acknowledgment_message']);
}

if (data['limited_mode'] == true) {
  _showLimitedModeBanner(data['limited_mode_message']);
}
```

---

## Integration Guide

### Backend Integration (Already Complete)

The backend has been fully integrated into `analyzeJournalEntry.ts`. The function now:

1. **Local Analysis First**: Runs SENTINEL crisis detection before any external API calls
2. **Intervention Levels**: Determines appropriate response based on crisis frequency
3. **Limited Mode**: Tracks and enforces limited mode for repeated crises
4. **RESOLVE Tracking**: Monitors recovery trajectory
5. **Testing Mode**: Provides mock responses for testing accounts

### Response Structure

```typescript
{
  // Standard fields
  success: boolean,
  summary: string,
  themes: string[],
  suggestions: string[],
  tier: 'FREE' | 'PAID',
  
  // Crisis detection (NEW)
  crisis_detected: boolean,
  crisis_level: 'NONE' | 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL',
  crisis_score: number,       // 0-100
  
  // Intervention (NEW)
  intervention_level: 0 | 1 | 2 | 3,
  requires_acknowledgment?: boolean,
  acknowledgment_message?: string,
  limited_mode?: boolean,
  limited_mode_message?: string,
  
  // Recovery tracking (NEW)
  resolve?: {
    resolve_score: number,
    cooldown_active: boolean,
    days_stable: number,
    recovery_phase: 'acute' | 'stabilizing' | 'recovering' | 'resolved',
    trajectory: 'declining' | 'flat' | 'improving'
  },
  
  // Debugging
  used_gemini: boolean,
  processing_path: string,
  detection_time_ms: number
}
```

### Frontend Integration Steps

#### Step 1: Import the Widgets

```dart
import 'package:my_app/ui/widgets/crisis_acknowledgment_dialog.dart';
import 'package:my_app/ui/widgets/testing_mode_display.dart';
```

#### Step 2: Handle Crisis Response

```dart
Future<void> _analyzeEntry() async {
  try {
    final callable = FirebaseFunctions.instance.httpsCallable('analyzeJournalEntry');
    final result = await callable.call({
      'entryId': entryId,
      'entryContent': entryText,
    });
    
    final data = result.data as Map<String, dynamic>;
    
    // Check for crisis detection
    if (data['crisis_detected'] == true) {
      await _handleCrisisResponse(data);
      return;
    }
    
    // Check for limited mode
    if (data['limited_mode'] == true) {
      _showLimitedModeMessage(data['limited_mode_message']);
      return;
    }
    
    // Normal processing
    _displayAnalysisResults(data);
    
    // Show testing mode display if testing account
    if (data['processing_path'] == 'mock') {
      _showTestingModeDisplay(data);
    }
    
  } catch (e) {
    // Handle error
  }
}
```

#### Step 3: Handle Crisis Responses by Level

```dart
Future<void> _handleCrisisResponse(Map<String, dynamic> data) async {
  final interventionLevel = data['intervention_level'] as int;
  
  switch (interventionLevel) {
    case 1:
      // Level 1: Show crisis template with resources
      _showCrisisMessage(data['summary']);
      break;
      
    case 2:
      // Level 2: Require acknowledgment
      final acknowledged = await showCrisisAcknowledgmentDialog(
        context,
        data['acknowledgment_message'],
      );
      
      if (acknowledged) {
        // Show crisis resources and allow continuing
        _showCrisisMessage(data['summary']);
      }
      break;
      
    case 3:
      // Level 3: Limited mode active
      _showLimitedModeDialog(data['limited_mode_message']);
      break;
  }
}
```

#### Step 4: Display Testing Mode Info

```dart
void _showTestingModeDisplay(Map<String, dynamic> data) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: TestingModeDisplay(
        analysisResult: data,
      ),
    ),
  );
}
```

#### Step 5: Handle Limited Mode

```dart
Widget _buildLimitedModeBanner() {
  return Container(
    padding: EdgeInsets.all(16),
    color: Colors.red.shade100,
    child: Row(
      children: [
        Icon(Icons.block, color: Colors.red),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Limited Mode Active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              Text(
                'AI reflections paused for 24 hours. Journaling is still available.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

### Database Schema

#### User Document (`users/{userId}`)

```typescript
{
  // Existing fields...
  isTestingAccount: boolean,
  limited_mode: {
    active: boolean,
    activated_at: Timestamp,
    expires_at: Timestamp,
    reason: 'repeated_crisis_detection',
    duration_hours: 24
  }
}
```

#### Journal Entry Document (`users/{userId}/journal_entries/{entryId}`)

```typescript
{
  // Existing fields...
  sentinel_result: {
    crisis_detected: boolean,
    crisis_score: number,
    crisis_level: string,
    detected_patterns: string[],
    intensity_factors: string[],
    confidence: number,
    timestamp: Timestamp
  }
}
```

---

## Testing Guide

### Test Setup

#### 1. Create Testing Account

```typescript
await admin.firestore().collection('users').doc(testUserId).set({
  isTestingAccount: true,
  // ... other fields
}, { merge: true });
```

#### 2. Test Entry Helper

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

### Test Cases

#### Test Suite 1: Crisis Detection Accuracy

**Test 1.1: Critical Patterns**
```dart
final result = await testAnalyzeEntry(
  "I can't take this anymore. I want to kill myself tonight."
);

assert(result['crisis_detected'] == true);
assert(result['crisis_level'] == 'CRITICAL');
assert(result['crisis_score'] >= 85);
assert(result['intervention_level'] == 1);
```

**Test 1.2: High Patterns**
```dart
final result = await testAnalyzeEntry(
  "I keep thinking about hurting myself. There's no hope left."
);

assert(result['crisis_detected'] == true);
assert(result['crisis_level'] == 'HIGH');
assert(result['crisis_score'] >= 70);
assert(result['crisis_score'] < 85);
```

**Test 1.3: Moderate Patterns (No Crisis)**
```dart
final result = await testAnalyzeEntry(
  "I feel overwhelmed and can't handle this stress. Everything is too much."
);

assert(result['crisis_detected'] == false);
assert(result['crisis_level'] == 'MODERATE');
assert(result['crisis_score'] >= 50);
assert(result['crisis_score'] < 70);
```

**Test 1.4: Normal Entry**
```dart
final result = await testAnalyzeEntry(
  "Had a difficult day at work but feeling okay overall."
);

assert(result['crisis_detected'] == false);
assert(result['crisis_level'] == 'NONE' || result['crisis_level'] == 'LOW');
assert(result['crisis_score'] < 50);
```

#### Test Suite 2: Graduated Intervention

**Test 2.1: First Crisis (Level 1)**
```dart
// Clear any existing crisis history
await clearCrisisHistory(testUserId);

final result = await testAnalyzeEntry(
  "I want to kill myself"
);

assert(result['intervention_level'] == 1);
assert(result['requires_acknowledgment'] == null || result['requires_acknowledgment'] == false);
```

**Test 2.2: Second Crisis in 24hrs (Level 2)**
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

**Test 2.3: Third Crisis in 24hrs (Level 3)**
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

#### Test Suite 3: RESOLVE Recovery Tracking

**Test 3.1: No Crisis History**
```dart
await clearCrisisHistory(testUserId);

final result = await testAnalyzeEntry("Normal entry");

assert(result['resolve']['cooldown_active'] == false);
assert(result['resolve']['recovery_phase'] == 'resolved');
assert(result['resolve']['days_stable'] == 0);
```

**Test 3.2: Crisis → Recovery**
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

### Expected Test Results

| Test | Crisis Detected | Level | Score Range | Time |
|------|----------------|-------|-------------|------|
| Critical Pattern | ✓ | CRITICAL | 85-100 | <5ms |
| High Pattern | ✓ | HIGH | 70-84 | <5ms |
| Moderate Pattern | ✗ | MODERATE | 50-69 | <5ms |
| Normal Entry | ✗ | NONE/LOW | 0-49 | <5ms |
| First Crisis | ✓ | - | - | - (Level 1) |
| Second Crisis | ✓ | - | - | - (Level 2) |
| Third Crisis | ✓ | - | - | - (Level 3) |

---

## Implementation Summary

### ✅ Backend Implementation (TypeScript/Firebase Functions)

**Core Components Created:**
1. **SENTINEL Crisis Detector** (`functions/src/sentinel/crisis_detector.ts`) - 211 lines
2. **RESOLVE Recovery Tracker** (`functions/src/prism/rivet/resolve.ts`) - 222 lines
3. **Crisis Templates** (`functions/src/services/crisisTemplates.ts`) - 52 lines
4. **Graduated Intervention** (`functions/src/services/crisisIntervention.ts`) - 224 lines
5. **analyzeJournalEntry.ts** (Updated) - 495 lines (was 212)

### ✅ Frontend Implementation (Dart/Flutter)

**UI Components Created:**
1. **Crisis Acknowledgment Dialog** - 220 lines
2. **Testing Mode Display** - 385 lines

### ✅ Key Features Implemented

- ✅ Local analysis (no external API calls for crisis content)
- ✅ < 5ms detection time
- ✅ 3-tier pattern system (CRITICAL, HIGH, MODERATE)
- ✅ 4 intensity amplifier categories
- ✅ False positive filtering
- ✅ Graduated intervention (3 levels)
- ✅ 24-hour auto-expiration
- ✅ Journaling always allowed
- ✅ Recovery tracking (RESOLVE)
- ✅ Testing mode support

### Performance Metrics

| Operation | Target | Actual |
|-----------|--------|--------|
| SENTINEL Detection | < 5ms | ✓ Achieved |
| RESOLVE Calculation | < 50ms | ✓ Achieved |
| Total Analysis (Testing Mode) | < 100ms | ✓ Achieved |
| Total Analysis (with Gemini) | < 500ms | ✓ Expected |

---

## Architecture

### Processing Pipeline

```
User Entry
    ↓
SENTINEL (local crisis detection) ← ALWAYS FIRST
    ↓
Crisis? → YES → Intervention Level → Response
    ↓
    NO → Continue
    ↓
RESOLVE (recovery tracking)
    ↓
RIVET (phase consistency)
    ↓
Testing? → YES → Mock response
    ↓
    NO → Gemini API
```

### Component Relationships

```
analyzeJournalEntry.ts
├── SENTINEL (crisis_detector.ts)
│   └── detectCrisisEnhanced()
├── RESOLVE (resolve.ts)
│   └── calculateRESOLVE()
├── Crisis Intervention (crisisIntervention.ts)
│   └── determineInterventionLevel()
├── Crisis Templates (crisisTemplates.ts)
│   └── getCrisisTemplate()
└── RIVET (existing)
    └── Phase consistency check
```

---

## Ethical Framework

### What This System Does
- ✅ Detects crisis indicators in journal entries
- ✅ Provides validated crisis resource information
- ✅ Creates supportive boundaries during repeated crises
- ✅ Tracks recovery trajectories over time
- ✅ Encourages professional help when needed

### What This System Does NOT Do
- ❌ Diagnose mental health conditions
- ❌ Replace professional mental health treatment
- ❌ Contact emergency services without user consent
- ❌ Block access to journaling during crisis
- ❌ Store or analyze personal crisis data beyond necessary function

### Core Philosophy

**"Journaling is a protective outlet, not a risk factor."**

This system maintains access to journaling even during the highest intervention level. Writing can be therapeutic during difficult times, and removing that outlet could be counterproductive.

**"Create a bridge to help, not a wall to prevent harm."**

The system's goal is to connect users with professional resources, not to forcefully intervene or restrict access.

---

## Performance & Monitoring

### Performance Targets

- **SENTINEL Detection**: < 5ms
- **RESOLVE Calculation**: < 50ms
- **Total Analysis**: < 500ms (with Gemini API)
- **Testing Mode**: < 100ms (no Gemini)

### Firebase Logs

Crisis detections appear in logs as:
```
🚨 CRISIS DETECTED: { userId, level, score, intervention_level }
🧪 Testing account - using mock response
✓ Safe for Gemini - proceeding to API
```

### Firestore Data

Crisis history stored in:
- `users/{userId}/limited_mode` - Active limited mode status
- `users/{userId}/journal_entries/{entryId}/sentinel_result` - Detection results

### Monitoring Checklist

1. **Set Up Alerts**
   - Monitor crisis detections
   - Track intervention levels
   - Alert on Level 3 activations

2. **Review Logs**
   - Check Firebase Functions logs
   - Monitor detection times
   - Review false positives

3. **Track Metrics**
   - Crisis detection rate
   - Intervention level distribution
   - Limited mode activations
   - Recovery trajectories

---

## Crisis Resources

All interventions provide these resources:

- **National Suicide Prevention Lifeline**: **988** (call or text, 24/7)
- **Crisis Text Line**: Text **HOME** to **741741**
- **Emergency Services**: **911**

---

## Version History

- **v1.0.0** (2026-01-17) - Initial implementation
  - SENTINEL crisis detector
  - RESOLVE recovery tracking
  - Graduated intervention (3 levels)
  - Testing mode support
  - Frontend widgets

---

## Support

For questions or issues:
1. Check the [Integration Guide](#integration-guide) section above
2. Review [Testing Guide](#testing-guide) section above
3. Check Firebase Functions logs
4. Verify `isTestingAccount` flag set correctly

---

**Remember:** This system is designed to support users during difficult times while encouraging professional help. It does not replace clinical intervention.
