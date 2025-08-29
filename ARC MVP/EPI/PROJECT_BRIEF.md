# ARC MVP — Project Brief for Cursor

## Overview
ARC is the **first module of EPI (Evolving Personal Intelligence)**. It is a journaling app that treats reflection as a **sacred act**. The experience should feel like the *Blessed* app: calming, atmospheric, and emotionally resonant. Journaling is the entry point, but the core differentiation is that each entry generates a **visual Arcform** — a glowing, constellation-like structure that evolves with the user’s story.

This MVP focuses on **journaling → keyword extraction → Arcform visualization**, with scaffolding in place for future EPI modules (ATLAS, AURORA, VEIL, Polymeta).

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

6. **Timeline View**  
   - Chronological scroll of entries + Arcform snapshots.  
   - Cards show excerpt + Arcform thumbnail.  

7. **Insights (Polymeta v1)**  
   - Graph view of keywords (nodes) and co-occurrences (edges).  
   - Tap node to see linked entries.  

---

## Current Development State
- Project scaffolding, theming, and navigation are implemented.  
- Onboarding questions display but **two issues persist**:  
  1. **White screen** on app boot (app hangs).  
  2. App sometimes boots but **freezes after onboarding**, never proceeding to Arcform creation.  

These are the highest-priority blockers before we can move deeper into Prompt 8 (Arcform renderer).

---

## Data Models
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
1. **Debug iOS boot issue**: white screen vs. freeze.  
   - Check main.dart startup logic and route handling.  
   - Verify correct use of async init (storage, theme, onboarding state).  

2. **Fix Arcform creation flow**:  
   - Ensure entry → keywords → Arcform snapshot pipeline runs.  
   - Verify that state management (e.g., Riverpod/Bloc) persists across navigation.  

3. **Stabilize onboarding → journal → Arcform pipeline** before layering in Timeline, Insights, and exports.  

---

## Design Goals
- **Atmosphere**: journaling should feel sacred, calm, and meaningful.  
- **Visuals**: glowing constellations, soft gradients, motion inspired by nature.  
- **Dignity**: no harsh errors, language is always supportive.  
- **Performance**: 60 fps animations, smooth iOS feel.  

---

This is the **ARC MVP brief for Cursor**.  
Cursor should now:  
1. Fix startup + onboarding → Arcform freeze issues.  
2. Ensure the data pipeline (journal entry → keywords → Arcform snapshot) works end-to-end.  
3. Maintain the reflective, humane tone of the UI.  
