# EPI ARC MVP - Changelog

**Version:** 3.3.13
**Last Updated:** January 26, 2026

---

## Changelog Index

This changelog has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[CHANGELOG_part1.md](CHANGELOG_part1.md)** | Dec 2025 | v2.1.43 - v2.1.87 (Current) |
| **[CHANGELOG_part2.md](CHANGELOG_part2.md)** | Nov 2025 | v2.1.28 - v2.1.42 |
| **[CHANGELOG_part3.md](CHANGELOG_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.27 & Earlier |

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
