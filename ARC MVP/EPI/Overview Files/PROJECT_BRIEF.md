# ARC MVP — Project Brief for Cursor

## Overview
ARC is the **first module of EPI (Evolving Personal Intelligence)**. It is a journaling app that treats reflection as a **sacred act**. The experience should feel like the *Blessed* app: calming, atmospheric, and emotionally resonant. Journaling is the entry point, but the core differentiation is that each entry generates a **visual Arcform** — a glowing, constellation-like structure that evolves with the user's story.

This MVP focuses on **journaling → AI analysis → Arcform visualization → memory graph**, with complete AI integration via Gemini API, MIRA semantic memory system, and enhanced MCP Memory Bundle export/import featuring mixed-version schema support (node.v1 + node.v2), chat analytics integration, and comprehensive semantic relationship mapping for full ecosystem interoperability.

---

## Tools & Setup
- **Code tools**: Cursor (connected to GitHub), GitHub repo up to date, local clone active.
- **Framework**: Flutter (cross-platform, iOS/Android).
- **Simulator**: iPhone 16 (iOS).
- **Architecture**: Offline-first, encrypted local storage, cloud sync stubbed (Firebase/Supabase later).

---

## Core Flows (MVP)
1. **Onboarding (Reflective Scaffolding)**  
   - Gentle, 3-step flow: why you’re here, journaling tone, preferred rhythm.  
   - Data saved under `user_profiles/{uid}/onboarding`.

2. **Journal Capture**  
   - Minimalist text input (voice optional).  
   - Auto-save drafts.  
   - Save creates `JournalEntry` JSON object.  

3. **SAGE Echo (post-processing)**  
   - After save, entry is annotated with Situation, Action, Growth, Essence.  
   - User can review/edit.  

4. **Keyword Extraction & Review**  
   - 5–10 keywords suggested, user can edit.  
   - Stored on `JournalEntry`.  

5. **Arcform Renderer**  
   - Uses keywords to render constellation/radial layout.  
   - Geometry mapped to ATLAS phase hint (spiral, flower, branch, weave, glow core, fractal).  
   - Emotional colors: warm = growth, cool = recovery.
   - **Enhanced**: Interactive phase selector with live geometry previews
   - **Fixed**: Proper geometry recreation when changing phases, correct edge generation patterns  

6. **Timeline View**  
   - Chronological scroll of entries + Arcform snapshots.  
   - Cards show excerpt + Arcform thumbnail.  

7. **Insights & Your Patterns Visualization**
   - Graph view of keywords (nodes) and co-occurrences (edges).
   - Tap node to see linked entries.
   - **Fixed**: Insight cards now generate properly with real data instead of placeholders
   - **Enhanced**: Comprehensive Your Patterns visualization system with 4 views:
     - Word Cloud: Frequency-based keyword layout with emotion coloring
     - Network Graph: Force-directed physics layout with curved Bezier edges
     - Timeline: Chronological keyword trends with sparkline visualization
     - Radial: Central theme with spoke connections to related concepts
   - **Interactive Features**: Phase filtering, emotion filtering, time range selection
   - **MIRA Integration**: Co-occurrence matrix adapter for semantic memory data
   - **Visual Enhancements**: Phase icons, selection highlighting, neighbor filtering
   - **Enhanced**: Your Patterns submenu displays imported keywords in circular pattern  

---

## Current Development State
- **Production Ready**: All core features implemented and stable ✅
- **Complete MVP Implementation**: Journal capture, arcforms, timeline, insights, onboarding, export functionality
- **First Responder Mode**: Complete specialized tools for emergency responders (P27-P34)
- **Coach Mode**: Complete coaching tools and fitness tracking system (P27, P27.1-P27.3)
- **MCP Export System**: Standards-compliant data export for AI ecosystem interoperability
- **Accessibility & Performance**: Full WCAG compliance with screen reader support and performance monitoring
- **Settings & Privacy**: Complete privacy controls, data management, and personalization
- **Critical Issues Resolved**: All startup, database, and navigation issues fixed

---

## Current Feature Set

### Core Features ✅
- **Journal Capture**: Text and multi-modal journaling with audio, camera, gallery, and OCR
- **Arcforms**: 2D and 3D visualization with phase detection and emotional mapping
- **Timeline**: Chronological entry management with editing and phase tracking
- **Insights**: Pattern analysis, phase recommendations, and emotional insights (Fixed: Now generates actual insight cards with real data)
- **Onboarding**: Reflective 3-step flow with mood selection and personalization

### Specialized Modes ✅
- **First Responder Mode**: Incident capture, debrief coaching, recovery planning, privacy protection
- **Coach Mode**: Coaching tools, fitness tracking, progress monitoring, client sharing

### Technical Features ✅
- **MIRA Semantic Memory System**: Complete semantic memory graph with mixed-version MCP support
  - Chat analytics with ChatMetricsService and EnhancedInsightService
  - Combined journal+chat insights with 60/40 weighting
  - Mixed schema exports (node.v1 legacy + node.v2 chat sessions)
  - Golden bundle validation with comprehensive test suite (6/6 tests passing)
- **MCP Export/Import System**: Complete MCP Memory Bundle v1 format support for AI ecosystem interoperability
  - Export with four storage profiles (minimal, space_saver, balanced, hi_fidelity)
  - Import with validation and error handling
  - Settings integration with dedicated MCP Export/Import buttons
  - Automatic data conversion between app's JournalEntry model and MCP format
  - Progress tracking and real-time status updates
  - Mixed-version exports with AJV-ready JSON validation
- **Settings & Privacy**: Complete privacy controls, data management, and personalization
- **Accessibility**: Full WCAG compliance with screen reader support and performance monitoring
- **Export**: PNG and JSON data export with share functionality
- **Error Recovery**: Comprehensive force-quit recovery and startup resilience

### Data Models
- **JournalEntry**  
```json
{
  "id": "...",
  "createdAt": "...",
  "text": "...",
  "audioUri": null,
  "sage": { "situation": "", "action": "", "growth": "", "essence": "" },
  "keywords": ["..."],
  "emotion": { "valence": 0, "arousal": 0 },
  "phaseHint": "Discovery"
}
```

- **ArcformSnapshot**  
```json
{
  "id": "...",
  "entryId": "...",
  "createdAt": "...",
  "keywords": ["..."],
  "geometry": "Spiral",
  "colorMap": { "keyword": "#hex" },
  "edges": [[0,1,0.8]]
}
```

- **UserProfile**  
```json
{
  "uid": "...",
  "onboarding": { "intent": "growth", "tone": "calm", "rhythm": "daily" },
  "prefs": {}
}
```

---

## Engineering Priorities
1. **Production Deployment**: App is ready for production deployment with all core features stable ✅
2. **MIRA Insights Complete**: Mixed-version MCP analytics with chat integration fully implemented ✅
3. **Feature Enhancement**: Continue developing advanced features like enhanced MIRA graph visualization and cloud sync
4. **Performance Optimization**: Monitor and optimize performance across all platforms
5. **User Experience**: Refine UI/UX based on user feedback and testing
6. **Platform Expansion**: Ensure compatibility across iOS, Android, and other platforms  

---

## Design Goals
- **Atmosphere**: journaling should feel sacred, calm, and meaningful.  
- **Visuals**: glowing constellations, soft gradients, motion inspired by nature.  
- **Dignity**: no harsh errors, language is always supportive.  
- **Performance**: 60 fps animations, smooth iOS feel.  

---

This is the **ARC MVP brief for Cursor**.
The project is now **production-ready** with:
1. ✅ All startup and navigation issues resolved - app boots reliably and flows work end-to-end
2. ✅ Complete data pipeline (journal entry → keywords → Arcform snapshot) implemented and tested
3. ✅ Reflective, humane tone maintained throughout the UI with sacred journaling experience
4. ✅ Production-ready features: First Responder Mode, Coach Mode, MCP Export/Import, Accessibility, Settings
5. ✅ MCP Memory Bundle v1 integration for AI ecosystem interoperability with Settings UI
6. ✅ MIRA Insights Complete: Mixed-version MCP support with chat analytics and combined insights (ALL TESTS PASSING)
7. ✅ Insights System Fixed: Keyword extraction, rule evaluation, and template rendering now working properly
8. ✅ LUMARA Prompts Complete: Universal system prompt with MCP Bundle Doctor validation and CLI tools
9. ✅ LUMARA Context Provider Fixed: Phase detection now works with content analysis fallback for accurate journal entry processing
10. ✅ Comprehensive testing, documentation, and error handling implemented  
