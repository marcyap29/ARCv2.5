# Correlation-Resistant PII Protection System

## Overview

This document describes the enhanced PII protection system that adds a correlation-resistant transformation layer on top of the existing PRISM scrubbing system. This prevents re-identification and cross-call linkage while preserving AI capability.

## Architecture

### Two-Layer Protection

1. **PRISM Layer** (Existing)
   - Detects and scrubs raw PII into tokens: `[EMAIL_1]`, `[NAME_1]`, `[PHONE_1]`, etc.
   - Creates reversible mapping (LOCAL ONLY)
   - Validates with `isSafeToSend()`

2. **Correlation-Resistant Layer** (New)
   - Transforms PRISM tokens into rotating aliases: `PERSON(H:7c91f2, S:⟡K3)`
   - Creates structured JSON abstraction instead of verbatim text
   - Implements session-based rotation to prevent cross-call linkage

### Flow Diagram

```
Raw Text
  ↓
PRISM Scrubbing → [EMAIL_1], [NAME_1], [PHONE_1]
  ↓
Correlation-Resistant Transformation
  ↓
Structured JSON Payload → Cloud (Gemini API)
  ↓
Response Processing
  ↓
PII Restoration (Local Only)
  ↓
Display to User
```

## Key Components

### 1. CorrelationResistantTransformer

**Location**: `lib/arc/chat/voice/voice_journal/correlation_resistant_transformer.dart`

**Purpose**: Transforms PRISM-scrubbed text into correlation-resistant payloads.

**Key Features**:
- Session-based rotation (default) or daily rotation (optional)
- Rotating salted hashes: `H:<short_hash>`
- Rotating symbols: `S:<symbol>`
- Structured JSON abstraction
- Local-only audit blocks

**Usage**:
```dart
final transformer = CorrelationResistantTransformer(
  rotationWindow: RotationWindow.session,
  prism: prismAdapter,
);

final result = await transformer.transform(
  prismScrubbedText: scrubbedText,
  intent: 'voice_journal',
  prismResult: prismResult,
);
```

### 2. PrismAdapter Enhancements

**Location**: `lib/arc/chat/voice/voice_journal/prism_adapter.dart`

**New Method**: `transformToCorrelationResistant()`

Convenience method that wraps the transformer:
```dart
final result = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: scrubbedText,
  intent: 'voice_journal',
  prismResult: prismResult,
  rotationWindow: RotationWindow.session,
);
```

### 3. Enhanced Security Guards

**Location**: `lib/arc/chat/voice/voice_journal/prism_adapter.dart`

**Updated**: `VoiceJournalSecurityGuard.validateBeforeGemini()`

Now validates:
1. No raw PII
2. PRISM tokens should be transformed to aliases
3. Alias format validation

### 4. Updated Gemini Client

**Location**: `lib/arc/chat/voice/voice_journal/gemini_client.dart`

**New Method**: `generateResponse()` (updated signature)

Accepts `CloudPayloadBlock` instead of plain text:
```dart
final response = await client.generateResponse(
  cloudPayload: transformationResult.cloudPayloadBlock,
  localAuditBlock: transformationResult.localAuditBlock,
  conversationHistory: history,
);
```

**Legacy Method**: `generateResponseLegacy()` (deprecated)

Kept for backward compatibility but marked as deprecated.

## Output Blocks

### Block A: LOCAL-ONLY (Never Transmit)

**Class**: `LocalAuditBlock`

Contains:
- PRISM scrub confirmation
- `isSafeToSend()` confirmation
- Token class counts (no raw values)
- Local alias dictionary (NEVER SENT)
- Window ID
- Timestamp

**Usage**: Local logging and audit only.

### Block B: CLOUD-PAYLOAD (Safe to Transmit)

**Class**: `CloudPayloadBlock`

Structured JSON with:
```json
{
  "pp_version": "PRISM+ROTATE-1.0",
  "rotation_window": "session",
  "window_id": "<opaque>",
  "intent": "<what user wants>",
  "task_type": "<summarize|plan|analyze|draft|debug|other>",
  "entities": {
    "people": ["PERSON(H:..., S:...)"],
    "orgs": ["ORG(H:..., S:...)"],
    "locations": ["LOC(H:..., S:...)"],
    "handles": ["HANDLE(H:..., S:...)"]
  },
  "time": {
    "granularity": "coarse",
    "buckets": ["2025-Q4", "recent-week", "recent-month"]
  },
  "constraints": [],
  "semantic_summary": "<non-verbatim paraphrase>",
  "themes": ["5-10 max"],
  "requested_outputs": [],
  "safety_notes": ["No raw PII sent", "Rotating aliases applied"]
}
```

## Rotation Windows

### Session Rotation (Default)

- New window per session/transformer instance
- Cleanest privacy boundary
- Minimal capability loss
- Recommended for most use cases

### Daily Rotation (Optional)

- New window per day
- Still enables linkage within a day
- Use only if explicitly configured

## Security Guarantees

### Non-Negotiable Rules

1. ✅ **Never send raw data**
2. ✅ **Never send raw PII or reconstructed PII**
3. ✅ **Never send reversible mapping**
4. ✅ **Never send verbatim user text** (uses abstraction)
5. ✅ **Protect PPI via hashes and symbols**
6. ✅ **Rotate identifiers per window**

### Validation Checks

1. PRISM scrubbing must pass
2. `isSafeToSend()` must pass
3. Enhanced validation checks alias format
4. Security exceptions thrown on violations

## Integration Points

### Voice Journal Pipeline

**File**: `lib/arc/chat/voice/voice_journal/voice_journal_pipeline.dart`

Already integrated via `VoiceJournalConversation.processTurn()`.

### Journal Capture Cubit

**File**: `lib/arc/core/journal_capture_cubit.dart`

Updated `_generateSummary()` method to use transformer.

### Gemini Client

**File**: `lib/arc/chat/voice/voice_journal/gemini_client.dart`

Updated to accept `CloudPayloadBlock` instead of plain text.

### Chat System (gemini_send.dart)

**File**: `lib/services/gemini_send.dart`

Updated `geminiSend()` function to:
- Use PRISM scrubbing (existing)
- Apply correlation-resistant transformation (new)
- Send structured JSON payloads instead of verbatim text
- Support optional `intent` parameter for better task type detection

**File**: `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

Chat system now automatically uses correlation-resistant transformation through `geminiSend()`.

## Usage Examples

### Basic Usage

```dart
// 1. Scrub with PRISM
final prismAdapter = PrismAdapter();
final prismResult = prismAdapter.scrub(rawText);

// 2. Validate
if (!prismAdapter.isSafeToSend(prismResult.scrubbedText)) {
  throw SecurityException('PII still detected');
}

// 3. Transform to correlation-resistant payload
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: prismResult.scrubbedText,
  intent: 'voice_journal',
  prismResult: prismResult,
);

// 4. Send to Gemini (structured payload)
final response = await geminiClient.generateResponse(
  cloudPayload: transformationResult.cloudPayloadBlock,
  localAuditBlock: transformationResult.localAuditBlock,
);

// 5. Restore PII for local display
final displayResponse = prismAdapter.restore(
  response,
  prismResult.reversibleMap,
);
```

### Voice Journal Integration

The voice journal pipeline automatically uses the transformer:

```dart
final turnResult = await conversation.processTurn(
  rawUserText: transcript,
  intent: 'voice_journal',
);
// turnResult contains transformation result
```

### Chat Integration

The chat system automatically uses the transformer through `geminiSend()`:

```dart
// Chat messages are automatically transformed
final response = await geminiSend(
  system: systemPrompt,
  user: userMessage,
  intent: 'chat', // Optional, defaults to 'chat'
  chatId: chatSessionId,
);
// Response has PII restored automatically
```

The `ArcLLM.chat()` method used by `LumaraAssistantCubit` automatically benefits from correlation-resistant transformation.

### Journal Entry Integration

Journal entries use a special flow to preserve natural language instructions:

```dart
// 1. Abstract entry text first (in enhanced_lumara_api.dart)
final entryTransformation = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: entryPrismResult.scrubbedText,
  intent: 'journal_reflection',
  prismResult: entryPrismResult,
);
final entryDescription = entryTransformation.cloudPayloadBlock.semanticSummary;

// 2. Build prompt with abstract description (natural language)
final userPrompt = 'Current entry: $entryDescription\n\n[instructions...]';

// 3. Skip transformation to preserve natural language
final response = await geminiSend(
  system: systemPrompt,
  user: userPrompt,
  skipTransformation: true, // Preserve natural language instructions
  entryId: entryId,
);
```

This ensures LUMARA receives natural language prompts with abstracted entry descriptions, not JSON payloads.

## Testing

### Security Validation

```dart
// Should pass
final transformer = CorrelationResistantTransformer();
final isValid = transformer.isSafeToSendEnhanced(aliasedText);

// Should fail
final isValid2 = transformer.isSafeToSendEnhanced(rawTextWithPII);
```

### Local Audit Block

```dart
final auditBlock = transformationResult.localAuditBlock;
print('Window ID: ${auditBlock.windowId}');
print('Token counts: ${auditBlock.tokenClassCounts}');
// NOTE: aliasDictionary is intentionally not accessible for security
```

## Migration Notes

### Backward Compatibility

- Legacy `generateResponseLegacy()` method still available (deprecated)
- Existing PRISM scrubbing still works
- Transformer is opt-in via new methods

### Breaking Changes

None. The system is backward compatible. New features are additive.

## Future Enhancements

1. **Local LLM for Abstraction**: Use on-device LLM for better semantic summaries
2. **Configurable Rotation**: User-configurable rotation windows
3. **Enhanced Entity Extraction**: Better entity type detection
4. **Theme Extraction**: More sophisticated theme detection
5. **Constraint Extraction**: Automatic constraint detection from text

## Security Considerations

1. **Local Dictionary**: The alias dictionary must NEVER leave the device
2. **Window Rotation**: Ensure windows rotate properly to prevent linkage
3. **Salt Security**: Salts are generated per window and never exposed
4. **Symbol Pool**: Symbol pool is large enough to prevent exhaustion
5. **Validation**: Multiple validation layers ensure no PII leakage

## Compliance

This system implements:
- ✅ GDPR compliance (no raw PII transmission)
- ✅ CCPA compliance (data minimization)
- ✅ HIPAA considerations (health data protection)
- ✅ Privacy by design principles

## References

- PRISM Scrubbing: `lib/services/lumara/pii_scrub.dart`
- PII Detection: `lib/echo/privacy_core/pii_detection_service.dart`
- Voice Journal: `lib/arc/chat/voice/voice_journal/`
