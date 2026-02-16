# CHRONICLE Paper vs Implementation: Key Differences and Suggested Edits

This document compares the CHRONICLE architecture paper (Quick Reference Guide) to the actual codebase and suggests **inserts**, **updates**, and **deletes** so the paper accurately reflects implementation.

---

## 1. Key Differences Summary

| Area | Paper | Implementation | Action |
|------|--------|----------------|--------|
| **Backfill service** | ChronicleBackfillService | ChronicleOnboardingService (backfillLayer0, backfillAndSynthesize*) | Update name + behavior |
| **User edit persistence** | ChronicleEditingService.editAggregation + version archive + propagation | In-place save in UI (repo.saveMonthly/Yearly/MultiYear); no archive, no propagation | Update / add “current vs planned” |
| **Version history** | previousVersions, archiveVersion, getVersionHistory | Not implemented (no archived files, no lastEdited/editSummary in model) | Soften or mark as roadmap |
| **Edit propagation** | _triggerDependentResynthesis on edit | Not implemented | Mark as planned |
| **Layer 0 source** | Journal only | Journal + Crossroads decisions (entryType, decisionData) | Insert |
| **Query routing** | Intent only | Intent + EngagementMode + ResponseSpeed (instant/fast/normal/deep) | Insert |
| **Query intent** | 6 intents | 7 (add decisionArchaeology) | Insert |
| **Pattern system** | Pattern queries use “monthly + yearly” | Separate PatternQueryRouter, ChronicleIndex, embeddings, theme clusters | Insert new section |
| **Changelog format** | JSONL, actions veil_examine / user_edited | Single JSON file, actions synthesized/edited/deleted/error | Update |
| **Universal importer → backfill** | “Run ChronicleBackfillService” | Saves to journal only; no explicit post-import backfill call | Update / recommend insert in code |
| **Phase Quiz instant aggregations** | Quiz → instant monthly/yearly/multi-year baseline | Onboarding triggers synthesis; “instant” quiz-derived aggregations not clearly as in paper | Clarify |
| **Aggregation model** | lastEdited, previousVersions, editSummary | userEdited, version only; no lastEdited/previousVersions/editSummary | Update model description |
| **Synthesis respectUserEdits** | YearlySynthesizer weights user-edited months | Not implemented (no parameter, no weighting in synthesizers) | Mark as planned |

---

## 2. Suggested INSERTS (add to paper)

### 2.1 Layer 0: Crossroads decisions

**Where:** In “Data Flow” and “Layer 0 (Hive)” / Raw Entry Schema.

**Insert:**

- Layer 0 is populated from **two sources**: journal entries (via `JournalRepository` + `Layer0Populator`) and **Crossroads decision captures** (via `CrossroadsService` + same populator). Raw entry schema includes `entryType` (journal | decision) and optional `decisionData` for decisions.

### 2.2 Query routing: EngagementMode and ResponseSpeed

**Where:** “Query Flow” and “Query Intent Classification”.

**Insert:**

- **EngagementMode** (explore / integrate / reflect) influences routing: e.g. explore/voice → instant (no CHRONICLE layers); integrate → yearly, fast, drill-down; reflect → intent-based with possible drill-down.
- **ResponseSpeed** (instant / fast / normal / deep) is part of `QueryPlan`. Instant → mini-context only (~50–100 tokens); fast → single-layer compressed; normal/deep → multi-layer. Context builder and cache use this to meet latency goals.

### 2.3 Query intent: decisionArchaeology

**Where:** Table “Query Intent Classification”.

**Insert row:**

| `decisionArchaeology` | “What decisions have I made about X?” / “When did I decide to…” | As implemented (e.g. Layer 0 + Crossroads or aggregations) | Decision retrieval / timeline |

(Exact “Layers Used” and “Strategy” to be aligned with current router logic.)

### 2.4 Pattern index and pattern query path (new subsection)

**Where:** After “Query Intent Classification” or under “Key Components”.

**Insert subsection:**

**Pattern index and pattern queries**

- In addition to temporal aggregation layers, CHRONICLE has a **pattern index** used for theme/pattern recognition and arc tracking:
  - **ChronicleIndex**: theme clusters, label→cluster mapping, pending echoes, unresolved arcs.
  - **ChronicleIndexBuilder** builds/updates the index (e.g. after monthly synthesis).
  - **PatternQueryRouter** + **ThreeStagePatternMatcher** + **EmbeddingService**: classify pattern/arc/resolution queries and return `QueryResponse` (e.g. pattern found vs needs standard CHRONICLE).
  - **MonthlyAggregationAdapter** feeds monthly aggregations into the index.
- Pattern queries can thus be handled by the **pattern path** (index + embeddings) rather than only “monthly + yearly” aggregation retrieval. Document where this path is invoked (e.g. before or alongside ChronicleQueryRouter) so the paper matches the code.

### 2.5 Universal importer and backfill

**Where:** “Universal Import Feature”.

**Insert:**

- **Current behavior:** UniversalImporterService saves imported entries via JournalRepository; each create can trigger Layer 0 population (if enabled). The service does **not** currently call ChronicleOnboardingService (or equivalent) to run a full backfill/synthesis after import.
- **Recommendation:** Either document that users should run “Backfill & synthesize” from Chronicle management after import, or add an explicit post-import step that triggers ChronicleOnboardingService.backfillLayer0 and/or backfillAndSynthesize* so the paper’s “Run ChronicleBackfillService” (or equivalent) is accurate.

---

## 3. Suggested UPDATES (change in paper)

### 3.1 Backfill and onboarding naming

- **Replace** “ChronicleBackfillService” with **ChronicleOnboardingService**.
- **Update** “Rapid Population” so that:
  - **Existing users:** ChronicleOnboardingService.backfillLayer0 + backfillAndSynthesizeCurrentMonth / backfillAndSynthesizeCurrentYear / backfillAndSynthesizeMultiYear, or full onboarding (backfill + batch synthesis). Progress is reported (e.g. 0/2 = backfill, 1/2 = synthesizing; or 0–100 scale for full onboarding).
  - **New users:** Describe actual behavior: Phase Quiz creates inaugural entry and triggers CHRONICLE synthesis (e.g. current month); clarify whether “instant” monthly/yearly/multi-year baselines are quiz-derived or synthesis-derived.

### 3.2 User editing and versioning (reflect current implementation)

- **Aggregation model:** State that the **implemented** aggregation has: layer, period, synthesisDate, entryCount, compressionRatio, content, sourceEntryIds, **userEdited**, **version**, userId. **Not yet in model:** lastEdited, previousVersions, editSummary (treat as roadmap if desired).
- **Edit flow:** Replace the detailed “ChronicleEditingService.editAggregation” pseudocode with:
  - **Current:** User edits in Chronicle viewer (_ChronicleContentSheet); content is saved in-place via AggregationRepository (saveMonthly/Yearly/MultiYear) with version incremented and userEdited set to true. No archive of previous version, no changelog entry for user_edited, no automatic re-synthesis of dependent layers.
  - **ChronicleEditingService** in code: used for **validation** only (EditValidator: pattern suppression, contradiction checks); it does not persist edits or manage versions.
- **Version history:** Remove or clearly mark as **planned** the “archiveVersion”, “getVersionHistory”, and “_ChronicleContentSheet → VersionHistorySheet” flow until implementation exists. Optionally keep a short “Planned: version history and edit propagation” sentence.

### 3.3 Synthesis and user edits

- **SynthesisEngine.synthesizeLayer:** No `respectUserEdits` parameter in current API. Yearly/MultiYear synthesizers do not yet separate or weight user-edited vs auto-generated monthlies.
- **Update** the “Synthesis with edit respect” snippet to: “Planned: when user edits a monthly aggregation, yearly (and multi-year) re-synthesis will weight user-edited content higher (respectUserEdits). Not yet implemented.”

### 3.4 Storage: aggregation files and changelog

- **Aggregation files:** Implementation uses a single file per period (e.g. `2025-01.md`), not `2025-01_v2.md` for edited versions. Frontmatter includes user_edited and version but not last_edited, previous_versions, or edit_summary. Update the “After user edit” YAML example to match (only user_edited + version), or label it as target schema.
- **Changelog:** Implementation uses a single file `chronicle/changelog/changelog.json` (and in-code comment references “one entry per line (JSONL)” but parsing is list-based). Actions used: synthesized, edited, deleted, error. VEIL stage logging is done via ChronicleNarrativeIntegration (_logVeilStage). Update the changelog section to describe this format and these actions; optionally add that JSONL and explicit veil_examine/user_edited actions are a desired evolution.

### 3.5 Key components list

- **Rename** “ChronicleBackfillService” → **ChronicleOnboardingService**.
- **Rename** “UniversalImporterService” is correct; add that it does not currently trigger backfill (see 2.5).
- **Editing:** State that **ChronicleEditingService** currently provides **edit validation** (EditValidator, pattern suppression, contradiction detection); **persistence and versioning** are done in the UI + AggregationRepository. Omit or mark as future: AggregationVersionManager, EditPropagationEngine.

---

## 4. Suggested DELETES (or soften to “planned”)

### 4.1 Remove or relabel as “planned”

- **editAggregation** with archiveVersion + new version file + changelog + _triggerDependentResynthesis — replace with “Planned” or “Current: in-place save only.”
- **getVersionHistory** and loading archived versions — mark as planned until implemented.
- **AggregationEditorScreen / VersionHistorySheet** — either remove or describe as “Target UI” and note that current UI is the Chronicle viewer’s content sheet with save (no version history panel).
- **Guard rails:** _validateEdit (continuity gaps / theme removal) — implementation has EditValidator (suppression/contradiction); keep the concept but align wording with EditValidator and ChronicleEditingService.validateEdit. Remove or soften “archive instead of delete” and “suggest improvements” if those flows are not yet in the app.
- **Export:** exportChronicle with “previous_versions” and version history files — implementation (ChronicleExportService) may not include archived versions; adjust description to match what export actually does.

### 4.2 Keep but clarify

- **Collaborative Intelligence** and “user retains narrative authority”: keep; implementation does set userEdited and shows a “Your edits will be used in future synthesis” message, but dependent re-synthesis and version history are not there yet.
- **Data flow (Journal → Layer 0 → synthesis):** keep; Layer0Populator is called from JournalRepository and CrossroadsService; SynthesisScheduler / ChronicleNarrativeIntegration run synthesis. Add Crossroads as a second Layer 0 source.

---

## 5. Implementation Details to Align

- **Box name:** `chronicle_raw_entries` — matches; no change.
- **LumaraPromptMode** (chronicleBacked, rawBacked, hybrid) — matches enhanced_lumara_api and lumara_master_prompt; no change.
- **VEIL → CHRONICLE mapping** and VeilChronicleScheduler — matches ChronicleNarrativeIntegration and scheduler; no change.
- **Tier-based cadence** (Free/Basic/Premium/Enterprise) — matches SynthesisScheduler and SynthesisCadence; no change.
- **ChronicleContextBuilder** and **buildMiniContext** — matches; paper’s “chronicle_mini_context” and voice mini-context are implemented.

---

## 6. Recommended Next Steps

1. **Paper:** Apply the inserts/updates/deletes above so the document is “implementation-accurate” and clearly marks roadmap (version history, edit propagation, respectUserEdits).
2. **Code (optional):** Have UniversalImporterService call ChronicleOnboardingService after import (e.g. backfillLayer0 + optional synthesis) so behavior matches the intended “backfill after import” story.
3. **Code (optional):** Add lastEdited, editSummary (and optionally previousVersions) to ChronicleAggregation and frontmatter; implement archive-on-edit and getVersionHistory when prioritizing collaborative editing and version history.

---

**Document version:** 1.0  
**Purpose:** Align CHRONICLE paper with current EPI implementation and suggest minimal edits for accuracy and clarity.
