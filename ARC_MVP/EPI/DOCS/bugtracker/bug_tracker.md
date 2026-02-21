# EPI MVP - Bug Tracker

**Version:** 3.3.0  
**Last Updated:** 2026-02-20  
**Record count:** 38 individual bug records in [records/](records/). Index below matches all files in records/.

**Master index & format:** For overview, document structure, standardized bug entry format, and maintenance procedures see [BUGTRACKER_MASTER_INDEX.md](BUGTRACKER_MASTER_INDEX.md). New records should follow the BUG-[ID] format (🐛🔧🎯📋) when possible; see audit [BUGTRACKER_AUDIT_REPORT.md](BUGTRACKER_AUDIT_REPORT.md).

---

## How to use this tracker

- **Index:** Use the sections below to find bugs by category (LUMARA, Timeline & UI, Export/Import, etc.). Each entry links to a detailed record in `records/`.
- **Fix instructions:** Each record in `records/` should include a **How to fix** section (or equivalent) with concrete steps so bugs can be resolved or worked around without hunting through the codebase.
- **Recent code changes:** Table derived from repo and [CHANGELOG.md](../CHANGELOG.md) – use it to see which fixes have bug records and which might need new records.
- **Archive:** Legacy bug tracker files (Bug_Tracker-1.md through Bug_Tracker-9.md) are in [archive/](archive/).

---

## Bug Tracker Index

This bug tracker has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[bug_tracker_part1.md](bug_tracker_part1.md)** | Dec 2025 | v2.1.43 - v2.1.60 (Recent) |
| **[bug_tracker_part2.md](bug_tracker_part2.md)** | Nov 2025 | v2.1.27 - v2.1.42 |
| **[bug_tracker_part3.md](bug_tracker_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.26 & Earlier |

---

## Individual Bug Records

Detailed bug reports are available in the [records/](records/) directory:

### LUMARA Issues
- [lumara-temporal-context-incorrect-dates.md](records/lumara-temporal-context-incorrect-dates.md) - **HIGH:** Incorrect date references in reflections (v3.2.2) ✅ RESOLVED
- [gemini-api-empty-user-string.md](records/gemini-api-empty-user-string.md) - **CRITICAL:** Empty user string rejection in journal reflections (v3.2.2) ✅ RESOLVED
- [lumara-user-prompt-override.md](records/lumara-user-prompt-override.md) - **CRITICAL:** User prompt overriding master prompt constraints (v3.0) ✅ RESOLVED
- [lumara-inline-api-pii-egress.md](records/lumara-inline-api-pii-egress.md) - **CRITICAL:** LumaraInlineApi softer/deeper reflection paths bypassed PRISM scrub (v3.3.49) ✅ RESOLVED BUG-PRISM-001
- [lumara-response-cutoff.md](records/lumara-response-cutoff.md) - Response truncation issues
- [lumara-subject-drift-and-repetitive-endings.md](records/lumara-subject-drift-and-repetitive-endings.md) - Subject focus and ending phrase issues
- [lumara-integration-formatting.md](records/lumara-integration-formatting.md) - Formatting and integration bugs
- [lumara-settings-refresh-loop.md](records/lumara-settings-refresh-loop.md) - Settings refresh issues
- [journal-context-current-entry-duplication.md](records/journal-context-current-entry-duplication.md) - **MEDIUM:** Journal context included current entry twice as "OLDER ENTRY" (v3.3.56) ✅ RESOLVED BUG-JOURNAL-001

### Timeline & UI Issues
- [timeline-infinite-rebuild-loop.md](records/timeline-infinite-rebuild-loop.md) - Timeline rebuild performance
- [timeline-ordering-timestamps.md](records/timeline-ordering-timestamps.md) - Entry ordering issues
- [timeline-overflow-empty-state.md](records/timeline-overflow-empty-state.md) - Empty state display
- [ui-ux-critical-fixes-jan-08-2025.md](records/ui-ux-critical-fixes-jan-08-2025.md) - Critical UI/UX fixes
- [ui-ux-fixes-jan-2025.md](records/ui-ux-fixes-jan-2025.md) - General UI/UX improvements
- [lumara-ui-overlap-stripe-auth-fixes.md](records/lumara-ui-overlap-stripe-auth-fixes.md) - LUMARA UI overlap and Stripe auth fixes

### Export/Import Issues
- [arcx-export-photo-directory-mismatch.md](records/arcx-export-photo-directory-mismatch.md) - Photo directory structure
- [arcx-import-date-preservation.md](records/arcx-import-date-preservation.md) - Date preservation during import
- [ios-folder-verification-permission-error.md](records/ios-folder-verification-permission-error.md) - **HIGH:** iOS folder verification permission error (v3.2.2) ✅ RESOLVED
- [mcp-repair-system-fixes.md](records/mcp-repair-system-fixes.md) - MCP repair system issues

### Data & Storage Issues
- [hive-initialization-order.md](records/hive-initialization-order.md) - Hive initialization problems
- [mediaitem-adapter-registration-conflict.md](records/mediaitem-adapter-registration-conflict.md) - MediaItem adapter conflicts
- [photo-duplication-view-entry.md](records/photo-duplication-view-entry.md) - Photo duplication bugs

### API & Integration Issues
- [gemini-api-empty-user-string.md](records/gemini-api-empty-user-string.md) - **CRITICAL:** Empty user string rejection in journal reflections ✅ RESOLVED
- [vision-api-integration-ios.md](records/vision-api-integration-ios.md) - Vision API iOS integration
- [wispr-flow-cache-issue.md](records/wispr-flow-cache-issue.md) - **MEDIUM:** Wispr Flow API key cached; new key not used until restart ✅ RESOLVED

### Subscription & Payment Issues
- [stripe-checkout-unauthenticated.md](records/stripe-checkout-unauthenticated.md) - **CRITICAL:** Cloud Run IAM blocking Stripe checkout ✅ RESOLVED
- [stripe-subscription-critical-fixes.md](records/stripe-subscription-critical-fixes.md) - Stripe subscription critical fixes

### Build & Platform Issues
- [build-fixes-session-feb-2026.md](records/build-fixes-session-feb-2026.md) - **CRITICAL:** Session consolidation – AppLifecycleState import, FeedRepository ChatMessage/session types, _buildRunAnalysisCard scope (3 bugs) ✅ RESOLVED
- [ios-build-rivet-models-keywords-set-type.md](records/ios-build-rivet-models-keywords-set-type.md) - **CRITICAL:** iOS build – rivet_models.g.dart keywords List vs Set<String> type error ✅ RESOLVED
- [ios-build-local-embedding-service-errors.md](records/ios-build-local-embedding-service-errors.md) - **CRITICAL:** iOS release build – CHRONICLE embedding stack (Dart parse/type, then EmbeddingService vs LocalEmbeddingService at call sites)
- [ios-build-native-embedding-channel-swift-scope.md](records/ios-build-native-embedding-channel-swift-scope.md) - **CRITICAL:** iOS Swift build – NativeEmbeddingChannel not in scope in AppDelegate.swift:104
- [ios-release-build-third-party-warnings.md](records/ios-release-build-third-party-warnings.md) - iOS release build third-party deprecation/warning noise (Pods, file_picker, Firebase, RevenueCat)

### Environment / Tooling
- [ollama-serve-address-in-use-and-quit-command.md](records/ollama-serve-address-in-use-and-quit-command.md) - Ollama: port 11434 already in use; `ollama quit` unknown command

### CHRONICLE Issues
- [chronicle-yearly-routing-early-year.md](records/chronicle-yearly-routing-early-year.md) - **HIGH:** Yearly layer routing returned empty context in Jan–Mar; early-year fallback to monthly (v3.3.56) ✅ RESOLVED BUG-CHRONICLE-001

### Feature-Specific Issues
- [constellation-zero-stars-display.md](records/constellation-zero-stars-display.md) - Constellation visualization
- [draft-creation-unwanted-drafts.md](records/draft-creation-unwanted-drafts.md) - Draft management
- [journal-editor-issues.md](records/journal-editor-issues.md) - Journal editor bugs
- [phase-analysis-integration-bugs.md](records/phase-analysis-integration-bugs.md) - Phase analysis integration
- [rivet-deterministic-recompute.md](records/rivet-deterministic-recompute.md) - RIVET computation issues
- [vision-api-integration-ios.md](records/vision-api-integration-ios.md) - Vision API iOS integration

---

## Recent code changes (reference for bug tracker)

This section is derived from the repo and [CHANGELOG.md](../CHANGELOG.md) to keep the bug tracker aligned with recent fixes. Use it for triage and to add new records when appropriate.

| Fix / change | Version | Bug record | Notes |
|--------------|---------|------------|--------|
| Reflection Session Safety System | v3.3.16 | — | Feature: AURORA-based risk monitoring with rumination/validation-seeking detection and tiered interventions. 6 new files. |
| RevenueCat In-App Purchases | v3.3.16 | — | Feature: In-app subscription via RevenueCat SDK; dual-channel premium (Stripe web + RevenueCat in-app). |
| Voice Sigil state machine upgrade | v3.3.16 | — | Feature: 6-state animation system replacing old glowing indicator; legacy voice journal files deleted. |
| PDF Preview screen | v3.3.16 | — | Feature: In-app PDF viewer for journal media. |
| Google Drive Folder Picker | v3.3.16 | — | Feature: In-app Google Drive folder browser for import/sync. |
| ARCX Clean Service | v3.3.16 | — | Utility: Remove low-content chats from ARCX archives. |
| DurationAdapter (Hive typeId 105) | v3.3.16 | — | Infrastructure: Required for video entries; fixes serialization of Duration fields. |
| CHRONICLE synthesis improvements | v3.3.16 | — | PatternDetector, Monthly/Yearly/MultiYear synthesizers modified for improved theme filtering. |
| iOS folder verification permission error | v3.3.13 | [ios-folder-verification-permission-error.md](records/ios-folder-verification-permission-error.md) ✅ | Security-scoped resource access on iOS for VerifyBackupScreen |
| Phase Quiz result not persisting; Phase tab mismatch | v3.3.13 | — | Quiz result now persisted via UserPhaseService; Phase tab uses quiz phase when no regimes. See CHANGELOG [3.3.13] "Phase Quiz result matches Phase tab". |
| llama.xcframework build / simulator | recent | — | Link llama static library directly; device build search paths; simulator stubs; exclude xcframework from simulator. Build/config fixes. |
| Import status bar, mini bar, per-file status | v3.3.13 | — | Feature; not a bug. See CHANGELOG. |
| Wispr Flow cache – new API key not used until restart | v3.3.13 | [wispr-flow-cache-issue.md](records/wispr-flow-cache-issue.md) ✅ | WisprConfigService cached key; fix: clearCache() on save in Settings. |
| iOS release build failure (LocalEmbeddingService) | — | [ios-build-local-embedding-service-errors.md](records/ios-build-local-embedding-service-errors.md) | Dart parse/type; then EmbeddingService vs LocalEmbeddingService at call sites (3 files). |
| iOS Swift: NativeEmbeddingChannel not in scope | — | [ios-build-native-embedding-channel-swift-scope.md](records/ios-build-native-embedding-channel-swift-scope.md) | AppDelegate.swift:104; Runner target membership / compile sources. |
| iOS release build third-party warnings | — | [ios-release-build-third-party-warnings.md](records/ios-release-build-third-party-warnings.md) | DKImagePickerController, file_picker, Firebase, RevenueCat deprecations; tech debt. |
| iOS build: rivet_models.g.dart keywords Set type | 2026-02-13 | [ios-build-rivet-models-keywords-set-type.md](records/ios-build-rivet-models-keywords-set-type.md) ✅ | List<String> assigned to Set<String> in generated adapter; fix: .toSet() in read(). |
| Ollama serve address in use; ollama quit unknown | 2026-02-13 | [ollama-serve-address-in-use-and-quit-command.md](records/ollama-serve-address-in-use-and-quit-command.md) | Environment: port 11434 in use; CLI "quit" not recognized. |

| Voice Moonshine spec, transcription cleanup, unified feed | v3.3.31 | — | Feature: VOICE_TRANSCRIPTION_MOONSHINE_SPEC; TranscriptCleanupService; unified feed/HomeView updates. |
| ExpandedEntryView, RelatedEntriesService | v3.3.32 | — | Unified feed expanded entry widget and CHRONICLE related-entries service updates. |
| Master prompt, control state, Narrative Intelligence docs | v3.3.33 | — | lumara_master_prompt.dart and LumaraControlStateBuilder extended; MASTER_PROMPT_CHRONICLE_VECTORIZATION.md, NARRATIVE_INTELLIGENCE_OVERVIEW.md added. |
| LUMARA API, control state, CHRONICLE query stack | v3.3.34 | — | enhanced_lumara_api, lumara_control_state_builder; query_plan, context_builder, query_router; NARRATIVE_INTELLIGENCE_OVERVIEW edit. |
| LUMARA agents, orchestrator, CHRONICLE alignment, settings refactor | v3.3.35 | — | agents/ (research, writing), orchestrator, intent classifier; CHRONICLE index/pattern/router/repos; lumara_settings_screen refactor; CHRONICLE_PAPER_VS_IMPLEMENTATION.md. |
| AppLifecycleState import; FeedRepository types; _buildRunAnalysisCard order | 2026-02-08 | [build-fixes-session-feb-2026.md](records/build-fixes-session-feb-2026.md) ✅ | auto_save_service: add `dart:ui` show AppLifecycleState. feed_repository: createdAt, metadata ?? {}, msg.id. phase_analysis_view: move _buildRunAnalysisCard before _buildArcformContent, remove duplicate. |
| Agents screen, agents_connection_service | v3.3.36 | — | agents_screen.dart extended; new agents_connection_service.dart. |
| Research/writing prompts, timeline context, synthesis/draft | v3.3.37 | — | research_prompts.dart, writing_prompts.dart, timeline_context_service.dart; research_agent, synthesis_engine, draft_composer, writing_agent, writing_models, writing_screen. |
| Writing drafts storage, research persistence, archive/delete, ARCX agents | v3.3.38 | — | WritingDraftRepository (list/archive/delete); ResearchArtifactRepository JSON persist; Agents tab Active/Archived; ARCX export/import extensions/agents. |
| Research/writing prompts expansion, screen and tab refinements | v3.3.39 | — | research_prompts.dart, writing_prompts.dart extended; research_screen, writing_screen, research_agent_tab, lumara_assistant_cubit, agents_screen. |
| Agents expansion, Narrative Intelligence .tex, chats/settings, orchestration | v3.3.40 | — | agents_screen major; saved_chats_screen, lumara_settings_screen; arc/agents/drafts, agent_operating_system_prompt, lumara_intent_classifier, orchestration_violation_checker; DOCS .md→.tex. |
| Dual CHRONICLE, Writing with LUMARA, timeline/feed, white paper .tex | v3.3.41 | — | lib/chronicle/dual/, dual_chronicle_view; LUMARA_DUAL_CHRONICLE_* docs; writing_with_lumara_screen; chat_draft_viewer_screen removed; timeline/feed/settings/journal updates. |
| Docs: ARCHITECTURE paper/archive ref, LaTeX gitignore, Narrative/LUMARA archive | v3.3.42 | — | DOCS only: ARCHITECTURE.md §2 ref; NARRATIVE_INTELLIGENCE_PAPER_ARCHITECTURE_SECTION archived; .gitignore LaTeX artifacts; bug_tracker tracked. |
| Dual CHRONICLE UI, LUMARA assistant, journal capture, onboarding, unified feed | v3.3.43 | — | dual_chronicle_view +311; lumara_assistant_cubit +117; journal_capture_cubit/view; unified_feed_screen refactor; home_view, arc_onboarding_sequence; ONBOARDING_TEXT. |
| CHRONICLE search (hybrid/BM25/semantic), unified feed, Arcform 3D | v3.3.44 | — | lib/chronicle/search/ (9 files); unified_feed_screen; simplified_arcform_view_3d; LUMARA_ARCHITECTURE_SECTION archive. |
| Dual CHRONICLE intelligence summary, settings, LUMARA definitive overview | v3.3.45 | — | intelligence_summary_* (models, repo, generator, view); dual_chronicle_view +356/−74; agentic_loop_orchestrator, dual_chronicle_services, chronicle_dual; settings_view; LUMARA_DEFINITIVE_OVERVIEW.md. |
| Google Drive folder picker, local backup settings, home; DOCS cleanup | v3.3.46 | — | google_drive_service, drive_folder_picker_screen, local_backup_settings_view, home_view; removed redundant LUMARA_DUAL_CHRONICLE_* (3) from DOCS (canonical = LUMARA_DUAL_CHRONICLE_GUIDE.md; originals in archive). |
| Dual CHRONICLE refactor, intelligence summary, search, prompts, phase/Arcform | v3.3.47 | — | user_chronicle_repository removed; chronicle_query_adapter, schedule prefs, lumara_comments_loader, chronicle_phase_signal_service, lumara_comments_context_loader; dual_chronicle_view, intelligence_summary_view; PROMPT_REFERENCES +104; BUGTRACKER_MASTER_INDEX, BUGTRACKER_AUDIT_REPORT. |
| Universal prompt optimization layer (80/20, provider-agnostic) | v3.3.48 | — | lib/arc/chat/prompt_optimization/ (optimizer, provider_manager, response_cache, universal_response_generator, Groq/OpenAI/Claude adapters); DOCS/UNIVERSAL_PROMPT_OPTIMIZATION.md; enhanced_lumara_api. |
| CHRONICLE layer0, dual CHRONICLE/LUMARA, ARCX/MCP, DevSecOps audit; LumaraInlineApi PII fix | v3.3.49 | [lumara-inline-api-pii-egress.md](records/lumara-inline-api-pii-egress.md) ✅ | chronicle_layer0_retrieval_service; lumara_inline_api PII fix (BUG-PRISM-001 — unscrubed text bypassed PRISM before cloud send); arcx_* / mcp_pack_*; DEVSECOPS_SECURITY_AUDIT.md. |
| Egress PII & LumaraInlineApi security tests; backend, auth, gemini_send, subscription, AssemblyAI | v3.3.50 | [lumara-inline-api-pii-egress.md](records/lumara-inline-api-pii-egress.md) ✅ | egress_pii_and_lumara_inline_test.dart verifies BUG-PRISM-001 fix; firebase_auth_service, gemini_send, subscription_service, assemblyai_service; DEVSECOPS_SECURITY_AUDIT.md. |
| Journal capture, journal repository, dual CHRONICLE (agentic loop, dual_chronicle_view) | v3.3.51 | — | journal_capture_cubit, journal_repository (mira); agentic_loop_orchestrator, dual_chronicle_view. |
| Google Drive sync folder push; Drive settings; unified feed; MCP export/management; DOCS checklist | v3.3.52 | — | sync_folder_push_screen; google_drive_service, google_drive_settings_view; unified_feed_screen; mcp_export_screen, mcp_management_screen; CONFIGURATION_MANAGEMENT, claude.md. |
| iOS project (Runner.xcodeproj) | v3.3.53 | — | ios/Runner.xcodeproj/project.pbxproj. |
| PDF content service; journal, CHRONICLE layer0, MCP orchestrators, media alt text; pubspec | v3.3.54 | — | pdf_content_service; journal_capture_cubit, journal_screen, layer0_populator; chat_multimodal_processor, ios_vision_orchestrator; media_alt_text_generator; pubspec. |
| Repo dir rename ARC MVP → ARC_MVP; prompt audit PROMPT_REFERENCES v2.7.0 | v3.3.55 | — | Filesystem rename committed; no code changes. ECHO On-Device LLM system prompt (prompt_templates.dart) added to PROMPT_REFERENCES. |
| PRISM context compression; CHRONICLE date-aware routing; LUMARA token caps; landscape orientation | v3.3.56 | [chronicle-yearly-routing-early-year.md](records/chronicle-yearly-routing-early-year.md) ✅ [journal-context-current-entry-duplication.md](records/journal-context-current-entry-duplication.md) ✅ | prism_adapter extractKeyPoints/compressAndScrub; enhanced_lumara_api 40K/60K caps; query_router month≥4 yearly rule (BUG-CHRONICLE-001); context_builder budget fix; journal dedup fix (BUG-JOURNAL-001); landscape support. |

**Source:** `git log --oneline`, [CHANGELOG.md](../CHANGELOG.md), terminal build log. Last synced: 2026-02-20.

---

## Archive

Historical bug tracker files are archived in [archive/](archive/):
- Legacy bug tracker files (Bug_Tracker-1.md through Bug_Tracker-9.md)
- Older bug tracker versions

Individual bug records stay in [records/](records/); only the legacy multi-part tracker files are in archive.

---

**Status**: ✅ Active - All resolved issues documented; Build & Platform: 5 records; Environment: 1 (Ollama); CHRONICLE: 1 (BUG-CHRONICLE-001 ✅); Privacy: 1 (BUG-PRISM-001 ✅). Bugtracker-consolidator run 2026-02-20: 3 new records added (38 total).  
**Last Updated**: 2026-02-20
