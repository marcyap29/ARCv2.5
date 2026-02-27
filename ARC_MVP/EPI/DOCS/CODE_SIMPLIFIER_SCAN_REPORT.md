# Code Simplifier Scan Report

**Project:** EPI at `/Users/mymac/Software/Development/ARCv2.5/ARC_MVP/EPI`  
**Scan Date:** 2026-02-25  
**Last Code Simplifier Run:** 2026-02-26  
**Reference:** DOCS/CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md

---

## 1. Executive Summary

Phase 1 consolidation items (JournalVersionService, QuickActionsService) and the SentinelRiskDetector duplicate are completed. Broken URIs have been fixed. Remaining: several overlapping widget/service patterns, many analyzer hints (avoid_print, deprecated_member_use), and multiple large files. Full Code Simplifier run (2026-02-26) consolidated SentinelRiskDetector and corrected import paths.

---

## 2. Duplicate Files Table

| Finding | File Path(s) | Line Count | Status | Impact | Risk |
|---------|--------------|------------|--------|--------|------|
| **SentinelRiskDetector duplicate** | `lib/prism/extractors/sentinel_risk_detector.dart` (canonical) | 1393 | **DONE** | Removed duplicate; `prism/atlas/index.dart` now re-exports from extractors | — |
| JournalVersionService | `lib/core/services/journal_version_service.dart` (canonical) | 1308 | **DONE** | — | — |
| QuickActionsService | `lib/arc/ui/quick_actions_service.dart` (single source) | 117 | **DONE** | — | — |

**Note:** `lib/arc/internal/mira/version_service.dart` does not exist. `mira_internal.dart` exports `journal_version_service.dart` from core (P1-DUP completed).

---

## 3. Component / Service Redundancy Table

| Area | Files | Overlap | Recommendation | Risk |
|------|-------|---------|----------------|------|
| **IOS widget extension** | `lib/arc/ui/widget_installation_service.dart` (IOSWidgetExtension) and `lib/arc/ui/widget_quick_actions_service.dart` (IOSWidgetQuickActionsIntegration) | Both expose `initializeWidget`, `updateWidget`, similar MethodChannel usage | Unify into one iOS widget/quick-actions integration | **Low** |
| **Chat screens** | `chats_screen.dart` (716 lines) and `enhanced_chats_screen.dart` (1071 lines) | Both use session_view, archive_screen | Document which is primary; deprecate ChatsScreen if unused | **Low** |
| **Feed entry cards** | base_feed_card.dart + 5 card types | BaseFeedCard shared | Optional P2-FEED-CARDS: generic FeedEntryCard<T> | **Low** |
| **Settings views** | 21 *_view.dart under lib/shared/ui/settings/ | Common app bar, sections, buttons | P1-SHARED-UI: extract shared patterns | **Low** |

---

## 4. Build / Import Findings

### 4.1 Broken URIs (errors) — FIXED 2026-02-26

| File | Resolution |
|------|------------|
| `lib/arc/chat/llm/lumara_native.dart` | Switched to `package:my_app/core/app_flags.dart` |
| `lib/arc/chat/llm/qwen_adapter.dart` | Switched to `package:my_app/core/llm/model_adapter.dart`, `package:my_app/core/app_flags.dart`, `package:my_app/core/prompts_arc.dart` |
| `lib/arc/chat/prompts/archive/lumara_unified_prompts.dart` | Fixed to `../lumara_prompt_encouragement.dart`, `../lumara_therapeutic_presence.dart` |
| `lib/arc/chat/voice/ui/voice_mode_launcher.dart` | Switched to `package:my_app/arc/chat/services/enhanced_lumara_api.dart`, `../voice_journal/prism_adapter.dart` |
| `lib/arc/chat/veil_edge/core/rivet_policy_engine.dart` | Switched to `package:my_app/aurora/models/circadian_context.dart` |
| `lib/arc/chat/veil_edge/services/veil_edge_service.dart` | Switched to `package:my_app/aurora/` imports |

### 4.2 Unused / dead code (sample)

- `arcform_renderer_3d.dart`: unused_field, unused_element
- `lumara_assistant_cubit.dart`: unused_field, unused_element
- `session_view.dart`: unused_element
- `main_chat_manager.dart`: unused_field

### 4.3 Analyzer summary

- **Total issues:** 8728 (mostly avoid_print, prefer_const_*, deprecated_member_use)
- Import-related issues addressed in P1-IMPORTS run (2026-02-25)

---

## 5. Oversized Files

| File | Lines | Recommendation |
|------|-------|----------------|
| journal_screen.dart | 6541 | Extract draft handling, entry list, toolbar |
| interactive_timeline_view.dart | 4046 | Extract timeline segments |
| lumara_master_prompt.dart | 3910 | Split by prompt category |
| arcx_export_service_v2.dart | 3824 | Extract export stages |
| lumara_assistant_cubit.dart | 3644 | Extract context building, streaming |
| lumara_assistant_screen.dart | 3099 | Extract UI sections |
| local_backup_settings_view.dart | 3082 | Extract backup/restore flows |
| settings_view.dart | 2872 | Extract section builders |

---

## 6. Prioritized Recommendations

### High priority

1. ~~**Consolidate SentinelRiskDetector**~~ – **DONE** 2026-02-26.
2. ~~**Fix broken URIs**~~ – **DONE** 2026-02-26.
3. **Split journal_screen.dart** – Extract logical blocks (Phase 2).
4. **Reduce lumara_assistant_cubit.dart** – Move logic to services; remove unused elements.

### Medium priority

5. Remove/refactor unused elements (arcform_renderer_3d, lumara_assistant_cubit, session_view).
6. Unify iOS widget integration.
7. Split large import/export services.
8. Clarify chat screen usage (primary vs deprecated).

### Low priority

9. P1-SHARED-UI: apply shared settings patterns.
10. P2-FEED-CARDS: optional generic FeedEntryCard<T>.
11. Clean session_view_temp.dart duplicate import.
12. Address analyzer hints (avoid_print, prefer_const_*, etc.).

---

## 7. Already Addressed

| Work Package | Status |
|--------------|--------|
| P1-DUP (JournalVersionService) | Done |
| P1-QUICK (QuickActionsService) | Done |
| P2-REPOS (AppRepos / ChronicleRepos) | Done |
| P1-SHARED-UI | Partial |
| P1-IMPORTS | Addressed in 2026-02-25 run (23 files, unused imports removed) |
| **SentinelRiskDetector consolidation** | **Done 2026-02-26** – Removed atlas duplicate; atlas re-exports from extractors |
| **Broken URIs** | **Done 2026-02-26** – lumara_native, qwen_adapter, voice_mode_launcher, veil_edge, lumara_unified_prompts |

---

*Generated for Code Simplifier. Last updated: 2026-02-26.*
