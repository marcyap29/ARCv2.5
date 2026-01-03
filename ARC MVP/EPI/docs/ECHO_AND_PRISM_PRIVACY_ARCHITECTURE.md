# ECHO and PRISM Privacy Architecture

**Version:** 2.1.84  
**Last Updated:** January 2025  
**Status:** ✅ Production Ready

---

## Overview

ARC implements a two-layer privacy architecture combining **ECHO** (Privacy & Security) and **PRISM** (Privacy-Resistant Information Scrubber Module) to provide comprehensive PII protection while maintaining AI capability. This document explains how these systems work together to protect user privacy.

---

## Architecture Overview

### Two-Layer Protection

```
┌─────────────────────────────────────────────────────────┐
│                    USER INPUT                            │
│         (Raw Text with PII)                             │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              LAYER 1: PRISM SCRUBBING                   │
│  • PII Detection (Pattern Matching)                    │
│  • Token Replacement ([EMAIL_1], [NAME_1])            │
│  • Reversible Map Creation (LOCAL ONLY)                │
│  • Security Validation                                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│      LAYER 2: CORRELATION-RESISTANT TRANSFORMATION     │
│  • Rotating Aliases (PERSON(H:7c91f2, S:⟡K3))        │
│  • Structured JSON Abstraction                         │
│  • Session-Based Rotation                              │
│  • Semantic Summary (Non-Verbatim)                     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              EXTERNAL AI SERVICE                        │
│         (Gemini API / Cloud LLM)                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              PII RESTORATION (LOCAL)                    │
│  • Use Reversible Map                                  │
│  • Restore Original Names/Data                         │
│  • Display to User                                     │
└─────────────────────────────────────────────────────────┘
```

---

## ECHO: Privacy & Security Layer

### What is ECHO?

**ECHO** (Privacy & Security) is ARC's internal privacy and security module that provides:
- PII detection and masking
- Privacy guardrails and validation
- Secure voice processing pipeline
- Privacy redaction in chat messages

### ECHO Components

#### 1. **PrismAdapter**
**Location**: `lib/arc/internal/echo/prism_adapter.dart`

ARC-specific adapter that wraps the PiiScrubber service and provides:
- Simplified API for voice journal and chat systems
- Integration with correlation-resistant transformation
- Security guardrails and validation

**Key Responsibilities**:
- Scrub PII from text
- Create reversible mapping (local only)
- Validate security before transmission
- Transform to correlation-resistant payloads
- Restore PII in responses (local only)

#### 2. **CorrelationResistantTransformer**
**Location**: `lib/arc/internal/echo/correlation_resistant_transformer.dart`

Transforms PRISM-scrubbed text into correlation-resistant payloads that:
- Prevent re-identification
- Prevent cross-call linkage
- Preserve AI capability
- Use rotating aliases instead of static tokens

**Key Features**:
- Session-based rotation (default)
- Rotating salted hashes: `H:<short_hash>`
- Rotating symbols: `S:<symbol>`
- Structured JSON abstraction
- Local-only audit blocks

#### 3. **VoicePipeline**
**Location**: `lib/arc/internal/echo/voice_pipeline.dart`

Secure voice processing pipeline that orchestrates:
- Speech-to-text transcription
- PRISM scrubbing
- Correlation-resistant transformation
- LLM interaction
- Text-to-speech response
- PII restoration

#### 4. **PrivacyRedactor**
**Location**: `lib/arc/internal/echo/privacy_redactor.dart`

Privacy redaction for chat messages:
- Real-time PII masking
- Chat-specific privacy rules
- User-configurable privacy levels

---

## PRISM: Privacy-Resistant Information Scrubber Module

### What is PRISM?

**PRISM** is the core PII detection and scrubbing system that:
- Detects PII using pattern matching
- Replaces PII with tokens (`[EMAIL_1]`, `[NAME_1]`, etc.)
- Creates reversible mapping (local only)
- Validates security before transmission

### PRISM Components

#### 1. **PiiScrubber Service**
**Location**: `lib/services/lumara/pii_scrub.dart`

Core service that performs PII detection and scrubbing:
- Pattern-based PII detection
- RIVET-gated keyword extraction
- Reversible mapping creation
- PII restoration

#### 2. **PII Detection Patterns**

PRISM detects:
- **Email Addresses**: `[EMAIL_1]`, `[EMAIL_2]`, etc.
- **Phone Numbers**: `[PHONE_1]`, `[PHONE_2]`, etc.
- **Physical Addresses**: `[ADDRESS_1]`, `[ADDRESS_2]`, etc.
- **Names**: `[NAME_1]`, `[NAME_2]`, etc. (Bible names whitelisted)
- **Dates**: `[DATE_MMYYYY]` (day masked)
- **Organizations**: `[ORG_1]`, `[ORG_2]`, etc.
- **Social Media Handles**: `[HANDLE_1]`, `[HANDLE_2]`, etc.

---

## How ECHO and PRISM Work Together

### Integration Flow

#### 1. **User Input**
```dart
// Raw user text with PII
final rawText = "I met with John Smith at john.smith@example.com";
```

#### 2. **PRISM Scrubbing (Layer 1)**
```dart
final prismAdapter = PrismAdapter();
final prismResult = prismAdapter.scrub(rawText);

// Result:
// scrubbedText: "I met with [NAME_1] at [EMAIL_1]"
// reversibleMap: {"[NAME_1]": "John Smith", "[EMAIL_1]": "john.smith@example.com"}
// findings: ["name", "email"]
```

#### 3. **Security Validation**
```dart
if (!prismAdapter.isSafeToSend(prismResult.scrubbedText)) {
  throw SecurityException('PII still detected after scrubbing');
}
```

#### 4. **Correlation-Resistant Transformation (Layer 2)**
```dart
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: prismResult.scrubbedText,
  intent: 'voice_journal',
  prismResult: prismResult,
  rotationWindow: RotationWindow.session,
);

// Result:
// cloudPayloadBlock: Structured JSON with rotating aliases
// localAuditBlock: Local-only audit information
```

#### 5. **Transmission to External Service**
```dart
// Send structured JSON payload (not verbatim text)
final response = await geminiClient.generateResponse(
  cloudPayload: transformationResult.cloudPayloadBlock,
  localAuditBlock: transformationResult.localAuditBlock,
);
```

#### 6. **PII Restoration (Local Only)**
```dart
// Restore PII in response for local display
final restoredResponse = prismAdapter.restore(
  response,
  prismResult.reversibleMap,
);
```

---

## Correlation-Resistant Transformation

### Why Correlation-Resistant?

Even with PRISM scrubbing, static tokens like `[NAME_1]` can be:
- **Linked across calls** - Same token in multiple requests
- **Re-identified** - Patterns in token usage
- **Correlated** - Combined with other data to identify users

### Solution: Rotating Aliases

Instead of static tokens, use **rotating aliases** that change per session:

**Before (PRISM only)**:
```
I met with [NAME_1] at [EMAIL_1]
```

**After (Correlation-Resistant)**:
```json
{
  "entities": {
    "people": ["PERSON(H:7c91f2, S:⟡K3)"],
    "emails": ["EMAIL(H:a3b4c5, S:◊M7)"]
  },
  "semantic_summary": "User met with a person at an email address"
}
```

### Rotation Windows

#### Session Rotation (Default)
- New window per session/transformer instance
- Cleanest privacy boundary
- Minimal capability loss
- Recommended for most use cases

#### Daily Rotation (Optional)
- New window per day
- Still enables linkage within a day
- Use only if explicitly configured

---

## Security Guarantees

### Non-Negotiable Rules

1. ✅ **Never send raw data**
2. ✅ **Never send raw PII or reconstructed PII**
3. ✅ **Never send reversible mapping**
4. ✅ **Never send verbatim user text** (uses abstraction)
5. ✅ **Protect PII via hashes and symbols**
6. ✅ **Rotate identifiers per window**

### Validation Layers

#### 1. **Pre-Scrub Check**
```dart
if (prismAdapter.containsPII(rawText)) {
  // PII detected, proceed with scrubbing
}
```

#### 2. **Post-Scrub Validation**
```dart
if (!prismAdapter.isSafeToSend(scrubbedText)) {
  throw SecurityException('PII still detected after scrubbing');
}
```

#### 3. **Guardrail Checks**
```dart
VoiceJournalSecurityGuard.validateBeforeGemini(scrubbedText);
```

#### 4. **Enhanced Validation** (with transformer)
```dart
if (!transformer.isSafeToSendEnhanced(text)) {
  throw SecurityException('PRISM tokens should be transformed to aliases');
}
```

---

## Data Flow Examples

### Example 1: Voice Journal Entry

```
1. User speaks: "I had a meeting with Sarah Johnson at sarah@company.com"
   ↓
2. STT Transcription: "I had a meeting with Sarah Johnson at sarah@company.com"
   ↓
3. PRISM Scrubbing: "I had a meeting with [NAME_1] at [EMAIL_1]"
   ↓
4. Correlation-Resistant Transformation:
   {
     "entities": {
       "people": ["PERSON(H:abc123, S:⟡K3)"],
       "emails": ["EMAIL(H:def456, S:◊M7)"]
     },
     "semantic_summary": "User had a meeting with a person at an email address"
   }
   ↓
5. Send to Gemini API (structured JSON)
   ↓
6. Gemini Response: "That sounds like an important meeting with PERSON(H:abc123, S:⟡K3)"
   ↓
7. PII Restoration: "That sounds like an important meeting with Sarah Johnson"
   ↓
8. Display to User
```

### Example 2: Chat Message

```
1. User types: "Can you remind me about my appointment with Dr. Smith?"
   ↓
2. PRISM Scrubbing: "Can you remind me about my appointment with [NAME_1]?"
   ↓
3. Correlation-Resistant Transformation:
   {
     "entities": {
       "people": ["PERSON(H:xyz789, S:★P2)"]
     },
     "semantic_summary": "User asking for reminder about appointment with a person"
   }
   ↓
4. Send to Gemini API
   ↓
5. Gemini Response: "I'll remind you about your appointment with PERSON(H:xyz789, S:★P2)"
   ↓
6. PII Restoration: "I'll remind you about your appointment with Dr. Smith"
   ↓
7. Display to User
```

---

## Local-Only Data

### What Stays Local

The following data **NEVER** leaves the device:

1. **Raw User Input** - Original text with PII
2. **Reversible Map** - Mapping of tokens to original values
3. **Local Audit Block** - Full audit information including alias dictionary
4. **Window IDs** - Opaque identifiers for rotation windows
5. **Salt Values** - Used for hashing (never exposed)

### What Gets Transmitted

Only the following data is sent to external services:

1. **Cloud Payload Block** - Structured JSON with rotating aliases
2. **Semantic Summary** - Non-verbatim abstract description
3. **Themes** - High-level themes extracted from content
4. **Entity Types** - Type of entity (PERSON, EMAIL, etc.) without values

---

## Privacy Architecture Benefits

### 1. **Prevents Re-Identification**
- Rotating aliases prevent linking across calls
- Session-based rotation ensures clean boundaries
- No static identifiers that can be tracked

### 2. **Preserves AI Capability**
- Structured JSON maintains semantic meaning
- Entity types preserved for context
- Themes and summaries enable intelligent responses

### 3. **Maintains User Experience**
- PII restored locally for natural responses
- User sees original names and data
- No degradation in conversation quality

### 4. **Compliance Ready**
- GDPR compliant (no raw PII transmission)
- CCPA compliant (data minimization)
- HIPAA considerations (health data protection)
- Privacy by design principles

---

## Integration Points

### 1. Voice Journal Pipeline

**Location**: `lib/arc/internal/echo/voice_pipeline.dart`

```dart
// Step 3: PRISM Scrubbing
final scrubResult = _prism.scrub(rawTranscript);

// Step 4: Correlation-Resistant Transformation
final transformationResult = await _prism.transformToCorrelationResistant(
  prismScrubbedText: scrubResult.scrubbedText,
  intent: 'voice_journal',
  prismResult: scrubResult,
);

// Step 5: Send to Gemini
final response = await _gemini.generateResponse(
  cloudPayload: transformationResult.cloudPayloadBlock,
);
```

### 2. Journal Entry Summary Generation

**Location**: `lib/arc/core/journal_capture_cubit.dart`

```dart
// Scrub and transform
final prismResult = prismAdapter.scrub(content);
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: prismResult.scrubbedText,
  intent: 'summary',
  prismResult: prismResult,
);

// Send structured payload
final summary = await _lumaraApi.generatePromptedReflection(
  entryText: transformationResult.cloudPayloadBlock.toJsonString(),
  intent: 'summary',
  // ...
);
```

### 3. Chat System

**Location**: `lib/services/gemini_send.dart`

Chat messages automatically use PRISM scrubbing and correlation-resistant transformation.

---

## Security Architecture

### Defense in Depth

ARC implements multiple layers of security:

1. **Layer 1: PRISM Scrubbing** - Removes raw PII
2. **Layer 2: Correlation-Resistant Transformation** - Prevents linkage
3. **Layer 3: Security Validation** - Multiple guardrail checks
4. **Layer 4: Local-Only Storage** - Reversible map never transmitted

### Security Exceptions

If any validation fails, a `SecurityException` is thrown:
- Prevents accidental PII transmission
- Logs security violations (without sensitive data)
- Stops processing until issue is resolved

---

## Best Practices

### 1. **Always Use Both Layers**
```dart
// ✅ GOOD - Use both PRISM and correlation-resistant transformation
final prismResult = prismAdapter.scrub(rawText);
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: prismResult.scrubbedText,
  intent: 'voice_journal',
  prismResult: prismResult,
);

// ❌ BAD - Only using PRISM (vulnerable to correlation)
final prismResult = prismAdapter.scrub(rawText);
await sendToGemini(prismResult.scrubbedText);
```

### 2. **Validate at Every Step**
```dart
// Validate after scrubbing
if (!prismAdapter.isSafeToSend(prismResult.scrubbedText)) {
  throw SecurityException('PII still detected');
}

// Validate before sending
VoiceJournalSecurityGuard.validateBeforeGemini(transformationResult.cloudPayloadBlock.toJsonString());
```

### 3. **Never Transmit Local-Only Data**
```dart
// ❌ BAD - NEVER DO THIS
await sendToServer({
  'payload': cloudPayloadBlock,
  'reversibleMap': reversibleMap, // SECURITY VIOLATION
  'localAudit': localAuditBlock, // SECURITY VIOLATION
});

// ✅ GOOD
await sendToServer({
  'payload': cloudPayloadBlock.toJsonString(),
  // reversibleMap and localAuditBlock stay local
});
```

### 4. **Use Session Rotation**
```dart
// ✅ GOOD - Session rotation (default, cleanest)
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  // ...
  rotationWindow: RotationWindow.session,
);

// ⚠️ CAUTION - Daily rotation (only if explicitly needed)
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  // ...
  rotationWindow: RotationWindow.daily,
);
```

---

## Compliance

This architecture helps ARC comply with:

- ✅ **GDPR** - No raw PII transmission without consent
- ✅ **CCPA** - Data minimization principles
- ✅ **HIPAA** - Health information protection
- ✅ **Privacy by Design** - Privacy built into architecture
- ✅ **Zero-Knowledge Architecture** - Service provider cannot identify users

---

## Technical Details

### Rotation Mechanism

#### Window ID Generation
```dart
String _generateOpaqueWindowId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return base64Url.encode(bytes).substring(0, 16);
}
```

#### Salted Hash Generation
```dart
String _generateSaltedHash(String prismToken, String windowId) {
  final salt = '$windowId:$prismToken:${DateTime.now().millisecondsSinceEpoch}';
  final bytes = utf8.encode(salt);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 6); // Short hash
}
```

#### Symbol Rotation
- Uses a pool of 40+ Unicode symbols
- Prevents reuse within a window
- Falls back to alphanumeric if pool exhausted

### Structured JSON Payload

The cloud payload is structured JSON, not verbatim text:

```json
{
  "pp_version": "PRISM+ROTATE-1.0",
  "rotation_window": "session",
  "window_id": "<opaque>",
  "intent": "voice_journal",
  "task_type": "summarize",
  "entities": {
    "people": ["PERSON(H:7c91f2, S:⟡K3)"],
    "emails": ["EMAIL(H:a3b4c5, S:◊M7)"]
  },
  "time": {
    "granularity": "coarse",
    "buckets": ["2025-Q4", "recent-week"]
  },
  "semantic_summary": "User met with a person at an email address",
  "themes": ["meeting", "communication"],
  "requested_outputs": ["summary"],
  "safety_notes": ["No raw PII sent", "Rotating aliases applied"]
}
```

---

## Future Enhancements

1. **Local LLM for Abstraction** - Use on-device LLM for better semantic summaries
2. **Configurable Rotation** - User-configurable rotation windows
3. **Enhanced Entity Extraction** - Better entity type detection
4. **Theme Extraction** - More sophisticated theme detection
5. **Constraint Extraction** - Automatic constraint detection from text
6. **Multi-Language Support** - PII detection for other languages
7. **Machine Learning Detection** - ML models for better PII detection

---

## References

- **PRISM Adapter**: `lib/arc/internal/echo/prism_adapter.dart`
- **Correlation-Resistant Transformer**: `lib/arc/internal/echo/correlation_resistant_transformer.dart`
- **Voice Pipeline**: `lib/arc/internal/echo/voice_pipeline.dart`
- **PII Scrubber**: `lib/services/lumara/pii_scrub.dart`
- **Privacy Scrubbing Documentation**: `docs/PRIVACY_SCRUBBING_AND_DATA_CLEANING.md`
- **Correlation-Resistant PII**: `docs/CORRELATION_RESISTANT_PII.md`

---

## Summary

The ECHO and PRISM privacy architecture provides:

1. **Two-Layer Protection** - PRISM scrubbing + correlation-resistant transformation
2. **Local-First Privacy** - All PII detection and scrubbing on-device
3. **Reversible Mapping** - PII can be restored locally for natural UX
4. **Security Validation** - Multiple guardrail checks prevent leakage
5. **Compliance Ready** - GDPR, CCPA, HIPAA compliant architecture

**Key Takeaway**: ECHO and PRISM work together to ensure that no raw PII ever leaves the device, while maintaining AI capability and natural user experience through local PII restoration.

