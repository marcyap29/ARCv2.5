# Unified Feed: LUMARA + Conversations Merge

**Version:** 1.0 (Phase 1)  
**Last Updated:** February 8, 2026  
**Status:** Phase 1 complete. Behind feature flag (`USE_UNIFIED_FEED`, default off).  
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
| Tab bar | LUMARA / Phase / Conversations | LUMARA / Phase |
| LUMARA tab | Full-screen chat | Scrollable feed with greeting, entries, input bar |
| Conversations tab | Journal timeline | Removed (entries appear in feed) |
| New journal entry | Tab bar "+" button | Tab bar "+" button (unchanged) |
| Phase tab | Phase constellation | Phase constellation (unchanged) |

---

## Feature Flag

```dart
// lib/core/feature_flags.dart
static const bool USE_UNIFIED_FEED = false;
```

When `false` (default): the app uses the legacy 3-tab layout. Nothing changes.  
When `true`: the app switches to the 2-tab unified layout.

The flag is checked in:
- `home_view.dart` — tab list, tab names, page routing, default tab index
- `tab_bar.dart` — dynamic tab rendering (already refactored from hardcoded 3 tabs to a loop)

---

## Architecture

### Directory Structure

```
lib/arc/unified_feed/
├── models/
│   ├── feed_entry.dart         # FeedEntry model (4 entry types)
│   └── entry_state.dart        # EntryState lifecycle (draft → saving → saved → error)
├── repositories/
│   └── feed_repository.dart    # Aggregates journal, chat, voice data into unified stream
├── services/
│   ├── conversation_manager.dart   # Active conversation lifecycle + auto-save
│   ├── auto_save_service.dart      # App lifecycle-aware save triggers
│   └── contextual_greeting.dart    # Time/recency-based greeting generation
├── utils/
│   └── feed_helpers.dart       # Date grouping, icons, colors, text utilities
└── widgets/
    ├── unified_feed_screen.dart    # Main feed screen
    ├── input_bar.dart              # Bottom input bar
    └── feed_entry_cards/
        ├── active_conversation_card.dart
        ├── saved_conversation_card.dart
        ├── voice_memo_card.dart
        └── written_entry_card.dart
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

1. **FeedRepository is read-through.** It queries existing repositories (JournalRepository, ChatRepoImpl) and merges results. All writes go through the original repositories. This avoids data duplication and keeps the existing persistence layer untouched.

2. **FeedEntry is a view model.** It does not inherit from JournalEntry or ChatSession. It's a lightweight, presentation-layer object that wraps data from any source into a consistent shape.

3. **ConversationManager handles lifecycle, not the screen.** The screen just calls `addUserMessage(text)` and the manager handles everything: creating the conversation, tracking messages, resetting inactivity timers, and persisting to journal storage when auto-save fires.

4. **Auto-save is multi-trigger.** Conversations save automatically when:
   - 5 minutes pass with no new messages (inactivity timeout, configurable)
   - The app goes to background/pauses
   - The user explicitly taps "Save"

---

## Models

### FeedEntry

The core view model. Represents any item in the feed.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique ID (prefixed: `journal_`, `chat_`, `active_`) |
| `type` | `FeedEntryType` | One of 4 types (see below) |
| `title` | `String` | Display title |
| `preview` | `String` | Truncated content preview (max 200 chars) |
| `createdAt` | `DateTime` | When created |
| `updatedAt` | `DateTime` | When last modified |
| `state` | `EntryState` | Lifecycle state (draft, saving, saved, error) |
| `messageCount` | `int` | Number of messages (conversations) |
| `audioDuration` | `Duration?` | Voice memo length |
| `tags` | `List<String>` | Tags |
| `mood` | `String?` | Emotion label |
| `phase` | `String?` | Life phase at time of entry |
| `isPinned` | `bool` | Pinned/favorited |
| `hasLumaraReflections` | `bool` | Has LUMARA inline blocks |
| `hasMedia` | `bool` | Has media attachments |
| `mediaCount` | `int` | Number of media attachments |
| `chatSessionId` | `String?` | Source chat session ID |
| `journalEntryId` | `String?` | Source journal entry ID |
| `voiceNoteId` | `String?` | Source voice note ID |

### FeedEntryType

| Type | Source | Visual | Description |
|------|--------|--------|-------------|
| `activeConversation` | ConversationManager | Indigo accent, pulsing border | Ongoing chat, not yet saved |
| `savedConversation` | JournalRepository (has LUMARA blocks) | Purple accent | Chat saved as journal entry |
| `voiceMemo` | JournalRepository (has audioUri) | Emerald accent | Voice recording |
| `writtenEntry` | JournalRepository (text only) | Blue accent | Traditional journal entry |

### EntryState

Tracks the lifecycle of a feed entry:

| State | Meaning |
|-------|---------|
| `draft` | Being composed, not yet saved |
| `saving` | Currently being persisted |
| `saved` | Successfully persisted to storage |
| `error` | Save failed (includes error message and retry count) |

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
1. **Greeting header** — LUMARA sigil + contextual greeting + sub-greeting
2. **Header actions** — Settings icon
3. **Date-grouped entry cards** — Today, Yesterday, This Week, This Month, etc.
4. **Input bar** — Fixed at bottom

**Interactions:**
- Pull-to-refresh to reload feed
- Tap entry card → open journal entry or chat session
- Tap "Save" on active conversation card → persist as journal entry
- Submit text in input bar → add user message to active conversation
- Tap "+" in input bar → open new journal entry screen
- Empty state with Chat / Write / Voice quick-start actions

### FeedInputBar

Bottom input bar replacing the separate input areas from old chat and journal screens.

| Element | Behavior |
|---------|----------|
| Pen icon (left) | Opens new journal entry |
| Text field | Expands up to 4 lines; placeholder "Talk to LUMARA..." |
| Attachment icon | Appears when text field is empty (Phase 2) |
| Send / Voice (right) | Animated switch: shows send arrow when text entered, microphone when empty |

### Entry Cards

Four card types with consistent layout (type icon + title + timestamp + preview) but distinct visual treatments:

| Card | Border | Accent | Extra UI |
|------|--------|--------|----------|
| ActiveConversationCard | Primary color border + shadow | Indigo | "Active" badge, message count, "Save" button |
| SavedConversationCard | Subtle border | Purple | Message count, "LUMARA" tag if has reflections |
| VoiceMemoCard | Subtle border | Emerald | Duration display, play icon |
| WrittenEntryCard | Subtle border | Blue | Mood indicator, media count, tags |

---

## Phases

### Phase 1 (current) — Core models and feed display

- FeedEntry model and EntryState
- FeedRepository aggregation
- ConversationManager with auto-save
- UnifiedFeedScreen with greeting, cards, input bar
- Feature flag and home view routing
- Dynamic tab bar

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
| `lib/shared/tab_bar.dart` | Refactored from hardcoded 3 tabs to dynamic loop |
| `lib/shared/ui/home/home_view.dart` | Conditional 2-tab/3-tab routing based on flag |

---

## Related Documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — ARC Module → `unified_feed/` submodule
- [FEATURES.md](FEATURES.md) — "Unified Feed (v3.3.17, feature-flagged)" section
- [CHANGELOG.md](CHANGELOG.md) — [3.3.17] entry
- [UI_UX.md](UI_UX.md) — UI patterns and components
