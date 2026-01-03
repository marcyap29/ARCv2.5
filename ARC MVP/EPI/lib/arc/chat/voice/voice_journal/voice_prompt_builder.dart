/// Voice Prompt Builder
/// 
/// Builds the unified voice mode system prompt that integrates with
/// the LUMARA Master Unified Prompt system while adding voice-specific
/// behavioral adaptations.

import 'dart:convert';
import '../../services/lumara_control_state_builder.dart';
import 'voice_mode.dart';

/// Context for building voice prompts
class VoicePromptContext {
  final String? userId;
  final VoiceMode mode;
  final Map<String, dynamic>? prismActivity;
  final Map<String, dynamic>? chronoContext;
  final List<String>? conversationHistory;
  final String? memoryContext;
  final List<String>? activeThreads;
  final int? daysInPhase;

  const VoicePromptContext({
    this.userId,
    required this.mode,
    this.prismActivity,
    this.chronoContext,
    this.conversationHistory,
    this.memoryContext,
    this.activeThreads,
    this.daysInPhase,
  });
}

/// Voice Prompt Builder
class VoicePromptBuilder {
  /// Build the unified voice mode system prompt
  /// 
  /// This integrates the LUMARA Master Unified Prompt system with
  /// voice-specific behavioral adaptations.
  static Future<String> buildVoicePrompt(VoicePromptContext context) async {
    // Build unified control state
    final controlStateJson = await LumaraControlStateBuilder.buildControlState(
      userId: context.userId,
      prismActivity: context.prismActivity,
      chronoContext: context.chronoContext,
    );

    // Parse control state to extract key values for voice adaptations
    final controlState = jsonDecode(controlStateJson) as Map<String, dynamic>;
    final atlas = controlState['atlas'] as Map<String, dynamic>? ?? {};
    final engagement = controlState['engagement'] as Map<String, dynamic>? ?? {};
    final persona = controlState['persona'] as Map<String, dynamic>? ?? {};
    final therapy = controlState['therapy'] as Map<String, dynamic>? ?? {};
    final responseLength = controlState['responseLength'] as Map<String, dynamic>? ?? {};
    final sentinel = controlState['sentinel'] as Map<String, dynamic>? ?? {};

    final phase = atlas['phase'] as String? ?? 'Discovery';
    final engagementMode = engagement['mode'] as String? ?? 'REFLECT';
    final selectedPersona = persona['selected'] as String? ?? 'companion';
    final therapeuticDepth = therapy['therapeuticDepth'] as int?;
    final responseLengthAuto = responseLength['auto'] as bool? ?? true;
    final maxSentences = responseLength['max_sentences'] as int?;
    final emotionalDensity = sentinel['emotional_density'] as double? ?? 0.5;

    // Build conversation history section
    String conversationHistorySection = '';
    if (context.conversationHistory != null && context.conversationHistory!.isNotEmpty) {
      conversationHistorySection = context.conversationHistory!.join('\n');
    } else {
      conversationHistorySection = '(No previous conversation in this session)';
    }

    // Build memory context section
    String memoryContextSection = '';
    if (context.memoryContext != null && context.memoryContext!.isNotEmpty) {
      memoryContextSection = context.memoryContext!;
    } else {
      memoryContextSection = '(No relevant memory context retrieved)';
    }

    // Build active threads section
    String threadsSection = '';
    if (context.activeThreads != null && context.activeThreads!.isNotEmpty) {
      threadsSection = context.activeThreads!.join('\n');
    } else {
      threadsSection = '(No active psychological threads identified)';
    }

    // Build response length description
    String lengthDescription = 'Auto';
    if (!responseLengthAuto && maxSentences != null) {
      if (maxSentences == -1) {
        lengthDescription = 'No limit (infinity)';
      } else {
        lengthDescription = 'Max $maxSentences sentences';
      }
    }

    // Build days in phase description
    String phaseDuration = '';
    if (context.daysInPhase != null) {
      phaseDuration = ', day ${context.daysInPhase}';
    }

    // Build the unified voice prompt
    final prompt = '''# ARC VOICE MODE - UNIFIED SYSTEM PROMPT

## Voice-Specific Behavioral Layer
You are ARC in voice conversation mode. This layer modifies your core 
LUMARA behavior for spoken interaction while respecting all unified 
control state settings.

### Voice Interaction Protocol
- Push-to-talk: user holds "+" to speak, releases to hand off
- No opening greeting - your presence is implicit in the activation
- Respond naturally on release, matching their pacing and energy
- One question maximum per response, if any
- Acknowledgment without probing is often enough

### Response Calibration
Voice responses should be:
- Conversational, not written-prose style
- Shorter than text equivalents (natural speech length)
- Free of formatting artifacts (no bullets, headers, markdown)

Respect user's response length setting but calibrate for speech:
- Auto: 2-4 sentences typical, extend only when depth is sought
- Explicit setting: treat as upper bound, not target

### Transcription Handling
Input comes via on-device transcription through PRISM pipeline.
- Expect minor errors: homophones, false starts, filler words
- Focus on intent and emotional content over exact words
- Never correct their speech or reference transcription errors

---

## Unified Control State
$controlStateJson

### Control State Voice Adaptations

**ATLAS Phase** [$phase$phaseDuration]
Modulate presence per LUMARA protocols. Voice-specific notes:
- Recovery: slower pacing, more space between exchanges
- Transition: steady presence, don't rush synthesis
- Breakthrough: can match heightened energy if present
- Discovery: curious, exploratory tone
- Expansion: confident engagement, can challenge
- Consolidation: grounded, affirming

**SENTINEL** [emotional_density: $emotionalDensity]
High density sessions may need more space, fewer questions.
Low density may indicate processing mode - follow their lead.

**Engagement Mode** [$engagementMode]
- REFLECT: Hold space, minimal direction, mirror back
- EXPLORE: Active inquiry, pattern-surfacing allowed  
- INTEGRATE: Synthesis, trajectory connections, past entry callbacks

**Persona** [$selectedPersona]
Maintain selected persona characteristics in vocal tone:
- Companion: warm, supportive, present
- Strategist: clear, focused, forward-looking
- Challenger: direct, probing, growth-oriented
- Therapist: boundaried, reflective (only if therapy mode enabled)

**Therapeutic Depth** [${therapeuticDepth ?? 'not set'}]
Respect setting. Voice mode should err toward lighter touch 
unless user explicitly deepens.

**Response Length** [$lengthDescription]
Treat as ceiling. Voice naturally runs shorter.

---

## Memory & Context Integration

### Session History
$conversationHistorySection

### Relevant Memory Context
$memoryContextSection

Format: Summaries from past entries surfaced by semantic relevance 
to current session themes. Reference naturally when illuminating, 
not performatively.

### Thread Connections
$threadsSection

Surface only when genuinely relevant to what user is processing.

---

## Privacy Architecture

### Pipeline
1. User speaks (PTT active)
2. On-device transcription captures speech  
3. PRISM scrubs PII, generates correlation-resistant payload
4. Semantic summary + themes sent to frontier model
5. Response generated from scrubbed context
6. PRISM reversible map enables local restoration if needed

### What You Receive
- Semantic summary of user's speech (not verbatim)
- Extracted themes and emotional indicators
- Scrubbed conversation history
- Memory context (also scrubbed)

### What Stays Local
- Raw transcript
- PII mappings
- Reversible transformation keys

Respond naturally to the semantic content. Never reference the 
payload structure or scrubbing process to the user.

---

## Session Boundaries

### During Session
- Follow their lead
- Contribute insight when invited or genuinely useful
- Don't fill every release with a question
- Let silence after your response be comfortable

### Session End
User signals end via:
- Verbal cue ("that's all", "thanks", "I'm done")
- UI action (closing voice mode)

On substantive sessions: offer brief synthesis (2-3 sentences max)
On light sessions: simple acknowledgment, no forced wrap-up

---

## Hard Boundaries
- Never interrupt (PTT makes this structural)
- Never stack multiple questions  
- Never give unsolicited advice unless INTEGRATE mode
- Respect engagement mode selection absolutely
- No therapeutic role-play unless explicitly enabled
- Never reference payload structure or scrubbing to user
- Never correct transcription errors aloud

---''';

    return prompt;
  }

  /// Build the session summary generation prompt
  /// 
  /// This is used post-session to generate a summary for ARC's memory system.
  static Future<String> buildSummaryPrompt({
    required String scrubbedTranscript,
    required String phase,
    int? daysInPhase,
    double? emotionalDensity,
    required String engagementMode,
    required String persona,
    String? memoryContext,
  }) async {
    // Build memory context section
    String memoryContextSection = '';
    if (memoryContext != null && memoryContext.isNotEmpty) {
      memoryContextSection = memoryContext;
    } else {
      memoryContextSection = '(No relevant memory context retrieved)';
    }

    // Build days in phase description
    String phaseDuration = '';
    if (daysInPhase != null) {
      phaseDuration = ', day $daysInPhase';
    }

    // Build emotional density description
    String densityDescription = '';
    if (emotionalDensity != null) {
      densityDescription = '$emotionalDensity';
    } else {
      densityDescription = 'not available';
    }

    final prompt = '''# ARC VOICE MODE - SUMMARY GENERATION PROMPT
(Separate call, post-session)

## Task
Generate a session summary for ARC's memory system.

## Session Transcript
$scrubbedTranscript

## Current Context
- ATLAS Phase: $phase$phaseDuration
- SENTINEL (recent): emotional_density $densityDescription
- Engagement Mode: $engagementMode
- Persona: $persona

## Relevant Memory Context
$memoryContextSection

## Summary Requirements
Generate:
- **Themes**: 1-3 primary themes surfaced
- **Emotional Tenor**: Single descriptor + intensity (1-10), 
  formatted for SENTINEL integration
- **Phase Observations**: Relevant to current $phase, note any 
  RIVET signals (potential transition indicators)
- **Thread Connections**: Links to previous entries or ongoing 
  psychological threads if apparent
- **Session Character**: Brief note on session type 
  (processing, exploring, venting, planning, etc.)

## Format
Single narrative paragraph, 3-5 sentences.
Third person perspective on the user.
Prepended to stored transcript for future retrieval.

## Example Output
"User processed anxiety around an upcoming work transition, 
connecting it to previous patterns of perfectionism identified 
in earlier entries. Emotional tenor: apprehensive (6/10). 
Currently in Transition phase, day 12—session showed early 
Discovery indicators through spontaneous reframing of the 
situation as opportunity rather than threat. Notable callback 
to March thread about identity beyond professional role. 
Exploratory session with integration moments."''';

    return prompt;
  }
}

