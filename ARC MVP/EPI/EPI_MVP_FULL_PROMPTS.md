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

## Prompt 19 — Accessibility and Performance Pass
**Goal:** Ensure the app is accessible and smooth.

**Generate:**
- Larger text mode, high‑contrast mode, reduced motion option.
- Frame budget warnings for heavy scenes.

**Acceptance criteria:**
- No scene drops below 45 fps on a mid‑tier device.
- All interactive elements have accessible labels.

---

## Prompt 20 — UI/UX Design Atmosphere (Blessed + Monument Valley)
**Goal:** Define the design language and interaction style of the ARC MVP, blending *Blessed’s sacred journaling calm* with the *poetic spatial design of Monument Valley (1–3)*.

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

### Final Note
Build iteratively. After Prompts 0–3 you can already capture entries. After Prompt 8 you have the first Arcform reveal. The rest deepens functionality and prepares for ATLAS, AURORA, VEIL, and Polymeta integration.
