# LUMARA In-Chat Response Cutoff Issue

**Date:** January 2025  
**Status:** 🔍 Investigating  
**Severity:** High  
**Priority:** High

---

## Problem Description

LUMARA in-chat replies sometimes get cut off mid-response. Users report that responses appear incomplete or truncated.

---

## Root Causes Identified

### 1. On-Device Model Token Limits (Primary Issue)

**Location:** `lib/arc/chat/llm/llm_adapter.dart:353-355`

**Issue:** On-device models have very restrictive token limits:
```dart
final adaptiveMaxTokens = useMinimalPrompt
    ? 32   // Ultra-terse for simple greetings
    : (preset['max_new_tokens'] ?? 64);  // Conservative for tiny models
```

**Impact:** 
- Responses are limited to 32-64 tokens
- This is approximately 25-50 words
- Longer responses get cut off mid-sentence

**Evidence:**
- Model presets show `max_new_tokens: 80-256` but adapter defaults to 64
- This is too conservative for meaningful responses

### 2. Streaming Error Handling (Secondary Issue)

**Location:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart:855-870`

**Issue:** If streaming encounters an error, the entire response is replaced with an error message:
```dart
catch (e) {
  print('LUMARA Debug: Error during streaming: $e');
  // Handle error by showing error message
  final errorMessage = LumaraMessage.assistant(
    content: "I'm sorry, I encountered an error while streaming the response. Please try again.",
  );
  // This replaces the partial response that was already streaming
}
```

**Impact:**
- If streaming fails partway through, user sees error message instead of partial response
- Makes it appear like response was cut off

### 3. Network/Streaming Interruption

**Location:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart:763-792`

**Issue:** If the Gemini stream is interrupted (network issue, timeout), the response will be incomplete but may not show an error.

**Impact:**
- Incomplete responses without clear indication
- User sees partial response that appears cut off

---

## Proposed Solutions

### Solution 1: Increase On-Device Token Limits

**File:** `lib/arc/chat/llm/llm_adapter.dart`

**Change:**
```dart
// Current (too restrictive):
final adaptiveMaxTokens = useMinimalPrompt
    ? 32
    : (preset['max_new_tokens'] ?? 64);

// Proposed (more reasonable):
final adaptiveMaxTokens = useMinimalPrompt
    ? 128   // Still concise but allows complete thoughts
    : (preset['max_new_tokens'] ?? 256);  // Use preset value or reasonable default
```

**Rationale:**
- 128 tokens allows for 2-3 complete sentences
- 256 tokens allows for meaningful paragraphs
- Still conservative for mobile but not overly restrictive

### Solution 2: Preserve Partial Responses on Error

**File:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

**Change:**
```dart
catch (e) {
  print('LUMARA Debug: Error during streaming: $e');
  
  // Preserve partial response if we have one
  if (state is LumaraAssistantLoaded) {
    final currentMessages = (state as LumaraAssistantLoaded).messages;
    if (currentMessages.isNotEmpty) {
      final lastIndex = currentMessages.length - 1;
      final lastMessage = currentMessages[lastIndex];
      
      // If we have partial content, keep it and append error note
      if (lastMessage.content.isNotEmpty && lastMessage.content.length > 10) {
        final partialContent = lastMessage.content;
        final errorMessage = LumaraMessage.assistant(
          content: '$partialContent\n\n[Response was interrupted. Please try again if you need more.]',
        );
        
        final finalMessages = [
          ...currentMessages.sublist(0, lastIndex),
          errorMessage,
        ];
        
        emit((state as LumaraAssistantLoaded).copyWith(
          messages: finalMessages,
          isProcessing: false,
        ));
        return; // Exit early, we've preserved the partial response
      }
    }
  }
  
  // Only show full error message if we have no partial response
  final errorMessage = LumaraMessage.assistant(
    content: "I'm sorry, I encountered an error while streaming the response. Please try again.",
  );
  // ... rest of error handling
}
```

**Rationale:**
- Preserves partial responses so users can see what was generated
- Adds clear indication if response was interrupted
- Better user experience than losing all progress

### Solution 3: Add Streaming Timeout and Retry Logic

**File:** `lib/arc/chat/bloc/lumara_assistant_cubit.dart`

**Change:**
- Add timeout detection for streaming
- Implement retry logic for network interruptions
- Add progress indicators for long responses

---

## Testing Plan

1. **Test On-Device Models:**
   - Verify responses complete with increased token limits
   - Test with various response lengths
   - Monitor performance impact

2. **Test Error Handling:**
   - Simulate network interruptions
   - Verify partial responses are preserved
   - Test error message display

3. **Test Streaming:**
   - Test with long responses (>500 tokens)
   - Verify complete streaming
   - Test timeout scenarios

---

## Related Files

- `lib/arc/chat/llm/llm_adapter.dart` - Token limit configuration
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` - Streaming and error handling
- `lib/arc/chat/llm/prompts/lumara_model_presets.dart` - Model preset definitions
- `lib/arc/chat/ui/lumara_assistant_screen.dart` - UI rendering (no truncation found)

---

## Status

- [x] Issue identified
- [x] Root causes documented
- [ ] Solutions implemented
- [ ] Testing completed
- [ ] Fix verified

---

**Last Updated:** January 2025

