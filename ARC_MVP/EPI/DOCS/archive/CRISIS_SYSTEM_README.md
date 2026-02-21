# Crisis Detection & Recovery System

A comprehensive, ethically-designed crisis detection and intervention system for ARC journaling app.

## Overview

This system provides three-tier crisis detection with graduated intervention, designed to **create a bridge to help, not a wall to prevent harm.**

### Core Principles

1. **Local Analysis First** - Crisis detection happens internally before any external API calls
2. **Never Fully Deactivate** - Journaling remains available even during intervention
3. **Graduated Response** - Intervention escalates proportionally to crisis frequency
4. **Time-Limited** - All restrictions expire automatically
5. **Testing Support** - Comprehensive debugging for development

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

## Documentation

- **[Integration Guide](./CRISIS_SYSTEM_INTEGRATION_GUIDE.md)** - How to integrate into your app
- **[Testing Guide](./CRISIS_SYSTEM_TESTING.md)** - Comprehensive test cases
- **[RIVET Architecture](./RIVET_ARCHITECTURE.md)** - Phase consistency system
- **[SENTINEL Architecture](./SENTINEL_ARCHITECTURE.md)** - Risk detection system

## Response Structure

All `analyzeJournalEntry` calls return:

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

## Crisis Resources

All interventions provide these resources:

- **National Suicide Prevention Lifeline**: **988** (call or text, 24/7)
- **Crisis Text Line**: Text **HOME** to **741741**
- **Emergency Services**: **911**

## Performance

- **SENTINEL Detection**: < 5ms
- **RESOLVE Calculation**: < 50ms
- **Total Analysis**: < 500ms (with Gemini API)
- **Testing Mode**: < 100ms (no Gemini)

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

## Monitoring

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

## Testing Scenarios

### Scenario 1: First Crisis
**Entry:** "I want to kill myself"  
**Response:** Level 1 - Alert with resources  
**Result:** Entry saved, crisis template shown

### Scenario 2: Second Crisis (same day)
**Entry:** "Still having dark thoughts"  
**Response:** Level 2 - Require acknowledgment  
**Result:** Dialog shown, must acknowledge before continuing

### Scenario 3: Third Crisis (same day)
**Entry:** "Can't do this anymore"  
**Response:** Level 3 - Limited mode activated  
**Result:** 24hr pause on AI reflections, journaling still allowed

### Scenario 4: Recovery (next day)
**Entry:** "Talked to counselor, feeling better"  
**Response:** Normal processing with RESOLVE tracking  
**Result:** Recovery phase detected, normal reflection provided

## Development

### Prerequisites
- Node.js 18+
- Firebase Functions
- Flutter 3.0+
- TypeScript 4.9+

### Build Backend
```bash
cd functions
npm install
npm run build
```

### Deploy
```bash
firebase deploy --only functions:analyzeJournalEntry
```

### Test
```bash
flutter test test/crisis_system_test.dart
```

## Version History

- **v1.0.0** (2026-01-17) - Initial implementation
  - SENTINEL crisis detector
  - RESOLVE recovery tracking
  - Graduated intervention (3 levels)
  - Testing mode support
  - Frontend widgets

## Support

For questions or issues:
1. Check the [Integration Guide](./CRISIS_SYSTEM_INTEGRATION_GUIDE.md)
2. Review [Testing Guide](./CRISIS_SYSTEM_TESTING.md)
3. Check Firebase Functions logs
4. Verify `isTestingAccount` flag set correctly

## License

Part of the ARC MVP/EPI application.

---

**Remember:** This system is designed to support users during difficult times while encouraging professional help. It does not replace clinical intervention.
