# Unified Feed: LUMARA + Conversations Merge

**Version:** 1.5 (Phase 1.5)  
**Last Updated:** February 9, 2026  
**Status:** Phase 1.5 complete. Behind feature flag (`USE_UNIFIED_FEED`, default off).  
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
| LUMARA tab | Full-screen chat | Scrollable feed with greeting, entries, input bar |
| Conversations tab | Journal timeline | Removed (entries appear in feed) |
| New journal entry | Tab bar "+" button | Removed — input bar + quick-start actions replace it |
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
- `unified_feed_screen.dart` — `onEmptyStateChanged` callback to report empty state to HomeView; input bar hidden when feed is empty

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
│   ├── contextual_greeting.dart        # Time/recency-based greeting generation
│   └── universal_importer_service.dart # Multi-format journal data import
├── utils/
│   └── feed_helpers.dart       # Date grouping, icons, colors, text utilities
└── widgets/
    ├── unified_feed_screen.dart    # Main feed screen (pagination, date nav, initial mode)
    ├── expanded_entry_view.dart    # Full-screen entry detail view
    ├── import_options_sheet.dart   # Data import bottom sheet (5 sources)
    ├── input_bar.dart              # Bottom input bar
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
       │  │  Date-grouped cards  │ │
       │  │   • Active convo     │ │
       │  │   • Saved convo      │ │
       │  │   • Voice memo       │ │
       │  │   • Written entry    │ │
       │  ├──────────────────────┤ │
       │  │  FeedInputBar        │ │
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

### ContextualGreetingService

Generates the greeting header based on:

| Signal | Example Output |
|--------|---------------|
| Time of day | "Good morning", "Good evening", "Late night" |
| Recency | "Picking up where we left off" (< 30 min), "Welcome back" (< 2 hr) |
| Entry count | "Ready when you are" (0 entries) |
| Day of week | "Happy Friday", "Fresh start to the week" |
| Phase | "Exploring new territory" (Discovery) |

Sub-greeting examples: "You have an active conversation", "3 entries today", "Last entry was yesterday"

---

## Widgets

### UnifiedFeedScreen

The main screen. Replaces both `LumaraAssistantScreen` (chat) and `UnifiedJournalView` (timeline).

**Layout (top to bottom):**
1. **App bar** — Timeline (calendar icon), Voice memo, Settings actions
2. **Greeting header** — LUMARA sigil + contextual greeting + sub-greeting
3. **LUMARA observation banner** — If LUMARA has a proactive observation
4. **Date-grouped entry cards** — Today, Yesterday, This Week, This Month, etc. with date dividers
5. **Input bar** — Fixed at bottom

**Interactions:**
- Pull-to-refresh to reload feed
- Infinite scroll: loads 20 entries at a time, loads more when near bottom
- Tap entry card → opens **ExpandedEntryView** (full-screen detail with phase, themes, CHRONICLE context)
- Tap "Save" on active conversation card → persist as journal entry
- Submit text in input bar → add user message to active conversation
- Tap "+" in input bar → open new journal entry screen
- Timeline button → opens **TimelineModal** for date-based navigation; jump to any date
- **Welcome screen (empty state):**
  - Settings gear (top-right) — direct access to SettingsView
  - LUMARA logo + title + subtitle
  - "Discover Your Phase" gradient button — launches PhaseQuizV2Screen
  - Chat / Reflect / Voice quick-start action buttons
  - "Import your data" link at bottom — opens ImportOptionsSheet (5 import sources)
  - Input bar and bottom nav hidden during empty state for clean first-use experience
- `initialMode` parameter: activates chat (focus input), reflect (open journal), or voice (launch voice mode) on first frame
- `onEmptyStateChanged` callback: reports empty/non-empty state to HomeView for nav visibility
- `GestureDetector` wrapper dismisses keyboard on outside tap

### FeedInputBar

Bottom input bar replacing the separate input areas from old chat and journal screens.

| Element | Behavior |
|---------|----------|
| Pen icon (left) | Opens new journal entry |
| Text field | Expands up to 4 lines; placeholder "Talk to LUMARA..." |
| Attachment icon | Appears when text field is empty (Phase 2) |
| Send / Voice (right) | Animated switch: shows send arrow when text entered, microphone when empty |

### Entry Cards

All cards extend **BaseFeedCard**, which provides a consistent wrapper with a phase-colored left border indicator and tap/long-press handling.

| Card | Left Border | Extra UI |
|------|-------------|----------|
| ActiveConversationCard | Phase color, pulsing | "Active" badge, exchange count, "Save" button |
| SavedConversationCard | Phase color | Exchange count, "LUMARA" tag if has reflections |
| ReflectionCard | Phase color | Content preview, mood, media count, themes on expand |
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

### Phase 1.5 (v3.3.18, current) — Model refactor, pagination, expanded views, timeline

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

### Phase 2 (planned) — LLM integration and full conversation flow

- Input bar text submission triggers LUMARA LLM call via `EnhancedLumaraAPI`
- Assistant responses stream into the active conversation card
- Voice recording from input bar
- Attachment support (photos, documents)
- Active conversation card shows live message exchange

### Phase 3 (planned) — Advanced features

- Search and filter within the feed
- Pinning and archiving entries
- Inline LUMARA reflection requests on any entry
- Drag-to-reorder pinned entries
- Feed-level analytics (writing streaks, patterns)

---

## Files Modified (outside `unified_feed/`)

| File | Change |
|------|--------|
| `lib/core/feature_flags.dart` | Added `USE_UNIFIED_FEED` flag |
| `lib/core/constants/phase_colors.dart` | Phase color constants for card borders |
| `lib/core/models/entry_mode.dart` | EntryMode enum (chat, reflect, voice) |
| `lib/shared/tab_bar.dart` | Dynamic tab loop; center "+" button conditionally rendered via `showCenterButton` |
| `lib/shared/ui/home/home_view.dart` | 2-tab layout (LUMARA + Settings); `_feedIsEmpty` state hides nav during welcome; `showCenterButton` off in unified mode |
| `lib/app/app.dart` | `onGenerateRoute` to pass EntryMode to HomeView |

---

## Related Documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — ARC Module → `unified_feed/` submodule
- [FEATURES.md](FEATURES.md) — "Unified Feed (v3.3.17, feature-flagged)" section
- [CHANGELOG.md](CHANGELOG.md) — [3.3.17] entry
- [UI_UX.md](UI_UX.md) — UI patterns and components
