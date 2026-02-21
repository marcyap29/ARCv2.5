# Universal Prompt Optimization – 80/20 Framework

This document describes LUMARA’s **provider-agnostic** prompt optimization layer and how it fits into the app.

## Principles

- **80/20:** The **20%** of optimizations that work **everywhere** (smart context, structured output, progressive context, caching) deliver most of the benefit.
- **Provider-agnostic:** No Groq-only or Claude-only tricks; same behavior on Groq, OpenAI, Claude, or any future provider.
- **Trade-off:** Slightly less peak optimization than a single-provider stack in exchange for **full provider flexibility** and automatic failover.

## Expected Results

| Metric            | Typical range   |
|-------------------|------------------|
| Token reduction   | ~70–85%          |
| Cost reduction    | ~50–60%          |
| Latency           | ~3× improvement  |
| Provider lock-in  | None             |

## Architecture (Dart/Flutter)

```
Application (Chat, Reflect, Voice, Agentic Loop)
         │
         ▼
Universal Optimization Strategy
  - Which prompts to optimize
  - How much context
  - Cache or not
         │
         ▼
UniversalPromptOptimizer
  - Smart context selection (patterns, relationships, state)
  - Structured vs prose output
  - Minimal prompt building
         │
         ▼
ProviderManager → ProviderAdapter (Groq | OpenAI | Claude)
         │
         ▼
UniversalResponseGenerator (+ optional ResponseCache)
```

## Code locations

| Component                    | Path |
|-----------------------------|------|
| Types                       | `lib/arc/chat/prompt_optimization/prompt_optimization_types.dart` |
| Readiness (injectable)      | `lib/arc/chat/prompt_optimization/readiness_calculator.dart` |
| Optimizer                   | `lib/arc/chat/prompt_optimization/universal_prompt_optimizer.dart` |
| Provider interface          | `lib/arc/chat/prompt_optimization/providers/provider_adapter.dart` |
| Groq / OpenAI / Claude       | `lib/arc/chat/prompt_optimization/providers/{groq,openai,claude}_adapter.dart` |
| Provider manager + failover | `lib/arc/chat/prompt_optimization/provider_manager.dart` |
| Response cache              | `lib/arc/chat/prompt_optimization/response_cache.dart` |
| Response generator          | `lib/arc/chat/prompt_optimization/universal_response_generator.dart` |
| Provider settings UI        | `lib/arc/chat/prompt_optimization/ui/provider_settings_section.dart` |
| Barrel export               | `lib/arc/chat/prompt_optimization/prompt_optimization.dart` |

## Use cases (`PromptUseCase`)

- **User-facing:** `userChat`, `userReflect`, `userVoice` – moderate context, prose, cacheable.
- **Agentic loop:** `gapClassification`, `patternExtraction`, `seekingDetection` – minimal context, JSON where useful, speed-focused.
- **Batch:** `intelligenceSummary` – full context, quality-focused.
- **Safety:** `crisisDetection` – full context, JSON, never cached.

## Integration

- **Optimizer** depends on:
  - `LumaraChronicleRepository` (patterns, relationships)
  - `ReadinessCalculator` (optional; default returns 50 if not wired).
- **ProviderManager** uses existing `LumaraAPIConfig` (API keys, primary/fallback). Provider choice is persisted via `setManualProvider` / `getBestProvider`.
- **Response cache** is optional; `DefaultResponseCache` uses in-memory + SharedPreferences with a key cap.

To use the optimized path for a given flow:

1. Build `UniversalPromptOptimizer`, `ProviderManager`, `ResponseCache` (e.g. `DefaultResponseCache`), and `UniversalResponseGenerator` (e.g. at app startup or in a service locator).
2. Call `UniversalResponseGenerator.generate(userId, query, useCase)` instead of calling the LLM directly with a large, fixed prompt.

Provider selection UI is already in LUMARA Settings (API card). The optional `ProviderSettingsSection` widget can be used to expose “AI Provider” and cost hints in another screen if desired.

## Configuration

- Primary provider and fallbacks come from **LumaraAPIConfig** (existing). No separate `config/providers` file; keys and preference are in SharedPreferences via the existing API config.
- To prefer a specific provider, set it in LUMARA Settings (API section); that updates the manual provider used by `getBestProvider()` and thus by `ProviderManager.getProvider()`.

## Master prompt integration

The **master prompt** (`LumaraMasterPrompt`) receives chronicle context via `lumaraChronicleContext`. That string is now built by the universal optimizer when possible:

- **Enhanced LUMARA API** (`enhanced_lumara_api.dart`): Before building the master prompt, it calls `UniversalPromptOptimizer.getChronicleContextForMasterPrompt(userId, request.userText, useCase, maxChars: 2000)`.
- **Use case:** `skipHeavyProcessing` (voice) → `PromptUseCase.userVoice` (2 patterns, 1 relationship); otherwise `PromptUseCase.userReflect` (3 patterns, 2 relationships). Context is query-relevant (entities, emotions, topics) and capped at 2000 chars.
- **Fallback:** If the optimizer returns null or throws, the legacy `_buildLumaraChronicleContext(userId)` is used so behavior is unchanged when the optimizer is unavailable.

The master prompt template and control state are unchanged; only the **chronicle slice** is optimizer-driven (smaller, more relevant, use-case-sized).

## Checklist (implementation status)

- [x] UniversalPromptOptimizer + strategies per use case  
- [x] Smart context selection (patterns, relationships, readiness)  
- [x] Structured vs prose formatting  
- [x] ProviderAdapter interface + Groq / OpenAI / Claude adapters  
- [x] ProviderManager with failover using LumaraAPIConfig  
- [x] UniversalResponseGenerator + cache path  
- [x] ResponseCache (default implementation)  
- [x] Provider settings section widget (optional embed)  
- [x] **Master prompt: chronicle context from optimizer** (getChronicleContextForMasterPrompt + enhanced_lumara_api)  
- [x] Documentation (this file)

Integrating the optimizer into a specific flow (e.g. chat or agentic loop) is done by calling `UniversalResponseGenerator.generate(...)` and using the returned `GeneratedResponse.content` (and optional metadata) instead of the current LLM path for that use case.
