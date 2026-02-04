# Enterprise Voice Mode

**Purpose:** Specification and roadmap for the Enterprise voice interface: command-driven voice, session limits, cooldowns, and AURORA usage tracking. This doc describes the **target** design; implementation (lib/arc/voice, EnterpriseVoiceMode, etc.) is not yet complete.

**Related:** [LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md](LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md); [SUBSYSTEMS.md](SUBSYSTEMS.md) (AURORA); [MASTER_PROMPT_CONTEXT.md](MASTER_PROMPT_CONTEXT.md) (voice payload and LAYER 2.5).

**Last updated:** February 2026

---

## 1. Goals

- **Intentional voice:** Command-driven interaction (syntax validation, clear commands) rather than open-ended only.
- **Safety and sustainability:** Bounded sessions and cooldowns to avoid over-reliance and fatigue.
- **AURORA integration:** Usage tracking (e.g. VoiceSessionLog, usage_tracker) so rhythm/regulation and sabbatical rules can be enforced.

---

## 2. Success Criteria (from guide)

**Safety:**

- **Session:** 3 minutes max per voice session.
- **Cooldown:** 15 minutes between sessions.
- **Daily cap:** 3 sessions per day.
- **AURORA:** Tracks usage; sabbatical after 30 days if specified (e.g. in user settings or regimen).

**UX:**

- Responses natural; voice intentional (command-driven); no regressions vs current voice.

---

## 3. Target Components (from guide)

| Component | Purpose |
|-----------|---------|
| **lib/arc/voice/** | Enterprise voice feature set. |
| **command_syntax_validator.dart** | Validates user voice commands against allowed syntax before processing. |
| **enterprise_voice_mode.dart** | Encapsulates enterprise voice behavior: limits, cooldown, session tracking. |
| **Enterprise voice screen** | UI entry for enterprise voice (when “enterprise voice” is enabled). |
| **Voice entry point** | Uses `EnterpriseVoiceMode` when enterprise voice is enabled (vs current voice path). |
| **AURORA** | aurora_service.dart, usage_tracker.dart; Hive model VoiceSessionLog for session and daily counts. |

---

## 4. Current State

- **Voice today:** Handled in EnhancedLumaraApi with `skipHeavyProcessing = true`; short system prompt (`getVoicePromptSystemOnly`) and user message (`buildVoiceUserMessage`); truncation by `VoiceResponseConfig.getVoicePromptMaxChars`. No orchestrator call; no enterprise command syntax or session limits.
- **AURORA subsystem:** Stub in `lib/arc/chat/services/aurora_subsystem.dart`; returns empty aggregations. No usage_tracker or VoiceSessionLog in the guide’s form yet; `lib/aurora/` exists with different layout (circadian, VEIL).

---

## 5. Implementation Order (when pursued)

1. Define **command set** and **command_syntax_validator** (allowed phrases/patterns, rejection message).
2. Add **EnterpriseVoiceMode** (or equivalent) that enforces 3 min session, 15 min cooldown, 3/day; integrate with AURORA usage tracking when available.
3. Add **VoiceSessionLog** (Hive) and **usage_tracker** (or aurora_service) to record sessions and daily count; expose to AURORA subsystem for rhythm/regulation summary if needed.
4. **Voice entry point:** When “enterprise voice” is enabled in settings, route to EnterpriseVoiceMode (command validation, limits) instead of the current open-ended voice path.
5. **Enterprise voice screen:** UI to enter enterprise voice mode and show remaining session/time until cooldown or daily cap.
6. **Sabbatical:** Optional rule (e.g. after 30 days of use) with settings and AURORA enforcement; document in AURORA/SUBSYSTEMS when implemented.

---

## 6. Docs and Code References

- **Master Prompt (voice):** [MASTER_PROMPT_CONTEXT.md](MASTER_PROMPT_CONTEXT.md) §8 – getVoicePromptSystemOnly, buildVoiceUserMessage, LAYER 2.5.
- **File and doc summary:** [LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md](LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md) §2 – lib/arc/voice, EnterpriseVoiceMode, voice entry point status.
- **Principles:** Wrap don’t rebuild; safety first (enterprise voice and AURORA enforce limits). See LUMARA_ENTERPRISE_ARCHITECTURE_GUIDE.md §4.
