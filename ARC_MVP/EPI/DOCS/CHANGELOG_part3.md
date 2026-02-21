# EPI ARC MVP - Changelog (Part 3: January-October 2025 & Earlier)

**Version:** 2.1.48
**Last Updated:** December 11, 2025
**Coverage:** v2.0.0 - v2.1.27 (January-October 2025 and earlier)

---

## Overview

This file contains historical changelog entries from January-October 2025 and earlier. For the most recent changes, see:
- **[CHANGELOG_part1.md](CHANGELOG_part1.md)** - December 2025
- **[CHANGELOG_part2.md](CHANGELOG_part2.md)** - November 2025

---

## [2.1.27] - October 2025

### **LUMARA Knowledge Attribution & Response Variety** - Complete
- **Explicit Distinction**: Updated `LumaraMasterPrompt` to distinguish between EPI Knowledge (user context) and General Knowledge (world facts)
- **Reduced Repetition**: Explicitly instructed LUMARA to avoid repetitive stock phrases
- **Calendar Scroll Sync Fix**: Fixed weekly calendar jumping ahead of selected date

---

## [2.1.26] - October 2025

### **LUMARA UI/UX Improvements & Navigation Updates**
- **Removed Long Press Menu**: Simplified interaction - only star icon needed
- **In-Chat Action Buttons**: Added same action buttons from in-journal to in-chat bubbles
- **Bottom Tab Navigation**: Moved + button from floating action button to center of tab bar
- **Timeline Date Connection**: Calendar week timeline date boxes now connected to timeline cubit data

---

## [2.1.25] - October 2025

### **Chat UX Improvements - Delete and Edit Functionality**
- **Fixed Delete Functionality**: Fixed the delete button on LUMARA message bubbles
- **Improved Edit UX**: Added clear visual indicators when editing messages

---

## [2.1.24] - October 2025

### **LUMARA Favorites Expansion** - Complete
- **Three-Category Favorites System**: LUMARA Answers (25), Saved Chats (20), Favorite Journal Entries (20)
- **Enhanced Context Gathering**: Repository integration, chat history integration, media extraction
- **ARCX Export/Import**: Category support with per-category counts

---

## [2.1.22] - October 2025

### **Enhanced Phase Transition Guidance** - Complete
- **Specific 99% Messaging**: System now provides specific, actionable guidance about what's missing
- **Plain Language Explanations**: Replaced technical jargon with clear, user-friendly language

---

## [2.1.20] - October 2025

### **Automatic Phase Hashtag System** - Complete
- **Phase Regime-Based Hashtag Assignment**: Journal entries automatically receive phase hashtags based on Phase Regimes
- **Smart Defaults**: If entry date doesn't fall within any regime, no hashtag is added

---

## [2.1.19] - October 2025

### **ARCX Import Improvements & Bug Fixes**
- **Auto-Navigation**: After successful import, clicking "Done" navigates to main screen
- **LUMARA Favorites Import Display**: Always shows favorites count in import dialogs
- **Import Stability**: Added timeouts and graceful degradation

### **Journal Timeline & ARCForm Timeline UX**
- **Phase Legend on Demand**: Phase Legend dropdown appears only when ARCForm Timeline is expanded
- **Full-Screen ARCForm Review**: Controls collapse for full viewport ARCForm Timeline
- **Clickable Phase Rail**: Wider with "ARC ✨" hint, supports tap + swipe gestures

---

## [2.1.17] - October 2025

### **Voiceover Mode & Favorites UI Improvements**
- **Voiceover Mode**: Settings toggle, TTS integration, per-message control
- **Favorites UI**: Removed long-press menu, reduced title font, added explainer text

---

## [2.1.16] - October 2025

### **LUMARA Favorites Style System** - Complete
- **Core Functionality**: Users can mark exemplary LUMARA replies as style exemplars (up to 25)
- **Style Adaptation**: LUMARA adapts tone, structure, rhythm based on favorites
- **Prompt Integration**: 3-7 examples per turn, randomized for variety

---

## [2.1.15] - October 2025

### **Advanced Analytics Toggle & UI/UX Improvements**
- **Settings Toggle**: Show/hide Health and Analytics tabs (default disabled)
- **Sentinel Relocation**: Moved to Analytics as its own expandable card
- **Tab UI/UX**: Dynamic sizing based on tab count

---

## [2.1.14] - October 2025

### **Unified LUMARA UI/UX & Context Improvements**
- **LUMARA Header**: Added to in-chat message bubbles, matching in-journal design
- **Consistent Button Placement**: Copy/delete buttons to lower left in both interfaces
- **Context Improvements**: Text state syncing, date information in context

---

## [2.1.10] - October 2025

### **In-Journal LUMARA Attribution & User Comment Support**
- **Actual Journal Content**: Attribution excerpts show actual journal entry content
- **User Comment Support**: LUMARA now considers questions asked in text boxes underneath in-journal comments

---

## [2.1.9] - February 2025

### **LUMARA Memory Attribution & Weighted Context**
- **Specific Attribution Excerpts**: Exact 2-3 sentences from memory entries used in responses
- **Three-Tier Context System**: Primary (current entry), Recent (last 5 messages), Deep (semantic search)
- **Draft Entry Support**: LUMARA can use unsaved draft entries as context

### **PRISM Data Scrubbing & Restoration**
- **Pre-Cloud Scrubbing**: All PII scrubbed before sending to cloud APIs
- **Reversible Restoration**: PII restored in API responses
- **PII Types**: Emails, phone numbers, addresses, names, SSNs, credit cards, API keys, GPS coordinates

### **LUMARA Semantic Search with Reflection Settings**
- **Intelligent Context Finding**: Semantic search to find relevant entries by meaning
- **Reflection Settings**: Similarity Threshold, Lookback Period, Max Matches, Cross-Modal Awareness

---

## [2.1.8] - February 2025

### **Export Simplification, Mobile Formatting, & Therapeutic Presence Mode**
- **Single Export Strategy**: Simplified to "All together" only
- **Streamlined Date Range**: Only "All Entries" and "Custom Date Range" options
- **Mobile Formatting**: Fixed formatting for chats and media

---

## [2.1.0 - 2.1.7] - January-February 2025

### Key Features Implemented
- **Phase Detector Service**: Real-time phase detection with 20+ keywords per phase
- **3D Constellation ARCForms**: Static display with manual 3D controls
- **Phase Timeline Visualization**: Phase legend, TODAY marker, interactive timeline
- **Phase Change Readiness Card**: Progress display, requirements checklist
- **RIVET Sweep Integration**: Automatic phase detection with change-point detection
- **Phase Dropdown & Auto-Capitalization**: Structured phase selection
- **Timeline Ordering Fixes**: Consistent ISO 8601 UTC timestamps
- **MCP Export/Import System**: Ultra-simplified single .zip format
- **LUMARA v2.0**: Multimodal reflective engine with semantic similarity

---

## [2.0.x] - October 2025 (Earlier)

### Major Milestones
- **Draft Creation Bug Fix**: Smart View/Edit mode
- **RIVET & SENTINEL Extensions**: Unified reflective analysis system
- **MIRA v0.2**: Enhanced semantic memory system with ULID-based identity
- **Privacy & Security**: Policy engine, consent logging, PII protection
- **Intelligent Retrieval**: Composite scoring (semantic + recency + phase + domain + engagement)

---

## Earlier Versions

For complete historical details of versions prior to 2.0, please refer to the archived documentation in `docs/archive/`.

---

## Navigation

- **[CHANGELOG.md](CHANGELOG.md)** - Index and overview
- **[CHANGELOG_part1.md](CHANGELOG_part1.md)** - December 2025
- **[CHANGELOG_part2.md](CHANGELOG_part2.md)** - November 2025

