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

### Import: Global status bar and progress during import

#### Overview
When an ARCX/MCP import runs in the background, a mini status bar is shown below the app bar on the home screen so users can see progress without staying on the import screen. The bar disappears when the import completes.

#### Changes
- **ImportStatusBar** (`lib/shared/widgets/import_status_bar.dart`): New widget shown below the app bar when an import is active; shows message and progress; pushes main content down.
- **ImportProgressCubit** (`lib/mira/store/arcx/import_progress_cubit.dart`): New cubit for global import progress (isActive, message, fraction, error, completed); used by ARCX import services and the status bar.
- **HomeView**: Wraps content with ImportStatusBar so the bar appears when import is running.
- **App**: Provides ImportProgressCubit at app level so import services and UI share the same state.
- **ARCX import services**: Updated to use ImportProgressCubit for progress updates during import.
- **ARCX import progress screen / MCP import screen**: Adjusted to work with global progress where applicable.

#### Files Modified
- `lib/app/app.dart` — Provide ImportProgressCubit
- `lib/shared/ui/home/home_view.dart` — Show ImportStatusBar
- `lib/mira/store/arcx/services/arcx_import_service.dart`, `arcx_import_service_unified.dart`, `arcx_import_service_v2.dart` — Use ImportProgressCubit
- `lib/mira/store/arcx/ui/arcx_import_progress_screen.dart` — Use shared progress
- `lib/shared/ui/settings/settings_view.dart` — Import flow
- `lib/ui/export_import/mcp_import_screen.dart` — Import flow
- `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements` — iOS project updates

#### New Files
- `lib/mira/store/arcx/import_progress_cubit.dart`
- `lib/shared/widgets/import_status_bar.dart`

---
