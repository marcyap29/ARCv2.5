# MCP Export UI Integration Guide

## Overview

The MCP (Memory Core Protocol) export UI provides a complete user experience for exporting journals and media packs.

---

## 🎨 New UI Components

### 1. **McpExportDialog** - Full Export Workflow

**Location**: `lib/ui/widgets/mcp_export_dialog.dart`

**Features**:
- ✅ Four-phase export flow (Configuration → Exporting → Complete → Error)
- ✅ Live progress tracking with percentage and time estimates
- ✅ Configurable export options (thumbnail size, pack size, JPEG quality)
- ✅ Statistics preview (entries, photos, estimated size)
- ✅ Directory picker for output location
- ✅ EXIF stripping toggle for privacy
- ✅ Auto-updates MediaResolverService after export
- ✅ Advanced settings panel
- ✅ Copy-to-clipboard for export paths

**Usage**:
```dart
import 'package:my_app/ui/widgets/mcp_export_dialog.dart';

// Show dialog
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => McpExportDialog(
    journalRepository: journalRepository,
    defaultOutputDir: '/path/to/exports',
  ),
);
```

**Export Flow**:
```
1. CONFIGURATION PHASE
   ├─ Show statistics (entries, photos, est. size)
   ├─ Select output directory
   ├─ Toggle export options
   │  ├─ Export Journal (checkbox)
   │  ├─ Export Media Packs (checkbox)
   │  └─ Strip EXIF (checkbox)
   ├─ Advanced Settings (expandable)
   │  ├─ Thumbnail Size (256px - 1024px)
   │  ├─ Max Media Pack Size (50MB - 500MB)
   │  └─ JPEG Quality (60% - 100%)
   └─ Click "Start Export"

2. EXPORTING PHASE
   ├─ Show circular progress spinner
   ├─ Display current operation
   ├─ Show progress bar (0-100%)
   ├─ Show photo count (processed/total)
   ├─ Show elapsed time
   └─ Show estimated remaining time

3. COMPLETE PHASE
   ├─ Show success checkmark
   ├─ Display statistics
   ├─ List exported files
   │  ├─ Journal path (with copy button)
   │  └─ Media pack paths (with copy buttons)
   ├─ Show auto-update notification
   └─ Actions: "Open Folder" or "Done"

4. ERROR PHASE (if export fails)
   ├─ Show error icon
   ├─ Display error message
   └─ Actions: "Try Again" or "Close"
```

---

### 2. **McpManagementScreen** - Centralized Management

**Location**: `lib/ui/screens/mcp_management_screen.dart`

**Features**:
- ✅ Export journal and media packs
- ✅ Manage mounted media packs
- ✅ Migrate legacy photos
- ✅ View MediaResolver status
- ✅ Card-based layout with clear sections

**Usage**:
```dart
import 'package:my_app/ui/screens/mcp_management_screen.dart';

// Navigate to screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => McpManagementScreen(
      journalRepository: journalRepository,
    ),
  ),
);
```

**Screen Sections**:

1. **Export & Backup Card**
   - Description of MCP export
   - "Export Now" button → Opens `McpExportDialog`

2. **Media Packs Card**
   - Description of media pack management
   - "Manage Packs" button → Opens `MediaPackManagementDialog`

3. **Migration Card**
   - Description of legacy photo migration
   - "Migrate Photos" button → Opens `PhotoMigrationDialog`

4. **Status Card**
   - MediaResolver initialization status
   - Mounted packs count
   - Cached photos count
   - Current journal path

---

## 🔗 Integration Steps

### Step 1: Add Route to MCP Management Screen

**Option A: From Settings Menu**

```dart
// In your settings screen
ListTile(
  leading: const Icon(Icons.cloud_upload),
  title: const Text('MCP Management'),
  subtitle: const Text('Export, import, and manage media packs'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => McpManagementScreen(
          journalRepository: context.read<JournalRepository>(),
        ),
      ),
    );
  },
)
```

**Option B: From AppBar Menu**

```dart
// In your main screen AppBar
AppBar(
  title: const Text('My Journal'),
  actions: [
    IconButton(
      icon: const Icon(Icons.cloud_upload),
      tooltip: 'MCP Management',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => McpManagementScreen(
              journalRepository: context.read<JournalRepository>(),
            ),
          ),
        );
      },
    ),
  ],
)
```

**Option C: Quick Export Action**

```dart
// Direct export dialog from anywhere
FloatingActionButton(
  onPressed: () {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => McpExportDialog(
        journalRepository: context.read<JournalRepository>(),
        defaultOutputDir: '/Users/Shared/EPI_Exports',
      ),
    );
  },
  child: const Icon(Icons.cloud_upload),
  tooltip: 'Export Journal',
)
```

---

### Step 2: Initialize MediaResolverService at App Startup

**In `main.dart` or app initialization**:

```dart
import 'package:my_app/services/media_resolver_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaResolver with existing journal/packs (if available)
  final prefs = await SharedPreferences.getInstance();
  final journalPath = prefs.getString('last_journal_path');
  final packPaths = prefs.getStringList('mounted_packs') ?? [];

  if (journalPath != null) {
    await MediaResolverService.instance.initialize(
      journalPath: journalPath,
      mediaPackPaths: packPaths,
    );
  }

  runApp(MyApp());
}
```

---

### Step 3: Persist Export Paths

**Save paths after successful export**:

```dart
// In McpExportDialog, after export completes
final prefs = await SharedPreferences.getInstance();
await prefs.setString('last_journal_path', _journalPath!);
await prefs.setStringList('mounted_packs', _mediaPackPaths);
```

---

## 📊 Export Configuration Options

### Default Settings

```dart
// Recommended defaults
final defaultConfig = MediaPackConfig(
  maxSizeBytes: 100 * 1024 * 1024,  // 100MB per pack
  maxItems: 1000,                    // 1000 photos per pack
  format: 'jpg',                     // JPEG format
  quality: 85,                       // 85% quality
  maxEdge: 2048,                     // 2048px max dimension
);

final defaultThumbnailConfig = ThumbnailConfig(
  size: 768,          // 768px thumbnails
  format: 'jpg',      // JPEG format
  quality: 85,        // 85% quality
);
```

### User-Configurable Options

| Option | Range | Default | Description |
|--------|-------|---------|-------------|
| Thumbnail Size | 256px - 1024px | 768px | Max dimension for embedded thumbnails |
| Max Pack Size | 50MB - 500MB | 100MB | Maximum size per media pack archive |
| JPEG Quality | 60% - 100% | 85% | Compression quality for images |
| Strip EXIF | On/Off | On | Remove GPS and camera metadata |

---

## 🎯 User Workflows

### Workflow 1: First-Time Export

```
User → Settings → MCP Management → Export Journal
  ↓
Configuration Screen
  ├─ Views statistics (50 entries, 120 photos, ~240MB)
  ├─ Selects output directory (/Users/Shared/EPI_Exports)
  ├─ Keeps default settings
  └─ Clicks "Start Export"
  ↓
Progress Screen (2-3 minutes)
  ├─ Watches progress bar
  ├─ Sees "Processing photo 45/120"
  └─ Waits for completion
  ↓
Success Screen
  ├─ Sees ✓ "Export Complete!"
  ├─ Views exported files:
  │   ├─ journal_v1.mcp.zip
  │   └─ mcp_media_2025_01.zip
  ├─ Clicks "Open Folder" to view files
  └─ Clicks "Done"
```

### Workflow 2: Importing on New Device

```
New Device → Settings → MCP Management → Manage Media Packs
  ↓
Media Pack Management Dialog
  ├─ Clicks "Mount Pack"
  ├─ Selects journal_v1.mcp.zip
  ├─ Selects mcp_media_2025_01.zip
  └─ Clicks "Done"
  ↓
Timeline View
  └─ All photos now display with green borders
```

### Workflow 3: Migrating Legacy Photos

```
User → Settings → MCP Management → Migrate Legacy Photos
  ↓
Migration Analysis
  ├─ Views statistics (30 ph:// photos, 5 file:// photos)
  ├─ Sees warnings about network photos
  └─ Clicks "START MIGRATION"
  ↓
Migration Progress (1-2 minutes)
  ├─ Watches progress bar
  └─ Waits for completion
  ↓
Success Screen
  ├─ Sees "Migration Complete!"
  ├─ Views new journal and media pack paths
  └─ Clicks "Done"
  ↓
Timeline View
  └─ All photos now show green borders instead of orange
```

---

## 🎨 Visual Design

### Color Scheme

- **Export Card**: Blue (`Colors.blue[700]`)
- **Media Packs Card**: Green (`Colors.green[700]`)
- **Migration Card**: Orange (`Colors.orange[700]`)
- **Success State**: Green (`Colors.green`)
- **Error State**: Red (`Colors.red`)
- **Info Boxes**: Light blue (`Colors.blue[50]`)

### Icons

- Export: `Icons.cloud_upload`
- Media Packs: `Icons.photo_library`
- Migration: `Icons.sync_alt`
- Success: `Icons.check_circle`
- Error: `Icons.error_outline`
- Info: `Icons.info_outline`
- Status OK: `Icons.check_circle`
- Status Warning: `Icons.warning`

---

## 🔍 Testing Checklist

### Before Release

- [ ] Test export with 0 entries (edge case)
- [ ] Test export with 1000+ photos (performance)
- [ ] Test export with mixed media types (photos, videos)
- [ ] Test export cancellation (if implemented)
- [ ] Test export error handling (disk full, permissions)
- [ ] Test import on new device
- [ ] Test auto-discovery of media packs
- [ ] Test migration with iCloud photos
- [ ] Test migration with missing photos
- [ ] Verify EXIF stripping works
- [ ] Verify deduplication works (same photo in multiple entries)
- [ ] Test with different export settings
- [ ] Verify MediaResolver auto-update after export
- [ ] Test "Copy path" functionality
- [ ] Test "Open Folder" functionality

---

## 📝 Example: Full Integration

```dart
// settings_screen.dart

import 'package:flutter/material.dart';
import 'package:my_app/ui/screens/mcp_management_screen.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ... other settings ...

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Data & Backup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('MCP Management'),
            subtitle: const Text('Export, import, and manage media packs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => McpManagementScreen(
                    journalRepository: context.read<JournalRepository>(),
                  ),
                ),
              );
            },
          ),

          // ... other settings ...
        ],
      ),
    );
  }
}
```

---

## 🚀 Quick Start

1. **Add to settings**:
   ```dart
   ListTile(
     leading: const Icon(Icons.cloud_upload),
     title: const Text('MCP Management'),
     onTap: () => Navigator.push(...),
   )
   ```

2. **Initialize at startup**:
   ```dart
   await MediaResolverService.instance.initialize(
     journalPath: savedJournalPath,
     mediaPackPaths: savedPackPaths,
   );
   ```

3. **Test export**:
   - Open MCP Management
   - Click "Export Now"
   - Select output directory
   - Click "Start Export"
   - Wait for completion
   - Verify files created

---

## 📖 Documentation Files

- **`QUICK_START_GUIDE.md`** - Quick 3-step integration
- **`FINAL_IMPLEMENTATION_SUMMARY.md`** - Complete backend reference
- **`UI_INTEGRATION_SUMMARY.md`** - Timeline and widget integration
- **`UI_EXPORT_INTEGRATION_GUIDE.md`** - This file (export UI)
- **`docs/README_MCP_MEDIA.md`** - Technical architecture

---

**The export UI is now complete and ready for integration!** 🎉

Users can now easily export their journals and media packs through an intuitive, well-designed interface.
