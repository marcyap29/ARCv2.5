# ARCX Implementation Status

## ✅ Completed

### Phase 1: iOS Native Crypto Infrastructure
- ✅ `ios/Runner/ARCXCrypto.swift` - Ed25519 signing + AES-256-GCM encryption via Secure Enclave
- ✅ `ios/Runner/ARCXFileProtection.swift` - NSFileProtectionComplete helpers and secure deletion
- ✅ `ios/Runner/Info.plist` - UTI registration for `.arcx` (com.orbital.arcx)
- ✅ `ios/Runner/AppDelegate.swift` - Open-in handler + MethodChannel handlers for AirDrop/Files app integration
- ✅ `pubspec.yaml` - Added `cryptography` dependency

### Phase 2: Dart Models & Crypto Bridge
- ✅ `lib/arcx/models/arcx_manifest.dart` - Manifest model with validation
- ✅ `lib/arcx/models/arcx_result.dart` - Result types for export/import/migration
- ✅ `lib/arcx/services/arcx_crypto_service.dart` - Platform channel bridge
- ✅ `lib/arcx/services/arcx_redaction_service.dart` - MCP-aware redaction logic

### Phase 3-4: Core Services
- ✅ `lib/arcx/services/arcx_export_service.dart` - Export to .arcx with redaction
- ✅ `lib/arcx/services/arcx_import_service.dart` - Import from .arcx with verification
- ✅ `lib/arcx/services/arcx_migration_service.dart` - Migrate legacy .zip to .arcx

### Phase 5: UI Components
- ✅ `lib/arcx/ui/arcx_import_progress_screen.dart` - Import progress screen

## 🚧 Remaining Work

### Export UI Integration (TODO)
**File: `lib/ui/export_import/mcp_export_screen.dart`**

Add:
- Radio button or toggle: "Legacy MCP (.zip)" vs "Secure Archive (.arcx)"
- Show redaction options if .arcx selected:
  - "Include photo labels" checkbox
  - "Timestamp precision" dropdown (full | date-only)
- Call `ARCXExportService.exportSecure()` instead of `McpExportService.exportToMcp()`

### Settings UI (TODO)
**File: `lib/features/settings/arcx_settings_view.dart`** (new)

Settings screen for:
- "Include photo labels in exports" toggle (default: off)
- "Timestamp precision" dropdown (full | date-only)
- "Secure delete original files after migration" toggle
- "Migrate Legacy Exports" button → file picker → batch migration UI

**File: `lib/features/settings/settings_view.dart`**

Add new tile in "Import & Export" section:
```dart
_buildSettingsTile(
  context,
  title: 'Secure Archive Settings',
  subtitle: 'Configure .arcx encryption and redaction',
  icon: Icons.security,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ARCXSettingsView()),
    );
  },
),
```

### MethodChannel Handler (TODO)
**File: `lib/main.dart` or `lib/main/bootstrap.dart`**

Add handler for iOS open-in events:
```dart
const _arcxChannel = MethodChannel('arcx/import');

void _setupARCXHandler() {
  _arcxChannel.setMethodCallHandler((call) async {
    if (call.method == 'onOpenARCX') {
      final String arcxPath = call.arguments['arcxPath'];
      final String? manifestPath = call.arguments['manifestPath'];
      
      // Navigate to import screen
      // TODO: Get Navigator context
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ARCXImportProgressScreen(
          arcxPath: arcxPath,
          manifestPath: manifestPath,
        ),
      ));
    }
  });
}
```

## 📋 Summary

### Core Infrastructure: ✅ Complete
All core services for ARCX export, import, and migration are implemented:
- ✅ iOS native crypto with Secure Enclave
- ✅ UTI registration and open-in handler
- ✅ Dart models and crypto bridge
- ✅ Redaction service
- ✅ Export service
- ✅ Import service with verification
- ✅ Migration service
- ✅ Import progress UI

### Remaining Tasks
1. **Export UI Integration** - Add .arcx option to MCP export screen
2. **Settings UI** - ARCX settings screen
3. **MethodChannel Handler** - Flutter-side handler for open-in events
4. **Testing** - AirDrop, Files app, signature/AEAD verification

The foundation is **fully implemented**. Remaining work focuses on UI integration and testing.

## 🧪 Testing Checklist

- [ ] Export .arcx from app → verify `NSFileProtectionComplete`
- [ ] AirDrop .arcx → tap to open → import succeeds
- [ ] Files app: tap .arcx → opens in ARC
- [ ] Wrong signature → import fails with clear error
- [ ] Tampered ciphertext → AEAD tag verification fails
- [ ] Migrate legacy .zip → round-trip verify
- [ ] dateOnly=true → timestamps are date-only
- [ ] includeLabels=false → no labels in photo metadata

## 📦 Files Created/Modified

**New Files (14):**
- `ios/Runner/ARCXCrypto.swift`
- `ios/Runner/ARCXFileProtection.swift`
- `lib/arcx/models/arcx_manifest.dart`
- `lib/arcx/models/arcx_result.dart`
- `lib/arcx/services/arcx_crypto_service.dart`
- `lib/arcx/services/arcx_redaction_service.dart`
- `lib/arcx/services/arcx_export_service.dart`
- `lib/arcx/services/arcx_import_service.dart`
- `lib/arcx/services/arcx_migration_service.dart`
- `lib/arcx/ui/arcx_import_progress_screen.dart`

**Modified Files (3):**
- `ios/Runner/Info.plist` (add UTI declarations)
- `ios/Runner/AppDelegate.swift` (add open-in handler + MethodChannel)
- `pubspec.yaml` (add `cryptography` dependency)
