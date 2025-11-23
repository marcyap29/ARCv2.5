# Content-Addressed Media System - Quick Start Guide

## 🚀 3-Step Integration

### Step 1: Generate Code (Required)

```bash
cd "/Users/mymac/Software Development/EPI_1b/ARC MVP/EPI"
flutter pub run build_runner build --delete-conflicting-outputs
```

This regenerates `media_item.g.dart` with the new SHA-256 fields.

---

### Step 2: Initialize Service (Required)

Add to your app initialization (e.g., `main.dart`):

```dart
import 'package:my_app/services/media_resolver_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaResolver
  await MediaResolverService.instance.initialize(
    journalPath: '/path/to/journal_v1.mcp.zip',
    mediaPackPaths: [
      '/path/to/mcp_media_2025_01.zip',
    ],
  );

  runApp(MyApp());
}
```

**OR use auto-discovery:**

```dart
// Find all media packs in a directory
await MediaResolverService.instance.initialize(
  journalPath: '/exports/journal_v1.mcp.zip',
  mediaPackPaths: [],
);

// Auto-discover packs
final count = await MediaResolverService.instance.autoDiscoverPacks('/exports');
print('Mounted $count packs');
```

---

### Step 3: Done! (Timeline Already Updated)

The `InteractiveTimelineView` is already integrated. Content-addressed media will automatically display with:
- 🟢 Green borders
- Fast thumbnail loading
- Tap-to-view full resolution

---

## 📱 Show UI Components

### MCP Management Screen (Recommended)

```dart
import 'package:my_app/ui/screens/mcp_management_screen.dart';

// Add to settings menu
ListTile(
  leading: const Icon(Icons.cloud_upload),
  title: const Text('MCP Management'),
  subtitle: const Text('Export, import, and manage media packs'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => McpManagementScreen(
          journalRepository: yourJournalRepository,
        ),
      ),
    );
  },
)
```

### Export Journal & Media Packs

```dart
import 'package:my_app/ui/widgets/mcp_export_dialog.dart';

// Show export dialog
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => McpExportDialog(
    journalRepository: yourJournalRepository,
    defaultOutputDir: '/Users/Shared/EPI_Exports',
  ),
);
```

### Media Pack Management

```dart
import 'package:my_app/ui/widgets/media_pack_management_dialog.dart';
import 'package:my_app/services/media_resolver_service.dart';

// Show from settings or menu
showDialog(
  context: context,
  builder: (context) => MediaPackManagementDialog(
    mountedPacks: MediaResolverService.instance.mountedPacks,
    onMountPack: (path) => MediaResolverService.instance.mountPack(path),
    onUnmountPack: (path) => MediaResolverService.instance.unmountPack(path),
  ),
);
```

### Photo Migration

```dart
import 'package:my_app/ui/widgets/photo_migration_dialog.dart';

// Show from settings
showDialog(
  context: context,
  builder: (context) => PhotoMigrationDialog(
    journalRepository: yourJournalRepository,
    outputDir: '/exports',
  ),
);
```

---

## 📊 Check Status

```dart
// Check if service is initialized
if (MediaResolverService.instance.isInitialized) {
  print('✅ MediaResolver ready');
}

// Get statistics
final stats = MediaResolverService.instance.stats;
print('Mounted packs: ${stats['mountedPacks']}');
print('Cached photos: ${stats['cachedShas']}');

// Validate packs are accessible
final results = await MediaResolverService.instance.validatePacks();
results.forEach((path, exists) {
  print('$path: ${exists ? "✅" : "❌"}');
});
```

---

## 🧭 Navigation & Timeline Sync

- **Tab Bar Journal Action**: The + (create journal) action now lives above the Journal | LUMARA | Insights tabs instead of floating over the screen, keeping the navigation chrome cohesive.
- **Calendar Week Linkage**: Scrolling the timeline entries updates the highlighted week tile, and tapping a calendar day scrolls the list to those entries while keeping the navigation state synchronized.
- **Unified LUMARA Actions**: Both in-journal and in-chat LUMARA responses now expose the same toolbar (Regenerate, Soften tone, More depth, Continue thought, Explore conversation), so advanced prompts behave consistently in every context.

---

## 🎨 Timeline Visual Indicators

| Border | Meaning | Format |
|--------|---------|--------|
| 🟢 Green | Content-addressed (SHA-256) | Future-proof ✅ |
| 🟠 Orange | Photo library (ph://) | Legacy ⚠️ |
| 🔴 Red | Broken file | Missing ❌ |

---

## 🧪 Testing

### Create Test Entry

```dart
final testMedia = MediaItem(
  id: 'test_001',
  uri: 'mcp://photo/abc123...',
  type: MediaType.image,
  createdAt: DateTime.now(),
  sha256: 'abc123...',  // 64-char SHA-256 hash
  thumbUri: 'assets/thumbs/abc123....jpg',
  fullRef: 'mcp://photo/abc123...',
);

final testEntry = JournalEntry(
  id: 'entry_test',
  title: 'Test Entry',
  content: 'Testing content-addressed media',
  media: [testMedia],
  createdAt: DateTime.now(),
  // ... other fields
);
```

### Verify in Timeline

1. Entry appears with green-bordered thumbnail
2. Tap thumbnail → full photo viewer opens
3. If pack mounted → full-res image with zoom
4. If pack not mounted → thumbnail with orange "Mount Pack" banner

---

## 🔧 Common Operations

### Mount New Pack

```dart
// Via file picker (MediaPackManagementDialog handles this)
// OR programmatically:
await MediaResolverService.instance.mountPack('/path/to/pack.zip');
```

### Unmount Pack

```dart
await MediaResolverService.instance.unmountPack('/path/to/pack.zip');
```

### Update Journal Path

```dart
// After export or import
await MediaResolverService.instance.updateJournalPath('/new/journal.mcp.zip');
```

### Reset Service

```dart
// Useful for logout or testing
MediaResolverService.instance.reset();
```

---

## 📚 Documentation

- **`FINAL_IMPLEMENTATION_SUMMARY.md`** - Complete implementation guide (start here!)
- **`docs/README_MCP_MEDIA.md`** - Technical architecture reference
- **`UI_INTEGRATION_SUMMARY.md`** - UI integration details
- **`CONTENT_ADDRESSED_MEDIA_SUMMARY.md`** - Backend summary

---

## ✅ Checklist

Before going to production:

- [ ] Run `flutter pub run build_runner build`
- [ ] Initialize MediaResolverService at app startup
- [ ] Test with at least one content-addressed entry
- [ ] Verify green border in timeline
- [ ] Test full photo viewer
- [ ] Test pack management dialog
- [ ] (Optional) Run migration on existing photos

---

## 🆘 Troubleshooting

**No thumbnails showing?**
→ Check `MediaResolverService.instance.isInitialized` is true

**"No media resolver available" error?**
→ Call `MediaResolverService.instance.initialize(...)` at app startup

**Full image not loading?**
→ Verify pack is mounted: `MediaResolverService.instance.mountedPacks`

**Want to see detailed docs?**
→ Open `FINAL_IMPLEMENTATION_SUMMARY.md`

---

## 🎉 That's It!

Your app now has:
- ✅ Durable, portable photo references
- ✅ Automatic deduplication
- ✅ Privacy-preserving (EXIF stripped)
- ✅ Fast timeline rendering
- ✅ Graceful degradation
- ✅ Beautiful UI

**Total setup time: ~5 minutes**

Happy coding! 🚀
