# LUMARA User Prompt Override Issue

**Status:** ✅ **RESOLVED**  
**Date:** January 2026  
**Version:** v3.0  
**Severity:** 🔴 **CRITICAL**

---

## Problem Summary

LUMARA responses were violating all v3.0 constraints despite correct master prompt implementation:
- **Word Count**: 520 words (target: 200-250) - More than DOUBLE the limit
- **Banned Phrases**: All 13 melodramatic phrases being used
- **Pattern Examples**: Zero dated examples (required: 2-4)
- **Action Items**: Unrequested guidance being provided
- **Strategic Framing**: Personal reflections treated as strategic analysis

## Root Cause

The **user prompt** in `enhanced_lumara_api.dart` was explicitly overriding master prompt constraints:

### Broken Instructions (Lines 386-418)

```dart
❌ "Be thorough and detailed - there is no limit on response length"
❌ "ACTIVELY references and draws connections to past journal entries"
❌ "You are encouraged to offer gentle guidance, suggestions, goals, or habits"
```

These instructions came **after** the master prompt, so the LLM followed them instead of the constraints.

## Solution

### 1. Removed Broken Instructions
- Removed all "no limit on response length" statements
- Removed vague pattern reference instructions without date requirements
- Removed unrequested action item encouragement

### 2. Created New User Prompt Builder
- `_buildUserPrompt()` method that reads constraints from control state
- Enforces word limits: "WORD LIMIT: $maxWords words MAXIMUM - STOP at $maxWords words"
- Requires dated examples: "$minPatternExamples-$maxPatternExamples dated examples required"
- Includes banned phrases list for Companion mode
- Distinguishes personal vs. project content

### 3. Added Persona-Specific Instructions
- `_getPersonaSpecificInstructions()` method
- Lists forbidden phrases for Companion mode
- Provides instructions for each persona
- Enforces structured format only for Strategist metaAnalysis

## Files Changed

- `lib/arc/chat/services/enhanced_lumara_api.dart`
  - Replaced lines 359-419 (broken user prompt building)
  - Added `_buildUserPrompt()` method (lines 982-1087)
  - Added `_getPersonaSpecificInstructions()` method (lines 1089-1168)
  - Removed unused `_standardReflectionLengthRule` and `_deepReflectionLengthRule` constants

## Verification

After fix, responses should:
- ✅ Respect 250-word limit for Companion
- ✅ Include 2-4 dated pattern examples
- ✅ Avoid all banned melodramatic phrases
- ✅ Not provide unrequested action items
- ✅ Use warm, conversational Companion tone
- ✅ Focus on personal patterns, not strategic vision

## Test Case

**Entry:**
```
I think if I had to describe my superpower it's never giving up.
I'm not as fast as other people. Nor am I knowledgeable in Breath of Depth.
What I can offer though is flexibility, the ability to learn quickly, and the
ability to iterate and break things down quickly.

Maybe I'm just being too lazy or stubborn but it's such a pain in the butt
trying to get Stripe integrated with the app right now.

I did make progress however on trying to integrate Wispr Flow into my app.
A requirement of Wispr Flow in order to use their API is that you need to
request permission. Apparently however I got the permission, I was never told
about it. Because once I looked at my professional account for Wispr Flow, I
saw that I've been given approval to create API keys.
```

**Expected Response:**
- ~200-250 words
- 2-4 dated examples (e.g., "Firebase in August", "phase detection in October")
- No banned phrases
- No unrequested action items
- Warm, conversational tone
- Focus on personal persistence pattern, not strategic vision

---

**Resolution Date:** January 2026  
**Fixed By:** User prompt builder rewrite  
**Status:** ✅ **RESOLVED**

