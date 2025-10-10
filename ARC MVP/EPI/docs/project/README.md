# EPI Project Documentation

**EPI**: Emergent Pattern Intelligence - AI-powered personal development companion

---

## 📚 Documentation Index

### 🔥 Latest Updates (October 9, 2025)

**Major Performance Breakthrough - 90% Faster Inference + Model Fixes**

Four comprehensive optimization sessions completed:
1. **GPU Optimization** - Full Metal acceleration (28/28 layers)
2. **Speed Optimization** - Eliminated bottlenecks (~5s saved)
3. **ChatGPT Mobile Optimization** - Latency-first design (50% faster)
4. **Model Recognition Fixes** - UI state synchronization + model ID updates

**Result:** "Hello" responses: 5-10s → **0.5-1.5s** (90% faster) + **Model download recognition fixed**

📖 **Read the guides:**
- [`Status_Update.md`](Status_Update.md) - GPU optimization results
- [`Speed_Optimization_Guide.md`](Speed_Optimization_Guide.md) - Performance deep-dive
- [`ChatGPT_Mobile_Optimizations.md`](ChatGPT_Mobile_Optimizations.md) - Mobile-first design
- [`Model_Recognition_Fixes.md`](Model_Recognition_Fixes.md) - Model ID & UI state fixes

---

## 📁 Documentation Structure

### `/docs/project/` - Active Project Docs

**Core Documents:**
- **`Status_Update.md`** - Initial GPU acceleration optimizations
- **`Speed_Optimization_Guide.md`** - Comprehensive performance guide
- **`ChatGPT_Mobile_Optimizations.md`** - ChatGPT recommendations implemented
- **`Model_Recognition_Fixes.md`** - Model ID & UI state synchronization fixes
- **`PROJECT_BRIEF.md`** - Project overview and objectives
- **`README.md`** - This file

**Configuration:**
- **`lumara_mobile_profiles.json`** - Model configuration presets

### `/docs/status/` - Status Tracking

- **`STATUS_UPDATE.md`** - Current project status (updated Oct 9, 2025)
- **`STATUS.md`** - Historical status
- **`SESSION_SUMMARY.md`** - Session summaries

### `/docs/guides/` - User Guides

- **`MVP_Install.md`** - Installation instructions
- **`Arc_Prompts.md`** - ARC module prompt templates

### `/docs/architecture/` - System Design

- **`EPI_Architecture.md`** - Complete system architecture

### `/docs/reports/` - Technical Reports

- **`LLAMA_CPP_MODERNIZATION_SUCCESS_REPORT.md`** - llama.cpp upgrade
- **`MEMORY_MANAGEMENT_SUCCESS_REPORT.md`** - Memory optimization
- **`ROOT_CAUSE_FIXES_SUCCESS_REPORT.md`** - Critical bug fixes

### `/docs/changelog/` - Change History

- **`CHANGELOG.md`** - Version history and changes

### `/docs/bugtracker/` - Issue Tracking

- **`Bug_Tracker.md`** - Active bug tracking
- **`Bug_Tracker Files/`** - Historical bug reports

### `/docs/archive/` - Historical Documents

Archived implementation reports, references, and old documentation.

---

## 🎯 Quick Reference

### Performance Benchmarks (Oct 9, 2025)

| Query Type | Before | After | Improvement |
|------------|--------|-------|-------------|
| Simple ("Hello") | 5-10s | 0.5-1.5s | **90% faster** |
| Complex | 15-20s | 2.5-3s | **85% faster** |
| Code snippet | 8-12s | ~2s | **75% faster** |

### System Specs

**Device:** iPhone 16 Pro
**GPU:** Apple A18 Pro (MTLGPUFamilyApple9)
**Model:** Llama 3.2 3B Q4_K_M (1.87GB)
**Context:** 1024 tokens
**GPU Utilization:** 100% (28/28 layers)
**Memory:** 2.1GB used / 5.7GB available

### Key Technologies

- **Flutter** - Cross-platform framework
- **llama.cpp** - On-device LLM inference
- **Metal** - Apple GPU acceleration
- **Swift** - Native iOS bridge
- **Pigeon** - Flutter ↔ Native communication

---

## 🚀 Getting Started

### For Developers

1. **Read the architecture:**
   - [`docs/architecture/EPI_Architecture.md`](../architecture/EPI_Architecture.md)

2. **Understand recent changes:**
   - [`Status_Update.md`](Status_Update.md)
   - [`Speed_Optimization_Guide.md`](Speed_Optimization_Guide.md)
   - [`ChatGPT_Mobile_Optimizations.md`](ChatGPT_Mobile_Optimizations.md)

3. **Build & deploy:**
   ```bash
   flutter build ios --no-codesign
   flutter install
   ```

4. **Monitor performance:**
   ```bash
   idevicesyslog | grep -E "load_tensors|⚡|📚"
   ```

### For Users

1. **Installation guide:**
   - [`docs/guides/MVP_Install.md`](../guides/MVP_Install.md)

2. **Feature overview:**
   - [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md)

---

## 📊 Recent Optimizations Summary

### Session 1: GPU Acceleration (Oct 9, 2025)
- **Full GPU offloading:** 16 → 28 layers (100%)
- **Adaptive prompts:** 1000+ → 75 tokens for simple queries
- **Context reduction:** 2048 → 1024 tokens

**Files:**
- `ios/Runner/LLMBridge.swift`
- `ios/Runner/ModelLifecycle.swift`
- `lib/lumara/llm/llm_adapter.dart`

### Session 2: Speed Optimization (Oct 9, 2025)
- **Removed artificial delay:** 30ms/word → 0ms
- **Reduced max tokens:** 256 → 128 → 80
- **Faster sampling:** Simplified parameters

**Files:**
- `lib/lumara/llm/llm_adapter.dart`
- `lib/lumara/llm/prompts/lumara_model_presets.dart`

### Session 3: ChatGPT Mobile Optimization (Oct 9, 2025)
- **Mobile-optimized prompt:** Latency-first, 75% shorter
- **[END] stop token:** Early stopping pattern
- **Simplified sampling:** Removed top_k, min_p, penalties
- **Token refinement:** 50 ultra-terse / 80 standard

**Files:**
- `lib/lumara/llm/prompts/lumara_system_prompt.dart`
- `lib/lumara/llm/prompts/lumara_model_presets.dart`
- `lib/lumara/llm/prompts/lumara_prompt_assembler.dart`
- `lib/lumara/llm/config/lumara_mobile_profiles.json` (NEW)

---

## 🔧 Configuration Files

### Model Presets
```dart
// lib/lumara/llm/prompts/lumara_model_presets.dart
{
  'temperature': 0.7,
  'top_p': 0.9,
  'max_new_tokens': 80,
  'stop_tokens': ['[END]', '</s>', '<|eot_id|>']
}
```

### GPU Configuration
```swift
// ios/Runner/LLMBridge.swift:289
ctxTokens: 1024,
nGpuLayers: 99  // All layers on GPU
```

### System Prompt
```dart
// lib/lumara/llm/prompts/lumara_system_prompt.dart
"Default to 40–80 tokens. Aim for 50 unless detail is requested.
Always end with '[END]'."
```

---

## 📈 Performance Metrics

### Token Generation Speed

| Metric | Value |
|--------|-------|
| **Prompt processing** | 15-25 tok/s (prefill) |
| **Token generation** | 20-30 tok/s (decode) |
| **Sampling latency** | ~30ms/token |
| **Average response** | 50-60 tokens |
| **Total time (simple)** | 1-1.5s |
| **Total time (complex)** | 2.5-3s |

### Resource Usage

| Resource | Usage |
|----------|-------|
| **GPU memory** | 2.1GB / 5.7GB (37%) |
| **KV cache** | 112MB |
| **Model size** | 1.87GB |
| **GPU utilization** | 100% (28/28 layers) |
| **CPU threads** | 6 (performance cores) |
| **Batch size** | 512 tokens |

---

## 🛠 Troubleshooting

### Common Issues

**Slow responses (> 3s):**
- Check GPU layers: Should show "28/29 layers to GPU"
- Verify Metal compilation: Look for "metal: engaged"
- Monitor thermal throttling

**Quality degradation:**
- Check if [END] token appearing prematurely
- Verify system prompt is mobile-optimized version
- Consider increasing max_tokens from 80 → 128

**Build failures:**
- Run `flutter clean`
- Check Xcode version compatibility
- Verify llama.cpp submodule is updated

---

## 📝 Contributing

### Documentation Standards

- Use markdown format
- Include date and version
- Add benchmarks when relevant
- Link to related documents
- Keep examples concise

### Commit Message Format

```
type: brief description

Detailed explanation of changes.

## Changes
- Bullet points
- With specifics

## Performance Impact
- Before/after metrics

🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## 🔗 Links

### Internal
- [EPI Architecture](../architecture/EPI_Architecture.md)
- [Status Update](../status/STATUS_UPDATE.md)
- [Bug Tracker](../bugtracker/Bug_Tracker.md)
- [Changelog](../changelog/CHANGELOG.md)

### External
- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [Flutter Documentation](https://flutter.dev/docs)
- [Apple Metal](https://developer.apple.com/metal/)

---

## 📧 Contact

For questions or issues:
- Create an issue in the project repository
- Review existing documentation first
- Check bug tracker for known issues

---

**Last Updated:** October 9, 2025
**Maintained By:** EPI Development Team
**Version:** 0.5.0-alpha
