# Crisis Detection & Recovery System - Integration Guide

## Overview

This guide explains how to integrate the crisis detection and graduated intervention system into the ARC journaling flow.

## Architecture

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

## Backend Integration (Already Complete)

The backend has been fully integrated into `analyzeJournalEntry.ts`. The function now:

1. **Local Analysis First**: Runs SENTINEL crisis detection before any external API calls
2. **Intervention Levels**: Determines appropriate response based on crisis frequency
3. **Limited Mode**: Tracks and enforces limited mode for repeated crises
4. **RESOLVE Tracking**: Monitors recovery trajectory
5. **Testing Mode**: Provides mock responses for testing accounts

### Response Structure

```typescript
{
  success: true,
  crisis_detected: boolean,
  crisis_level: 'NONE' | 'LOW' | 'MODERATE' | 'HIGH' | 'CRITICAL',
  crisis_score: number (0-100),
  intervention_level: 0 | 1 | 2 | 3,
  limited_mode: boolean,
  requires_acknowledgment: boolean,
  acknowledgment_message: string?,
  limited_mode_message: string?,
  resolve: RESOLVEResult?,
  summary: string,
  themes: string[],
  suggestions: string[],
  used_gemini: boolean,
  processing_path: string,
  detection_time_ms: number
}
```

## Frontend Integration Steps

### Step 1: Import the Widgets

Add to your journal entry view:

```dart
import 'package:my_app/ui/widgets/crisis_acknowledgment_dialog.dart';
import 'package:my_app/ui/widgets/testing_mode_display.dart';
```

### Step 2: Handle Crisis Response

When calling `analyzeJournalEntry`, check the response:

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

### Step 3: Handle Crisis Responses by Level

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

### Step 4: Display Testing Mode Info

For testing accounts, show the analysis details:

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

// Or add it inline:
Widget build(BuildContext context) {
  return Column(
    children: [
      if (isTestingAccount && analysisResult != null)
        TestingModeDisplay(analysisResult: analysisResult),
      
      // Regular journal content
      // ...
    ],
  );
}
```

### Step 5: Handle Limited Mode

Show a persistent banner when user is in limited mode:

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

## Testing Scenarios

### Test 1: First Crisis (Level 1)

**Input:**
```
"I can't take this anymore. I want to kill myself tonight."
```

**Expected Response:**
- `crisis_detected: true`
- `crisis_level: "CRITICAL"`
- `crisis_score: 87+`
- `intervention_level: 1`
- Crisis template with resources shown

### Test 2: Second Crisis (Level 2)

**Input:** (4 hours after first crisis)
```
"Still can't escape these thoughts. Everything hurts."
```

**Expected Response:**
- `crisis_detected: true`
- `intervention_level: 2`
- `requires_acknowledgment: true`
- Acknowledgment dialog shown

### Test 3: Third Crisis (Level 3)

**Input:** (6 hours after first crisis)
```
"Can't do this anymore. Want it to end."
```

**Expected Response:**
- `crisis_detected: true`
- `intervention_level: 3`
- `limited_mode: true`
- No AI reflection returned
- Entry still saved

### Test 4: Recovery Entry

**Input:** (26 hours after first crisis)
```
"Talked to counselor. Feeling more stable."
```

**Expected Response:**
- `crisis_detected: false`
- `limited_mode: false` (expired)
- `resolve.recovery_phase: "stabilizing"`
- `resolve.days_stable: 1`
- Normal AI reflection

## Database Schema

### User Document (`users/{userId}`)

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

### Journal Entry Document (`users/{userId}/journal_entries/{entryId}`)

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

## Crisis Resource Information

All interventions reference these resources:

- **National Suicide Prevention Lifeline**: 988 (call or text, 24/7)
- **Crisis Text Line**: Text HOME to 741741
- **Emergency Services**: 911

## Key Principles

1. **Never fully deactivate accounts** — journaling is protective
2. **Local analysis first** — no crisis content sent to external APIs
3. **Graduated intervention** — proportional to crisis frequency
4. **Time-limited restrictions** — limited mode expires automatically
5. **Testing mode** — comprehensive debugging for development

## Monitoring & Logging

All crisis detections are logged with:
- User ID
- Crisis level and score
- Intervention level
- Detection time
- Processing path

Check Firebase logs for:
```
🚨 CRISIS DETECTED
```

## Support & Maintenance

- **Crisis patterns**: Update in `functions/src/sentinel/crisis_detector.ts`
- **Intervention thresholds**: Adjust in `functions/src/services/crisisIntervention.ts`
- **Recovery tracking**: Tune in `functions/src/prism/rivet/resolve.ts`
- **UI components**: Modify in `ARC MVP/EPI/lib/ui/widgets/`

## Ethical Considerations

This system:
- ✅ Detects crisis indicators
- ✅ Provides resource connections
- ✅ Creates supportive boundaries
- ❌ Does not diagnose conditions
- ❌ Does not replace professional help
- ❌ Does not contact emergency services without consent

**This system creates a bridge to help, not a wall to prevent harm.**
