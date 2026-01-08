# LUMARA Output Generation - All Dart Files

## Critical Files That Control Output

### 1. **Master Prompt (System Prompt)**
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
  - ✅ **UPDATED** - Contains word limit enforcement
  - ✅ **UPDATED** - Contains Companion mode detection
  - ✅ **UPDATED** - Contains banned phrases list
  - ⚠️ **PROBLEM**: User prompt overrides these constraints

### 2. **User Prompt Builder (THE PROBLEM)**
- `lib/arc/chat/services/enhanced_lumara_api.dart`
  - ❌ **BROKEN** - Lines 386, 389, 392, 395, 398: "Be thorough and detailed - there is no limit on response length"
  - ❌ **BROKEN** - Lines 400-418: Instructions to "ACTIVELY reference past journal entries" causing project name-dropping
  - ❌ **BROKEN** - Lines 408-416: "You are encouraged to offer gentle guidance" causing unrequested action items
  - ❌ **BROKEN** - No word limit enforcement in user prompt
  - ❌ **BROKEN** - No banned phrases enforcement in user prompt
  - ❌ **BROKEN** - No dated examples requirement in user prompt

### 3. **Control State Builder**
- `lib/arc/chat/services/lumara_control_state_builder.dart`
  - ✅ **UPDATED** - Sets persona.effective
  - ✅ **UPDATED** - Sets responseMode.maxWords
  - ✅ **UPDATED** - Sets entryClassification
  - ✅ **UPDATED** - Uses PersonaSelector for Companion-first logic

### 4. **Response Mode Configuration**
- `lib/services/lumara/response_mode_v2.dart`
  - ✅ **UPDATED** - Sets maxWords: 250 for Companion
  - ✅ **UPDATED** - Sets pattern example requirements
  - ✅ **UPDATED** - Sets isPersonalContent flag

### 5. **Entry Classification**
- `lib/services/lumara/entry_classifier.dart`
  - ✅ **WORKING** - Classifies entries correctly

### 6. **Persona Selection**
- `lib/services/lumara/persona_selector.dart`
  - ✅ **UPDATED** - Companion-first logic implemented

### 7. **User Intent Detection**
- `lib/services/lumara/user_intent.dart`
  - ✅ **UPDATED** - Maps ConversationMode to UserIntent

### 8. **Context Builder**
- `lib/arc/chat/llm/prompts/lumara_context_builder.dart`
  - ✅ **UPDATED** - Favorites are library-only

### 9. **Master Prompt Builder (Alternative - Not Currently Used)**
- `lib/services/lumara/master_prompt_builder.dart`
  - ⚠️ **NOT USED** - This is the v3.0 prompt builder but `enhanced_lumara_api.dart` uses `LumaraMasterPrompt` instead
  - Contains correct constraints but isn't being called

## Root Cause

The **user prompt** in `enhanced_lumara_api.dart` is overriding the master prompt constraints:

1. **Word Limit**: User prompt says "no limit on response length" (lines 386, 389, 392, 395, 398)
2. **Pattern Recognition**: User prompt says "ACTIVELY reference past journal entries" without requiring dates (lines 400-418)
3. **Action Items**: User prompt says "You are encouraged to offer gentle guidance" (lines 408-416)
4. **Banned Phrases**: No enforcement in user prompt
5. **Dated Examples**: No requirement in user prompt

## Files That Need Fixing

### Priority 1: User Prompt (CRITICAL)
- `lib/arc/chat/services/enhanced_lumara_api.dart`
  - Remove "no limit on response length" instructions
  - Add word limit enforcement from control state
  - Add dated examples requirement
  - Remove unrequested action item encouragement
  - Add banned phrases reference

### Priority 2: Verify Master Prompt
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
  - Already updated but verify it's being used correctly

### Priority 3: Context Building
- `lib/arc/chat/services/enhanced_lumara_api.dart` (lines 432-464)
  - May need to limit historical context to prevent over-referencing

## Summary

**The master prompt has the correct constraints, but the user prompt is overriding them.**

The user prompt needs to:
1. Respect `responseMode.maxWords` from control state
2. Require 2-4 dated examples for Companion mode
3. Not encourage unrequested action items
4. Reference banned phrases list
5. Focus on personal patterns, not strategic project references

