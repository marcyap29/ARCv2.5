# EPI LUMARA MVP - Changelog

**Version:** 3.3.20
**Last Updated:** February 10, 2026

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.87 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [3.3.20] - February 10, 2026 (working changes)

### ARC → LUMARA Branding Rename

Complete rename of all user-facing "ARC" references to "LUMARA" throughout the application.

**Asset Changes:**
- Deleted `assets/icon/LUMARA_Sigil_White.png`, `assets/icon/app_icon.png`, `assets/images/ARC-Logo.png`.
- Added `assets/icon/LUMARA_Sigil.png` — consolidated single sigil asset used everywhere (splash, tab bar, feed, voice sigil, onboarding, pulsing symbol, LumaraIcon widgets).

**Backup File Naming:**
- `ARC_BackupSet_` → `LUMARA_BackupSet_`, `ARC_Full_` → `LUMARA_Full_`, `ARC_Inc_` → `LUMARA_Inc_` (export filenames).
- Backward-compatible regex: reading existing backups matches both `LUMARA_*` and legacy `ARC_*` patterns.
- Google Drive folder: `ARC Backups` → `LUMARA Backups`.
- Local backup default folder: `ARCX_Backups` → `LUMARA_Backups`.

**UI Text:**
- Splash screen: uses `LUMARA_Sigil.png` instead of `ARC-Logo.png`; comments updated.
- Onboarding: "Welcome to ARC." → "Welcome to LUMARA.", "ARC learns..." → "LUMARA learns...", "ARC and LUMARA are built on..." → "LUMARA is built on...".
- Notifications: `ARC Monthly Review` → `LUMARA Monthly Review`, `ARC 6-Month View` → `LUMARA 6-Month View`, `ARC Year in Review` → `LUMARA Year in Review`.
- Copy.dart: "ARC changes your phase" → "LUMARA changes your phase".
- Keyword analysis: "ARC is analyzing" → "LUMARA is analyzing", "ARC Analysis" → "LUMARA Analysis".
- Arcform export: "ARC MVP" → "LUMARA MVP".
- Chat export: "ARC EPI v1.0" → "LUMARA EPI v1.0".
- Local backup: "Clean ARCX" → "Clean LUMARA archive", updated descriptions.
- Google Drive settings: all "ARC" references → "LUMARA".
- Permissions: "ARC needs a few permissions" → "LUMARA needs a few permissions".

#### Files deleted
- `assets/icon/LUMARA_Sigil_White.png`
- `assets/icon/app_icon.png`
- `assets/images/ARC-Logo.png`

#### Files added
- `assets/icon/LUMARA_Sigil.png`

#### Files modified (branding only)
- `lib/arc/chat/chat/chat_category_models.dart`
- `lib/arc/chat/ui/lumara_splash_screen.dart`
- `lib/arc/chat/ui/widgets/lumara_icon.dart`
- `lib/arc/chat/voice/ui/voice_sigil.dart`
- `lib/arc/core/widgets/keyword_analysis_view.dart`
- `lib/arc/ui/arcforms/arcform_mvp_view.dart`
- `lib/arc/ui/widgets/keyword_analysis_view.dart`
- `lib/core/i18n/copy.dart`
- `lib/mira/store/arcx/services/arcx_export_service_v2.dart`
- `lib/services/arcform_export_service.dart`
- `lib/services/temporal_notification_service.dart`
- `lib/shared/tab_bar.dart`
- `lib/shared/ui/onboarding/arc_onboarding_sequence.dart`
- `lib/shared/ui/onboarding/onboarding_view.dart`
- `lib/shared/ui/onboarding/widgets/lumara_pulsing_symbol.dart`
- `lib/shared/ui/settings/google_drive_settings_view.dart`
- `lib/shared/ui/settings/local_backup_settings_view.dart`
- `lib/shared/widgets/lumara_icon.dart`
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart`

---

### Phase Sentinel Safety Integration

New Sentinel integration layer ensures RIVET/ATLAS phase proposals are checked against Sentinel (crisis/cluster alert) before being applied. If alert triggers, segment phase is overridden to Recovery as a safety measure.

**New file:** `lib/services/phase_sentinel_integration.dart`
- `resolvePhaseWithSentinel(proposal, allEntries)` — calculates Sentinel score on segment text; returns `PhaseLabel.recovery` if `score.alert` is true, otherwise returns RIVET/ATLAS proposed label.
- Graceful degradation: if Sentinel is unavailable (offline/Firestore), keeps the RIVET/ATLAS phase.

**Applied in:**
- `rivet_sweep_service.dart` — `runAutoPhaseAnalysis()` uses `resolvePhaseWithSentinel()` when creating regimes.
- `phase_analysis_view.dart` — `_runRivetSweep()` applies Sentinel check.
- `phase_analysis_settings_view.dart` — same integration.

**RIVET/ATLAS/Sentinel Roles Documented:**
- Header comments in `rivet_sweep_service.dart` now document the three-system architecture: RIVET (segmentation, gating), ATLAS (phase scoring), Sentinel (safety override).

#### Files added
- `lib/services/phase_sentinel_integration.dart`

#### Files modified
- `lib/services/rivet_sweep_service.dart` — Sentinel integration, updated comments
- `lib/ui/phase/phase_analysis_view.dart` — Sentinel integration
- `lib/shared/ui/settings/phase_analysis_settings_view.dart` — Sentinel integration

---

### Unified Feed: Selective Export, Phase Gantt, Paragraph Rendering

**Selective Export from Feed:**
- Selection bar now shows "Export (N)" button alongside "Delete (N)" when entries are selected.
- `_showExportOptions()` — bottom sheet offering ARCX (encrypted) or ZIP (portable) export.
- `_exportSelectedAsArcx()` — uses `ARCXExportServiceV2` with subset of journal IDs, shows progress dialog, shares via `Share.shareXFiles`.
- `_exportSelectedAsZip()` — uses `McpPackExportService`, shows progress dialog, shares via `Share.shareXFiles`.
- Only saved journal entries (with `journalEntryId`) can be exported.

**Phase Journey Gantt Card:**
- New `_PhaseJourneyGanttCard` widget embedded in the feed between phase Arcform preview and communication actions.
- Gantt-style horizontal bar showing phase regimes over time using `PhaseTimelinePainter`.
- Displays start/end dates, total days, number of phases.
- `PhaseRegimeService.getLastEntryDateInRange()` — returns latest journal entry date in a date range.
- `PhaseRegimeService.extendMostRecentRegimeToLastEntry()` — extends most recent regime end to last entry date.

**Phase Preview Refresh:**
- `_phasePreviewRefreshKey` state variable bumped when returning from Phase view, so both the Arcform preview and Gantt card rebuild with updated phase data.
- Wrapped in `KeyedSubtree` for forced rebuild.

**Paragraph Rendering:**
- `ExpandedEntryView._buildParagraphWidgets()` — splits text on double newlines (paragraph break) or single newlines (line break), renders each paragraph with 12px bottom spacing and 1.5 line height.
- Applied across all content renderers: conversation messages, written reflections, voice memos, LUMARA initiatives.
- `EntryContentRenderer._buildParagraphs()` — same paragraph logic applied in timeline view (replaces single `Text(content)` with properly spaced paragraphs).

**Summary Extraction:**
- `FeedHelpers.extractSummary()` — extracts `## Summary\n\n...\n\n---\n\n` header from content.
- `FeedHelpers.bodyWithoutSummary()` — returns content after the summary section.
- `ExpandedEntryView._buildWrittenContent()` — renders summary (italic, with "Summary" label) and body separately.

**Card Date Formatting:**
- New `FeedHelpers.formatEntryCreationDate()` — formats as "Today, 14:30", "Yesterday, 09:15", "Mar 15, 14:30", or "Mar 15, 2025".
- All 5 feed entry cards now use `formatEntryCreationDate()` — more prominent (12px, 0.8 opacity) than previous `formatFeedDate()` (11px, 0.5 opacity).
- `ReflectionCard` and `SavedConversationCard`: date moved to leading position in metadata row.

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Export, Gantt card, phase preview refresh
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart` — Paragraph rendering, summary extraction
- `lib/arc/unified_feed/utils/feed_helpers.dart` — `extractSummary`, `bodyWithoutSummary`, `formatEntryCreationDate`
- `lib/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart` — Date in metadata row, `formatEntryCreationDate`
- `lib/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart` — Same
- `lib/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart` — `formatEntryCreationDate`
- `lib/arc/unified_feed/widgets/feed_entry_cards/lumara_prompt_card.dart` — Same
- `lib/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart` — Same
- `lib/arc/ui/timeline/widgets/entry_content_renderer.dart` — Paragraph rendering

---

### RIVET Reset on User Phase Change

When a user manually sets their phase (via quiz, timeline, or onboarding), RIVET is now reset so its gate closes and it accumulates fresh evidence before opening again.

- `PhaseRegimeService.changeCurrentPhase()` — calls `RivetProvider().safeClearUserData()` after creating new regime.
- `UserPhaseService.forceUpdatePhase()` — also resets RIVET.
- `simplified_arcform_view_3d.dart` — phase change now persists to `UserPhaseService.forceUpdatePhase()`.

#### Files modified
- `lib/services/phase_regime_service.dart` — RIVET reset, `getLastEntryDateInRange`, `extendMostRecentRegimeToLastEntry`
- `lib/services/user_phase_service.dart` — RIVET reset on `forceUpdatePhase`
- `lib/ui/phase/simplified_arcform_view_3d.dart` — `forceUpdatePhase` on phase change

---

### Voice Session: Auto-Endpoint Disabled

- `VoiceSessionService`: Endpoint detector callback is now a no-op — voice recording no longer auto-stops on silence.
- Previous behavior caused premature stop when users pause to think.
- User must now explicitly tap the talk button to indicate they're finished speaking.
- Removed `_onEndpointDetected()` method entirely.

#### Files modified
- `lib/arc/chat/voice/services/voice_session_service.dart`

---

### Privacy Settings: Inline PII Scrub Demo

- `PrivacySettingsView`: New "Test privacy protection" card with real-time PII scrubbing demo.
- Inline `TextField` with debounced input (350ms) → runs `PrismAdapter.scrub()` → shows scrubbed output and redaction count.
- Pre-filled example: "Hi, I'm Jane. Email me at jane@example.com or call (555) 123-4567."
- Shows "What we send to the cloud:" label with scrubbed text and "N PII item(s) redacted" counter.

#### Files modified
- `lib/shared/ui/settings/privacy_settings_view.dart`

---

## [3.3.19] - February 9, 2026 (working changes)

### Unified Feed — Phase 2.0: Entry Management, Media, LUMARA Chat Integration, Phase Priority

Building on Phase 1.5 (`v3.3.18`), this update evolves the Unified Feed from read-only browsing into a full entry-management hub with deletion, media display, direct LUMARA chat, and phase-priority fixes across the application.

**Entry Deletion (swipe + batch):**
- Swipe-to-delete on any card that has a `journalEntryId` — `Dismissible` with confirmation dialog, calls `JournalRepository.deleteJournalEntry()`, refreshes feed.
- **Batch selection mode**: "Select entries" (checklist icon) in header actions enters multi-select. Selection overlay with checkboxes on each card. "Delete (N)" button with confirmation dialog deletes all selected entries, then refreshes feed.
- **ExpandedEntryView delete**: Options menu "Delete" is now fully wired — confirmation dialog, actual deletion via `JournalRepository`, calls `onEntryDeleted` callback, pops view, shows snackbar.

**Media Support:**
- `FeedEntry.mediaItems` (`List<MediaItem>`) added to model and populated by `FeedRepository` from journal entry media.
- **ReflectionCard**: Shows `FeedMediaThumbnails` strip (up to 4 thumbnails) beneath content preview.
- **ExpandedEntryView**: Full media section with grid of thumbnail tiles; resolves `ph://`, `file://`, and MCP-style URIs via `MediaResolverService`/`PhotoLibraryService`. Tapping an image opens `FullImageViewer`.
- **New widget**: `FeedMediaThumbnailTile` and `FeedMediaThumbnails` (`widgets/feed_media_thumbnails.dart`) — reusable media thumbnail components.

**LUMARA Chat Integration:**
- "Chat" button in feed now opens `LumaraAssistantScreen` directly (replaces focusing input bar).
- `_buildEntryMessageForLumara()` finds the most recent entry with content and sends it to LUMARA as "Please reflect on this entry" — enabling one-tap reflection on any recent entry.
- `LumaraAssistantScreen` gains `initialMessage` parameter; auto-sends via `addPostFrameCallback` on first frame.
- Removed `ChatNavigationDrawer` — AppBar leading is now a back arrow (when navigable) instead of hamburger menu. "New Chat" removed from popup menu.

**Input Bar Removed:**
- `FeedInputBar` entirely removed from `UnifiedFeedScreen` (import, widget, `_inputFocusNode`, `_onMessageSubmit` all deleted). Chat, Reflect, and Voice are now dedicated action buttons.

**Communication Actions in Populated Feed:**
- Chat / Reflect / Voice row (`_buildCommunicationActions()`) added to the populated feed (above "Today" section, below phase preview), replacing the input bar for quick-start actions.
- Previously these actions only existed in the welcome/empty state.

**Phase Arcform Preview in Feed:**
- `CurrentPhaseArcformPreview` widget embedded in the feed (below header actions, above communication row). Tap opens `PhaseAnalysisView`.
- `onTapOverride` callback added to `CurrentPhaseArcformPreview` for customizable navigation.
- Phase resolution now uses `UserPhaseService.getDisplayPhase()` (profile-first priority) with RIVET gate check via `RivetProvider`.

**Phase Hashtag Stripping:**
- New `FeedHelpers.contentWithoutPhaseHashtags()` strips `#discovery`, `#expansion`, `#transition`, `#consolidation`, `#recovery`, `#breakthrough` from display content. Phase information shows only in card metadata/header, not in body text.
- Applied in: `ReflectionCard`, `ExpandedEntryView` (all content renderers: conversation, reflection, voice memo, LUMARA initiative).

**ExpandedEntryView Edit:**
- Edit button now loads full `JournalEntry` via `JournalRepository.getJournalEntryById()` and opens `JournalScreen` in edit mode.

**Header Actions Rearranged:**
- Voice memo icon replaced by "Select entries" (checklist icon) for batch delete.
- Remaining: Select, Timeline (calendar), Settings gear.

**Phase Priority Fix (UserPhaseService):**
- `getDisplayPhase()` reordered: user's explicit phase (quiz or manual "set overall phase") takes priority over RIVET/regime. This ensures a user who sets "Breakthrough" via the Phase Timeline keeps that phase visible everywhere.
- `PhaseTimelineView`: Changing phase now persists to `UserPhaseService.forceUpdatePhase()`.
- `JournalScreen`: User profile creation preserves existing phase from quiz/snapshots instead of defaulting to "Discovery".

**Auto Phase Analysis After Import:**
- `runAutoPhaseAnalysis()` top-level function added to `rivet_sweep_service.dart` — headless RIVET Sweep that auto-creates phase regimes from all entries (no user navigation required).
- `RivetSweepResult.approvableProposals` getter — combines auto-assign + review proposals, sorted by start date.
- `HomeView`: After successful ARCX/ZIP import, automatically runs phase analysis in background with snackbar notification ("Phase analysis complete — N phases detected").

**Phase Analysis Refactored:**
- `PhaseAnalysisView`: Removed pending analysis approval flow (`_hasUnapprovedAnalysis`, `_lastSweepResult`). Analysis now auto-applies. `_checkPendingAnalysis` clears stale flags (no-op).
- `CombinedAnalysisView`: Removed entire Phase Analysis tab (~564 lines). Now contains only Advanced Analytics.
- **New**: `PhaseAnalysisSettingsView` (`lib/shared/ui/settings/phase_analysis_settings_view.dart`) — dedicated Settings screen for Phase Analysis with run-analysis button and phase statistics cards.
- `SettingsView`: Added "Phase Analysis" menu item linking to `PhaseAnalysisSettingsView`. Renumbered subsequent items.

**CHRONICLE Management Progress UI:**
- `ChronicleManagementView`: Rich progress view replacing generic spinner — circular progress indicator with percentage overlay, stage label ("Backfilling Layer 0..."), entry count ("12 / 340 entries"), and linear progress bar.

**Journal Screen Cleanup:**
- Removed `_trackJournalModeEntry()` and `_showPromptNotice()` (prompt notice dialog was interruptive UX).

**FeedRepository:**
- Phase extraction now uses `entry.computedPhase` (manual user override takes priority over auto-detected).
- Empty-string phase check prevents passing blank phases to `PhaseColors.getPhaseColor()`.

#### Files added
- `lib/arc/unified_feed/widgets/feed_media_thumbnails.dart`
- `lib/shared/ui/settings/phase_analysis_settings_view.dart`

#### Files modified
- `lib/arc/unified_feed/models/feed_entry.dart` — Added `mediaItems` field
- `lib/arc/unified_feed/repositories/feed_repository.dart` — `computedPhase`, empty check, `mediaItems`
- `lib/arc/unified_feed/utils/feed_helpers.dart` — `contentWithoutPhaseHashtags()`
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Removed input bar; added batch select, swipe-to-delete, communication actions, phase preview, LUMARA chat integration
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart` — Media section, working edit/delete, phase hashtag stripping, `onEntryDeleted` callback
- `lib/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart` — Phase hashtag stripping, media thumbnails
- `lib/arc/chat/ui/lumara_assistant_screen.dart` — `initialMessage`, removed drawer, back arrow navigation
- `lib/services/rivet_sweep_service.dart` — `approvableProposals`, `runAutoPhaseAnalysis()`
- `lib/services/user_phase_service.dart` — Phase priority reordered (profile first)
- `lib/shared/ui/home/home_view.dart` — Auto phase analysis after import
- `lib/shared/ui/settings/chronicle_management_view.dart` — Rich progress UI
- `lib/shared/ui/settings/combined_analysis_view.dart` — Removed Phase Analysis tab
- `lib/shared/ui/settings/settings_view.dart` — Phase Analysis menu item
- `lib/ui/journal/journal_screen.dart` — Removed prompt notice, phase-preserving profile creation
- `lib/ui/phase/phase_analysis_view.dart` — Auto-apply analysis, removed approval flow
- `lib/ui/phase/phase_timeline_view.dart` — `forceUpdatePhase` on phase change
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` — `onTapOverride`, profile-first phase resolution

---

## [3.3.18] - February 9, 2026 (working changes)

### Unified Feed — Phase 1.5: Model refactor, pagination, expanded views, timeline navigation

Building on Phase 1 (`v3.3.17`), this update significantly evolves the Unified Feed architecture:

**Model Refactor:**
- **FeedEntry**: `writtenEntry` type renamed to `reflection`; new `lumaraInitiative` type for LUMARA-initiated observations/prompts. Replaced `createdAt`/`updatedAt` with single `timestamp`. Added `FeedMessage` class for in-model conversation messages. Added `themes`, `phaseColor`, `messages`, `isActive`, `audioPath`, `transcriptPath`. Content is now `dynamic` (string or structured). `preview` is a computed getter. Removed Equatable dependency.
- **EntryState**: Simplified from full lifecycle class to streamlined enum-based state.

**FeedRepository Enhancements:**
- Pagination via `getFeed(before, after, limit, types)`.
- `getActiveConversation()` with 20-minute staleness check.
- Robust error handling: journal and chat repos initialize independently; errors don't block feed.
- Phase color extraction via `PhaseColors.getPhaseColor()`.
- Theme extraction from entry metadata.
- Search now includes themes.

**New Widgets:**
- **ExpandedEntryView** (`widgets/expanded_entry_view.dart`): Full-screen detail view for any entry — phase indicator, full content, themes, CHRONICLE-related entries, LUMARA notes, edit/share/delete actions.
- **BaseFeedCard** (`widgets/feed_entry_cards/base_feed_card.dart`): Shared card wrapper with phase-colored left border indicator. All cards extend this.
- **ReflectionCard** (`widgets/feed_entry_cards/reflection_card.dart`): Replaces `WrittenEntryCard` for text-based reflections.
- **LumaraPromptCard** (`widgets/feed_entry_cards/lumara_prompt_card.dart`): LUMARA-initiated observations, check-ins, and prompts detected by CHRONICLE/VEIL/SENTINEL.
- **TimelineModal** (`widgets/timeline/timeline_modal.dart`): Bottom sheet for date-based feed navigation.
- **TimelineView** (`widgets/timeline/timeline_view.dart`): Calendar/timeline view within the modal.

**Infrastructure:**
- **PhaseColors** (`lib/core/constants/phase_colors.dart`): Phase color constants for card borders and indicators.
- **EntryMode** (`lib/core/models/entry_mode.dart`): Enum (`chat`, `reflect`, `voice`) for initial screen state from welcome screen or deep links.
- **app.dart**: Switched from named routes to `onGenerateRoute` to pass `EntryMode` arguments to HomeView.

**UnifiedFeedScreen Enhancements:**
- Infinite scroll / load-more pagination (loads 20 entries at a time).
- Timeline modal accessible from app bar (calendar icon) for date navigation.
- Date filter: jump to specific date, clear filter to return to feed.
- Voice mode launch via callback from HomeView.
- `initialMode` parameter: feed activates chat/reflect/voice mode on first frame (from welcome screen).
- LUMARA observation banner.
- Card taps navigate to ExpandedEntryView.

**HomeView:**
- Simplified from 2 tabs (LUMARA + Phase) to single LUMARA tab in unified mode. Phase accessible via Timeline button inside the feed.
- Passes `onVoiceTap` and `initialMode` to UnifiedFeedScreen.

#### Files added
- `lib/arc/unified_feed/widgets/expanded_entry_view.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/base_feed_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/lumara_prompt_card.dart`
- `lib/arc/unified_feed/widgets/timeline/timeline_modal.dart`
- `lib/arc/unified_feed/widgets/timeline/timeline_view.dart`
- `lib/core/constants/phase_colors.dart`
- `lib/core/models/entry_mode.dart`

#### Files modified
- `lib/arc/unified_feed/models/feed_entry.dart` — Major refactor (see above)
- `lib/arc/unified_feed/models/entry_state.dart` — Simplified
- `lib/arc/unified_feed/repositories/feed_repository.dart` — Pagination, error handling, phase colors
- `lib/arc/unified_feed/services/conversation_manager.dart` — Adapted to new FeedEntry shape
- `lib/arc/unified_feed/services/auto_save_service.dart` — Minor update
- `lib/arc/unified_feed/utils/feed_helpers.dart` — Extended helpers
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Timeline, pagination, modes, expanded view
- `lib/arc/unified_feed/widgets/input_bar.dart` — Minor update
- `lib/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart` — Uses BaseFeedCard
- `lib/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart` — Uses BaseFeedCard
- `lib/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart` — Uses BaseFeedCard
- `lib/shared/ui/home/home_view.dart` — Single tab, passes onVoiceTap/initialMode
- `lib/app/app.dart` — onGenerateRoute for EntryMode

#### Files deleted
- `lib/arc/unified_feed/widgets/feed_entry_cards/written_entry_card.dart` — Replaced by ReflectionCard

### Welcome Screen / First-Use UX & Settings Tab

**Empty state awareness:**
- **UnifiedFeedScreen**: New `onEmptyStateChanged` callback reports whether the feed has entries. Input bar is hidden when the feed is empty so the welcome screen stands alone. Wrapped in `GestureDetector` to dismiss keyboard on outside tap.
- **HomeView**: Tracks `_feedIsEmpty` state. Bottom navigation bar is hidden when the unified feed is in the empty/welcome state, providing a clean first-use onboarding experience. Once entries exist, the full nav appears.

**Tab layout change (unified mode):**
- Restored 2-tab layout: **LUMARA** (index 0) + **Settings** (index 1).
- `_getPageForIndex` routes Settings tab to `SettingsView`.
- Center "+" journal button hidden in unified feed mode (`showCenterButton: false`) since the input bar and quick-start actions replace it.

**tab_bar.dart:**
- The center "+" button is now conditionally rendered based on `showCenterButton` property (previously always rendered regardless of the flag value).

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — `onEmptyStateChanged` callback, input bar hidden in empty state, GestureDetector wrapper
- `lib/shared/tab_bar.dart` — Center button conditional rendering
- `lib/shared/ui/home/home_view.dart` — `_feedIsEmpty` state, nav hidden on empty, Settings tab, showCenterButton logic

### Welcome Screen: Phase Quiz, Settings Gear, Data Import

**Welcome screen redesign (`_buildEmptyState`):**
- **Settings gear** (top-right) — opens SettingsView directly from the welcome screen, giving first-time users access to account/preferences before creating any entries.
- **"Discover Your Phase" button** — prominent gradient button (using `kcPrimaryGradient`) placed between the subtitle and quick-start actions. Launches `PhaseQuizV2Screen` so new users can immediately identify their life phase, which seeds ATLAS phase detection for all future entries.
- **Chat / Reflect / Voice buttons** moved down one row below the Phase Quiz button.
- **"Import your data" link** at the bottom — separated by a divider. Opens `ImportOptionsSheet` bottom sheet for users with existing journal data.
- Welcome content wrapped in `SingleChildScrollView` for small screens and `SafeArea`.

**ImportOptionsSheet** (`widgets/import_options_sheet.dart`):
- Full-height bottom sheet with 5 import source options: LUMARA Backup, Day One, Journey, Text Files, CSV/Excel.
- Each option uses `file_picker` to select files.
- Progress view with circular indicator, percentage, and status messages during import.
- Info card explaining CHRONICLE temporal intelligence will be built from imported data.

**UniversalImporterService** (`services/universal_importer_service.dart`):
- Format-specific importers for each source: LUMARA/ARCX JSON, Day One JSON, Journey JSON, plain text/Markdown (auto-split by date patterns), CSV (column auto-detection).
- Deduplication against existing entries (timestamp + content hash).
- Progress callbacks throughout the pipeline.
- Robust error handling per-entry (bad entries skipped, not blocking).

#### Files added
- `lib/arc/unified_feed/widgets/import_options_sheet.dart`
- `lib/arc/unified_feed/services/universal_importer_service.dart`

#### Files modified
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart` — Redesigned `_buildEmptyState` with settings gear, phase quiz, import link; added `_buildPhaseQuizButton`, `_showImportOptions`

---

## [3.3.17] - February 8, 2026

### Unified Feed — Phase 1 (NEW, feature-flagged)

- **Feature flag:** `USE_UNIFIED_FEED` in `lib/core/feature_flags.dart` (default: `false`). When enabled, replaces the 3-tab layout (LUMARA / Phase / Conversations) with a 2-tab layout (LUMARA / Phase) where the LUMARA tab is a unified scrollable feed merging chat and journal entries.
- **FeedEntry model** (`lib/arc/unified_feed/models/feed_entry.dart`): View-layer model aggregating journal entries, chat sessions, and voice memos into a single `FeedEntry` with 4 types (`activeConversation`, `savedConversation`, `voiceMemo`, `writtenEntry`).
- **EntryState** (`lib/arc/unified_feed/models/entry_state.dart`): State tracking (draft, saving, saved, error).
- **FeedRepository** (`lib/arc/unified_feed/repositories/feed_repository.dart`): Aggregates data from JournalRepository, ChatRepo, and VoiceNoteRepository into a unified feed stream.
- **ConversationManager** (`lib/arc/unified_feed/services/conversation_manager.dart`): Active conversation lifecycle — message tracking, auto-save after inactivity (5 min default, configurable), conversation→journal entry persistence with LUMARA inline blocks.
- **AutoSaveService** (`lib/arc/unified_feed/services/auto_save_service.dart`): App lifecycle-aware auto-save triggers (saves on background/pause).
- **ContextualGreetingService** (`lib/arc/unified_feed/services/contextual_greeting.dart`): Time-of-day and recency-based greeting generation for the feed header.
- **FeedHelpers** (`lib/arc/unified_feed/utils/feed_helpers.dart`): Date grouping and sorting utilities.
- **UnifiedFeedScreen** (`lib/arc/unified_feed/widgets/unified_feed_screen.dart`): Main feed screen — LUMARA sigil header with contextual greeting, date-grouped entry cards, pull-to-refresh, empty state with Chat/Write/Voice actions.
- **FeedInputBar** (`lib/arc/unified_feed/widgets/input_bar.dart`): Bottom input bar with text field, voice, attachment, and new entry buttons.
- **Feed entry cards** (`lib/arc/unified_feed/widgets/feed_entry_cards/`): 4 card widgets — `ActiveConversationCard`, `SavedConversationCard`, `VoiceMemoCard`, `WrittenEntryCard`.
- **CustomTabBar** (`lib/shared/tab_bar.dart`): Refactored from hardcoded 3 tabs to dynamic loop over `tabs` list; removed unused `LumaraIcon` import.
- **HomeView** (`lib/shared/ui/home/home_view.dart`): Conditional tab layout — 2 tabs + UnifiedFeedScreen in unified mode, 3 tabs in legacy mode.

#### Files added
- `lib/arc/unified_feed/models/feed_entry.dart`
- `lib/arc/unified_feed/models/entry_state.dart`
- `lib/arc/unified_feed/repositories/feed_repository.dart`
- `lib/arc/unified_feed/services/conversation_manager.dart`
- `lib/arc/unified_feed/services/auto_save_service.dart`
- `lib/arc/unified_feed/services/contextual_greeting.dart`
- `lib/arc/unified_feed/utils/feed_helpers.dart`
- `lib/arc/unified_feed/widgets/unified_feed_screen.dart`
- `lib/arc/unified_feed/widgets/input_bar.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart`
- `lib/arc/unified_feed/widgets/feed_entry_cards/written_entry_card.dart`

#### Files modified
- `lib/core/feature_flags.dart` — Added `USE_UNIFIED_FEED` flag
- `lib/shared/tab_bar.dart` — Dynamic tab generation
- `lib/shared/ui/home/home_view.dart` — Conditional unified/legacy routing

### Google Drive Export Progress UI

- **GoogleDriveSettingsView** (`lib/shared/ui/settings/google_drive_settings_view.dart`): Added visual progress bar with percentage during export/upload to Google Drive. Granular stage-by-stage progress messages (initializing, loading entries, creating ZIP, connecting to Drive, uploading, complete). `LinearProgressIndicator` with accent color, `CircularProgressIndicator` spinner, and percentage text. Brief 100% pause before clearing. New `_setExportProgress()` helper and `_exportPercentage` tracking (0.0–1.0).

---

## [3.3.16] - February 8, 2026

### Reflection Session Safety System (NEW)

- **ReflectionSession model** (`lib/models/reflection_session.dart`): Hive model (typeId 125/126) tracking reflection exchanges per journal entry with pause capability.
- **ReflectionSessionRepository** (`lib/repositories/reflection_session_repository.dart`): Hive-backed CRUD for active, paused, and recent sessions.
- **ReflectionPatternAnalyzer** (`lib/arc/chat/reflection/reflection_pattern_analyzer.dart`): Detects rumination (same themes repeated across 3+ queries without CHRONICLE usage).
- **ReflectionEmotionalAnalyzer** (`lib/arc/chat/reflection/reflection_emotional_analyzer.dart`): Measures validation-seeking ratio; detects avoidance patterns via emotional density.
- **AuroraReflectionService** (`lib/aurora/reflection/aurora_reflection_service.dart`): Risk assessment with 4 signals (prolonged session, rumination, emotional dependence, avoidance); tiered interventions (notice, redirect, pause).
- **ReflectionHandler** (`lib/arc/chat/services/reflection_handler.dart`): Orchestrates reflection flow — creates/retrieves sessions, appends exchanges, runs safety checks, issues interventions.

### RevenueCat In-App Purchases (NEW)

- **RevenueCatService** (`lib/services/revenuecat_service.dart`): In-app purchase management via RevenueCat SDK. Configures at app startup with Firebase UID sync. Login/logout with auth flow. Checks `ARC Pro` entitlement for premium access. Paywall presentation via RevenueCat UI.
- **SubscriptionService** (`lib/services/subscription_service.dart`): Updated to check both Stripe (web) and RevenueCat (in-app) for premium status.
- **Bootstrap** (`lib/main/bootstrap.dart`): RevenueCat configured during app initialization.

### Voice Sigil State Machine

- **VoiceSigil** (`lib/arc/chat/voice/ui/voice_sigil.dart`): Upgraded from simple glowing indicator to 6-state animation system (Idle, Listening, Commitment, Accelerating, Thinking, Speaking) with particle effects, shimmer, and constellation points. LUMARA sigil image as center element.
- **Deleted**: `lib/arc/chat/voice/voice_journal/new_voice_journal_service.dart`, `new_voice_journal_ui.dart` (legacy voice journal files removed).

### PDF Preview

- **PdfPreviewScreen** (`lib/ui/journal/widgets/pdf_preview_screen.dart`): Full-screen in-app PDF viewer with pinch-to-zoom, "Open in app" system action, and file existence validation.

### Google Drive Folder Picker

- **DriveFolderPickerScreen** (`lib/shared/ui/settings/drive_folder_picker_screen.dart`): Browse Google Drive folder hierarchy for import (multi-folder) and sync (single-folder) selection.

### ARCX Clean Service

- **ARCXCleanService** (`lib/mira/store/arcx/services/arcx_clean_service.dart`): Removes chat sessions with fewer than 3 LUMARA responses from device-key-encrypted ARCX archives.
- **clean_arcx_chats.py** (`scripts/clean_arcx_chats.py`): Companion Python script for batch ARCX cleaning.

### Data & Infrastructure

- **DurationAdapter** (`lib/data/hive/duration_adapter.dart`): Hive TypeAdapter for `Duration` (typeId 105) — required for video entries with duration fields.
- **CHRONICLE synthesis**: PatternDetector, MonthlySynthesizer, YearlySynthesizer, MultiYearSynthesizer modified for improved theme extraction and non-theme word filtering.
- **LumaraReflectionOptions** (`lib/arc/chat/models/lumara_reflection_options.dart`): Updated with conversation modes and tone configuration.

#### Files added
- `lib/models/reflection_session.dart`, `lib/models/reflection_session.g.dart`
- `lib/repositories/reflection_session_repository.dart`
- `lib/arc/chat/reflection/reflection_emotional_analyzer.dart`
- `lib/arc/chat/reflection/reflection_pattern_analyzer.dart`
- `lib/arc/chat/services/reflection_handler.dart`
- `lib/aurora/reflection/aurora_reflection_service.dart`
- `lib/data/hive/duration_adapter.dart`
- `lib/services/revenuecat_service.dart`
- `lib/shared/ui/settings/drive_folder_picker_screen.dart`
- `lib/ui/journal/widgets/pdf_preview_screen.dart`
- `lib/mira/store/arcx/services/arcx_clean_service.dart`
- `scripts/clean_arcx_chats.py`
- `DOCS/ARC_AND_LUMARA_OVERVIEW.md`

#### Files deleted
- `lib/arc/chat/voice/voice_journal/new_voice_journal_service.dart`
- `lib/arc/chat/voice/voice_journal/new_voice_journal_ui.dart`

---

## Documentation update - February 7, 2026

**Docs:** Full documentation review and sync. Updated ARCHITECTURE, CHANGELOG, CONFIGURATION_MANAGEMENT, FEATURES, PROMPT_TRACKER, bug_tracker, backend, git.md with current dates. Backend and inventory now reference RevenueCat (in-app) and PAYMENTS_CLARIFICATION; added NARRATIVE_INTELLIGENCE, PAYMENTS_CLARIFICATION, revenuecat/ to DOCS.

---

## [3.3.15] - February 2, 2026 (merge & backup 2026-02-03)

**2026-02-03:** Branch `test` merged into `main`; backup branch `backup-main-2026-02-03` created from `main`.

### Journal & CHRONICLE robustness

- **JournalRepository:** Per-entry try/catch in `getAllJournalEntries` so one bad or legacy entry does not drop the entire list; skip and log on normalize failure.
- **Layer0Populator:** Backwards compatibility for legacy Hive entries: `_safeContent()` and `_safeKeywords()` handle null content/keywords. `populateFromJournalEntry` returns `bool` (true if saved); `populateFromJournalEntries` returns `(succeeded, failed)` counts.
- **Layer0Repository:** New `getMonthsWithEntries(userId)` — distinct months with Layer 0 data for batch synthesis.
- **ChronicleOnboardingService:** Layer 0 backfill uses populator’s succeeded/failed counts; clearer messages (e.g. "X of Y entries", "Z failed"). Batch synthesis builds months from Layer 0 via `getMonthsWithEntries` (not journal date range); message "No Layer 0 entries for this user. Run Backfill Layer 0 first." when none.

### Phase consistency (timeline / Conversations)

- **Phase tab → UserProfile:** After loading Phase tab, call `_updateUserPhaseFromRegimes()` so UserProfile current phase is in sync; timeline and Conversations phase preview then match Phase tab.
- **Current phase preview:** Prefer `UserPhaseService.getCurrentPhase()` (UserProfile) when set, so Conversations/timeline preview matches Phase tab; fallback to RIVET + regime logic when profile phase empty.
- **Home tab label:** "Conversation" → "Conversations" (plural).

#### Files modified

- `lib/arc/internal/mira/journal_repository.dart` — Per-entry try/catch in getAllJournalEntries; skip bad entries
- `lib/chronicle/services/chronicle_onboarding_service.dart` — Backfill counts; synthesis from Layer 0 months; messages
- `lib/chronicle/storage/layer0_populator.dart` — _safeContent/_safeKeywords; return succeeded/failed
- `lib/chronicle/storage/layer0_repository.dart` — getMonthsWithEntries(userId)
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` — Prefer profile phase for preview
- `lib/shared/ui/home/home_view.dart` — Tab label "Conversations"
- `lib/ui/phase/phase_analysis_view.dart` — _updateUserPhaseFromRegimes() after load

---

## [3.3.14] - February 2, 2026

### Settings & LUMARA

- **LUMARA from chat:** Drawer "Settings" now opens **Settings → LUMARA** (LumaraFolderView) instead of the full LUMARA settings screen; users can tap "API & providers" for full setup.
- **Settings structure:** Top-level **CHRONICLE** folder added (View CHRONICLE Layers, CHRONICLE Management). LUMARA and CHRONICLE folders moved above Health & Readiness. LUMARA folder includes new "API & providers" tile → LumaraSettingsScreen.
- **Web access default:** LUMARA web access default changed from opt-in (false) to automatic (true) — LUMARA may use the web when needed.
- **LUMARA settings screen:** Status card and Web Access card removed (settings simplified).

### Voice notes (Ideas)

- **VoiceNoteRepository:** Static broadcast added so any instance (e.g. saving from Voice Mode) notifies all `watch()` subscribers; Ideas list refreshes when saving from voice without reopening.

### CHRONICLE

- **Layer 0 backfill:** Re-populates entries when existing Layer 0 entry has different `userId` (e.g. `default_user`), not only when missing.
- **MonthlySynthesizer:** Log when no entries for month: "No entries for … (run Backfill Layer 0 if you have journal entries)."

### Google Drive backup & import

- **GoogleDriveService:** `getOrCreateAppFolder()` now searches for existing "ARC Backups" folder to avoid duplicates. New `getOrCreateDatedSubfolder(date)` (yyyy-MM-dd) with in-memory cache so same-day uploads use one folder. New `listAllBackupFiles()` for Import from Drive (dated subfolders + root).
- **GoogleDriveSettingsView:** Security-scoped access retained after folder pick so Upload works without re-picking (iOS/macOS). In-app sandbox detection (no security-scoped request for Documents/Support/Temp). Import backup list expandable; last upload-from-folder time persisted.

### Local backup

- **LocalBackupSettingsView:** iOS/macOS security-scoped access for backup folder when path is outside app sandbox; start/stop around backup and export operations. User message to re-select folder if access is needed. Helper `_isBackupPathInAppSandbox()`.

#### Files modified

- `lib/arc/chat/services/lumara_reflection_settings_service.dart` — Web access default true
- `lib/arc/chat/ui/lumara_assistant_screen.dart` — Settings → LumaraFolderView; label "Settings"
- `lib/arc/chat/ui/lumara_settings_screen.dart` — Remove Status card, Web Access card
- `lib/arc/voice_notes/repositories/voice_note_repository.dart` — Static broadcast for watch() across instances
- `lib/chronicle/services/chronicle_onboarding_service.dart` — Layer 0 re-populate when userId differs
- `lib/chronicle/synthesis/monthly_synthesizer.dart` — Log when no entries for month
- `lib/services/google_drive_service.dart` — Search app folder; dated subfolder + cache; listAllBackupFiles
- `lib/shared/ui/settings/google_drive_settings_view.dart` — Retain security-scoped access; sandbox check; Import list; last upload time
- `lib/shared/ui/settings/local_backup_settings_view.dart` — Security-scoped access for external backup path
- `lib/shared/ui/settings/settings_view.dart` — CHRONICLE folder; LUMARA/CHRONICLE order; LumaraFolderView "API & providers"; ChronicleFolderView

---

## [3.3.13] - January 31, 2026

### Fix: Wispr Flow cache – new API key used after save without restart

#### Overview
Wispr Flow API key was cached in `WisprConfigService`. After saving a new or updated API key in **LUMARA Settings → External Services**, voice mode could still use the previous key until the app was restarted. Fix: call `WisprConfigService.instance.clearCache()` after saving the API key so the next voice session uses the new key.

#### Changes
- **lumara_settings_screen.dart**: In `_saveWisprApiKey()`, after writing the key to SharedPreferences, call `WisprConfigService.instance.clearCache()` so the new key is used on the next voice mode session without restart.
- **WisprConfigService**: Already had `clearCache()` (clears `_cachedApiKey`, `_hasCheckedPrefs`); settings screen now invokes it on save.

#### Related
- Bug Tracker: `DOCS/bugtracker/records/wispr-flow-cache-issue.md`

---

### Fix: Phase Quiz result matches Phase tab; rotating phase on Phase tab

#### Overview
Phase Quiz V2 result (e.g. Breakthrough) was not persisted, so the main app and Phase tab showed Discovery. Phase tab now uses the quiz result when there are no phase regimes (e.g. right after onboarding). The rotating phase shape from the phase reveal is now shown alongside the detailed 3D constellation on the Phase tab.

#### Changes
- **Phase Quiz V2 → UserProfile**: After completing the phase quiz, the selected phase is persisted via `UserPhaseService.forceUpdatePhase()` (capitalized) so the main app and Phase tab show the same phase.
- **UserPhaseService.forceUpdatePhase**: Now updates both `onboardingCurrentSeason` and `currentPhase` on UserProfile for consistency.
- **Phase tab when no regimes**: When there are no phase regimes (e.g. right after onboarding), Phase tab and SimplifiedArcformView3D use `UserPhaseService.getCurrentPhase()` (quiz result) instead of defaulting to Discovery.
- **Rotating phase on Phase tab**: The same rotating phase shape (AnimatedPhaseShape) used on the phase reveal screen is now displayed above the detailed 3D constellation on the Phase tab, with the phase name label alongside.

#### Methodology
- **Quiz**: Self-reported phase from Q1 ("Which best describes where you are right now?").
- **App (Rivet/Sentinel/Prism)**: Inferred phase from journal content via phase regimes. When no regimes exist, the app respects the quiz result until regimes are created.

#### Files Modified
- `lib/shared/ui/onboarding/phase_quiz_v2_screen.dart` — Persist quiz phase via UserPhaseService after conductQuiz
- `lib/services/user_phase_service.dart` — forceUpdatePhase sets both onboardingCurrentSeason and currentPhase
- `lib/ui/phase/phase_analysis_view.dart` — _phaseFromUserProfile when no regimes; rotating AnimatedPhaseShape above 3D view
- `lib/ui/phase/simplified_arcform_view_3d.dart` — When no regimes, use UserPhaseService.getCurrentPhase() instead of Discovery

---

## [3.3.13] - January 31, 2026

### Fix: iOS Folder Verification Permission Error

#### Overview
Fixed critical issue where folder verification in `VerifyBackupScreen` failed on iOS with "Operation not permitted" error when attempting to scan `.arcx` backup files in user-selected folders.

#### Changes
- **iOS Security-Scoped Resource Access**: Added proper handling of security-scoped resources when accessing user-selected folders on iOS
- **`arcx_scan_service.dart`**: Modified `scanArcxFolder()` to start accessing security-scoped resource before listing directory, with proper cleanup in `finally` block
- **`verify_backup_screen.dart`**: Added security-scoped resource access handling in `_scanFolder()` method with user-friendly error messages
- **Error Handling**: Improved error messages when folder access is denied on iOS

#### Technical Details
- On iOS, `FilePicker` returns security-scoped resource paths that require explicit access permissions
- Added calls to `startAccessingSecurityScopedResourceWithFilePath()` before directory operations
- Added proper cleanup with `stopAccessingSecurityScopedResourceWithFilePath()` in `finally` blocks
- Uses existing `accessing_security_scoped_resource` package (v3.4.0)

#### Files Modified
- `lib/mira/store/arcx/services/arcx_scan_service.dart` - Added security-scoped resource handling
- `lib/shared/ui/settings/verify_backup_screen.dart` - Added security-scoped resource handling and improved error messages

#### Related
- Bug Tracker: `DOCS/bugtracker/records/ios-folder-verification-permission-error.md`

---

## [3.3.13] - January 26, 2026

### Import: Global status bar, percentage, and Import Status screen

#### Overview
When an ARCX/MCP import runs in the background, a mini status bar is shown below the app bar on the home screen so users can see progress (including percentage) without staying on the import screen. Users can also go to **Settings → Import Data** to open the **Import Status** screen, which shows current import progress and a list of files with status (pending / in progress / completed / failed). The app remains usable during import.

#### Changes
- **ImportStatusBar** (`lib/shared/widgets/import_status_bar.dart`): Shown below the app bar when an import is active; shows message, progress bar, and **percentage (0%–100%)**; includes “You can keep using the app”; pushes main content down.
- **ImportStatusScreen** (`lib/shared/ui/settings/import_status_screen.dart`): New screen under Settings → Import. When no import is active: “No import in progress” and “Choose files to import”. When import is active: overall message, progress bar, and list of files with status (Pending / In progress / Completed / Failed). When completed or failed: result summary, file list, Done, and “Import more”.
- **ImportProgressCubit** (`lib/mira/store/arcx/import_progress_cubit.dart`): Global import progress (isActive, message, fraction, error, completed); **per-file status** for multi-file imports (`fileItems`, `ImportFileStatus`, `startWithFiles`, `updateFileStatus`); used by the status bar and Import Status screen.
- **HomeView**: Wraps content with ImportStatusBar so the bar appears when import is running.
- **App**: Provides ImportProgressCubit at app level so import services and UI share the same state.
- **Settings → Import Data**: Opens Import Status screen (with “Choose files to import” to start an import); user can view progress and file list while import runs in the background.
- **Multi-ARCX import**: Uses `startWithFiles` and `updateFileStatus` so the Import Status screen shows per-file status.
- **ARCX import services**: Updated to use ImportProgressCubit for progress updates during import.
- **ARCX import progress screen / MCP import screen**: Adjusted to work with global progress where applicable.

#### Files Modified
- `lib/app/app.dart` — Provide ImportProgressCubit
- `lib/shared/ui/home/home_view.dart` — Show ImportStatusBar
- `lib/shared/ui/settings/settings_view.dart` — Import Data tile opens ImportStatusScreen; multi-ARCX uses startWithFiles/updateFileStatus
- `lib/mira/store/arcx/services/arcx_import_service.dart`, `arcx_import_service_unified.dart`, `arcx_import_service_v2.dart` — Use ImportProgressCubit
- `lib/mira/store/arcx/ui/arcx_import_progress_screen.dart` — Use shared progress
- `lib/ui/export_import/mcp_import_screen.dart` — Import flow
- `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements` — iOS project updates

#### New Files
- `lib/mira/store/arcx/import_progress_cubit.dart`
- `lib/shared/widgets/import_status_bar.dart`
- `lib/shared/ui/settings/import_status_screen.dart`

#### Build fix
- **Local backup service** (`lib/services/local_backup_service.dart`): `onProgress` callbacks updated to accept optional fraction parameter `(msg, [fraction])` to match `void Function(String, [double?])?` used by `exportFullBackupChunked` and related export APIs.

---
