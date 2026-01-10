# LUMARA Prompt Consolidation Proposal

**Status:** 📋 Proposal  
**Version:** 3.2  
**Date:** January 9, 2026

---

## Overview

Consolidate the master prompt and user prompt into a single, unified prompt to eliminate duplication, reduce maintenance burden, and prevent constraint conflicts.

---

## Current Architecture (Two-Prompt System)

### Master Prompt (System Prompt)
- **Location:** `lib/arc/chat/llm/prompts/lumara_master_prompt.dart`
- **Content:**
  - Persona definitions and behavioral rules
  - Control state interpretation
  - Word limit enforcement
  - Web access rules
  - All persona-specific instructions
- **Size:** ~1700 lines

### User Prompt
- **Location:** `lib/arc/chat/services/enhanced_lumara_api.dart` (`_buildUserPrompt()`)
- **Content:**
  - Historical context (baseContext)
  - Current entry text
  - Response requirements (duplicates master prompt constraints)
  - Persona-specific instructions (duplicates master prompt)
  - Mode-specific instructions
- **Size:** ~200 lines

### Current Flow
```dart
// Build control state
final controlStateJson = buildControlState(...);

// Get master prompt (system)
final systemPrompt = LumaraMasterPrompt.getMasterPrompt(controlStateJson);

// Build user prompt (reinforces constraints)
final userPrompt = _buildUserPrompt(...);

// Call LLM with both prompts
final response = await geminiSend(
  system: systemPrompt,
  user: userPrompt,
);
```

---

## Problems with Current System

1. **Duplication**
   - Word limits defined in both prompts
   - Persona instructions duplicated
   - Pattern example requirements repeated
   - Content type guidance in both places

2. **Override Risk**
   - User prompt comes after system prompt
   - LLM may prioritize later instructions
   - Risk of constraints being overridden (fixed in v3.0, but still fragile)

3. **Maintenance Burden**
   - Changes must be made in two places
   - Risk of inconsistencies
   - Harder to reason about behavior

4. **Code Complexity**
   - Two prompt builders to maintain
   - Complex interaction between prompts
   - Harder to debug

---

## Proposed Solution: Single Unified Prompt

### New Structure

```
┌─────────────────────────────────────────────────────────┐
│ UNIFIED LUMARA PROMPT                                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ SECTION 1: IDENTITY & BEHAVIORAL RULES                   │
│ - You are LUMARA...                                      │
│ - Control state JSON                                     │
│ - How to interpret control state                          │
│ - Persona definitions                                     │
│                                                          │
│ SECTION 2: CONSTRAINTS & REQUIREMENTS                    │
│ - Word limit enforcement                                  │
│ - Pattern example requirements                            │
│ - Content type guidance                                   │
│ - Banned phrases                                          │
│                                                          │
│ SECTION 3: CURRENT TASK                                   │
│ - Historical context (if any)                            │
│ - Current entry text                                      │
│ - Mode-specific instructions (if any)                    │
│                                                          │
│ SECTION 4: RESPONSE INSTRUCTIONS                          │
│ - Respond now following all constraints above             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Implementation

**New File:** `lib/arc/chat/llm/prompts/lumara_unified_prompt.dart`

```dart
class LumaraUnifiedPrompt {
  /// Build unified prompt with all instructions and content
  static String buildPrompt({
    required String controlStateJson,
    required String entryText,
    String? baseContext,
    String? modeSpecificInstructions,
  }) {
    final buffer = StringBuffer();
    
    // SECTION 1: Identity & Behavioral Rules
    buffer.writeln(_buildIdentitySection(controlStateJson));
    
    // SECTION 2: Constraints & Requirements
    buffer.writeln(_buildConstraintsSection(controlStateJson));
    
    // SECTION 3: Current Task
    buffer.writeln(_buildCurrentTaskSection(
      entryText: entryText,
      baseContext: baseContext,
      modeSpecificInstructions: modeSpecificInstructions,
    ));
    
    // SECTION 4: Response Instructions
    buffer.writeln(_buildResponseInstructions());
    
    return buffer.toString();
  }
  
  static String _buildIdentitySection(String controlStateJson) {
    return '''You are LUMARA, the user's Evolving Personal Intelligence (EPI).

Your behavior is governed entirely by the unified control state below.

This state is computed BACKEND-SIDE.

You DO NOT modify the state. You only follow it.

[LUMARA_CONTROL_STATE]
$controlStateJson
[/LUMARA_CONTROL_STATE]

Treat everything inside this block as the single, authoritative source of truth.

Your tone, reasoning style, pacing, warmth, structure, rigor, challenge level, therapeutic framing,
day/night shift, multimodal sensitivity, and web access capability MUST follow this profile exactly.

${_buildControlStateInterpretation()}
''';
  }
  
  static String _buildConstraintsSection(String controlStateJson) {
    // Parse control state to extract constraints
    final controlState = jsonDecode(controlStateJson);
    final responseMode = controlState['responseMode'];
    final persona = controlState['persona']['effective'];
    
    return '''
═══════════════════════════════════════════════════════════
CRITICAL CONSTRAINTS
═══════════════════════════════════════════════════════════

WORD LIMIT: ${responseMode['maxWords']} words MAXIMUM
- Count as you write
- STOP at ${responseMode['maxWords']} words
- This is NOT negotiable
- If you exceed the limit, you have FAILED

PATTERN EXAMPLES: ${responseMode['minPatternExamples']}-${responseMode['maxPatternExamples']} dated examples required
- Include specific dates or timeframes
- Examples:
  * "When you got stuck on Firebase in August..."
  * "Your Learning Space insight from September 15..."
  * "Like when you hit this threshold on October 3..."

CONTENT TYPE: ${responseMode['isPersonalContent'] ? 'PERSONAL REFLECTION' : 'PROJECT/WORK CONTENT'}
${_buildContentTypeGuidance(responseMode['isPersonalContent'])}

PERSONA: $persona
${_buildPersonaInstructions(persona, responseMode)}

${_buildBannedPhrases(persona)}
''';
  }
  
  static String _buildCurrentTaskSection({
    required String entryText,
    String? baseContext,
    String? modeSpecificInstructions,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('CURRENT TASK');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln();
    
    if (baseContext != null && baseContext.isNotEmpty) {
      buffer.writeln('HISTORICAL CONTEXT:');
      buffer.writeln(baseContext);
      buffer.writeln();
    }
    
    buffer.writeln('CURRENT ENTRY:');
    buffer.writeln(entryText);
    buffer.writeln();
    
    if (modeSpecificInstructions != null && modeSpecificInstructions.isNotEmpty) {
      buffer.writeln('MODE-SPECIFIC INSTRUCTION:');
      buffer.writeln(modeSpecificInstructions);
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  static String _buildResponseInstructions() {
    return '''
═══════════════════════════════════════════════════════════
RESPOND NOW
═══════════════════════════════════════════════════════════

Follow ALL constraints and requirements above.
''';
  }
  
  // Helper methods for building sections...
  static String _buildControlStateInterpretation() { /* ... */ }
  static String _buildContentTypeGuidance(bool isPersonal) { /* ... */ }
  static String _buildPersonaInstructions(String persona, Map responseMode) { /* ... */ }
  static String _buildBannedPhrases(String persona) { /* ... */ }
}
```

### Updated API Call

**File:** `lib/arc/chat/services/enhanced_lumara_api.dart`

```dart
// OLD (two prompts)
final systemPrompt = LumaraMasterPrompt.getMasterPrompt(controlStateJson);
final userPrompt = _buildUserPrompt(...);
final response = await geminiSend(
  system: systemPrompt,
  user: userPrompt,
);

// NEW (single prompt)
final unifiedPrompt = LumaraUnifiedPrompt.buildPrompt(
  controlStateJson: controlStateJson,
  entryText: request.userText,
  baseContext: baseContext,
  modeSpecificInstructions: _getModeSpecificInstructions(...),
);
final response = await geminiSend(
  system: unifiedPrompt,
  user: '', // Empty or minimal
);
```

---

## Migration Plan

### Phase 1: Create Unified Prompt Builder
1. Create `lumara_unified_prompt.dart`
2. Port all content from master prompt
3. Port entry-specific content from user prompt
4. Test with existing control state

### Phase 2: Update API Integration
1. Update `enhanced_lumara_api.dart` to use unified prompt
2. Remove `_buildUserPrompt()` method
3. Update `geminiSend()` call
4. Test end-to-end

### Phase 3: Cleanup
1. Mark `lumara_master_prompt.dart` as deprecated
2. Remove `_buildUserPrompt()` method
3. Update documentation
4. Remove old prompt files after validation period

### Phase 4: Validation
1. Run comparison tests (old vs new)
2. Verify response quality unchanged
3. Check constraint enforcement
4. Monitor for 1-2 weeks

---

## Benefits

1. **Single Source of Truth**
   - All constraints in one place
   - No duplication
   - Easier to reason about

2. **No Override Risk**
   - Can't have conflicting instructions
   - All constraints in one prompt
   - LLM sees everything at once

3. **Simpler Codebase**
   - One prompt builder instead of two
   - Less code to maintain
   - Clearer structure

4. **Easier Maintenance**
   - Update constraints in one place
   - No risk of inconsistencies
   - Simpler debugging

5. **Better Performance**
   - Potentially faster (one prompt vs two)
   - Less token overhead
   - Simpler API calls

---

## Risks & Considerations

1. **LLM Behavior**
   - Some LLMs treat system/user prompts differently
   - Need to verify Gemini handles single prompt well
   - May need to adjust formatting

2. **Prompt Length**
   - Single prompt may be longer
   - Need to monitor token usage
   - May need to optimize sections

3. **Backward Compatibility**
   - Old code may break
   - Need careful migration
   - Keep old code during transition

4. **Testing**
   - Need comprehensive testing
   - Compare old vs new responses
   - Verify all constraints still work

---

## Recommendation

**✅ PROCEED WITH CONSOLIDATION**

The benefits outweigh the risks:
- Eliminates duplication and override risk
- Simplifies codebase significantly
- Easier to maintain and debug
- Single source of truth

**Timeline:** 1-2 weeks for implementation and validation

---

## Questions to Answer

1. Does Gemini handle single-prompt well? (Test needed)
2. Should we keep old code during transition? (Yes, for safety)
3. How to handle prompt length? (Monitor and optimize)
4. What about chat mode? (Same consolidation applies)

