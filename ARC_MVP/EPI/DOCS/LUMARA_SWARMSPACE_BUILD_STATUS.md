# LUMARA + SwarmSpace build status vs 7-phase prompt

Reference: `LUMARA_SwarmSpace_Build_Prompt.docx` (Seven-Phase Construction Guide, March 2026).

Current stack: **Flutter + Firebase** (Auth, Firestore, Cloud Functions), **Cloudflare Workers** for some plugins. Doc assumes Supabase + Cloudflare; we use Firestore where doc says Supabase.

---

## Phase 1 — PRISM core

| Doc requirement | Status | Notes |
|-----------------|--------|--------|
| 1. PRISM intercept service (`prism_service.dart`) | **Partial** | Intercept is in **router** (TypeScript): logs `prism_transaction`, checks `privacy_data_required`, `_prism_consent`. No Flutter `prism_service.dart` with ANONYMOUS/USER_CONTENT/STRUCTURED_PERSONAL classification. |
| 2. Consent prompt UI (tiered: ANONYMOUS / USER_CONTENT / STRUCTURED_PERSONAL) | **Partial** | First-use consent via `onConsentRequired` and Vision screen dialog. No tiered modal (banner / mid / full). |
| 3. Pre-authorisation store (`preauth_store.dart`) | **Partial** | `SwarmSpacePluginApprovalStore` persists approved plugin IDs; no `dataScope` or revoke list in Settings. |
| 4. Activity log (table + `activity_log.dart` + fetch) | **Done** | Router writes to Firestore `plugin_activity_log` on every invoke (success/error). Flutter `PluginActivityLogService` + `PluginActivityScreen`; Activity card on Agents and Catalog. |
| 5. PRISM pipeline (`prism_pipeline.dart`) | **Missing** | No single `execute(pluginCall)` that runs intercept → consent → log → invoke. Call sites call `SwarmSpaceClient.invoke` directly. |
| 6. Test harness (`prism_test.dart`) | **Missing** | No tests for PRISM block/prompt/log. |
| 7. Settings stub (privacy_settings.dart) | **Missing** | No dedicated Privacy > pre-auth list + Activity link. |

**Phase 1 gate:** Intercept fires, consent resolves, Activity log records every transaction, no plugin call without authorisation.  
**Current:** Intercept and first-use consent exist; Activity log and pipeline do not; calls can pass without going through a formal pipeline.

---

## Phase 2 — Plugin infrastructure

| Doc requirement | Status | Notes |
|-----------------|--------|--------|
| 1. Plugin manifest schema (JSON Schema + validator) | **Partial** | `PluginConfig` in router has: workerUrl, requiredTier, capabilities, description, exampleQuery, privacy_data_required. No JSON Schema file or trust_tier, credit_cost, semantic_tags, input_schema, etc. |
| 2. Supabase plugin registry table (pgvector) | **Different** | Plugins are in-memory `PLUGIN_REGISTRY` in Firebase. No Supabase/pgvector. |
| 3. SwarmSpace Query API (POST /query, embedding search) | **Different** | We have `swarmspacePluginCatalog` (callable) returning full list; no semantic query. |
| 4. LUMARA SwarmSpace client | **Done** | `SwarmSpaceClient`: invoke, getPluginCatalog, isPluginAvailable. |
| 5. Docking procedure (modal + approval store) | **Done** | First-use consent in invoke; `SwarmSpacePluginApprovalStore`. |
| 6. Execute proxy (Cloudflare /execute) | **Done** | Firebase `swarmspaceRouter` forwards to worker URLs. |
| 7. Seed mock plugins | **N/A** | Real plugins (brave-search, vision-ocr, etc.) registered. |

---

## Phase 3 — Research plugins

| Doc requirement | Status | Notes |
|-----------------|--------|--------|
| Brave Search | **Done** | Via SwarmSpace worker. |
| Semantic Scholar | **Done** | In PLUGIN_REGISTRY. |
| Groq Compound | **Partial** | Not a separate plugin; research uses SwarmSpace search + backend synthesis. |
| Research pipeline orchestrator | **Done** | Research agent + `SwarmSpaceWebSearchTool`. |
| ContentBrief model | **Partial** | Research report model exists; doc’s ContentBrief (topic, key_points, sources, synthesis) is similar. |
| Research UI | **Done** | Research screen. |

---

## Phase 4 — Vision & media

| Doc requirement | Status | Notes |
|-----------------|--------|--------|
| Vision/OCR plugin | **Done** | `visionOcrInvoke` (Cloud Vision + Gemini), Vision/OCR screen. |
| Media hosting plugin (R2, public URL, 24h TTL) | **Missing** | Not built. |
| Document parser (PDF/DOCX → text) | **Missing** | Not built. |
| Media input UI | **Partial** | Vision screen has image picker; no shared “What should I do with this?” panel. |
| PRISM escalation tests (media) | **Missing** | No tests. |

---

## Phase 5 — Writing pipeline

| Doc requirement | Status | Notes |
|-----------------|--------|--------|
| Writing plugin | **Done** | Writing agent + SwarmSpace gemini-flash / backend. |
| Style profile system | **Partial** | Theme/voice in writing; no full StyleProfile + CHRONICLE extraction. |
| Content brief UI | **Partial** | Research → Writing flow exists; no dedicated content_brief_screen. |
| Template system | **Partial** | Content types (e.g. LinkedIn); no formal template_service. |
| Draft editor | **Done** | Writing screen + drafts. |
| Intent router | **Partial** | Research vs Writing entry points; no single intent_router. |

---

## Phase 6 — Form intelligence

| Doc requirement | Status | Notes |
|-----------------|--------|--------|
| User profile schema (CHRONICLE) | **Missing** | No formal user_profile_data for form pre-fill. |
| Form Intelligence plugin | **Missing** | Not built. |
| PRISM STRUCTURED_PERSONAL for forms | **Missing** | Not built. |
| Form review UI / export | **Missing** | Not built. |

---

## Phase 7 — Social publisher

| Doc requirement | Status | Notes |
|-----------------|--------|--------|
| Social Publisher plugin (OAuth, post/schedule) | **Missing** | Not built. |
| Platform formatting / OAuth / Publish UI | **Missing** | Not built. |
| Full pipeline (photo → post) | **Missing** | Not built. |
| Activity tab (full) | **Missing** | No Activity tab. |

---

## Recommended next steps (in order)

1. **Phase 1 — Activity log**  
   - Add Firestore collection `plugin_activity_log` (or equivalent).  
   - In `swarmspaceRouter`, after each plugin call (success/block/error), fire-and-forget write: user_id, plugin_id, plugin_name, data_fields_sent, consent_tier, pre_authorised, result, called_at.  
   - Add Flutter `activity_log_service.dart`: `fetchRecentActivity(userId, limit)`.  
   - Add a simple Activity screen or tab that lists recent entries.

2. **Phase 1 — Flutter PRISM pipeline**  
   - Add `lib/services/swarmspace_prism_service.dart` (or `prism_service.dart`): `intercept(pluginId, params, catalogEntry)` → classify sensitivity (ANONYMOUS / USER_CONTENT / STRUCTURED_PERSONAL from `privacy_data_required` and payload), return decision.  
   - Add `lib/widgets/swarmspace_consent_prompt.dart`: tiered consent (banner / modal / full modal) from doc.  
   - Add `lib/services/swarmspace_prism_pipeline.dart`: `execute(pluginId, params)` → intercept → pre-auth check → show consent if needed → log to Activity → call `SwarmSpaceClient.invoke`.  
   - Wire Vision/OCR and any other plugin call sites through this pipeline so no plugin call bypasses it.

3. **Phase 1 — Settings stub**  
   - Add `privacy_settings.dart` (or section in existing settings): list pre-authorised plugins (from SwarmSpacePluginApprovalStore), revoke; link to Activity log.

4. **Phase 4 — Media hosting plugin**  
   - Implement media-host: accept image (base64), store in R2 (or Firebase Storage) with 24h TTL, return public URL. Register in router; add to catalog.

5. **Phase 4 — Document parser plugin**  
   - Implement document-parser: accept PDF/DOCX (base64), return extracted text + structure. Register in router.

6. **PRISM_ARCHITECTURE.md**  
   - Document: intercept flow (router + Flutter), consent tiers, pre-authorisation, Activity log schema.

**Activity log (implemented):**
- **Router:** `swarmspaceRouter.ts` writes to Firestore collection `plugin_activity_log` (fire-and-forget) on every plugin call: `user_id`, `plugin_id`, `plugin_name`, `user_tier`, `privacy_required`, `consent_given`, `data_fields_sent`, `result`, `error_message?`, `called_at`.
- **Flutter:** `lib/services/swarmspace/plugin_activity_log_service.dart` — `fetchRecentActivity(userId, limit)`; `lib/lumara/agents/screens/plugin_activity_screen.dart` — list of recent entries. Activity card on Agents tab and "Activity" action in Plugin Catalog app bar.
- **Firestore index:** The Activity screen query uses `where('user_id', isEqualTo: userId).orderBy('called_at', descending: true)`. If Firestore prompts for a composite index, create one on collection `plugin_activity_log` with fields `user_id` (Ascending) and `called_at` (Descending).
- **Security:** Ensure Firestore rules allow read only for `request.auth != null && resource.data.user_id == request.auth.uid` on `plugin_activity_log`.

Implementing the Flutter PRISM pipeline + tiered consent next will satisfy the Phase 1 gate and align with the doc.
