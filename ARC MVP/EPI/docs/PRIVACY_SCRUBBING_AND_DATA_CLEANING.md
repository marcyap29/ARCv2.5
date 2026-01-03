# Privacy Scrubbing and Data Cleaning

**Version:** 2.1.84  
**Last Updated:** January 2025  
**Status:** ✅ Production Ready

---

## Overview

ARC implements a comprehensive privacy scrubbing and data cleaning system called **PRISM** (Privacy-Resistant Information Scrubber Module). PRISM ensures that no Personally Identifiable Information (PII) leaves the device before being processed by external AI services, while maintaining the ability to restore PII locally for user display.

---

## Core Principles

### 1. **Local-First Privacy**
- All PII detection and scrubbing happens **on-device**
- Raw user data **never** leaves the device
- Only scrubbed, anonymized data is sent to external services

### 2. **Reversible Mapping**
- PRISM creates a **reversible map** of scrubbed tokens to original values
- This map is **LOCAL ONLY** and never transmitted
- Used to restore PII in AI responses for local display

### 3. **Security Validation**
- Multiple validation layers ensure no PII leakage
- `isSafeToSend()` checks prevent accidental transmission of raw PII
- Security exceptions thrown on violations

---

## PRISM Architecture

### Components

#### 1. **PiiScrubber Service**
**Location**: `lib/services/lumara/pii_scrub.dart`

Core service that performs PII detection and scrubbing using pattern matching and RIVET-gated keyword extraction.

**Key Methods**:
- `rivetScrubWithMapping(String text)` - Main scrubbing method with reversible mapping
- `containsPii(String text)` - Quick PII detection check
- `restore(String scrubbedText, Map<String, String> map)` - Restore original PII

#### 2. **PrismAdapter**
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

---

## PII Detection

### Detected PII Types

PRISM detects and scrubs the following types of PII:

#### 1. **Email Addresses**
- Pattern: `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`
- Replacement: `[EMAIL_1]`, `[EMAIL_2]`, etc.
- Example: `john.doe@example.com` → `[EMAIL_1]`

#### 2. **Phone Numbers**
- Pattern: US phone number formats (with/without country code)
- Replacement: `[PHONE_1]`, `[PHONE_2]`, etc.
- Example: `(555) 123-4567` → `[PHONE_1]`

#### 3. **Physical Addresses**
- Pattern: Street addresses with common suffixes (St, Ave, Rd, etc.)
- Replacement: `[ADDRESS_1]`, `[ADDRESS_2]`, etc.
- Example: `123 Main Street` → `[ADDRESS_1]`

#### 4. **Names**
- Pattern: Capitalized first name + last name pairs
- Replacement: `[NAME_1]`, `[NAME_2]`, etc.
- Example: `John Smith` → `[NAME_1]`
- **Note**: Bible names are whitelisted and not scrubbed

#### 5. **Dates**
- Pattern: MM/DD/YYYY format
- Replacement: `[DATE_MMYYYY]` (day masked, month/year preserved)
- Example: `12/25/2024` → `[DATE_122024]`

#### 6. **Organizations**
- Pattern: Company/organization names
- Replacement: `[ORG_1]`, `[ORG_2]`, etc.

#### 7. **Social Media Handles**
- Pattern: @username formats
- Replacement: `[HANDLE_1]`, `[HANDLE_2]`, etc.

---

## Scrubbing Process

### Step-by-Step Flow

```
1. User Input (Raw Text)
   ↓
2. PII Detection (Pattern Matching)
   ↓
3. Token Replacement ([EMAIL_1], [NAME_1], etc.)
   ↓
4. Reversible Map Creation (LOCAL ONLY)
   ↓
5. Validation (isSafeToSend check)
   ↓
6. Scrubbed Text (Safe to Send)
```

### Example

**Input**:
```
I met with John Smith at john.smith@example.com yesterday. 
We discussed the project at 123 Main Street.
```

**After PRISM Scrubbing**:
```
I met with [NAME_1] at [EMAIL_1] yesterday. 
We discussed the project at [ADDRESS_1].
```

**Reversible Map** (LOCAL ONLY):
```json
{
  "[NAME_1]": "John Smith",
  "[EMAIL_1]": "john.smith@example.com",
  "[ADDRESS_1]": "123 Main Street"
}
```

---

## Data Cleaning

### What is Data Cleaning?

Data cleaning in ARC refers to the process of:
1. **Removing PII** (via PRISM scrubbing)
2. **Normalizing text** (removing formatting artifacts)
3. **Validating content** (ensuring no sensitive data remains)
4. **Preparing for transformation** (correlation-resistant layer)

### Cleaning Operations

#### 1. **PII Removal**
- All PII is replaced with tokens
- Original values stored in reversible map (local only)

#### 2. **Format Normalization**
- Removes markdown artifacts
- Normalizes whitespace
- Cleans up transcription errors (for voice input)

#### 3. **Content Validation**
- Checks for remaining PII after scrubbing
- Validates token format
- Ensures no raw data leakage

#### 4. **Security Checks**
- `isSafeToSend()` validation
- Multiple guardrail checks
- Security exception on violations

---

## Reversible Mapping

### Purpose

The reversible map allows ARC to:
1. **Restore PII in AI responses** - When LUMARA mentions a person or place, the original name is restored
2. **Maintain context** - User sees natural responses with their actual data
3. **Preserve privacy** - Map never leaves the device

### Map Structure

```dart
Map<String, String> reversibleMap = {
  "[NAME_1]": "John Smith",
  "[EMAIL_1]": "john.smith@example.com",
  "[PHONE_1]": "(555) 123-4567",
  // ... more mappings
}
```

### Security Guarantees

- ✅ **Never transmitted** - Map stays on device only
- ✅ **Never logged** - Not included in audit logs
- ✅ **Never backed up** - Excluded from cloud backups
- ✅ **Memory-only** - Cleared when session ends

---

## Security Validation

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

### Security Exceptions

If validation fails, a `SecurityException` is thrown:
- Prevents accidental PII transmission
- Logs security violations (without sensitive data)
- Stops processing until issue is resolved

---

## Integration Points

### 1. Voice Journal Pipeline

**Location**: `lib/arc/internal/echo/voice_pipeline.dart`

```dart
// Step 3: PRISM Scrubbing
final scrubResult = _prism.scrub(rawTranscript);
_log('PRISM: ${scrubResult.redactionCount} redactions');

// Validation
if (!_prism.isSafeToSend(scrubResult.scrubbedText)) {
  throw SecurityException('PII detected after scrubbing');
}
```

### 2. Journal Entry Summary Generation

**Location**: `lib/arc/core/journal_capture_cubit.dart`

```dart
// Step 1: Scrub PII
final prismAdapter = PrismAdapter();
final scrubbingResult = prismAdapter.scrub(content);

// Step 2: Validate
if (!prismAdapter.isSafeToSend(scrubbedContent)) {
  return ''; // Fail safely
}

// Step 3: Transform to correlation-resistant payload
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: scrubbedContent,
  intent: 'summary',
  prismResult: scrubbingResult,
);
```

### 3. Chat System

**Location**: `lib/services/gemini_send.dart`

Chat messages are automatically scrubbed before sending to Gemini API.

---

## Usage Examples

### Basic Scrubbing

```dart
final prismAdapter = PrismAdapter();

// Scrub PII
final result = prismAdapter.scrub(rawText);
print('Scrubbed: ${result.scrubbedText}');
print('Redactions: ${result.redactionCount}');
print('Findings: ${result.findings}');

// Validate
if (!prismAdapter.isSafeToSend(result.scrubbedText)) {
  throw SecurityException('PII still detected');
}

// Send scrubbed text to external service
await sendToGemini(result.scrubbedText);

// Restore PII in response (local only)
final restoredResponse = prismAdapter.restore(
  geminiResponse,
  result.reversibleMap,
);
```

### With Correlation-Resistant Transformation

```dart
// Step 1: Scrub with PRISM
final prismResult = prismAdapter.scrub(rawText);

// Step 2: Transform to correlation-resistant payload
final transformationResult = await prismAdapter.transformToCorrelationResistant(
  prismScrubbedText: prismResult.scrubbedText,
  intent: 'voice_journal',
  prismResult: prismResult,
  rotationWindow: RotationWindow.session,
);

// Step 3: Send structured payload (not verbatim text)
await sendToGemini(transformationResult.cloudPayloadBlock.toJsonString());

// Step 4: Restore PII in response
final restoredResponse = prismAdapter.restore(
  geminiResponse,
  prismResult.reversibleMap,
);
```

---

## Best Practices

### 1. **Always Validate Before Sending**
```dart
if (!prismAdapter.isSafeToSend(text)) {
  // Don't send - security violation
}
```

### 2. **Never Log Raw Text**
```dart
// ❌ BAD
print('User said: $rawText');

// ✅ GOOD
print('User said: ${prismAdapter.scrub(rawText).scrubbedText}');
```

### 3. **Never Transmit Reversible Map**
```dart
// ❌ BAD - NEVER DO THIS
await sendToServer({
  'text': scrubbedText,
  'map': reversibleMap, // SECURITY VIOLATION
});

// ✅ GOOD
await sendToServer({
  'text': scrubbedText,
  // map stays local
});
```

### 4. **Use Guardrails**
```dart
// Always use security guardrails
VoiceJournalSecurityGuard.validateBeforeGemini(scrubbedText);
```

---

## Privacy Guarantees

### What PRISM Guarantees

1. ✅ **No Raw PII Transmission** - All PII is scrubbed before leaving device
2. ✅ **Reversible Restoration** - PII can be restored locally for display
3. ✅ **Security Validation** - Multiple checks prevent accidental leakage
4. ✅ **Local-Only Mapping** - Reversible map never leaves device
5. ✅ **Audit Trail** - Security events logged (without sensitive data)

### What PRISM Does NOT Do

1. ❌ **Semantic Analysis** - PRISM only detects patterns, not meaning
2. ❌ **Context Understanding** - Doesn't understand relationships between entities
3. ❌ **Cross-Entry Linking** - Each entry is scrubbed independently
4. ❌ **Encryption** - PRISM scrubs, but doesn't encrypt (use correlation-resistant layer for that)

---

## Compliance

PRISM helps ARC comply with:

- ✅ **GDPR** - No raw PII transmission without consent
- ✅ **CCPA** - Data minimization principles
- ✅ **HIPAA** - Health information protection
- ✅ **Privacy by Design** - Privacy built into architecture

---

## Technical Details

### Pattern Matching

PRISM uses regular expressions for PII detection:
- **Deterministic** - Same input always produces same output
- **Pattern-based** - Detects common PII formats
- **RIVET-gated** - Uses keyword library for context-aware detection

### Performance

- **Fast** - Pattern matching is O(n) where n is text length
- **Local** - No network calls required
- **Efficient** - Minimal memory overhead

### Limitations

1. **Pattern-Based Only** - May miss non-standard PII formats
2. **No Semantic Understanding** - Doesn't understand context
3. **English-Focused** - Patterns optimized for English text
4. **False Positives** - May flag non-PII as PII (safe default)

---

## Future Enhancements

1. **Machine Learning Detection** - Use ML models for better PII detection
2. **Multi-Language Support** - Patterns for other languages
3. **Context-Aware Scrubbing** - Understand relationships between entities
4. **Custom PII Types** - User-defined PII patterns
5. **Real-Time Scrubbing** - Scrub as user types (for chat)

---

## References

- **PRISM Adapter**: `lib/arc/internal/echo/prism_adapter.dart`
- **PII Scrubber**: `lib/services/lumara/pii_scrub.dart`
- **Correlation-Resistant Transformer**: `lib/arc/internal/echo/correlation_resistant_transformer.dart`
- **Voice Pipeline**: `lib/arc/internal/echo/voice_pipeline.dart`
- **Security Guardrails**: `lib/arc/internal/echo/prism_adapter.dart` (VoiceJournalSecurityGuard)

---

## Summary

PRISM provides a robust, on-device privacy scrubbing system that:
- Detects and scrubs PII before transmission
- Maintains reversible mapping for local restoration
- Validates security at multiple layers
- Integrates seamlessly with ARC's privacy architecture

**Key Takeaway**: PRISM ensures that no raw PII ever leaves the device, while maintaining the ability to restore PII locally for natural user experience.

