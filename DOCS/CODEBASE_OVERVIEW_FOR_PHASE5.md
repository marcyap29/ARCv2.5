# Codebase Overview for Phase 5 Prompts

**Purpose:** Ground Phase 5 prompts in what actually exists. Use this to sequence tasks and avoid inventing structure.

**Repo root:** `ARCv2.5/`  
**Flutter app:** `ARC_MVP/EPI/` (package `my_app`)  
**Firebase project:** `arc-epi`

---

## 1. Repository layout

| Path | Description |
|------|-------------|
| `ARC_MVP/EPI/` | Flutter app (iOS/Android). `lib/` = Dart source, `test/` = tests. |
| `functions/` | Firebase Cloud Functions (TypeScript). `src/` compiles to `lib/`. |
| `scripts/` | Deploy scripts; `scripts/cloudflare-workers/media-upload/` = R2 upload worker. |
| `workers/` | Other Cloudflare workers (chronicle-context, entry-classifier, etc.) — separate from `scripts`. |
| `DOCS/` | Root docs (this file). `ARC_MVP/EPI/DOCS/` = app-specific (FIREBASE.md, CLOUD_VISION_SETUP.md, etc.). |
| `firebase.json`, `firestore.rules` | Firebase config at repo root. |

---

## 2. Flutter app entry and shell

- **Entry:** `lib/main.dart` → `bootstrap()` → `App()` (`lib/app/app.dart`).
- **Feature flag:** `lib/core/feature_flags.dart` — `FeatureFlags.USE_UNIFIED_FEED = true` (current default).
- **Home:** `lib/shared/ui/home/home_view.dart` — `HomeCubit` drives `selectedIndex`; `_getPageForIndex(index)` returns the page widget.

**Unified feed mode tabs (index → widget):**

| Index | Tab label | Widget |
|-------|-----------|--------|
| 0 | LUMARA | `UnifiedFeedScreen` |
| 1 | Agents | `AgentsScreen` |
| 2 | Outputs | `OutputsTabScreen` |
| 3 | Settings | `SettingsView` |

Legacy mode (when `USE_UNIFIED_FEED` is false): LUMARA | Conversations (no Agents/Outputs/Settings as separate tabs).

---

## 3. Main lib/ domains (Flutter)

- **`lib/arc/`** — Chat (LUMARA UI, cubit, prompts), unified feed, outputs, timeline, voice, journal capture, internal (e.g. Prism adapter).
- **`lib/lumara/`** — Orchestrator, intent classifier, subsystems; **`lumara/agents/`** = Research, Writing, Vision, Agents UI (screens, services, widgets).
- **`lib/chronicle/`** — Dual chronicle, storage, synthesis, scheduling, embeddings, retrieval.
- **`lib/prism/`** — Atlas, pipelines, extractors, MCP, vital, repositories.
- **`lib/echo/`** — Echo service, prompts, providers, response (e.g. LumaraAssistantCubit echo path).
- **`lib/mira/`** — Store (MCP, ArcX), ingest, retrieval, reasoning, veil.
- **`lib/core/`** — Feature flags, services (media pick, audio, etc.), constants, LLM, Mira.
- **`lib/services/`** — SwarmSpace (PrismService, plugin_activity_log_service, swarmspace_client), Lumara, Sentinel, etc.
- **`lib/shared/`** — UI (home, settings, onboarding), widgets, tab bar, app colors, text styles.

---

## 4. LUMARA and Agents flow (what exists)

**Reaching Research and “Scan document”:**

1. User is in **Unified feed mode** and taps **Agents** tab → `AgentsScreen` (`lib/lumara/agents/screens/agents_screen.dart`).
2. AgentsScreen shows cards: **Writing**, **Research**, **Vision / OCR**, **Plugin Activity**, **All SwarmSpace Capabilities**.
3. Tapping **Research** → `Navigator.push(ResearchScreen)`.
4. **ResearchScreen** (`lib/arc/chat/ui/research_screen.dart`): query field, **“Scan document”** button (outlined) next to **“Run research”**. Scan document opens gallery/camera → image picker → `DocumentParser.parseDocument()` → result stored as `_documentContext` and passed to `runResearchPipeline(..., documentContext: _documentContext)`.

**Key files:**

- **Research:** `research_screen.dart`, `research_pipeline.dart`, `research_agent.dart`, `synthesis_engine.dart`, `research_models.dart`, `research_artifact_repository.dart`, `swarmspace_web_search_tool.dart`, `research_report_detail_screen.dart`, `research_report_card.dart`.
- **Document/vision:** `lumara/agents/vision/document_parser.dart`, `parsed_document.dart`. Parser uses vision OCR (PrismService / backend) then Gemini for structured JSON.
- **Writing:** `writing_screen.dart`, `writing_agent.dart`, `draft_composer.dart`, `theme_tracker.dart`, `writing_models.dart`, `writing_prompts.dart`, `content_draft.dart`, `writing_draft_repository.dart`.
- **Agents UI:** `agents_screen.dart`, `research_agent_tab.dart`, `writing_agent_tab.dart`, `vision_ocr_screen.dart`, `plugin_catalog_screen.dart`, `plugin_activity_screen.dart`.
- **Persistence:** `agents_chronicle_service.dart`, `report_export_service.dart`, `docx_export_helper.dart`.

**Chat/LUMARA (non-Agents):** `lumara_chat_redesign_screen.dart`, `lumara_assistant_cubit.dart`, `enhanced_lumara_api.dart`, `lumara_mode_definition.dart`, `lumara_reflection_settings_service.dart`, `lumara_settings_screen.dart`. Orchestrator: `lumara_chat_orchestrator.dart`, `chat_intent_classifier.dart` — can route to Research/Writing.

---

## 5. SwarmSpace and backend

**Client (Flutter):**

- `services/swarmspace/prism_service.dart` — calls Firebase callable (e.g. swarmspaceRouter) and/or HTTP (e.g. vision OCR).
- `services/swarmspace/swarmspace_client.dart` — low-level invoke to SwarmSpace.
- `services/swarmspace/plugin_activity_log_service.dart` — logs to Firestore `plugin_activity_log`.

**Firebase Functions (`functions/src/`):**

- **`functions/swarmspaceRouter.ts`** — Main SwarmSpace router. `PLUGIN_REGISTRY` maps `plugin_id` → `{ workerUrl, requiredTier, capabilities, ... }`. Registered plugins include: `gemini-flash`, `brave-search`, `semantic-scholar`, `weather`, `wikipedia`, `currency`, **`vision-ocr`** (points to Cloud Function `visionOcrInvoke`), `url-reader`, **`media-upload`** (R2 worker), `tavily-search`, `exa-search`, `perplexity-sonar`. Router forwards with `X-SwarmSpace-User-Id`, `X-SwarmSpace-User-Tier`, `Authorization: Bearer SWARMSPACE_INTERNAL_TOKEN`.
- **`functions/visionOcrInvoke.ts`** — HTTP endpoint for vision/OCR; used by app and document parser.
- **`functions/index.ts`** — Exports: `swarmspaceRouter`, `swarmspacePluginStatus`, `swarmspacePluginCatalog`, `visionOcrInvoke`, plus `sendChatMessage`, `analyzeJournalEntry`, `proxyGemini`, etc.

**Cloudflare (R2 media-upload):**

- `scripts/cloudflare-workers/media-upload/` — Worker: POST `/upload` (multipart, Bearer token), GET `/media/:path`. Stores objects in R2 at `media/{uuid}.{ext}`. See `scripts/cloudflare-workers/media-upload/README.md` for setup and deploy.

---

## 6. Key data and config

- **Firestore:** e.g. `plugin_activity_log`, user/LLM config, chronicle data — see `firestore.rules` and `ARC_MVP/EPI/DOCS/FIRESTORE_ACTIVITY_INDEX_AND_RULES.md`.
- **Secrets:** Firebase: `SWARMSPACE_INTERNAL_TOKEN`, Gemini API key, etc. Cloudflare worker: `SWARMSPACE_INTERNAL_TOKEN` (and optional `PUBLIC_MEDIA_BASE_URL`).
- **Feature flag:** `USE_UNIFIED_FEED` in `lib/core/feature_flags.dart` controls 4-tab vs legacy 2-tab shell.

---

## 7. Sequencing Phase 5 prompts

- **Navigation:** Any new “Agents” or “Research” entry points should align with existing tabs (Agents = index 1) and `AgentsScreen` → `ResearchScreen` flow; no separate “Agents tab” exists outside this.
- **Research:** Extend or call `runResearchPipeline()` and existing research models/repositories; add document context via the existing `documentContext` parameter if needed.
- **Vision/Documents:** Use or extend `document_parser.dart` and `parsed_document.dart`; backend OCR path is `visionOcrInvoke` and/or SwarmSpace `vision-ocr` plugin.
- **SwarmSpace/Plugins:** New plugins = new entry in `PLUGIN_REGISTRY` in `swarmspaceRouter.ts` + worker or function implementing the invoke contract; optional activity logging via `plugin_activity_log`.
- **Backend:** New capabilities = new or updated Cloud Function in `functions/src/` and export from `index.ts`; worker URLs must be deployed and wired in the registry.

Use this overview to reference real file paths, widget names, and data flow when writing Phase 5 prompts so they are implementable without assuming non-existent structure.
