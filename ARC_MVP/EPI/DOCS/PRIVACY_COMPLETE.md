# Privacy & PII Protection - Complete Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [PRISM Scrubbing System](#prism-scrubbing-system)
3. [Correlation-Resistant PII Protection](#correlation-resistant-pii-protection)
4. [Private Notes Privacy Guarantee](#private-notes-privacy-guarantee)
5. [Architecture](#architecture)
6. [Usage Examples](#usage-examples)
7. [Security Validation](#security-validation)

---

## Overview

ARC implements a comprehensive privacy scrubbing and data cleaning system called **PRISM** (Privacy-Resistant Information Scrubber Module). PRISM ensures that no Personally Identifiable Information (PII) leaves the device before being processed by external AI services, while maintaining the ability to restore PII locally for user display.

**Core Principles:**
1. **Local-First Privacy** - All PII detection and scrubbing happens **on-device**
2. **Reversible Mapping** - PRISM creates a **reversible map** of scrubbed tokens to original values (LOCAL ONLY)
3. **Security Validation** - Multiple validation layers ensure no PII leakage
4. **Correlation Resistance** - Enhanced layer prevents re-identification and cross-call linkage
5. **Private Notes Isolation** - Private Notes are architecturally isolated from all intelligence layers

---

## PRISM Scrubbing System

### Core Components

#### 1. PiiScrubber Service
**Location**: `lib/services/lumara/pii_scrub.dart`

Core service that performs PII detection and scrubbing using pattern matching and RIVET-gated keyword extraction.

**Key Methods**:
- `rivetScrubWithMapping(String text)` - Main scrubbing method with reversible mapping
- `containsPii(String text)` - Quick PII detection check
- `restore(String scrubbedText, Map<String, String> map)` - Restore original PII

#### 2. PrismAdapter
**Location**: `lib/arc/internal/echo/prism_adapter.dart`

ARC-specific adapter that wraps the PiiScrubber service and provides:
- Simplified API for voice journal and chat systems
- Integration with correlation-resistant transformation
- Security guardrails and validation

**Key Methods**:
- `scrub(String rawText)` - Scrub PII and return PrismResult
- `restore(String scrubbedText, Map<String, String> map)` - Restore PII locally
- `containsPII(String text)` - Check if text contains PII
- `isSafeToSend(String text)` - Validate text is safe for transmission
- `transformToCorrelationResistant(...)` - Add correlation-resistant layer

#### 3. PrismContextPreserver
**Location**: `lib/arc/internal/echo/prism_context_preserver.dart`

Enhanced PRISM layer that scrubs PII while preserving conversational structure for cloud API effectiveness. Core principle: **Strip identifiers, preserve meaning and structure**.

**Key Features**:
- Query classification (question, request_for_suggestions, request_for_input, etc.)
- Semantic content extraction (preserves meaning while removing PII)
- Expected response type inference (guides LUMARA's response style)
- Context building from conversation history (PII-scrubbed summaries)

**Key Methods**:
- `prepareCloudContext(...)` - Main entry point: Convert raw user input into privacy-safe, context-rich payload

**Context Payload Structure**:
```dart
{
  "conversation_turn": 4,
  "total_turns": 6,
  "previous_context": "User asked about conversational realism → system reflected",
  "current_query_type": "request_for_suggestions",
  "semantic_content": "User wants specific implementation methods for conversational realism",
  "phase": "discovery",
  "phase_stability": 0.7,
  "emotional_intensity": 0.3,
  "engagement_mode": "explore",
  "recent_patterns": ["technical_iteration", "ui_refinement"],
  "expected_response_type": "substantive_answer_with_concrete_suggestions",
  "interaction_mode": "voice",
  "scrubbed_input": "Suggestions on how to do this?"
}
```

### PII Detection Patterns

PRISM detects and scrubs:
- **Names**: Personal names, nicknames
- **Email addresses**: All email formats
- **Phone numbers**: Various formats (US, international)
- **Addresses**: Street addresses, cities, states, countries
- **Dates**: Birth dates, anniversaries
- **SSN**: Social Security Numbers
- **Credit cards**: Card numbers
- **Medical info**: Medical conditions, medications
- **Organizations**: Company names, institutions
- **Locations**: Specific places, landmarks

### Scrubbing Process

```
Raw Text: "I told Sarah about my job at Google in San Francisco"
                ↓
PRISM Scrubbing (on-device)
                ↓
Scrubbed: "I told [NAME1] about my job at [ORG1] in [LOCATION1]"
                ↓
Reversible Map (LOCAL ONLY):
{
  "[NAME1]": "Sarah",
  "[ORG1]": "Google",
  "[LOCATION1]": "San Francisco"
}
                ↓
Sent to Cloud: Only scrubbed text
                ↓
Response: "It sounds like sharing with [NAME1] was meaningful..."
                ↓
PII Restoration (on-device)
                ↓
Display: "It sounds like sharing with Sarah was meaningful..."
```

---

## Correlation-Resistant PII Protection

### Two-Layer Protection

1. **PRISM Layer** (Existing)
   - Detects and scrubs raw PII into tokens: `[EMAIL_1]`, `[NAME_1]`, `[PHONE_1]`, etc.
   - Creates reversible mapping (LOCAL ONLY)
   - Validates with `isSafeToSend()`

2. **Correlation-Resistant Layer** (Enhanced)
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

### Key Components

#### 1. CorrelationResistantTransformer

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

#### 2. Enhanced Security Guards

**Location**: `lib/arc/chat/voice/voice_journal/prism_adapter.dart`

**Updated**: `VoiceJournalSecurityGuard.validateBeforeGemini()`

Now validates:
1. No raw PII
2. PRISM tokens should be transformed to aliases
3. Alias format validation

---

## Private Notes Privacy Guarantee

### Privacy Guarantee Statement

**Private Notes are architecturally isolated from ARC's intelligence layers.**

Content stored in Private Notes is:
- ✅ **Local-only** - Never transmitted to cloud services
- ✅ **Never processed** - Excluded from all AI analysis
- ✅ **Never indexed** - Not searchable by ARC
- ✅ **Never analyzed** - No semantic analysis, keyword extraction, or phase detection
- ✅ **Never summarized** - Not included in any summaries or reports
- ✅ **Never backed up** - Excluded from automatic backups (unless explicitly enabled by user)

### Technical Implementation

#### Storage Isolation

Private Notes are stored in a **separate, encrypted directory** that is completely isolated from journal entry storage:

- **Location**: `{appDocuments}/private_notes/`
- **Format**: Encrypted files (`.encrypted` extension)
- **Encryption**: XOR encryption with device-specific key stored in Flutter Secure Storage
- **Key Management**: Encryption key stored in iOS Keychain / Android Keystore

#### Architectural Boundaries

The following ARC services **cannot access** Private Notes:

1. **PRISM** - No content analysis or PII scrubbing
2. **ATLAS** - No phase detection or semantic analysis
3. **LUMARA** - No AI reflections or suggestions
4. **MIRA** - No memory indexing or retrieval
5. **RIVET** - No phase calculation or regime analysis
6. **SENTINEL** - No risk assessment or monitoring

#### Code Isolation

Private Notes are accessed **only** through:

- `PrivateNotesStorage.savePrivateNote()` - Write access
- `PrivateNotesStorage.loadPrivateNote()` - Read access (UI only)
- `PrivateNotesStorage.deletePrivateNote()` - Delete access

**No other code paths** can access Private Notes content.

### User Interface

#### Visual Indicators

The Private Notes UI clearly signals privacy:

- **Lock icon** (🔒) - Visual indicator of privacy
- **Header text**: "Private Notes - Stored locally and never analyzed"
- **Distinct styling** - Separate visual language from main journal
- **No autocomplete** - No AI suggestions or autocomplete
- **No tone analysis** - No writing assistance

#### Interaction Model

- **Write-only UI surface** - Users can type freely
- **Auto-save** - Content saved automatically after 2 seconds of inactivity
- **No telemetry** - No analytics or logging on content
- **No references** - Private Notes never appear in main journal text

### Threat Model

#### What Private Notes Protect Against

1. **AI Analysis** - Content is never sent to any AI model
2. **Cloud Sync** - Content never leaves the device (unless user explicitly exports)
3. **Backup Inclusion** - Excluded from automatic backups
4. **Search Indexing** - Not indexed for search
5. **Analytics** - No telemetry or analytics on content

#### What Private Notes Do NOT Protect Against

1. **Physical Device Access** - If device is unlocked, files are accessible
2. **Device Backups** - May be included in full device backups (iOS/Android)
3. **User Export** - User can explicitly export encrypted notes
4. **Forensic Analysis** - Encrypted files exist on device storage

### Audit Trail

#### Verification Method

Use `PrivateNotesStorage.verifyIsolation()` to verify the privacy boundary:

```dart
final verification = await PrivateNotesStorage.instance.verifyIsolation();
// Returns:
// {
//   'storage_location': '/path/to/private_notes',
//   'note_count': 5,
//   'isolation_verified': true,
//   'encryption_enabled': true,
//   'separate_from_journal_storage': true,
// }
```

#### Code Inspection

To verify isolation, search codebase for:
- `PrivateNotesStorage` - Only 3 methods should access it
- `private_notes` directory - Should only appear in storage service
- No references in: PRISM, ATLAS, LUMARA, MIRA, RIVET, SENTINEL services

### User Control

#### Export (User-Initiated)

Users can export Private Notes as encrypted blobs:

```dart
final export = await PrivateNotesStorage.instance.exportPrivateNotes();
// Returns JSON with encrypted notes (key NOT included)
```

#### Backup Exclusion

Private Notes are excluded from:
- Automatic ARC backups
- MCP export packages
- ARCX export files
- Cloud sync operations

**Exception**: User can explicitly export encrypted notes for personal backup.

### Mental Model

> **"This is paper inside a locked drawer, not part of the system's memory."**

Private Notes are designed to be:
- A **write-only UI surface**
- A **cryptographically and logically isolated store**
- A **"sealed envelope"** inside the journal

ARC treats Private Notes as if they don't exist - they are completely invisible to the system's intelligence layers.

---

## Architecture

### Complete Privacy Flow

```
User Input (Voice/Text)
    ↓
┌─────────────────────────────────────┐
│  PRISM Scrubbing (On-Device)        │
│  - Detects PII                      │
│  - Creates tokens: [NAME1], [ORG1] │
│  - Creates reversible map (LOCAL)   │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Correlation-Resistant Transform     │
│  - Rotating aliases: PERSON(H:...)  │
│  - Structured JSON abstraction      │
│  - Session-based rotation            │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Security Validation                │
│  - isSafeToSend() check              │
│  - Alias format validation           │
│  - No raw PII verification           │
└─────────────────────────────────────┘
    ↓
Cloud API (Gemini)
    ↓
Response Processing
    ↓
┌─────────────────────────────────────┐
│  PII Restoration (On-Device)         │
│  - Uses reversible map               │
│  - Restores original values          │
└─────────────────────────────────────┘
    ↓
Display to User
```

### Component Relationships

```
PiiScrubber (Core Service)
    ↓
PrismAdapter (ARC Integration)
    ├─→ PrismContextPreserver (Enhanced Context)
    └─→ CorrelationResistantTransformer (Enhanced Privacy)
            ↓
        Security Guards
            ↓
        Cloud API
```

---

## Usage Examples

### Basic PRISM Scrubbing

```dart
final prismAdapter = PrismAdapter();
final result = await prismAdapter.scrub(
  "I told Sarah about my job at Google in San Francisco"
);

print(result.scrubbedText);
// Output: "I told [NAME1] about my job at [ORG1] in [LOCATION1]"

print(result.reversibleMap);
// Output: {
//   "[NAME1]": "Sarah",
//   "[ORG1]": "Google",
//   "[LOCATION1]": "San Francisco"
// }
```

### Correlation-Resistant Transformation

```dart
final transformer = CorrelationResistantTransformer(
  rotationWindow: RotationWindow.session,
  prism: prismAdapter,
);

final result = await transformer.transform(
  prismScrubbedText: "I told [NAME1] about my job at [ORG1]",
  intent: 'voice_journal',
  prismResult: prismResult,
);

// Result contains structured JSON with rotating aliases
// Original PII never leaves device
```

### PII Restoration

```dart
final restored = await prismAdapter.restore(
  "It sounds like sharing with [NAME1] was meaningful...",
  reversibleMap,
);

print(restored);
// Output: "It sounds like sharing with Sarah was meaningful..."
```

### Security Validation

```dart
// Check if text is safe to send
if (await prismAdapter.isSafeToSend(text)) {
  // Safe to send to cloud
} else {
  // Contains PII - should not send
  throw SecurityException("PII detected in text");
}
```

---

## Security Validation

### Validation Layers

1. **PII Detection**: `containsPII()` - Quick check before processing
2. **Scrubbing Validation**: Ensures all PII is tokenized
3. **Safe-to-Send Check**: `isSafeToSend()` - Final validation before transmission
4. **Alias Format Validation**: Ensures correlation-resistant format is correct
5. **Security Exceptions**: Thrown on violations

### Security Guarantees

- ✅ **No raw PII** leaves the device
- ✅ **Reversible mapping** is LOCAL ONLY (never transmitted)
- ✅ **Correlation-resistant** aliases prevent cross-call linkage
- ✅ **Session-based rotation** prevents long-term tracking
- ✅ **Multiple validation layers** prevent accidental leakage
- ✅ **Private Notes** are completely isolated from all processing

---

## Related Documentation

- [ECHO and PRISM Privacy Architecture](./ECHO_AND_PRISM_PRIVACY_ARCHITECTURE.md) - Complete privacy architecture
- [PiiScrubber Service](../lib/services/lumara/pii_scrub.dart) - Core scrubbing implementation
- [PrismAdapter](../lib/arc/internal/echo/prism_adapter.dart) - ARC integration
- [Private Notes Storage](../lib/arc/core/private_notes_storage.dart) - Private Notes implementation

---

**Document Version**: 1.0  
**Last Updated**: January 2025  
**Maintainer**: ARC Development Team
