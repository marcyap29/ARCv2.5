# Unified Feed: LUMARA + Conversations Merge

**Version:** 2.3 (Phase 2.3)  
**Last Updated:** February 11, 2026  
**Status:** Phase 2.3 complete. Behind feature flag (`USE_UNIFIED_FEED`, default off).  
**Location:** `lib/arc/unified_feed/`

---

## Overview

The Unified Feed replaces the separate **LUMARA** (chat) and **Conversations** (journal timeline) tabs with a single, scrollable feed that shows everything in one place — active conversations, saved conversations, voice memos, and written journal entries.

### Why

The old layout used three tabs:

| Tab | What it showed | Problem |
|-----|---------------|---------|
| LUMARA (0) | Chat with LUMARA | Separate from journal entries |
| Phase (1) | Phase constellation | Fine — stays |
| Conversations (2) | Journal timeline | Disconnected from LUMARA chat |

Users had to mentally separate "talking to LUMARA" from "writing in my journal." In practice, these are the same activity — reflecting on life. The unified feed treats all forms of input (chat, text, voice) as entries in a single chronological feed.

### What changes

| Aspect | Legacy (3-tab) | Unified (2-tab) |
|--------|----------------|-----------------|
| Tab bar | LUMARA / Phase / Conversations | LUMARA / Settings (2 tabs) |
| LUMARA tab | Full-screen chat | Scrollable feed with greeting, phase preview, action buttons, entries |
| Conversations tab | Journal timeline | Removed (entries appear in feed) |
| New journal entry | Tab bar "+" button | Removed — Chat/Reflect/Voice action buttons replace it |
| Phase tab | Phase constellation | Removed from tab bar; accessible via Timeline button in feed |
| Settings | Gear icon in app bar | Dedicated Settings tab (index 1) |
| First-use (empty feed) | N/A | Welcome screen shown alone — bottom nav + input bar hidden |

---

## Feature Flag

```dart
// lib/core/feature_flags.dart
static const bool USE_UNIFIED_FEED = false;
```

When `false` (default): the app uses the legacy 3-tab layout. Nothing changes.  
When `true`: the app switches to the 2-tab unified layout (LUMARA + Settings).

The flag is checked in:
- `home_view.dart` — tab list (LUMARA + Settings), tab names, page routing, `_feedIsEmpty` state to hide bottom nav during welcome screen, `showCenterButton` (hidden in unified mode)
- `tab_bar.dart` — dynamic tab rendering; center "+" button conditionally rendered via `showCenterButton`
- `unified_feed_screen.dart` — `onEmptyStateChanged` callback to report empty state to HomeView

---

## Architecture

### Directory Structure

```
lib/arc/unified_feed/
├── models/
│   ├── feed_entry.dart         # FeedEntry model (5 entry types), FeedMessage
│   └── entry_state.dart        # EntryState lifecycle
├── repositories/
│   └── feed_repository.dart    # Aggregates journal, chat, voice data; pagination; phase colors
├── services/
│   ├── conversation_manager.dart       # Active conversation lifecycle + auto-save
│   ├── auto_save_service.dart          # App lifecycle-aware save triggers
│   ├── contextual_greeting.dart        # Time/recency-based greeting generation (unused in v2.2; kept for reference)
│   └── universal_importer_service.dart # Multi-format journal data import
├── utils/
│   └── feed_helpers.dart       # Date grouping, icons, colors, text utilities
└── widgets/
    ├── unified_feed_screen.dart    # Main feed screen (pagination, date nav, deletion, LUMARA chat)
    ├── expanded_entry_view.dart    # Full-screen entry detail view (media, edit, delete)
    ├── import_options_sheet.dart   # Data import bottom sheet (5 sources)
    ├── feed_media_thumbnails.dart  # Compact media thumbnail strip (photos, video, files)
    ├── input_bar.dart              # Bottom input bar (unused in v2.0; kept for reference)
    ├── feed_entry_cards/
    │   ├── base_feed_card.dart         # Shared card wrapper with phase-colored left border
    │   ├── active_conversation_card.dart
    │   ├── saved_conversation_card.dart
    │   ├── reflection_card.dart        # Text-based reflections (replaces written_entry_card)
    │   ├── lumara_prompt_card.dart      # LUMARA-initiated observations/prompts
    │   └── voice_memo_card.dart
    └── timeline/
        ├── timeline_modal.dart     # Bottom sheet for date navigation
        └── timeline_view.dart      # Calendar/timeline view

Supporting files (outside unified_feed/):
lib/core/constants/phase_colors.dart    # Phase color constants
lib/core/models/entry_mode.dart         # EntryMode enum (chat, reflect, voice)
```

### Data Flow

```
┌─────────────────┐    ┌──────────────┐    ┌────────────────────┐
│ JournalRepository│    │  ChatRepoImpl │    │ VoiceNoteRepository│
│  (Hive entries) │    │ (chat sessions)│    │   (voice notes)    │
└────────┬────────┘    └──────┬───────┘    └─────────┬──────────┘
         │                    │                      │
         └──────────┬─────────┘──────────────────────┘
                    │
            ┌───────▼────────┐
            │ FeedRepository  │   read-through aggregation layer
            │  (unified view) │   does NOT own persistence
            └───────┬────────┘
                    │
            feedStream (broadcast)
                    │
       ┌────────────▼──────────────┐
       │    UnifiedFeedScreen       │
       │  ┌──────────────────────┐ │
       │  │  Greeting Header     │ │
       │  ├──────────────────────┤ │
       │  │  Header Actions      │ │
       │  │  (Select/Timeline/⚙) │ │
       │  ├──────────────────────┤ │
       │  │  Phase Arcform       │ │
       │  ├──────────────────────┤ │
       │  │  Chat|Reflect|Voice  │ │
       │  ├──────────────────────┤ │
       │  │  Date-grouped cards  │ │
       │  │   • Active convo     │ │
       │  │   • Saved convo      │ │
       │  │   • Voice memo       │ │
       │  │   • Reflection       │ │
       │  │   (swipe/select/del) │ │
       │  └──────────────────────┘ │
       └───────────────────────────┘
```

### Key Design Decisions

1. **FeedRepository is read-through with pagination.** It queries existing repositories (JournalRepository, ChatRepoImpl) and merges results. Supports `getFeed(before, after, limit, types)` for pagination and filtering. All writes go through the original repositories. Journal and chat repos initialize independently so one failing doesn't block the feed.

2. **FeedEntry is a view model.** It does not inherit from JournalEntry or ChatSession. It's a lightweight, presentation-layer object that wraps data from any source into a consistent shape. Phase colors and themes are extracted at the repository level.

3. **ConversationManager handles lifecycle, not the screen.** The screen just calls `addUserMessage(text)` and the manager handles everything: creating the conversation, tracking messages, resetting inactivity timers, and persisting to journal storage when auto-save fires.

4. **Auto-save is multi-trigger.** Conversations save automatically when:
   - 5 minutes pass with no new messages (inactivity timeout, configurable)
   - The app goes to background/pauses
   - The user explicitly taps "Save"

5. **Phase colors thread through everything.** `PhaseColors.getPhaseColor()` maps phase labels to colors. The color flows from repository → FeedEntry → BaseFeedCard left border, giving every entry a visual phase indicator.

---

## Models

### FeedEntry

The core view model. Represents any item in the feed.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique ID (prefixed: `journal_`, `chat_`, `active_`) |
| `type` | `FeedEntryType` | One of 5 types (see below) |
| `timestamp` | `DateTime` | Primary timestamp (creation or last activity) |
| `state` | `EntryState` | Lifecycle state (active, saving, saved, error) |
| `title` | `String?` | Display title (optional) |
| `content` | `dynamic` | Content body (string or structured data) |
| `themes` | `List<String>` | Theme tags from LUMARA analysis |
| `exchangeCount` | `int?` | Number of user-assistant exchanges (conversations) |
| `duration` | `Duration?` | Voice memo or conversation duration |
| `phase` | `String?` | Life phase label (e.g., "Expansion") |
| `phaseColor` | `Color?` | Phase accent color for card left border |
| `messages` | `List<FeedMessage>?` | Conversation messages (for conversation types) |
| `isActive` | `bool` | Whether this is an ongoing conversation |
| `audioPath` | `String?` | Path to audio file (voice memos) |
| `transcriptPath` | `String?` | Path to transcript file |
| `chatSessionId` | `String?` | Source chat session ID |
| `journalEntryId` | `String?` | Source journal entry ID |
| `voiceNoteId` | `String?` | Source voice note ID |
| `mood` | `String?` | Emotion label |
| `isPinned` | `bool` | Pinned/favorited |
| `hasLumaraReflections` | `bool` | Has LUMARA inline blocks |
| `hasMedia` | `bool` | Has media attachments |
| `mediaCount` | `int` | Number of media attachments |
| `mediaItems` | `List<MediaItem>` | Media items (photos, videos, files) for display |
| `tags` | `List<String>` | Tags from original entry |
| `metadata` | `Map<String, dynamic>` | Additional metadata |

`preview` is a computed getter (first 200 chars of content or first message).

### FeedEntryType

| Type | Source | Visual | Description |
|------|--------|--------|-------------|
| `activeConversation` | ConversationManager | Phase-colored left border, pulsing | Ongoing chat, not yet saved |
| `savedConversation` | JournalRepository (has LUMARA blocks) or ChatRepo | Phase-colored left border | Chat saved as journal entry |
| `voiceMemo` | JournalRepository (has audioUri) | Phase-colored left border | Voice recording |
| `reflection` | JournalRepository (text only) | Phase-colored left border | Text-based journal reflection (was `writtenEntry`) |
| `lumaraInitiative` | LUMARA/CHRONICLE/SENTINEL | Phase-colored left border, LUMARA sigil | LUMARA-initiated observation, check-in, or prompt |

### EntryState

Tracks the lifecycle of a feed entry (simplified enum-based):

| State | Meaning |
|-------|---------|
| `active` | Ongoing conversation or draft |
| `saving` | Currently being persisted |
| `saved` | Successfully persisted to storage |
| `error` | Save failed |

---

## Services

### ConversationManager

Manages the lifecycle of the active conversation.

**Responsibilities:**
- Start / discard conversations
- Track user and assistant messages
- Auto-generate titles from first user message
- Reset inactivity timer on each message
- Persist conversation as journal entry (with LUMARA inline blocks) on save
- Emit state changes via `stateStream`

**Auto-save config (defaults):**
- Inactivity threshold: 5 minutes
- Minimum messages before eligible: 2
- Enabled: true

**Save process:**
1. Compose journal entry body from user messages
2. Build `InlineBlock` list from assistant messages
3. Create `JournalEntry` with `source: 'unified_feed'` metadata
4. Save via `JournalRepository`
5. Clear active conversation from FeedRepository
6. Refresh feed

### AutoSaveService

Thin wrapper that hooks into app lifecycle:

| App State | Action |
|-----------|--------|
| `paused` / `inactive` | Save if active conversation has 2+ messages |
| `resumed` | Resume auto-save |
| `detached` / `hidden` | Emergency save |

### ContextualGreetingService (deprecated in v2.2)

**Note:** As of v2.2, the `ContextualGreetingService` is no longer used by the feed. The greeting header now shows a static message: "Share what's on your mind." with a description of LUMARA's compounding intelligence. The service file is kept for reference but is not imported or instantiated.

Previously generated the greeting header based on time of day, recency, entry count, day of week, and phase

---

## Widgets

### UnifiedFeedScreen

The main screen. Replaces both `LumaraAssistantScreen` (chat) and `UnifiedJournalView` (timeline).

**Layout — populated feed (top to bottom):**
1. **Greeting header** — LUMARA sigil + static message ("Share what's on your mind.") + intelligence-compounds description
2. **Header actions** — Select (batch delete/export), Timeline (calendar), Settings gear
3. **Selection mode bar** — Cancel / Export (N) / Delete (N) — visible only when in selection mode
4. **Phase Arcform preview** — `CurrentPhaseArcformPreview` widget; tap opens `PhaseAnalysisView`; refreshes on return
5. **Phase Journey Gantt** — `_PhaseJourneyGanttCard`: Gantt-style bar showing phase regimes over time (days, phases, date range). Uses `PhaseTimelinePainter`. Tappable: navigates directly to editable timeline (`PhaseAnalysisView(initialView: 'timeline')`); edit-phases icon button. Auto-refreshes on phase/regime change (listens to `regimeChangeNotifier` / `phaseChangeNotifier`). Reloads regimes on return.
6. **Communication actions** — Chat / Reflect / Voice buttons (above "Today" section)
7. **LUMARA observation banner** — If LUMARA has a proactive observation
8. **Date-grouped entry cards** — Today, Yesterday, This Week, This Month, etc. with date dividers

**Entry Management:**
- **Swipe-to-delete**: Swipe any card left to delete (with confirmation dialog). Uses `Dismissible` + `JournalRepository.deleteJournalEntry()`.
- **Batch selection**: Tap "Select entries" (checklist icon) → multi-select mode with checkbox overlays → "Export (N)" and "Delete (N)" buttons.
- **Selective export**: Export selected entries as ARCX (encrypted) or ZIP (portable) via `ARCXExportServiceV2` / `McpPackExportService`. Progress dialog shown; result shared via `Share.shareXFiles`.
- **ExpandedEntryView actions**: Edit opens `JournalScreen` in edit mode. Delete permanently removes entry with confirmation dialog and `onEntryDeleted` callback to refresh feed.

**LUMARA Chat:**
- "Chat" button opens `LumaraAssistantScreen` directly. If the feed has entries, the most recent entry with content is sent as `initialMessage` ("Please reflect on this entry...") so LUMARA can immediately engage.
- `LumaraAssistantScreen` auto-sends `initialMessage` on first frame via `addPostFrameCallback`.

**Scroll Navigation (v2.3):**
- Direction-aware scroll-to-top/bottom pill buttons appear when scrolling the feed
- Scrolling down (not near bottom) → "Jump to bottom" centered pill button with arrow icon
- Scrolling up (not near top) → "Jump to top" centered pill button with arrow icon
- Threshold-based: 150px from edges, 400px min scroll extent
- Animated 200ms opacity; 400ms smooth scroll on tap with easeOut curve
- Pill design: `kcSurfaceColor` background, `kcPrimaryColor` accent, shadow, rounded corners

**Interactions:**
- Pull-to-refresh to reload feed (fires `PhaseRegimeService.regimeChangeNotifier` and `UserPhaseService.phaseChangeNotifier` so phase preview and Gantt refresh)
- Infinite scroll: loads 20 entries at a time, loads more when near bottom
- Tap entry card → opens **ExpandedEntryView** (full-screen detail with phase, themes, media, CHRONICLE context)
- Tap "Save" on active conversation card → persist as journal entry
- Timeline button → opens **TimelineModal** for date-based navigation; jump to any date
- **Welcome screen (empty state):**
  - Settings gear (top-right) — direct access to SettingsView
  - LUMARA logo + title + subtitle
  - "Discover Your Phase" gradient button — launches PhaseQuizV2Screen
  - "Import your data" link at bottom — opens ImportOptionsSheet (5 import sources)
  - Bottom nav hidden during empty state for clean first-use experience
- `initialMode` parameter: activates chat (open LUMARA), reflect (open journal), or voice (launch voice mode) on first frame
- `onEmptyStateChanged` callback: reports empty/non-empty state to HomeView for nav visibility
- `GestureDetector` wrapper dismisses keyboard on outside tap

**Phase Hashtag Stripping:**
- `FeedHelpers.contentWithoutPhaseHashtags()` strips `#discovery`, `#expansion`, `#transition`, `#consolidation`, `#recovery`, `#breakthrough` from display content. Phase shows only in card metadata/header.

**Paragraph Rendering (improved v2.3):**
- `ExpandedEntryView._buildParagraphWidgets()` — splits text on `\n\n` (paragraph break); preserves `\n` within paragraphs as line breaks; 14px bottom spacing, 1.6 line height. `---` lines become visual `Divider` widgets. Markdown headers (`#`) skipped in display. Replaces single `Text()` blocks.
- Summary section only shown when meaningfully different from body (60% overlap detection prevents redundant display).
- `EntryContentRenderer._buildParagraphs()` — same paragraph logic in the timeline view.

**Summary Extraction:**
- `FeedHelpers.extractSummary()` / `bodyWithoutSummary()` — parses `## Summary\n\n...\n\n---\n\n<body>` header. Written entries display summary (italic, labelled) and body separately.
- `FeedEntry.preview` (v2.3) — strips `## Summary...---` prefix before computing preview text, so card previews show actual body content instead of summary header.

**Card Date Formatting:**
- `FeedHelpers.formatEntryCreationDate()` — "Today, 14:30", "Yesterday, 09:15", "Mar 15, 14:30", "Mar 15, 2025".
- All 5 feed cards use this format (12px, 0.8 opacity). `ReflectionCard` and `SavedConversationCard` show date at leading position in metadata row.
- Feed entries sort by `createdAt` (original creation date) instead of `updatedAt` (v2.3).

### FeedMediaThumbnails

Compact horizontal thumbnail strip for feed cards and expanded entry view.

| Component | Description |
|-----------|-------------|
| `FeedMediaThumbnails` | Horizontal `ListView` of thumbnails (configurable size and max count) |
| `FeedMediaThumbnailTile` | Single tile resolving `ph://`, `file://`, MCP, and raw path URIs via `MediaResolverService` / `PhotoLibraryService`. Tap opens `FullImageViewer` for images. |

### Entry Cards

All cards extend **BaseFeedCard**, which provides a consistent wrapper with a phase-colored left border indicator and tap/long-press handling.

| Card | Left Border | Extra UI |
|------|-------------|----------|
| ActiveConversationCard | Phase color, pulsing | "Active" badge, exchange count, "Save" button |
| SavedConversationCard | Phase color | Exchange count, "LUMARA" tag if has reflections |
| ReflectionCard | Phase color | Content preview (phase hashtags stripped), mood, media thumbnails, themes on expand |
| LumaraPromptCard | Phase color + LUMARA sigil | Observation text, respond/dismiss actions |
| VoiceMemoCard | Phase color | Duration display, play icon, transcript snippet |

---

## Phases

### Phase 1 (v3.3.17) — Core models and feed display

- FeedEntry model and EntryState
- FeedRepository aggregation
- ConversationManager with auto-save
- UnifiedFeedScreen with greeting, cards, input bar
- Feature flag and home view routing
- Dynamic tab bar

### Phase 1.5 (v3.3.18) — Model refactor, pagination, expanded views, timeline

- FeedEntry refactored: `reflection` + `lumaraInitiative` types, `FeedMessage`, phase colors, themes, computed preview
- EntryState simplified
- FeedRepository pagination (`getFeed`), robust error handling, phase color extraction
- ExpandedEntryView for full-screen entry detail
- BaseFeedCard with phase-colored left border
- ReflectionCard and LumaraPromptCard
- TimelineModal / TimelineView for date navigation
- Infinite scroll and date filtering
- EntryMode (chat/reflect/voice) from welcome screen
- PhaseColors constants
- Single-tab home layout (Phase moved inside feed)
- Welcome screen: settings gear, Phase Quiz CTA, data import flow (5 sources)
- UniversalImporterService for multi-format journal import with deduplication

### Phase 2.0 (v3.3.19) — Entry management, media, LUMARA chat, phase priority

- **Entry deletion**: Swipe-to-delete (`Dismissible`) and batch selection mode (multi-select + bulk delete)
- **Media support**: `FeedEntry.mediaItems`, `FeedMediaThumbnails` widget, media grid in ExpandedEntryView with URI resolution (`ph://`, `file://`, MCP)
- **LUMARA chat integration**: Chat button opens `LumaraAssistantScreen` directly with `initialMessage` from most recent entry
- **Input bar removed**: `FeedInputBar` removed from feed; Chat/Reflect/Voice action buttons serve as quick-start actions in both empty and populated states
- **Phase Arcform preview**: `CurrentPhaseArcformPreview` embedded in feed, tap opens `PhaseAnalysisView`
- **Phase hashtag stripping**: `FeedHelpers.contentWithoutPhaseHashtags()` strips phase tags from display content everywhere
- **ExpandedEntryView enhanced**: Media section, working edit (opens `JournalScreen`), working delete with `onEntryDeleted` callback
- **Phase priority fix**: `UserPhaseService.getDisplayPhase()` reordered — user's explicit phase (quiz/manual) takes priority over RIVET/regime
- **Auto phase analysis**: `runAutoPhaseAnalysis()` headless function auto-creates phase regimes after ARCX import
- **Phase Analysis refactored**: Removed pending approval flow; analysis auto-applies; new `PhaseAnalysisSettingsView` in Settings
- **Header actions rearranged**: Select (batch), Timeline, Settings (Voice memo icon removed)
- **CHRONICLE progress UI**: Rich progress view in `ChronicleManagementView` with percentage, stage label, linear bar
- **LumaraAssistantScreen**: `initialMessage` param, back arrow navigation, removed drawer and "New Chat" menu item
- **JournalScreen cleanup**: Removed prompt notice dialog, phase-preserving profile creation

### Phase 2.1 (v3.3.20) — Export, Gantt, paragraph rendering, Sentinel integration

- **Selective export**: Export selected entries as ARCX or ZIP from feed selection bar
- **Phase Journey Gantt**: `_PhaseJourneyGanttCard` widget showing phase regimes over time (Gantt-style bar)
- **Phase preview refresh**: `_phasePreviewRefreshKey` forces Arcform preview and Gantt rebuild on return from Phase view
- **Paragraph rendering**: `_buildParagraphWidgets()` in ExpandedEntryView; `_buildParagraphs()` in EntryContentRenderer
- **Summary extraction**: `FeedHelpers.extractSummary()` / `bodyWithoutSummary()` for `## Summary` headers
- **Card date formatting**: `FeedHelpers.formatEntryCreationDate()` — all cards show "Today, 14:30" style dates
- **Phase Sentinel integration**: `resolvePhaseWithSentinel()` checks Sentinel before applying RIVET/ATLAS proposals; overrides to Recovery on alert
- **RIVET reset on user phase change**: `PhaseRegimeService.changeCurrentPhase()` and `UserPhaseService.forceUpdatePhase()` reset RIVET
- **ARC → LUMARA branding**: All asset references updated to `LUMARA_Sigil.png`; backup filenames use `LUMARA_*` prefix

### Phase 2.3 (v3.3.23, current) — Scroll navigation, content display, streaming, Gantt auto-refresh, phase display fix

- **Scroll-to-top/bottom navigation**: Direction-aware pill buttons (centered bottom) for quick scroll. Threshold-based, animated.
- **Feed content improvements**: `FeedEntry.preview` strips summary header. Entries sort by `createdAt`. `contentWithoutPhaseHashtags` preserves newlines. Paragraph rendering: `---` as dividers, skip `#` headers, preserve single newlines, 1.6 line height, summary overlap detection.
- **ReflectionCard preview**: Collapses newlines to spaces for compact card display.
- **Gantt card auto-refresh**: Listens to `regimeChangeNotifier` / `phaseChangeNotifier`; auto-reloads on change.
- **Gantt direct navigation**: Taps navigate to `PhaseAnalysisView(initialView: 'timeline')` — editable timeline, not overview.
- **Phase display fix**: `getDisplayPhase()` shows regime phase even when RIVET gate is closed — trusts imported/detected regimes.
- **Phase change bottom sheet**: Redesigned from AlertDialog to modal bottom sheet with colored list and current-phase chip.
- **Pull-to-refresh fires notifiers**: Phase preview and Gantt refresh after pull-to-refresh.
- **Startup notifiers**: `HomeView` fires notifiers on app startup; `App` fires after import.
- **Streaming LUMARA responses**: `onStreamChunk` callback updates inline blocks in real-time.
- **DevSecOps audit verified**: Auth, secrets, storage, network, logging findings documented.

### Phase 2.2 (v3.3.21) — Phase locking, regime notifications, bulk apply, onboarding streamline

- **Phase locking**: `isPhaseLocked: true` after inference prevents re-inference on reload/import. Import services default lock when phase data exists.
- **Regime change notifications**: `PhaseRegimeService.regimeChangeNotifier` and `UserPhaseService.phaseChangeNotifier` (`ValueNotifier<DateTime>`). Phase preview listens and auto-reloads.
- **Extend-not-rebuild**: Timeline and import services use `extendRegimesWithNewEntries` instead of `rebuildRegimesFromEntries`, preserving existing regimes.
- **Gantt card interactive**: Tappable card navigates to `PhaseAnalysisView`; edit-phases icon button; reloads on return.
- **Greeting simplified**: `ContextualGreetingService` removed from feed; static "Share what's on your mind." message with intelligence-compounds description.
- **Onboarding streamlined**: Removed `_ArcIntroScreen` and `_SentinelIntroScreen` (6 → 4 screens). Text condensed and third-person language in phase explanation.
- **Bulk phase apply (Phase Timeline)**: "Apply phase by date range" and per-regime "Apply this phase to all entries in this period" — sets `userPhaseOverride` and `isPhaseLocked` on matching entries.
- **Asset optimization**: `LUMARA_Sigil.png` 256KB → 42KB.
- **Selective branding reverts**: "ARC" restored for internal analysis labels and monthly review notification.

### Phase 3 (planned) — LLM-powered conversation and advanced features

- Input bar or chat submission triggers LUMARA LLM call via `EnhancedLumaraAPI`
- Assistant responses stream into the active conversation card
- Voice recording from feed
- Attachment support (photos, documents)
- Search and filter within the feed
- Pinning and archiving entries
- Inline LUMARA reflection requests on any entry
- Feed-level analytics (writing streaks, patterns)

---

## Files Modified (outside `unified_feed/`)

| File | Change |
|------|--------|
| `lib/core/feature_flags.dart` | Added `USE_UNIFIED_FEED` flag |
| `lib/core/constants/phase_colors.dart` | Phase color constants for card borders |
| `lib/core/models/entry_mode.dart` | EntryMode enum (chat, reflect, voice) |
| `lib/shared/tab_bar.dart` | Dynamic tab loop; center "+" button conditionally rendered via `showCenterButton` |
| `lib/shared/ui/home/home_view.dart` | 2-tab layout; `_feedIsEmpty` hides nav; auto phase analysis after import |
| `lib/app/app.dart` | `onGenerateRoute` to pass EntryMode to HomeView |
| `lib/arc/chat/ui/lumara_assistant_screen.dart` | `initialMessage` param; removed drawer; back arrow nav |
| `lib/services/rivet_sweep_service.dart` | `approvableProposals` getter; `runAutoPhaseAnalysis()` |
| `lib/services/user_phase_service.dart` | Phase priority reordered (profile first) |
| `lib/shared/ui/settings/settings_view.dart` | Phase Analysis menu item |
| `lib/shared/ui/settings/phase_analysis_settings_view.dart` | New: Phase Analysis settings screen |
| `lib/shared/ui/settings/combined_analysis_view.dart` | Removed Phase Analysis tab |
| `lib/shared/ui/settings/chronicle_management_view.dart` | Rich progress UI |
| `lib/ui/journal/journal_screen.dart` | Removed prompt notice; phase-preserving profile creation |
| `lib/ui/phase/phase_analysis_view.dart` | Auto-apply analysis; removed approval flow |
| `lib/ui/phase/phase_timeline_view.dart` | `forceUpdatePhase` on phase change |
| `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` | `onTapOverride`; profile-first phase resolution; listens to `phaseChangeNotifier`/`regimeChangeNotifier` for auto-reload |
| `lib/arc/ui/timeline/widgets/entry_content_renderer.dart` | Paragraph rendering |
| `lib/arc/ui/timeline/timeline_cubit.dart` | `extendRegimesWithNewEntries` replaces `rebuildRegimesFromEntries` |
| `lib/arc/core/journal_capture_cubit.dart` | Phase backfill respects `isPhaseLocked`; locks after inference |
| `lib/services/phase_sentinel_integration.dart` | New: Sentinel safety override for phase proposals |
| `lib/services/phase_regime_service.dart` | `regimeChangeNotifier`; `getEntriesForRegime`; `getEntriesInDateRange` |
| `lib/services/user_phase_service.dart` | `phaseChangeNotifier`; fires on `forceUpdatePhase` |
| `lib/mira/store/arcx/services/arcx_export_service_v2.dart` | ARC → LUMARA backup naming; backward-compat regex |
| `lib/mira/store/arcx/services/arcx_import_service.dart` | `extendRegimesWithNewEntries`; extend-not-rebuild |
| `lib/mira/store/arcx/services/arcx_import_service_v2.dart` | Smart `isPhaseLocked` default; lock after inference |
| `lib/mira/store/mcp/import/mcp_pack_import_service.dart` | `extendRegimesWithNewEntries`; smart `isPhaseLocked`; lock after inference |
| `lib/ui/export_import/mcp_import_screen.dart` | Fires notifiers after import for phase preview refresh |
| `lib/ui/phase/phase_timeline_view.dart` | Bulk phase apply: by date range + per-regime |
| `lib/shared/ui/onboarding/arc_onboarding_sequence.dart` | Removed `_ArcIntroScreen`, `_SentinelIntroScreen`; condensed text |
| `lib/shared/ui/onboarding/arc_onboarding_cubit.dart` | Flow skips removed screens |
| `lib/shared/ui/onboarding/widgets/phase_explanation_screen.dart` | Third-person language |
| `lib/chronicle/models/query_plan.dart` | `ResponseSpeed` enum; `speedTarget` field |
| `lib/chronicle/query/query_router.dart` | Mode-aware routing; `_selectLayersForMode`, `_inferReflectLayer` |
| `lib/chronicle/query/context_builder.dart` | Speed-tiered building; cache; `_buildSingleLayerContext`, `_compressForSpeed` |
| `lib/chronicle/query/chronicle_context_cache.dart` | NEW: Singleton in-memory TTL cache for CHRONICLE contexts |
| `lib/arc/chat/services/enhanced_lumara_api.dart` | Mode/voice to router; cache; streaming `onStreamChunk`; voice mini-context fallback |
| `lib/arc/chat/services/reflection_handler.dart` | Passes `onStreamChunk` to API |
| `lib/arc/internal/mira/journal_repository.dart` | Cache invalidation on save |
| `lib/ui/journal/journal_screen.dart` | Streaming UI for LUMARA inline blocks |
| `lib/app/app.dart` | Fires notifiers after ARCX import |
| `lib/shared/ui/home/home_view.dart` | Fires notifiers on startup |
| `lib/ui/phase/simplified_arcform_view_3d.dart` | Fires notifiers after phase change |

---

## Related Documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — ARC Module → `unified_feed/` submodule
- [FEATURES.md](FEATURES.md) — "Unified Feed (v3.3.23, feature-flagged)" section
- [CHANGELOG.md](CHANGELOG.md) — [3.3.23] entry
- [UI_UX.md](UI_UX.md) — UI patterns and components
