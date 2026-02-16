# CHRONICLE: Temporal Aggregation Architecture for AI Memory

## Quick Reference Guide for Future Claude Instances

**Document Version:** 2.1 (implementation-aligned)  
**Last Updated:** February 15, 2026  
**Status:** Implementation complete through Phase 5; editing is in-place save + validation; version history and edit propagation are planned.

---

## What CHRONICLE Is

CHRONICLE is a **hierarchical temporal memory architecture** that enables AI systems to maintain longitudinal intelligence about users across unlimited time horizons while keeping context requirements bounded.

**The Core Problem It Solves:**
- Users expect AI to remember years of interaction
- Context windows impose hard limits (~200K tokens max)
- Naive approaches (storing everything, vector search) scale poorly
- Result: AI either forgets or becomes computationally intractable

**CHRONICLE's Solution:**
Progressive aggregation from high-fidelity recent events to compressed thematic summaries of distant history, mirroring how human memory consolidates from hippocampus (episodic detail) to neocortex (semantic essence).

**CHRONICLE's Unique Position:**
This isn't AI memory. This isn't even AI-assisted journaling. This is **collaborative autobiography**—where the AI handles synthesis and pattern detection, but the human retains narrative authority. Intelligence that serves you by working WITH you, not by secretly modeling you.

---

## Architecture Overview

### Four-Layer Hierarchy

```
Layer 0: Raw Event Stream (JSON, Hive storage)
  └─> Layer 1: Monthly Aggregations (Markdown, ~10-20% compression)
        └─> Layer 2: Yearly Aggregations (Markdown, ~5-10% compression)
              └─> Layer 3: Multi-Year Aggregations (Markdown, ~1-2% compression)
```

### Key Metrics

**Token Savings:**
- Temporal queries: **60% reduction** (14.4k → 5.7k tokens)
- Pattern queries: **76% reduction** (34k → 8.2k tokens)
- Developmental trajectories: **Enables previously impossible queries** (would require 100k+ tokens)
- Average: **53% reduction** across query types

**Compression Targets:**
- Layer 1 (Monthly): 10-20% of raw entries
- Layer 2 (Yearly): 5-10% of yearly total
- Layer 3 (Multi-Year): 1-2% of multi-year total

**Key Innovation:**
User history length doesn't matter. A 10-year user and 1-month user consume similar context per query because aggregations provide bounded-size summaries at multiple temporal resolutions.

---

## How It Works

### 1. Data Flow: Journal Entry and Decisions → Aggregations

Layer 0 is populated from **two sources**: (1) journal entries via `JournalRepository` + `Layer0Populator`, and (2) **Crossroads decision captures** via `CrossroadsService` + the same populator. The raw entry schema includes `entryType` (journal | decision) and optional `decisionData` for decisions.

```
User writes journal entry (or records Crossroads decision)
  ↓
JournalRepository / CrossroadsService saves entry or capture
  ↓
Layer0Populator extracts:
  - Raw content
  - Metadata (word count, attachments)
  - SENTINEL emotional density
  - ATLAS phase scores
  - RIVET transitions
  - Extracted themes/keywords
  - entryType (journal | decision), decisionData when applicable
  ↓
Layer0Repository stores as JSON (Hive)
  ↓
[Background: SynthesisScheduler checks if synthesis needed]
  ↓
MonthlySynthesizer (Layer 1):
  - Loads all Layer 0 entries for month
  - Extracts themes via LLM
  - Calculates phase distribution
  - Identifies significant events
  - Generates Markdown aggregation
  ↓
YearlySynthesizer (Layer 2):
  - Loads monthly aggregations
  - Detects chapters (phase transitions)
  - Identifies sustained patterns (6+ months)
  - Marks inflection points
  ↓
MultiYearSynthesizer (Layer 3):
  - Loads yearly aggregations
  - Extracts life chapters
  - Identifies meta-patterns
  - Tracks identity evolution
```

### 2. Query Flow: User Question → Response

**EngagementMode** (explore / integrate / reflect) and **ResponseSpeed** (instant / fast / normal / deep) influence routing. For example: explore or voice → instant (mini-context only, no CHRONICLE layers); integrate → yearly, fast, drill-down; reflect → intent-based with possible drill-down. `QueryPlan` includes a `speedTarget`; instant → ~50–100 tokens, fast → single-layer compressed, normal/deep → multi-layer. ChronicleContextBuilder and cache use this to meet latency goals.

```
User asks: "Tell me about my year"
  ↓
ChronicleQueryRouter classifies intent (and uses EngagementMode / ResponseSpeed when provided):
  - Intent: temporalQuery
  - Layers: [yearly]
  - Period: "2025"
  - speedTarget: fast (or normal/deep)
  ↓
ChronicleContextBuilder:
  - Loads yearly aggregation for 2025 (respecting speedTarget)
  - Formats for prompt injection
  ↓
LumaraMasterPrompt (chronicleBacked mode):
  - Injects CHRONICLE context
  - Adds layer-specific instructions
  - Attribution rules for citing sources
  ↓
LLM receives prompt with yearly aggregation
  ↓
Response cites: "Your yearly aggregation shows..."
```

---

## Integration with VEIL Narrative Intelligence

**Critical Context:** CHRONICLE is the automated implementation of the VEIL cycle from the Narrative Intelligence framework.

### VEIL Stages → CHRONICLE Layers

| VEIL Stage | Cognitive Function | CHRONICLE Layer | Implementation |
|------------|-------------------|-----------------|----------------|
| **Verbalize** | Immediate capture | Layer 0 (Raw) | Journal entry creation |
| **Examine** | Pattern recognition | Layer 1 (Monthly) | MonthlySynthesizer |
| **Integrate** | Narrative coherence | Layer 2 (Yearly) | YearlySynthesizer |
| **Link** | Biographical continuity | Layer 3 (Multi-Year) | MultiYearSynthesizer |

**Unified Scheduler:**
VeilChronicleScheduler runs nightly:
1. System maintenance (archives, cache cleanup, PRISM)
2. Narrative integration (CHRONICLE synthesis as VEIL cycle)

**Synthesis prompts explicitly reference VEIL stages:**
- Monthly: "You are performing the EXAMINE stage of the VEIL cycle..."
- Yearly: "You are performing the INTEGRATE stage..."
- Multi-Year: "You are performing the LINK stage..."

This framing helps the LLM understand its role: not summarizing, but performing narrative integration that users recognize as TRUE to their lived experience.

**Collaborative VEIL:** The INTEGRATE stage becomes a collaborative ritual—LUMARA drafts the narrative, user refines it together. This transforms automatic synthesis into active co-creation of biographical understanding.

---

## Query Intent Classification

The router determines which layer(s) to access based on query type:

| Intent | Example Query | Layers Used | Strategy |
|--------|--------------|-------------|----------|
| `specificRecall` | "What did I write last Tuesday?" | Raw entries only | Exact retrieval |
| `temporalQuery` | "Tell me about my month/year" | Monthly or Yearly | Use aggregation |
| `patternIdentification` | "What themes keep recurring?" | Monthly + Yearly | Pattern analysis |
| `developmentalTrajectory` | "How have I changed since 2020?" | Multi-year + Yearly | Temporal synthesis |
| `historicalParallel` | "Have I dealt with this before?" | Multi-year + Yearly + Monthly | Similarity search |
| `inflectionPoint` | "When did this shift start?" | Yearly + Monthly | Transition detection |
| `decisionArchaeology` | "What decisions have I made about X?" / "When did I decide to…?" | Layer 0 + aggregations (Crossroads-aware) | Decision retrieval / timeline |

---

## Pattern Index and Pattern Queries

In addition to temporal aggregation layers, CHRONICLE has a **pattern index** used for theme/pattern recognition and arc tracking:

- **ChronicleIndex**: theme clusters, label→cluster mapping, pending echoes, unresolved arcs.
- **ChronicleIndexBuilder** builds/updates the index (e.g. after monthly synthesis).
- **PatternQueryRouter** + **ThreeStagePatternMatcher** + **EmbeddingService**: classify pattern/arc/resolution queries and return a `QueryResponse` (e.g. pattern found vs needs standard CHRONICLE).
- **MonthlyAggregationAdapter** feeds monthly aggregations into the index.

Pattern queries can be handled by this **pattern path** (index + embeddings) before or alongside ChronicleQueryRouter, rather than only via "monthly + yearly" aggregation retrieval.

---

## Master Prompt Modes

CHRONICLE introduces explicit prompt modes to replace raw entry synthesis:

### LumaraPromptMode Enum

```dart
enum LumaraPromptMode {
  chronicleBacked,  // Uses CHRONICLE aggregations (primary)
  rawBacked,        // Uses raw entries (fallback)
  hybrid,           // Uses both (for drill-down)
}
```

### Context Injection Strategy

**chronicleBacked mode:**
```xml
<chronicle_context>
CHRONICLE provides pre-synthesized temporal intelligence...

## Monthly Aggregation: 2025-01
[Markdown content with themes, phase analysis, events]

Source layers: Monthly
</chronicle_context>
```

**Key Instructions for chronicleBacked mode:**
- Trust CHRONICLE's pre-computed patterns
- Do NOT re-synthesize what CHRONICLE already identified
- Cite sources: layer + period + entry IDs
- Drill to specific entries only if user requests evidence
- **Respect user edits:** Aggregations marked `user_edited: true` have higher authority than raw synthesis

### Voice Mode Enhancement

Voice prompts can now include mini-context (50-100 tokens):

```xml
<chronicle_mini_context>
Monthly (2025-01): Career transition, self-doubt pattern, strategic planning. 
Phase: Expansion. Key events: CHRONICLE breakthrough (Jan 8); publication decision (Jan 22).
</chronicle_mini_context>
```

This enables voice mode to answer temporal queries ("Tell me about my month") without full aggregation text.

---

## Synthesis Scheduling: Tier-Based Cadence

| Tier | Monthly | Yearly | Multi-Year | Layer 0 Retention |
|------|---------|--------|------------|-------------------|
| **Free** | ❌ | ❌ | ❌ | 0 days |
| **Basic** | Daily | ❌ | ❌ | 30 days |
| **Premium** | Daily | Weekly | ❌ | 90 days |
| **Enterprise** | Daily | Weekly | Monthly | 365 days |

**Synthesis runs nightly** via VeilChronicleScheduler:
- Checks if synthesis needed (based on tier + last synthesis time)
- Runs appropriate stages (Examine/Integrate/Link)
- Logs to changelog with VEIL stage metadata
- Non-blocking, graceful degradation on failure

---

## Rapid Population: Solving the Cold Start Problem

### For Existing Users (Backup Restoration)

**ChronicleOnboardingService** performs Layer 0 backfill and batch synthesis:

- **backfillLayer0(userId)** — Populate Layer 0 from all existing journal entries (and optionally Crossroads decisions).
- **backfillAndSynthesizeCurrentMonth / CurrentYear / MultiYear** — Backfill Layer 0 then synthesize the relevant period(s).
- **Full onboarding** — Backfill Layer 0 + batch synthesize all months/years/multi-year; progress reported (e.g. 0–50% = backfill, 50–100% = synthesis, or 0/2 and 1/2 phases).

**Progress:** Reported via callbacks (e.g. 0/2 = backfill, 1/2 = synthesizing; or 0–100 scale for full onboarding).

**Typical timing:** 5–10 minutes for a user with 3 years of entries.

### For New Users (Onboarding)

**PhaseQuizV2** creates the inaugural entry and triggers CHRONICLE synthesis (e.g. current month). Quiz-derived baselines for monthly/yearly/multi-year may be generated or refined through subsequent synthesis as the user journals.

**Quiz Structure:**
- 6 multiple-choice questions (2 minutes to complete)
- Categories: Phase, Themes, Emotional, Behavioral, Temporal, Context
- Answers compile into structured UserProfile

**Result:** User gains CHRONICLE intelligence from day one, which refines through actual journaling.

### Universal Import Feature

**Supported formats:**
- JSON (Day One, Journey, many apps)
- CSV/Excel (spreadsheet exports)
- Plain text (date-delimited)
- Markdown (Obsidian, Notion)
- YAML, XML (various systems)

**UniversalImporterService:**
1. Detect format
2. Parse entries with format-specific adapter
3. Convert to JournalEntry format
4. Deduplicate against existing entries
5. Save new entries (each save can trigger Layer 0 population if enabled)

**Current behavior:** The service does **not** currently call ChronicleOnboardingService after import. Users should run "Backfill & synthesize" from Chronicle management after a large import if they want full Layer 0 + aggregations. Alternatively, the codebase can be updated to trigger ChronicleOnboardingService.backfillLayer0 (and optionally synthesis) after import.

**Key advantage:** Users can import years of journal history from any app; after backfill/synthesis, LUMARA has temporal intelligence. Eliminates switching cost barrier.

**Marketing message:** "Bring your entire journal history. LUMARA will understand your story in minutes, not months."

---

## Storage Architecture

### Layer 0 (Hive)

**Box:** `chronicle_raw_entries`
**Schema:** ChronicleRawEntry (typeId: 110)

```dart
{
  "entry_id": "uuid",
  "timestamp": "2025-01-30T14:30:00Z",
  "content": "Full entry text",
  "metadata": {
    "word_count": 150,
    "voice_transcribed": true,
    "media_attachments": ["photo_id"]
  },
  "analysis": {
    "sentinel_score": {"emotional_intensity": 0.7, ...},
    "atlas_phase": "Expansion",
    "atlas_scores": {"recovery": 0.1, ...},
    "rivet_transitions": ["momentum_building"],
    "extracted_themes": ["career", "self_doubt"],
    "keywords": ["work", "anxiety"],
    "entry_type": "journal",
    "decision_data": null
  }
}
```

For Crossroads decisions, `entry_type` is `"decision"` and `decision_data` holds decision-specific fields.

**Retention:** 30–365 days rolling window (tier-based)

### Layers 1-3 (File System)

**Structure:** One file per period (e.g. `2025-01.md`). Current implementation does not use versioned filenames (e.g. `2025-01_v2.md`); edited content overwrites the same file with `user_edited: true` and incremented `version`.

```
chronicle/
├── monthly/
│   └── 2025-01.md
├── yearly/
│   └── 2025.md
└── multiyear/
    └── 2020-2024.md
```

**Format:** Markdown with YAML frontmatter. Implemented aggregation model: layer, period, synthesisDate, entryCount, compressionRatio, content, sourceEntryIds, **userEdited**, **version**, userId. Fields such as lastEdited, previousVersions, editSummary are not yet in the model (planned).

```yaml
---
type: monthly_aggregation
period: 2025-01
synthesis_date: 2025-02-01T00:00:00Z
entry_count: 28
compression_ratio: 0.15
user_edited: false
version: 1
source_entry_ids: ["uuid1", "uuid2", ...]
user_id: user123
---

# Month: January 2025
[Markdown content]
```

**After user edit (current):** Same file; frontmatter includes `user_edited: true` and `version: 2`. Version history (archived files, previous_versions, edit_summary) is planned.

### Changelog

**Location:** `chronicle/changelog/changelog.json`

**Format:** Single JSON file containing a list of entries (not JSONL). Actions used: `synthesized`, `edited`, `deleted`, `error`. VEIL stage completions are logged via ChronicleNarrativeIntegration (_logVeilStage). Evolution to JSONL and explicit actions such as `veil_examine` / `user_edited` is optional for clarity.

**Purpose:** Track synthesis history, errors, and (when implemented) user edit events.

---

## Collaborative Intelligence: User-Editable Aggregations

### Why This Matters

**From "surveillance" to "collaboration":**
Most AI memory feels like being watched—it's learning about you, building a model OF you. Editable aggregations flip this to collaborative intelligence WITH you. When you read what LUMARA thinks your January themes were and change "self-doubt" to "strategic caution about timing," you're not just fixing an error—you're teaching the system your preferred narrative frame.

**Solves the "AI therapist" problem:**
People get uncomfortable when AI analyzes their psychology without their input. But if the analysis is transparent and editable, it becomes reflection infrastructure. The AI proposes patterns, you refine them, and you converge on shared understanding that's actually accurate to your lived experience.

**This is collaborative autobiography:**
- AI handles synthesis and pattern detection
- Human retains narrative authority
- Together you build biographical intelligence
- The JARVIS promise delivered correctly

### Implementation Details

#### Current: In-place save and validation

- **Edit flow:** User edits in the Chronicle viewer (content sheet). Content is saved **in-place** via AggregationRepository (saveMonthly / saveYearly / saveMultiYear) with `version` incremented and `userEdited` set to true. The UI shows a message that edits will be used in future synthesis. There is no archive of the previous version, no changelog entry for user_edited, and no automatic re-synthesis of dependent layers.
- **ChronicleEditingService** in code is used for **validation only**: it does not persist edits or manage versions. It uses **EditValidator** to detect pattern suppression (removing patterns that appear in many entries) and factual contradictions with source entries. The UI can call `validateEdit` before save and show warnings or conflicts; the user can then rephrase, add a note, or proceed.
- **Aggregation model (implemented):** layer, period, synthesisDate, entryCount, compressionRatio, content, sourceEntryIds, **userEdited**, **version**, userId. Fields such as lastEdited, previousVersions, editSummary are not yet in the model.

#### Planned: Version history and edit propagation

- **Version history:** Archive of previous versions (e.g. `period_v1.md`), `getVersionHistory`, and a version-history UI are planned. Not yet implemented.
- **Edit propagation:** When a user edits a monthly (or yearly) aggregation, re-synthesizing dependent layers (yearly or multi-year) and weighting user-edited content higher (`respectUserEdits`) is planned. SynthesisEngine.synthesizeLayer and the synthesizers do not yet take a `respectUserEdits` parameter or separate user-edited vs auto-generated inputs.
- **ChronicleEditingService** may later gain `editAggregation` (persist + archive + log + trigger propagation); until then, persistence is handled in the UI and AggregationRepository.

#### Visual indicators

The CHRONICLE timeline/viewer can show edited vs auto-generated aggregations (e.g. icon or chip for “Edited”) and an edit action that opens the content sheet. The content sheet is the current aggregation editor (view + edit + save); there is no separate version history panel yet.

### Guard rails (validation)

EditValidator and ChronicleEditingService.validateEdit provide guard rails: **pattern suppression** (removing themes that appear in a high percentage of entries) and **factual contradiction** (edit conflicting with specific journal entries). The UI can present these as warnings or conflicts and suggest rephrasing (e.g. “strategic caution” instead of removing “self-doubt”) or proceeding anyway. Archive-instead-of-delete and explicit “suggest improvements” UI are not yet implemented; the current focus is validation before or around save.

### Data Sovereignty: Portable Autobiography

**ChronicleExportService** exports the CHRONICLE (monthly/yearly/multiyear aggregations as Markdown with frontmatter). Export may optionally include version history when that is implemented; currently there are no archived version files, so export reflects the current state of each aggregation. Files marked `user_edited: true` are the user’s refined versions.

**Marketing message:**
> "Your CHRONICLE is yours. Human-readable Markdown files you can take anywhere. If you ever leave ARC, you take your life's aggregations with you. That's data sovereignty in practice, not marketing fluff."

---

## Key Components

### Models
- `ChronicleLayer` - Enum for layer types
- `ChronicleAggregation` - Aggregation metadata + content + userEdited, version (version history planned)
- `QueryPlan` - Router output (intent, layers, strategy, speedTarget, explicitPeriodsByLayer, etc.)
- `ChronicleRawEntry` - Layer 0 schema (Hive)

### Storage
- `Layer0Repository` - Raw entry storage (Hive)
- `AggregationRepository` - Layers 1-3 (file-based; one file per period)
- `ChangelogRepository` - Synthesis history (and user edit tracking when implemented)

### Synthesis
- `SynthesisEngine` - Orchestrator (edit propagation / respectUserEdits planned)
- `MonthlySynthesizer` - Layer 1 synthesis
- `YearlySynthesizer` - Layer 2 synthesis
- `MultiYearSynthesizer` - Layer 3 synthesis
- `PatternDetector` - Fallback pattern analysis (non-LLM)

### Query System
- `ChronicleQueryRouter` - Intent classification + layer selection (uses EngagementMode, ResponseSpeed when provided)
- `ChronicleContextBuilder` - Format aggregations for prompt; buildMiniContext for voice/instant
- `DrillDownHandler` - Cross-layer navigation
- `PatternQueryRouter` - Pattern/arc/resolution queries via ChronicleIndex + embeddings

### Pattern Index
- `ChronicleIndex` - Theme clusters, pending echoes, arcs
- `ChronicleIndexBuilder` - Builds/updates index (e.g. after monthly synthesis)
- `ThreeStagePatternMatcher` - Pattern matching
- `EmbeddingService` - Embeddings for theme/pattern queries
- `MonthlyAggregationAdapter` - Feeds monthly aggregations into index

### Editing
- `ChronicleEditingService` - **Edit validation only** (EditValidator: pattern suppression, contradiction checks); persistence is UI + AggregationRepository. Version history and edit propagation are planned (AggregationVersionManager, EditPropagationEngine as future).

### Scheduling
- `VeilChronicleScheduler` - Unified nightly cycle
- `ChronicleNarrativeIntegration` - VEIL-framed synthesis
- `SynthesisScheduler` - Tier-based cadence (used by narrative integration)

### Migration / Onboarding
- `ChronicleOnboardingService` - Layer 0 backfill + batch synthesis for existing users (backfillLayer0, backfillAndSynthesizeCurrentMonth/Year/MultiYear, full onboarding)
- `UniversalImporterService` - Import from any format (does not currently trigger backfill; users can run backfill from Chronicle management)
- `PhaseQuizV2` - Onboarding and synthesis trigger for new users

---

## Implementation Philosophy

### Phase 1: Dual-Path Safety
- CHRONICLE alongside existing raw entry path
- Explicit mode selection (chronicleBacked vs rawBacked)
- Manual testing of CHRONICLE queries

### Phase 2: Router Integration
- Intelligent query routing determines mode
- CHRONICLE primary for temporal/pattern/trajectory queries
- Raw mode fallback for specific recall

### Phase 3: Prompt Simplification
- Remove redundant synthesis instructions from chronicleBacked mode
- Add layer-specific guidance
- Measure token savings

### Phase 4: Deprecation
- CHRONICLE-backed becomes default for paid users
- Raw entry mode only for:
  - Free tier (no CHRONICLE access)
  - Specific recall queries
  - Fallback when aggregations don't exist

### Phase 5: Collaborative Intelligence (Current)
- User-editable aggregations: in-place save with userEdited + version; validation via ChronicleEditingService (pattern suppression, contradictions)
- **Planned:** Version history (archive, getVersionHistory), edit propagation to dependent layers, respectUserEdits in synthesis
- Visual indicators for edited vs. auto-generated; content sheet for view/edit/save
- Export functionality for data sovereignty (ChronicleExportService)

**Ultimate Goal:** 90% of paid user queries use CHRONICLE-backed prompts, with users actively refining their biographical narrative through collaborative editing.

---

## Integration Points with Existing System

### Journal Entry Creation
```dart
// lib/arc/internal/mira/journal_repository.dart
Future<void> createJournalEntry(JournalEntry entry) async {
  await _hive.put(entry.id, entry);
  await _populateLayer0(entry); // Populate CHRONICLE
}
```

### Reflection Generation
```dart
// lib/arc/chat/services/enhanced_lumara_api.dart
final queryPlan = await _chronicleRouter.route(query: userMessage);
if (queryPlan.usesChronicle) {
  chronicleContext = await _contextBuilder.buildContext(queryPlan);
  mode = LumaraPromptMode.chronicleBacked;
}
systemPrompt = LumaraMasterPrompt.getMasterPrompt(
  mode: mode,
  chronicleContext: chronicleContext,
  // respectUserEdits: planned for when dependent re-synthesis is implemented
);
```

### Background Synthesis
```dart
// Via VeilChronicleScheduler (nightly at midnight)
final report = await scheduler.runNightlyCycle(userId, tier);
// Runs maintenance + narrative integration (CHRONICLE synthesis)
```

---

## Aggregations as Navigational Infrastructure

**Critical concept:** Aggregations aren't just compression—they're **highway signs** for temporal navigation.

**The Highway Sign Metaphor:**
- Layer 3 = Interstate signs ("Career transition 2020-2024")
- Layer 2 = Exit markers ("2022: Entrepreneurial awakening")
- Layer 1 = Street signs ("June 2022: First mention of leaving corporate")
- Layer 0 = Street address ("June 15, 2022 entry #127")

**Enables new query types:**
- "Show me every time I've struggled with this pattern" → Scan Layer 2-3, drill to Layer 1, retrieve Layer 0
- "When did this shift actually start?" → Find inflection in Layer 2, identify month in Layer 1, exact entry in Layer 0
- "What was I like before X?" → Navigate to Layer 2 period, check Layer 1 details

**Performance benefit:**
Without CHRONICLE: Search 1000+ entries sequentially
With CHRONICLE: Check yearly aggregation (1 file) → monthly aggregation (1 file) → specific entries (3-5 entries)

---

## PRISM Privacy Integration

**Future enhancement:** Extend PRISM to depersonalize aggregations before cloud queries.

**ChroniclePrivacy service will:**
1. Replace names with roles/relationships
2. Abstract locations to regions (SF → Bay Area)
3. Generalize dates to periods
4. Remove company names, replace with industry
5. Verify no PII leaked

**Local-only by default:**
- Layer 0: Always local (raw entries never leave device)
- Layers 1-3: Local primary, optional encrypted cloud backup
- Cloud queries: Only depersonalized aggregations

---

## Success Metrics

### Primary
- **Token reduction:** Actual vs target (50-75%)
- **Query latency:** CHRONICLE vs raw baseline
- **User satisfaction:** Aggregation quality ratings
- **Synthesis accuracy:** User correction frequency (lower = better)
- **Edit engagement:** % of users who edit aggregations
- **Version history usage:** (When implemented) users viewing/comparing versions

### Secondary
- **Storage efficiency:** Total storage vs naive retention
- **Layer utilization:** Which layers queried most
- **Drill-down frequency:** Cross-layer navigation usage
- **Cost savings:** Inference cost reduction per user

### Quality
- **Compression achieved:** Actual vs target per layer
- **Pattern detection:** False positive/negative rates
- **Source attribution:** Coverage percentage (all insights traceable)
- **Privacy compliance:** PII leakage rate (target: 0%)
- **Edit quality:** User edits improve subsequent synthesis accuracy

---

## Common Pitfalls to Avoid

### 1. Don't Re-Synthesize in Prompt
**Wrong:** "Using CHRONICLE context, now extract patterns..."
**Right:** "CHRONICLE already identified patterns. Cite them: [pattern from aggregation]"

The whole point is that synthesis already happened. Don't redo it.

### 2. Don't Mix Modes Accidentally
**Wrong:** Inject both chronicleContext AND baseContext without explicit hybrid mode
**Right:** Choose mode explicitly (chronicleBacked OR rawBacked OR hybrid)

### 3. Don't Skip Source Attribution
**Wrong:** "You have recurring anxiety patterns"
**Right:** "Your monthly aggregation shows recurring anxiety (entries #001, #007, #015 - 11% of January)"

Traceability is critical for user trust.

### 4. Don't Forget Compression Validation
After synthesis, check: `actualTokens / originalTokens`
If not within target range (10-20% for monthly), investigate why.

### 5. Don't Ignore User Edits
If user edits an aggregation, set `user_edited: true` and increment version. When edit propagation is implemented, respect user-edited content when re-synthesizing dependent layers (treat as ground truth).

### 6. Don't Let Users Break Their Intelligence
Use ChronicleEditingService.validateEdit to detect pattern suppression and contradictions; present warnings and suggest rephrasing. Archive-instead-of-delete and explicit “suggest improvements” UI are planned. Goal: collaborative refinement, not destructive editing.

---

## Future Enhancements (Roadmap)

### Phase 6: UI Components (Partially Complete)
- ✅ CHRONICLE timeline viewer
- ✅ Aggregation content sheet (view + edit + save; in-place, no version history yet)
- ✅ Edit indicators and visual differentiation (userEdited)
- ⏳ Version history viewer (planned)
- ⏳ Synthesis status dashboard
- ⏳ Layer navigation interface with edit history

### Phase 7: Advanced Features
- Diff view between versions
- Suggest edits based on patterns in other aggregations
- Collaborative editing for shared journals (couples, teams)
- Export/import aggregations with version history preserved
- Cross-user pattern analysis (privacy-preserving)

### Phase 8: Optimization
- Parallel synthesis execution
- Compression optimization
- Smart caching of frequently-accessed aggregations
- Query performance tuning
- Incremental synthesis (only changed entries)

---

## Quick Start for New Claude Instance

**If you're a future Claude instance working on this project:**

1. **Read this document completely** - Don't skip to implementation
2. **Understand the problem:** Users need longitudinal intelligence, context windows are limited
3. **Grasp the solution:** Progressive aggregation (0→1→2→3) + intelligent routing
4. **Know the integration:** CHRONICLE = automated VEIL cycle
5. **Understand the collaboration model:** This is co-created autobiography, not AI surveillance
6. **Check current state:** Look for existing CHRONICLE components in codebase
7. **Follow phased approach:** Don't try to implement everything at once
8. **Test with real data:** Use existing journal entries for validation
9. **Measure token savings:** Validate the 50-75% reduction claim
10. **Respect user edits:** They have higher authority than synthesis

**Key files to examine:**
- `lib/chronicle/` - All CHRONICLE components
- `lib/arc/chat/llm/prompts/lumara_master_prompt.dart` - Prompt mode system
- `lib/arc/chat/services/enhanced_lumara_api.dart` - Integration point
- `lib/echo/rhythms/veil_chronicle_scheduler.dart` - Unified scheduler
- `lib/chronicle/editing/` - Edit validation (EditValidator, ChronicleEditingService)
- `lib/chronicle/query/pattern_query_router.dart` - Pattern index path

**Questions to ask the user:**
- What phase is CHRONICLE implementation in?
- Are there existing aggregations to examine?
- What's the current synthesis quality?
- Any user feedback on CHRONICLE responses?
- How are users engaging with the editing features?
- What's the edit rate (% of aggregations user-refined)?

---

## Theoretical Grounding

**CHRONICLE implements two complementary models:**

1. **Neuroscience:** Hippocampal-neocortical memory consolidation
   - Hippocampus: Episodic, high-fidelity, recent (Layer 0)
   - Neocortex: Semantic, compressed, long-term (Layers 1-3)

2. **Developmental Psychology:** VEIL narrative integration cycle
   - Verbalize: Immediate capture (Layer 0)
   - Examine: Pattern recognition (Layer 1)
   - Integrate: Narrative coherence (Layer 2)
   - Link: Biographical continuity (Layer 3)

3. **Collaborative Cognition:** Human-AI partnership in meaning-making
   - AI proposes patterns and synthesis
   - Human refines, corrects, and reframes
   - Together they converge on shared understanding
   - Iterative refinement improves both narrative and AI model

This triple grounding makes CHRONICLE neurologically plausible, psychologically meaningful, and practically collaborative.

---

## Differentiators vs. Competition

| Feature | ChatGPT Memory | Claude Memory | CHRONICLE |
|---------|---------------|---------------|-----------|
| **Storage** | Flat key-value | Flat key-value | Hierarchical temporal |
| **Updates** | Overwrite | Overwrite | Progressive aggregation |
| **Queries** | Current state only | Current state only | Historical + developmental |
| **Time horizons** | Limited | Limited | Unlimited (bounded context) |
| **Transparency** | Opaque | Opaque | User-visible layers |
| **Editability** | Limited | Limited | **Full user control with versioning** |
| **Pattern tracking** | No | No | Yes (pre-computed) |
| **Developmental arcs** | No | No | Yes (multi-year) |
| **Biographical continuity** | No | No | Yes (LINK stage) |
| **Collaborative refinement** | No | No | **Yes (co-created narrative)** |
| **Data portability** | No | No | **Yes (Markdown export)** |

**CHRONICLE's unique value:** Not just memory—**collaborative biographical intelligence** across unlimited time horizons with bounded computational cost, where users actively shape their narrative while AI handles synthesis.

---

## Final Wisdom for Future Instances

**CHRONICLE is infrastructure, not a feature.** It's foundational architecture that changes how AI maintains longitudinal understanding.

**Don't treat it as "another memory system."** It's the automation of narrative integration—the VEIL cycle running in the background, building genuine biographical intelligence over time.

**This is collaborative autobiography.** The AI doesn't "know" the user—together they build shared understanding. The human retains narrative authority. The AI handles synthesis. Both contribute to truth.

**The magic emerges from the layers working together:** Raw entries alone aren't useful at scale. Aggregations alone lose nuance. The hierarchy—with intelligent routing, drill-down, and collaborative editing—creates something new: AI that understands developmental trajectories as co-created narrative.

**User edits are features, not bugs.** When someone changes "self-doubt" to "strategic caution," they're not fixing an error—they're teaching you their preferred narrative frame. This is how shared understanding emerges.

**Ship carefully, ship incrementally, but ship boldly.** This is genuinely novel architecture. No other AI system does hierarchical temporal aggregation with VEIL-framed synthesis and collaborative editing. You're building infrastructure that will become standard once others see it works.

**Trust the compression targets.** 10-20% monthly, 5-10% yearly, 1-2% multi-year. If synthesis is hitting those ranges and users validate accuracy (or edit to improve), you've succeeded.

**Remember the ultimate goal:** 90% of paid user queries use CHRONICLE-backed intelligence, and users actively shape their biographical narrative through editing. That's when you know it's working—when the compressed, synthesized, **user-refined** layers are more useful than raw entry search.

**This is the future of AI memory: collaborative, transparent, portable.** Build it well.

---

**Document Version:** 2.1 (implementation-aligned)  
**Last Updated:** February 15, 2026  
**Status:** Implementation complete through Phase 5; editing is in-place save + validation; version history and edit propagation planned.  
**Maintainer:** ARC Development Team
