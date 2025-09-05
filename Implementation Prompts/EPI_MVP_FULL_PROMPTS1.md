# EPI MVP — Vibe Studio Step‑by‑Step Prompts (Unified with UI/UX)

This document contains the complete set of prompts to guide ARC MVP development in Vibe Studio and Cursor. Each block includes goals, generation requirements, data models, acceptance criteria, and sample copy. Keep dark mode as default, avoid harsh system messages, and maintain a calm, reflective tone throughout.

---

## Prompt 0 — Project Seed and Design Tokens
**Goal:** Initialize a mobile‑first Flutter app called **EPI** with consistent visual identity.

**Generate:**
- App shell with routing, state store, and dark theme by default.
- Design tokens: colors, typography, spacing, radius, shadows, animation speeds.
- Asset folders for icons, lottie animations, and illustrations.

**Design tokens:**
- Colors: background `#0C0F14`, surface `#121621`, surfaceAlt `#171C29`, primaryGradient (indigo to violet), accent `#D1B3FF`, success `#6BE3A0`, warning `#F7D774`, danger `#FF6B6B`.
- Type: Headline 1–3 (semi‑bold), Body (regular), Caption (medium). Use a readable humanist sans.
- Radius: `lg=24`, `md=16`, `sm=10`.
- Shadows: soft glow on cards.
- Animations: ease in out, 250–450 ms.

**Acceptance criteria:**
- Launch screen with app name, tagline, and subtle glow.
- Navigation placeholder with four tabs: Journal, Arcforms, Timeline, Insights.
- Global theme switch exists but dark mode is default.

**Copy:**
- App title: EPI (Evolving Personal Intelligence)
- Tagline: A new kind of intelligence that grows with you.

---

## Prompt 1 — App Structure and Navigation
**Goal:** Create bottom navigation and route structure for four primary tabs.

**Generate:**
- Tabs: Journal, Arcforms, Timeline, Insights.
- Each tab has a header, empty state, and floating action button if relevant.
- Global drawer with Settings, Privacy, About.

**Acceptance criteria:**
- Tabs switch without losing state.
- Each tab has a distinct icon. Use outline icons with soft glow.

**Copy:**
- Empty state (Journal): “Capture a moment of your story.”
- Empty state (Arcforms): “Your Arcform will appear after your first entry.”
- Empty state (Timeline): “Entries will line up here in time.”
- Empty state (Insights): “Come back after a few entries for patterns.”

---

## Prompt 2 — Data Model and Storage Setup
**Goal:** Define local encrypted storage models for MVP with sync stubs.

**Generate:**
- Encrypted local store for all user data.
- Data interfaces and mock repositories.

**Models (JSON schema):**
- `JournalEntry`: `{ id, createdAt, text, audioUri?, sage: {situation?, action?, growth?, essence?}, keywords: string[], emotion?: { valence: -1..1, arousal: 0..1 }, phaseHint?: "Discovery|Expansion|Transition|Consolidation|Recovery|Breakthrough" }`
- `ArcformSnapshot`: `{ id, entryId, createdAt, keywords: string[], geometry: "Spiral|Flower|Branch|Weave|GlowCore|Fractal", colorMap: { [keyword]: hex }, edges: [ [i,j,strength] ] }`
- `UserProfile`: `{ uid, onboarding, prefs }`

**Acceptance criteria:**
- CRUD works locally.
- Dev menu can reset local data.

---

## Prompt 3 — Onboarding: Reflective Scaffolding
**Goal:** Gentle, three‑page onboarding that stores preferences and phase hints.

**Generate:**
- Three screens with soft backgrounds and progress dots.
- Questions and options persisted to `user_profiles/{uid}/onboarding`.

**Questions:**
1) What brings you here? (self‑discovery, coaching, journaling, growth, recovery)  
2) How do you want to feel while journaling? (calm, energized, reflective, focused)  
3) What rhythm fits you best? (daily, weekly, free‑flow)

**Acceptance criteria:**
- Skippable at any point with a clear “Skip for now.”
- Summary screen shows selected choices with edit buttons.
- Choices influence initial tones and suggestions.

**Copy tone:** invitational and supportive.

---

## Prompt 4 — Journal Capture (Text)
**Goal:** Minimalist journaling screen with auto‑save and metadata capture.

**Generate:**
- Full‑screen editor with large calm text field, glowing caret.
- Auto‑save draft; explicit Save action creates a `JournalEntry`.
- Quick tags row for mood chips (calm, hopeful, stressed, tired, grateful).

**Acceptance criteria:**
- Save writes `JournalEntry` with timestamp.
- Editor autosaves without visible jitter.
- Keyboard shortcuts on desktop preview.

**Copy:**
- Placeholder: “Write what is true right now.”

---

## Prompt 5 — Journal Capture (Voice)
**Goal:** Add optional voice journaling with permission flow and transcription.

**Generate:**
- Microphone button with visualizer.
- Permission dialog, recording timer, pause, stop, playback.
- Transcribe to text and attach `audioUri` to entry.

**Acceptance criteria:**
- Failed permission shows gentle guidance.
- Transcription editable before save.

---

## Prompt 6 — SAGE Echo Post‑Processing
**Goal:** After save, apply SAGE Echo to annotate entries with Situation, Action, Growth, Essence.

**Generate:**
- Background worker that runs a lightweight classifier or rule set.
- UI panel under each entry showing detected S, A, G, E with edit toggles.

**Acceptance criteria:**
- SAGE fields prefilled with confidence badges.
- User can edit and save corrections.
- Edits persist to the `JournalEntry.sage` object.

**Copy:**
- Panel title: “SAGE Echo”
- Helper: “Adjust if something feels off.”

---

## Prompt 7 — Keyword Extraction and Review
**Goal:** Extract 5–10 keywords, allow user review before visualization.

**Generate:**
- Keyword suggestion chip list with add, remove, reorder.
- Auto color assignment per keyword with accessible contrast.

**Acceptance criteria:**
- At least 5 and at most 10 keywords enforced with gentle prompts.
- Final keyword set stored on the entry.

**Copy:**
- Title: “Choose the words that matter most.”

---

## Prompt 8 — Arcform Renderer (Constellation Style)
**Goal:** Render an Arcform from a saved entry and chosen keywords.

**Generate:**
- Force‑directed or radial layout of keyword nodes with glowing edges.
- Geometry maps to ATLAS hint: Spiral (Discovery), Flower (Expansion), Branch (Transition), Weave (Consolidation), GlowCore (Recovery), Fractal (Breakthrough).
- Emotional color rule: warm for growth, cool for recovery tones.

**Acceptance criteria:**
- 60 fps on recent devices with 10 nodes and up to 20 edges.
- Tap a node to show linked journal excerpt and SAGE snippet.
- Export Arcform as PNG to device photo library.

**Copy:**
- Tooltip: “Tap a word to open its thread.”

---

## Prompt 9 — Timeline View
**Goal:** Chronological stream that blends entries and Arcform snapshots.

**Generate:**
- Vertical list grouped by month. Each card shows date, a line from the entry, and a mini Arcform thumbnail.
- Filters: All, Text only, With Arcform.

**Acceptance criteria:**
- Infinite scroll with lazy loading.
- Tapping a card opens detail with full entry, SAGE, keywords, Arcform.

---

## Prompt 10 — Insights: Polymeta v1 Graph
**Goal:** Simple semantic memory graph to navigate related entries.

**Generate:**
- Graph view where nodes are keywords and edges represent co‑occurrence strength.
- Tapping a node reveals linked entries as a list; tapping an edge previews joint context.

**Acceptance criteria:**
- Graph reflects actual stored keywords.
- Basic pan and zoom with inertia.

**Copy:**
- Header: “Your patterns”
- Helper: “Follow a word to its moments.”

---

## Prompt 11 — Phase Detection Placeholder (ATLAS)
**Goal:** Show phase hint and placeholder while FFT model is not yet active.

**Generate:**
- Insight card that displays current phase hint with a calm pulse.
- Text: “Phase detection in progress” when insufficient data.
- Rules: require at least 5 entries across 10 days to compute a coarse hint from keyword frequency and mood trend.

**Acceptance criteria:**
- Card is visible in Insights and on Arcform detail.
- Updates when new entries arrive.

---

## Prompt 12 — Rhythm and Restoration Placeholders (AURORA and VEIL)
**Goal:** Introduce future modules with informative cards.

**Generate:**
- AURORA card: “Daily rhythm insights will appear here.” Optional suggested times for journaling based on user preference.
- VEIL card: “Nightly reflection will help restore coherence.” Simple pulse animation at local night hours.

**Acceptance criteria:**
- Cards are clearly marked as not yet active.

---

## Prompt 13 — Settings and Privacy
**Goal:** Give users control over privacy, exports, and preferences.

**Generate:**
- Settings pages: Privacy, Data, Personalization, About.
- Privacy toggles: local only mode, biometric lock, export data, delete all data.
- Personalization: tone, rhythm, color accessibility.

**Acceptance criteria:**
- Export creates a JSON file with entries and snapshots.
- Delete requires a two‑step confirmation.

**Copy:**
- Privacy header: “Your data, your choice.”

---

## Prompt 14 — Cloud Sync Stubs
**Goal:** Prepare for Firebase or Supabase without enabling write by default.

**Generate:**
- Sync service with offline‑first approach and queued writes.
- Toggle in Settings to enable sync.

**Acceptance criteria:**
- App runs fully offline when sync is off.
- Turning sync on shows a connection status indicator.

---

## Prompt 15 — Instrumentation and QA Checklist
**Goal:** Add basic analytics events and a non‑intrusive QA screen.

**Generate:**
- Events: `onboarding_completed`, `entry_saved`, `voice_recorded`, `sage_reviewed`, `arcform_rendered`, `timeline_opened`, `insights_opened`, `export_png`, `export_json`.
- QA screen: device info, performance stats, sample data seeder.

**Acceptance criteria:**
- Events fire only with user consent.
- Seeder can generate 12 synthetic entries across 30 days.

---

## Prompt 16 — Demo Data and Screenshots Mode
**Goal:** One‑tap demo content for presentations.

**Generate:**
- Seed script that creates plausible journal entries, SAGE annotations, keywords, three phases over time, and Arcforms.
- Screenshot mode that hides user identifiers and locks animations to stable frames.

**Acceptance criteria:**
- Demo looks authentic and consistent with the tone of the app.

---

## Prompt 17 — Share and Export Arcform
**Goal:** Let users save or share an Arcform image with a caption.

**Generate:**
- Share sheet integration and local save.
- Default caption includes date, top keywords, and a reflective line.

**Acceptance criteria:**
- Exported PNG is crisp on retina devices.
- Share respects privacy mode and excludes raw journal text unless user opts in.

---

## Prompt 18 — Copy Pack for UI Text
**Goal:** Provide consistent, humane microcopy across the app.

**Generate:**
- Strings table with keys and values for prompts, helpers, empty states, and error recovery messages.

**Examples:**
- `copy.journal.placeholder`: “Write what is true right now.”
- `copy.sage.helper`: “Adjust if something feels off.”
- `copy.arcform.tooltip`: “Tap a word to open its thread.”
- `copy.privacy.title`: “Your data, your choice.”

---

## Prompt 19 — Accessibility and Performance Pass ✅ COMPLETE & MERGED
**Goal:** Ensure the app is accessible and smooth.

**✅ COMPLETED - Full P19 Implementation: All 10 Core Features - Successfully Merged to Main Branch**
- **Phase 1: Quick Wins** - Maximum accessibility value with minimal effort
  - ✅ **Larger Text Mode** - Dynamic text scaling (1.2x) with `withTextScale` helper
  - ✅ **High-Contrast Mode** - High-contrast color palette with `highContrastTheme`
  - ✅ **A11yCubit Integration** - Added to app providers for global accessibility state
- **Phase 2: Polish** - Motion sensitivity and advanced accessibility support
  - ✅ **Reduced Motion Support** - Motion sensitivity support with debug display
  - ✅ **Real-time Testing** - Debug display shows all accessibility states
  - ✅ **App Builds** - Everything compiles and builds successfully
- **Phase 3: Advanced Testing & Profiling** - Comprehensive accessibility and performance tools
  - ✅ **Screen Reader Testing** - `ScreenReaderTestingService` with semantic label testing, navigation order validation, color contrast analysis, and touch target compliance
  - ✅ **Performance Profiling** - `PerformanceProfiler` with frame timing monitoring, custom metrics, execution time measurement, and automated recommendations
  - ✅ **Enhanced Debug Panels** - Both testing panels integrated into Journal Capture View with real-time updates
- **Accessibility Infrastructure** - Comprehensive accessibility services implemented
  - ✅ `A11yCubit` for accessibility state management (larger text, high contrast, reduced motion)
  - ✅ `a11y_flags.dart` with reusable accessibility helpers and semantic button wrappers
  - ✅ `accessibility_debug_panel.dart` for development-time accessibility testing
  - ✅ `screen_reader_testing.dart` with comprehensive accessibility testing framework
- **Performance Monitoring** - Real-time performance tracking and optimization
  - ✅ `FrameBudgetOverlay` for live FPS monitoring in debug mode (45 FPS target)
  - ✅ `frame_budget.dart` with frame timing analysis and performance alerts
  - ✅ `performance_profiler.dart` with advanced performance profiling and recommendations
  - ✅ Visual performance feedback with color-coded FPS display
- **Accessibility Features Applied** - Journal Composer screen fully accessible
  - ✅ **Accessibility Labels** - All voice recording buttons have proper semantic labels
  - ✅ **44x44dp Tap Targets** - All interactive elements meet minimum touch accessibility requirements
  - ✅ **Semantic Button Wrappers** - Consistent accessibility labeling across all controls

**✅ Technical Achievements:**
- Successfully applied "Comment Out and Work Backwards" debugging strategy
- A11yCubit integrated into app providers for global state management
- BlocBuilder pattern for reactive accessibility state updates
- Theme and text scaling applied conditionally based on accessibility flags
- Debug display for testing all accessibility features in real-time
- App builds successfully for iOS with no compilation errors
- Performance monitoring active in debug mode with real-time feedback
- Comprehensive testing framework with automated accessibility compliance checking

**✅ Acceptance Criteria Met:**
- ✅ No scene drops below 45 fps on a mid‑tier device (FrameBudgetOverlay monitoring)
- ✅ All interactive elements have accessible labels (semantic button wrappers)
- ✅ Larger text mode, high‑contrast mode, reduced motion option implemented
- ✅ Frame budget warnings for heavy scenes (real-time FPS monitoring)
- ✅ Screen reader testing framework with comprehensive accessibility validation
- ✅ Performance profiling with real-time metrics and optimization recommendations

**📊 P19 Progress Summary - COMPLETE & MERGED:**
- **Core Features**: 10/10 completed (100% complete!)
- **Phase 1 & 2**: Larger Text, High-Contrast, Reduced Motion ✅
- **Phase 3**: Screen Reader Testing, Performance Profiling ✅
- **Infrastructure**: 100% complete
- **Applied Features**: 100% complete on Journal Composer
- **Testing**: App builds successfully, all features functional
- **Documentation**: Complete ✅
- **Merge Status**: Successfully merged to main branch ✅
- **Production Ready**: All P19 features now available in main branch for deployment

---

## Prompt 20 — UI/UX Design Atmosphere (Blessed + Monument Valley)
**Goal:** Define the design language and interaction style of the ARC MVP, blending *Blessed’s sacred journaling calm* with the *poetic spatial design of Monument Valley (1–3)*.

Always show details
from pathlib import Path

# Extend unified prompts file with Prompt 21, 22, 23
extended_prompts = """

## Prompt 21 — Welcome & Introductory Flow
**Goal:** Add a calm welcome screen and introductory questions to seed the first Arcform.

**Generate:**
- Welcome screen with app title, tagline, and subtle glow animation.
- Introductory question flow (3 steps):
  1. “What brings you here today?” (self‑discovery, journaling, growth, recovery)
  2. “How are you feeling right now?” (mood chips: calm, hopeful, stressed, tired, grateful)
  3. “What rhythm fits you best?” (daily, weekly, free‑flow)
- Store responses under `user_profiles/{uid}/onboarding`.
- Auto‑generate an **initial Arcform snapshot** from the chosen mood keywords.

**Acceptance criteria:**
- App boots into Welcome → Intro flow (not straight to journal).
- First Arcform generated immediately after onboarding.

---

## Prompt 22 — Ethereal Music / Intro Soundscape
**Goal:** Add optional ambient music to the Welcome + Intro flow.

**Generate:**
- Integrate lightweight audio package (e.g. `just_audio` or `audioplayers`).
- Play 30–60 second loop of ambient audio during Welcome/Intro screens.
- Fade out as journaling begins.

**Acceptance criteria:**
- Audio plays only during onboarding.
- User can mute or skip audio easily.
- App ships with a placeholder audio asset (replaceable later).

**Asset Sources:**
- Free: Pixabay Music, FreeSound (attribution required).
- Paid: Epidemic Sound, Artlist, Soundstripe.

---

## Prompt 23 — Arcform Sovereignty (Auto vs Manual)
**Goal:** Arcforms default to auto‑detected geometry but allow user override.

**Generate:**
- Auto‑detect geometry from ATLAS phase hint (keywords + mood trend).
- Render Arcform in that geometry by default.
- Provide “Reshape?” option to let user manually select (Spiral, Flower, etc.).
- Store whether Arcform was auto or manual in `ArcformSnapshot`.

**Acceptance criteria:**
- Auto geometry works end‑to‑end.
- Manual override option available but optional.
- UI clearly shows current geometry + override option.

### Design Principles
- **Atmosphere as sacred:** journaling is a ritual, not a utility. The UI should slow the user down and feel contemplative.  
- **Spatial elegance:** like Monument Valley, screens should feel like crafted rooms, not flat menus.  
- **Minimal but expressive:** avoid clutter. Use glowing highlights, gradients, and geometry to imply depth and meaning.  
- **Every interaction matters:** no harsh transitions; all motion should be graceful and intentional.  

### Visual Palette
- Dark mode default (deep navy to black).  
- Accent gradients: violet, indigo, soft gold.  
- Keywords: pastel but glowing (lavender, teal, coral, sky blue, soft orange).  
- Sacred glow: interactive elements radiate gently when active.  

### Typography
- Humanist sans serif, semi-rounded.  
- Headlines: medium weight, spacious tracking.  
- Body: calm, readable.  
- Captions: smaller, warm tone.  

changes that need to be made:\
  \
  1. when I'm in the Arcform tab, the correct phase is listed at the top, however, the 3D arcform Geometry defaults at 
  discovery, creating confusion between the 3d form on display (discovery), and what is the user's official phase (Transition, 
  etc.). \
  2. When I'm in the "Arcform" tab, I want the ability to change my phase as well. make it a small button on the upper right, 
  and ask for confirmation that you want the phase changed.\
  \
  3. in my timeline here's the image: [Image #1], I actually want the Phase shape or phase on display above the "Journal Entry"
   text, not that circle with 5 points etc.\
  4. Also when I go into the editing menu, the "keywords" in that section [Image #2], are different than the keywords from the 
  historical arcform [Image #4]. These actually don't even match the keywords that are autoselected by the app when I first 
  enter a journal entry. I want the keywords in these past timeline apps to actually be the keywords chosen by the algorithm.
  ### Motion & Animation
- **Transitions:** Monument Valley-style, panels sliding as if planes in space.  
- **Arcform reveal:** animate like a flower unfolding or constellation forming.  
- **Microinteractions:** glowing nodes, soft button pulses, ink-dissolving fades.  

### UI Layout Inspiration
1. **Onboarding:** soft question cards, gradient-shifting background.  
2. **Journal:** full-screen text canvas, glowing caret, ambient background.  
3. **Arcform:** constellation center, interactive, unfolding gracefully.  
4. **Timeline:** vertical river with glowing connectors, Arcform thumbnails hovering.  
5. **Insights:** infinite dark canvas, slowed physics for meditative navigation.  

### Acceptance Criteria
- Contemplative and artistic, not clinical.  
- Animation timing aligns with human breath (300–800ms).  
- Evokes calm wonder and sacred reflection.  
- No harsh edges or error states.  

### Copy Tone
- Always invitational and poetic.  
- Examples:  
  - “Every journey begins with a reflection.”  
  - “Your words are safe here.”  
  - “This is how your story takes shape.”  

---

You're right to ask — **Prompt 23** is listed in your progress file as:

> **P23 — Arcform sovereignty (auto/manual)** → ✅ Complete
> **Manual “Reshape?” override**

But the full **prompt definition** is missing.

Here is a complete version of **Prompt P23** you can add directly to your `ARC_MVP_IMPLEMENTATION.md` under prompt traceability and optionally as an open ticket (if there’s refinement ahead):

---

### 🟩 **P23 — Arcform Sovereignty (Auto/Manual Override)**

> **Purpose:** Allow users to either accept the system-detected Arcform (based on emotion + keywords + phase) or manually override the geometry to fit their inner experience, preserving narrative dignity.

---

#### 🔧 Prompt Summary

* Users can choose to **accept** the system-generated Arcform shape after journaling *or* tap **“Reshape?”** to select one manually.
* All 6 ATLAS phase shapes are available in a selector (Spiral, Flower, Branch, Weave, GlowCore, Fractal).
* Manual overrides are saved per journal entry (`entry.arcform_shape_override`).
* Overriding does **not** change the underlying detected phase — only the Arcform geometry visual.

---

#### ✅ Checklist

* [x] `geometry_selector.dart` modal with 6 sacred shape icons
* [x] “Reshape?” button shown after phase detection
* [x] Save override flag to entry metadata
* [x] Maintain phase name for display even if visual is manually selected
* [x] Analytics stub for “override frequency” (P15 tie-in)
* [x] Optional: Tooltip explaining the purpose of Arcform sovereignty

---

#### 📁 Files Modified


P26 — “Keyword Selection — RIVET-Gated (20 candidates; top 15 preselected)”.

```
lib/features/arcforms/widgets/geometry_selector.dart
lib/features/journal/journal_capture_view.dart
lib/features/arcforms/arcform_renderer_cubit.dart
lib/features/arcforms/arcform_mvp_implementation.dart
```

[EPI • MVP • Keyword Selection — RIVET-gated]

ROLE
You are the EPI MVP keyword selector running inside ECHO. Your job is to propose high-signal keywords from an ARC entry, gate out weak candidates with RIVET evidence rules, and return a JSON payload for the UI. Keep the existing scoring equation S(·) EXACTLY as previously defined (do not change terms or weights).

INPUTS
You will receive a JSON input with:
- entry_text: string (the ARC entry or transcript)
- current_phase: string (ATLAS phase label)
- phase_lexicon: {term -> phase_match_strength ∈ [0,1]}
- user_lexicon_topk: [strings] (frequent/personalized terms from Polymeta)
- emotion_spans: [{start,int, end,int, label,str, amplitude ∈ [0,1]}]
- centrality_map: {term -> centrality ∈ [0,1]} (from Polymeta / corpus stats)
- recency_map: {term -> recency_boost ∈ [0,1]}
- n_docs: int (doc count used by the equation’s stats)
- config:
    max_candidates = 20
    preselect_top = 15
    rivet_thresholds = {
      min_score: τ_score_add,          // keep from your existing equation
      min_evidence_types: 2,           // at least two distinct supports
      min_phase_match: 0.20,           // drop if below
      min_emotion_amp: 0.15            // drop if below, unless neutral/contextual
    }

CANDIDATE GENERATION
1) Extract raw candidates (ngrams, keyphrases, entities) using your normal pipeline.
2) Compute S(candidate) with the EXISTING scoring equation (unchanged).
3) Attach features per candidate:
   - score: S ∈ [0,1] (normalized if your equation isn’t)
   - emotion: {label, amplitude ∈ [0,1]} (from emotion_spans around mentions)
   - phase_match: {phase: current_phase, strength ∈ [0,1]} (from phase_lexicon)
   - evidence: {
       support_types: set ⊆ {tfidf, freq, centrality, recency, emotion, phase, span_count},
       span_indices: [[start,end], ...]  // where the term appears in entry_text
     }

RIVET GATING (gate out weak ones)
Drop any candidate that fails evidence sufficiency:
- score < τ_score_add  OR
- |support_types| < min_evidence_types OR
- phase_match.strength < min_phase_match (unless term is clearly descriptive, e.g., names/dates) OR
- emotion.amplitude < min_emotion_amp for emotion-anchored terms
Also drop near-duplicates and merge morphological variants/synonyms, keeping the canonical lemma with the highest score (carry over unioned evidence).

RANKING & TRUNCATION
- Sort remaining candidates by score DESC, then by phase_match.strength DESC, then by emotion.amplitude DESC, then by centrality DESC.
- Keep the top max_candidates (≤ 20).

PRESELECTION & CHIPS
- Mark the top preselect_top (≤ 15) as selected=true by default.
- Return a “chips” array (strings) listing those preselected keywords in order; these will render as selectable chips in the UI.

OUTPUT (JSON only — no prose)
Return exactly this shape:

{
  "meta": {
    "current_phase": "<string>",
    "limits": { "max_candidates": 20, "preselect_top": 15 },
    "equation": "AS_IS",                // literal marker to confirm we did not change it
    "notes": "RIVET applied before truncation; deterministic ordering; no randomness."
  },
  "candidates": [
    {
      "keyword": "<string>",
      "score": <float 0..1>,
      "emotion": { "label": "<string|none>", "amplitude": <float 0..1> },
      "phase_match": { "phase": "<string>", "strength": <float 0..1> },
      "evidence": {
        "support_types": ["tfidf","centrality","emotion", "..."],
        "span_indices": [[start,end], ...]
      },
      "selected": true|false,
      "rivet": { "gated_out": false, "reasons": [] }
    }
    // ... up to 20 total
  ],
  "chips": ["<kw1>", "<kw2>", "..."]   // the 15 preselected keywords (or fewer if <15 remain)
}

CONSTRAINTS & BEHAVIOR
- Deterministic: no randomness, seeds, or temperature; same input ⇒ same output.
- If fewer than 20 viable remain post-RIVET, return however many you have; still preselect top min(15, count).
- Never invent terms not present (exact or lemmatized) in entry_text or user_lexicon_topk.
- Keep keywords concise (1–3 words), semantically atomic, and user-meaningful.
- Safety: don’t expose sensitive PII in keywords unless the user explicitly wrote it (still allowed if present).
- Do not change the scoring equation or thresholds beyond provided config.



---

#### 🧠 UX Purpose

This feature reinforces ARC’s principle of **narrative autonomy** — the user is always the final author of meaning. It prevents frustration when internal emotional states don’t match algorithmic output, and builds long-term trust.

---


### Final Note
Build Iteratively