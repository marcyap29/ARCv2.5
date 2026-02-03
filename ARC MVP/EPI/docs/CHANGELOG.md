# EPI ARC MVP - Changelog

**Version:** 3.3.15
**Last Updated:** February 2, 2026

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.87 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

---

## [3.3.15] - February 2, 2026

### Journal & CHRONICLE robustness

- **JournalRepository:** Per-entry try/catch in `getAllJournalEntries` so one bad or legacy entry does not drop the entire list; skip and log on normalize failure.
- **Layer0Populator:** Backwards compatibility for legacy Hive entries: `_safeContent()` and `_safeKeywords()` handle null content/keywords. `populateFromJournalEntry` returns `bool` (true if saved); `populateFromJournalEntries` returns `(succeeded, failed)` counts.
- **Layer0Repository:** New `getMonthsWithEntries(userId)` — distinct months with Layer 0 data for batch synthesis.
- **ChronicleOnboardingService:** Layer 0 backfill uses populator’s succeeded/failed counts; clearer messages (e.g. "X of Y entries", "Z failed"). Batch synthesis builds months from Layer 0 via `getMonthsWithEntries` (not journal date range); message "No Layer 0 entries for this user. Run Backfill Layer 0 first." when none.

### Phase consistency (timeline / Conversations)

- **Phase tab → UserProfile:** After loading Phase tab, call `_updateUserPhaseFromRegimes()` so UserProfile current phase is in sync; timeline and Conversations phase preview then match Phase tab.
- **Current phase preview:** Prefer `UserPhaseService.getCurrentPhase()` (UserProfile) when set, so Conversations/timeline preview matches Phase tab; fallback to RIVET + regime logic when profile phase empty.
- **Home tab label:** "Conversation" → "Conversations" (plural).

#### Files modified

- `lib/arc/internal/mira/journal_repository.dart` — Per-entry try/catch in getAllJournalEntries; skip bad entries
- `lib/chronicle/services/chronicle_onboarding_service.dart` — Backfill counts; synthesis from Layer 0 months; messages
- `lib/chronicle/storage/layer0_populator.dart` — _safeContent/_safeKeywords; return succeeded/failed
- `lib/chronicle/storage/layer0_repository.dart` — getMonthsWithEntries(userId)
- `lib/arc/ui/timeline/widgets/current_phase_arcform_preview.dart` — Prefer profile phase for preview
- `lib/shared/ui/home/home_view.dart` — Tab label "Conversations"
- `lib/ui/phase/phase_analysis_view.dart` — _updateUserPhaseFromRegimes() after load

---

## [3.3.14] - February 2, 2026

### Settings & LUMARA

- **LUMARA from chat:** Drawer "Settings" now opens **Settings → LUMARA** (LumaraFolderView) instead of the full LUMARA settings screen; users can tap "API & providers" for full setup.
- **Settings structure:** Top-level **CHRONICLE** folder added (View CHRONICLE Layers, CHRONICLE Management). LUMARA and CHRONICLE folders moved above Health & Readiness. LUMARA folder includes new "API & providers" tile → LumaraSettingsScreen.
- **Web access default:** LUMARA web access default changed from opt-in (false) to automatic (true) — LUMARA may use the web when needed.
- **LUMARA settings screen:** Status card and Web Access card removed (settings simplified).

### Voice notes (Ideas)

- **VoiceNoteRepository:** Static broadcast added so any instance (e.g. saving from Voice Mode) notifies all `watch()` subscribers; Ideas list refreshes when saving from voice without reopening.

### CHRONICLE

- **Layer 0 backfill:** Re-populates entries when existing Layer 0 entry has different `userId` (e.g. `default_user`), not only when missing.
- **MonthlySynthesizer:** Log when no entries for month: "No entries for … (run Backfill Layer 0 if you have journal entries)."

### Google Drive backup & import

- **GoogleDriveService:** `getOrCreateAppFolder()` now searches for existing "ARC Backups" folder to avoid duplicates. New `getOrCreateDatedSubfolder(date)` (yyyy-MM-dd) with in-memory cache so same-day uploads use one folder. New `listAllBackupFiles()` for Import from Drive (dated subfolders + root).
- **GoogleDriveSettingsView:** Security-scoped access retained after folder pick so Upload works without re-picking (iOS/macOS). In-app sandbox detection (no security-scoped request for Documents/Support/Temp). Import backup list expandable; last upload-from-folder time persisted.

### Local backup

- **LocalBackupSettingsView:** iOS/macOS security-scoped access for backup folder when path is outside app sandbox; start/stop around backup and export operations. User message to re-select folder if access is needed. Helper `_isBackupPathInAppSandbox()`.

#### Files modified

- `lib/arc/chat/services/lumara_reflection_settings_service.dart` — Web access default true
- `lib/arc/chat/ui/lumara_assistant_screen.dart` — Settings → LumaraFolderView; label "Settings"
- `lib/arc/chat/ui/lumara_settings_screen.dart` — Remove Status card, Web Access card
- `lib/arc/voice_notes/repositories/voice_note_repository.dart` — Static broadcast for watch() across instances
- `lib/chronicle/services/chronicle_onboarding_service.dart` — Layer 0 re-populate when userId differs
- `lib/chronicle/synthesis/monthly_synthesizer.dart` — Log when no entries for month
- `lib/services/google_drive_service.dart` — Search app folder; dated subfolder + cache; listAllBackupFiles
- `lib/shared/ui/settings/google_drive_settings_view.dart` — Retain security-scoped access; sandbox check; Import list; last upload time
- `lib/shared/ui/settings/local_backup_settings_view.dart` — Security-scoped access for external backup path
- `lib/shared/ui/settings/settings_view.dart` — CHRONICLE folder; LUMARA/CHRONICLE order; LumaraFolderView "API & providers"; ChronicleFolderView

---

## [3.3.13] - January 31, 2026

### Fix: Wispr Flow cache – new API key used after save without restart

#### Overview
Wispr Flow API key was cached in `WisprConfigService`. After saving a new or updated API key in **LUMARA Settings → External Services**, voice mode could still use the previous key until the app was restarted. Fix: call `WisprConfigService.instance.clearCache()` after saving the API key so the next voice session uses the new key.

#### Changes
- **lumara_settings_screen.dart**: In `_saveWisprApiKey()`, after writing the key to SharedPreferences, call `WisprConfigService.instance.clearCache()` so the new key is used on the next voice mode session without restart.
- **WisprConfigService**: Already had `clearCache()` (clears `_cachedApiKey`, `_hasCheckedPrefs`); settings screen now invokes it on save.

#### Related
- Bug Tracker: `DOCS/bugtracker/records/wispr-flow-cache-issue.md`

---

### Fix: Phase Quiz result matches Phase tab; rotating phase on Phase tab

#### Overview
Phase Quiz V2 result (e.g. Breakthrough) was not persisted, so the main app and Phase tab showed Discovery. Phase tab now uses the quiz result when there are no phase regimes (e.g. right after onboarding). The rotating phase shape from the phase reveal is now shown alongside the detailed 3D constellation on the Phase tab.

#### Changes
- **Phase Quiz V2 → UserProfile**: After completing the phase quiz, the selected phase is persisted via `UserPhaseService.forceUpdatePhase()` (capitalized) so the main app and Phase tab show the same phase.
- **UserPhaseService.forceUpdatePhase**: Now updates both `onboardingCurrentSeason` and `currentPhase` on UserProfile for consistency.
- **Phase tab when no regimes**: When there are no phase regimes (e.g. right after onboarding), Phase tab and SimplifiedArcformView3D use `UserPhaseService.getCurrentPhase()` (quiz result) instead of defaulting to Discovery.
- **Rotating phase on Phase tab**: The same rotating phase shape (AnimatedPhaseShape) used on the phase reveal screen is now displayed above the detailed 3D constellation on the Phase tab, with the phase name label alongside.

#### Methodology
- **Quiz**: Self-reported phase from Q1 ("Which best describes where you are right now?").
- **App (Rivet/Sentinel/Prism)**: Inferred phase from journal content via phase regimes. When no regimes exist, the app respects the quiz result until regimes are created.

#### Files Modified
- `lib/shared/ui/onboarding/phase_quiz_v2_screen.dart` — Persist quiz phase via UserPhaseService after conductQuiz
- `lib/services/user_phase_service.dart` — forceUpdatePhase sets both onboardingCurrentSeason and currentPhase
- `lib/ui/phase/phase_analysis_view.dart` — _phaseFromUserProfile when no regimes; rotating AnimatedPhaseShape above 3D view
- `lib/ui/phase/simplified_arcform_view_3d.dart` — When no regimes, use UserPhaseService.getCurrentPhase() instead of Discovery

---

## [3.3.13] - January 31, 2026

### Fix: iOS Folder Verification Permission Error

#### Overview
Fixed critical issue where folder verification in `VerifyBackupScreen` failed on iOS with "Operation not permitted" error when attempting to scan `.arcx` backup files in user-selected folders.

#### Changes
- **iOS Security-Scoped Resource Access**: Added proper handling of security-scoped resources when accessing user-selected folders on iOS
- **`arcx_scan_service.dart`**: Modified `scanArcxFolder()` to start accessing security-scoped resource before listing directory, with proper cleanup in `finally` block
- **`verify_backup_screen.dart`**: Added security-scoped resource access handling in `_scanFolder()` method with user-friendly error messages
- **Error Handling**: Improved error messages when folder access is denied on iOS

#### Technical Details
- On iOS, `FilePicker` returns security-scoped resource paths that require explicit access permissions
- Added calls to `startAccessingSecurityScopedResourceWithFilePath()` before directory operations
- Added proper cleanup with `stopAccessingSecurityScopedResourceWithFilePath()` in `finally` blocks
- Uses existing `accessing_security_scoped_resource` package (v3.4.0)

#### Files Modified
- `lib/mira/store/arcx/services/arcx_scan_service.dart` - Added security-scoped resource handling
- `lib/shared/ui/settings/verify_backup_screen.dart` - Added security-scoped resource handling and improved error messages

#### Related
- Bug Tracker: `DOCS/bugtracker/records/ios-folder-verification-permission-error.md`

---

## [3.3.13] - January 26, 2026

### Import: Global status bar, percentage, and Import Status screen

#### Overview
When an ARCX/MCP import runs in the background, a mini status bar is shown below the app bar on the home screen so users can see progress (including percentage) without staying on the import screen. Users can also go to **Settings → Import Data** to open the **Import Status** screen, which shows current import progress and a list of files with status (pending / in progress / completed / failed). The app remains usable during import.

#### Changes
- **ImportStatusBar** (`lib/shared/widgets/import_status_bar.dart`): Shown below the app bar when an import is active; shows message, progress bar, and **percentage (0%–100%)**; includes “You can keep using the app”; pushes main content down.
- **ImportStatusScreen** (`lib/shared/ui/settings/import_status_screen.dart`): New screen under Settings → Import. When no import is active: “No import in progress” and “Choose files to import”. When import is active: overall message, progress bar, and list of files with status (Pending / In progress / Completed / Failed). When completed or failed: result summary, file list, Done, and “Import more”.
- **ImportProgressCubit** (`lib/mira/store/arcx/import_progress_cubit.dart`): Global import progress (isActive, message, fraction, error, completed); **per-file status** for multi-file imports (`fileItems`, `ImportFileStatus`, `startWithFiles`, `updateFileStatus`); used by the status bar and Import Status screen.
- **HomeView**: Wraps content with ImportStatusBar so the bar appears when import is running.
- **App**: Provides ImportProgressCubit at app level so import services and UI share the same state.
- **Settings → Import Data**: Opens Import Status screen (with “Choose files to import” to start an import); user can view progress and file list while import runs in the background.
- **Multi-ARCX import**: Uses `startWithFiles` and `updateFileStatus` so the Import Status screen shows per-file status.
- **ARCX import services**: Updated to use ImportProgressCubit for progress updates during import.
- **ARCX import progress screen / MCP import screen**: Adjusted to work with global progress where applicable.

#### Files Modified
- `lib/app/app.dart` — Provide ImportProgressCubit
- `lib/shared/ui/home/home_view.dart` — Show ImportStatusBar
- `lib/shared/ui/settings/settings_view.dart` — Import Data tile opens ImportStatusScreen; multi-ARCX uses startWithFiles/updateFileStatus
- `lib/mira/store/arcx/services/arcx_import_service.dart`, `arcx_import_service_unified.dart`, `arcx_import_service_v2.dart` — Use ImportProgressCubit
- `lib/mira/store/arcx/ui/arcx_import_progress_screen.dart` — Use shared progress
- `lib/ui/export_import/mcp_import_screen.dart` — Import flow
- `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements` — iOS project updates

#### New Files
- `lib/mira/store/arcx/import_progress_cubit.dart`
- `lib/shared/widgets/import_status_bar.dart`
- `lib/shared/ui/settings/import_status_screen.dart`

#### Build fix
- **Local backup service** (`lib/services/local_backup_service.dart`): `onProgress` callbacks updated to accept optional fraction parameter `(msg, [fraction])` to match `void Function(String, [double?])?` used by `exportFullBackupChunked` and related export APIs.

---
