---

# 📌 Sprint A — Stability, Safety, Shareability

### **Prompt P13 — Settings & Privacy**

**Goal:** Let users control privacy, exports, and personalization.
**Files:**

* `lib/features/settings/settings_view.dart`
* `lib/features/settings/privacy_view.dart`
* `lib/core/security/biometric_guard.dart`
* `lib/core/export/export_service.dart`

**Tasks:**

* Add toggles for local-only mode, biometric lock, personalization (tone/rhythm/color).
* Implement JSON export (journal entries + Arcforms).
* Implement delete all data with 2-step confirmation.

**Acceptance Criteria:**

* JSON export produces correct schema.
* Delete flow requires explicit confirmation.
* Biometric lock gates resume/open.
* All toggles accessible (labels, contrast).

---

### **Prompt P15 — Analytics & QA**

**Goal:** Add consent-gated analytics events and QA screen.
**Files:**

* `lib/core/analytics/analytics.dart`
* `lib/features/qa/qa_screen.dart`

**Tasks:**

* Track: `onboarding_completed`, `entry_saved`, `voice_recorded`, `sage_reviewed`, `arcform_rendered`, `timeline_opened`, `insights_opened`, `export_png`, `export_json`.
* Gate event logging behind explicit consent.
* Create QA screen: device info, performance stats, sample data seeder.

**Acceptance Criteria:**

* Events only fire if user opts in.
* QA screen loads on mid-tier devices.
* Seeder generates \~12 synthetic entries over 30 days.

---

### **Prompt P19 — Accessibility & Performance Pass**

**Goal:** Ensure inclusivity and perf stability.
**Files:**

* `lib/core/a11y/a11y_flags.dart`
* `lib/core/perf/frame_budget.dart`

**Tasks:**

* Add larger text, high-contrast, reduced motion options.
* Ensure semantic labels on all tappable elements.
* Monitor frame budgets in Arcform renderer.

**Acceptance Criteria:**

* All screens ≥45fps on mid-tier devices.
* Users can toggle reduced motion and larger text.
* Screen reader labels present and accurate.

---

### **Prompt P17 — Share/Export Arcform**

**Goal:** Let users share/export Arcform snapshots.
**Files:**

* `lib/features/arcforms/export/export_arcform.dart`
* `lib/features/arcforms/export/share_sheet.dart`

**Tasks:**

* Render Arcform → high-DPI PNG.
* Save locally or open native share sheet.
* Optional caption: date, top keywords, reflective line.

**Acceptance Criteria:**

* Exported PNG crisp on retina devices.
* Share respects privacy mode (exclude raw journal text unless opted in).
* Works on iOS simulator + Android emulator.

---

# 📌 Sprint B — Insights, Capture, Continuity

### **Prompt P10 — Insights: Polymeta v1 Graph**

**Goal:** First semantic insights view.
**Files:**

* `lib/features/insights/polymeta_graph_view.dart`
* `lib/features/insights/polymeta_graph_cubit.dart`

**Tasks:**

* Build keyword co-occurrence graph from stored entries.
* Pan/zoom with inertia.
* Tap node → list of linked entries.
* Tap edge → joint context preview.

**Acceptance Criteria:**

* Graph reflects real stored data.
* Interactions smooth (≥45fps mid-tier).
* Empty/error states handled gently.

---

### **Prompt P5 — Voice Journaling**

**Goal:** Enable audio capture + transcription.
**Files:**

* `lib/features/journal/voice/voice_capture_view.dart`
* `lib/features/journal/voice/voice_recorder.dart`
* `lib/features/journal/voice/voice_transcriber.dart`

**Tasks:**

* Mic permission flow (iOS + Android).
* Record/pause/stop/playback flow.
* Save `.m4a` file; persist `audioUri`.
* Stub transcription service (editable transcript before save).

**Acceptance Criteria:**

* Permissions handled gracefully.
* Transcript editable.
* Works offline; retry on next launch.

---

### **Prompt P14 — Cloud Sync Stubs**

**Goal:** Prepare offline-first sync framework.
**Files:**

* `lib/core/sync/sync_service.dart`
* `lib/core/sync/sync_toggle_cubit.dart`

**Tasks:**

* Queue writes offline.
* Add Settings toggle for sync.
* Show connection status indicator.

**Acceptance Criteria:**

* App runs fully offline if sync disabled.
* Toggle on/off without crash.
* Status indicator updates correctly.

---

# ✅ Usage

Each prompt can be:

* Dropped into Cursor/Claude as **“Implement Prompt Px”**.
* Opened as a **GitHub Issue** with the “Tasks” list as a checklist.
* Treated as **acceptance criteria** for PR review.

---
