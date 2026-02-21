# Content-Addressed Media System for MCP

## Overview

The Content-Addressed Media System replaces fragile `ph://` photo references with SHA-256 content hashes, enabling durable, portable journal exports that work across devices and years.

### Key Benefits

- **Durability**: Entries reference photos by immutable content hash, not device-specific URIs
- **Portability**: Journals work on any device with the matching media packs
- **Privacy**: EXIF data stripped by default; only safe metadata preserved
- **Deduplication**: Identical photos stored once, saving space
- **Performance**: Thumbnails in journal for fast timeline rendering
- **Scalability**: Full-res photos in rolling monthly packs, keeping journal small

---

## Architecture

### Journal Bundle (Small & Fast)

```
journal_v1.mcp.zip
├── manifest.json              # Journal metadata + media pack references
├── entries/
│   ├── entry_001.json        # Entry with media references
│   ├── entry_002.json
│   └── ...
└── assets/
    └── thumbs/
        ├── 7f5e2c...a9.jpg   # 768px thumbnails (SHA-256 named)
        └── ...
```

### Media Pack (Cold Storage)

```
mcp_media_2025_01.zip
├── manifest.json              # Pack metadata + SHA index
└── photos/
    ├── 7f5e2c...a9.jpg       # Full-res photos (max 2048px, quality 85)
    ├── 3a8b1d...f2.jpg
    └── ...
```

---

## Entry Format

### Before (Fragile)

```json
{
  "id": "entry_001",
  "content": "Great hike today.",
  "media": [
    {
      "id": "m_001",
      "uri": "ph://F7E2C4A9-1234-5678-ABCD-9876543210FE/L0/001",
      "type": "image"
    }
  ]
}
```

**Problems:**
- `ph://` only works on the same device
- Breaks if photo deleted from library
- No deduplication across entries

### After (Durable)

```json
{
  "id": "entry_001",
  "timestamp": "2025-10-18T19:02:00Z",
  "content": "Great hike today.",
  "media": [
    {
      "id": "m_001",
      "kind": "photo",
      "sha256": "7f5e2c4a9b8d1f3e6c5a2d9b1f4e7a3c8d5b2f9a1e6c3d7b4f8a2e5c9d1b6f3a",
      "thumbUri": "assets/thumbs/7f5e2c4a9b8d1f3e6c5a2d9b1f4e7a3c8d5b2f9a1e6c3d7b4f8a2e5c9d1b6f3a.jpg",
      "fullRef": "mcp://photo/7f5e2c4a9b8d1f3e6c5a2d9b1f4e7a3c8d5b2f9a1e6c3d7b4f8a2e5c9d1b6f3a",
      "createdAt": "2025-10-18T18:44:12Z"
    }
  ]
}
```

**Benefits:**
- Works on any device with the media pack
- Survives photo deletion from library
- Automatic deduplication by SHA-256
- Fast thumbnail rendering
- Graceful degradation (show thumb if pack missing)

---

## Manifests

### Journal Manifest

```json
{
  "version": 1,
  "createdAt": "2025-10-18T20:00:00Z",
  "mediaPacks": [
    {
      "id": "2025_01",
      "filename": "mcp_media_2025_01.zip",
      "from": "2025-01-01T00:00:00Z",
      "to": "2025-01-31T23:59:59Z"
    }
  ],
  "thumbnails": {
    "size": 768,
    "format": "jpg",
    "quality": 85
  }
}
```

### Media Pack Manifest

```json
{
  "id": "2025_01",
  "from": "2025-01-01T00:00:00Z",
  "to": "2025-01-31T23:59:59Z",
  "items": {
    "7f5e2c...a9": {
      "path": "photos/7f5e2c...a9.jpg",
      "bytes": 812344,
      "format": "jpg"
    }
  }
}
```

---

## Export Pipeline

### 1. Fetch Original Bytes

```dart
// From iOS Photo Library
final photoData = await PhotoBridge.getPhotoBytes(localIdentifier);
final originalBytes = photoData['bytes'] as Uint8List;
final originalFormat = photoData['ext'] as String;

// Or from file
final file = File(filePath);
final originalBytes = await file.readAsBytes();
```

### 2. Compute SHA-256

```dart
final sha = sha256Hex(originalBytes);
// Result: "7f5e2c4a9b8d1f3e..."
```

### 3. Process Full-Resolution

```dart
final reencoded = reencodeFull(
  originalBytes,
  maxEdge: 2048,     // Max dimension
  quality: 85,       // JPEG quality
);
// EXIF automatically stripped
```

### 4. Generate Thumbnail

```dart
final thumbnail = makeThumbnail(
  originalBytes,
  maxEdge: 768,      // Thumbnail max dimension
);
```

### 5. Write to Packs

```dart
// Add full photo to media pack
mediaPackWriter.addPhoto(sha, reencoded.ext, reencoded.bytes);

// Add thumbnail to journal
journalWriter.addThumbnail(sha, thumbnail);
```

### 6. Create Entry Reference

```json
{
  "id": "m_001",
  "kind": "photo",
  "sha256": "7f5e2c...",
  "thumbUri": "assets/thumbs/7f5e2c...jpg",
  "fullRef": "mcp://photo/7f5e2c...",
  "createdAt": "2025-10-18T18:44:12Z"
}
```

---

## Import & Resolution

### Timeline Rendering (Fast)

```dart
final mediaResolver = MediaResolver(
  journalPath: '/path/to/journal_v1.mcp.zip',
  mediaPackPaths: ['/path/to/mcp_media_2025_01.zip'],
);

// Load thumbnail for timeline tile
final thumbnailBytes = await mediaResolver.loadThumbnail(sha);
// Display 768px thumbnail instantly
```

### Full Image Viewing

```dart
// User taps to view full photo
final fullImageBytes = await mediaResolver.loadFullImage(sha);

if (fullImageBytes != null) {
  // Show full 2048px image
} else {
  // Show "Mount media pack 2025_01" prompt
}
```

### Cache Optimization

```dart
// Build cache at startup for fast lookups
await mediaResolver.buildCache();

// Now resolver has SHA -> pack ID map in memory
// Future lookups skip manifest scanning
```

---

## Rolling Media Packs

### Monthly Strategy (Default)

```dart
final packId = '2025_01';  // YYYY_MM format
final packPath = 'mcp_media_2025_01.zip';

// On month change, finalize current pack and create new one
if (DateTime.now().month != currentPackMonth) {
  await currentMediaPack.finalize();
  await initializeNewMediaPack();
}
```

### Size-Based Strategy (Alternative)

```dart
final maxPackSize = 100 * 1024 * 1024;  // 100MB

if (currentMediaPack.archiveSize > maxPackSize) {
  await currentMediaPack.finalize();
  await initializeNewMediaPack();
}
```

---

## Migration from `ph://`

### Analysis (Dry Run)

```dart
final migrationService = PhotoMigrationService(
  journalRepository: journalRepo,
  outputDir: '/path/to/exports',
);

final analysis = await migrationService.analyzeMigration();

print('Total entries: ${analysis.totalEntries}');
print('Entries with media: ${analysis.entriesWithMedia}');
print('Photo library photos: ${analysis.photoLibraryMedia}');
print('File path photos: ${analysis.filePathMedia}');
```

### Migration (Execute)

```dart
final result = await migrationService.migrateAllEntries();

if (result.success) {
  print('✅ Migrated ${result.migratedEntries} entries');
  print('✅ Migrated ${result.migratedMedia} media items');
  print('📦 Journal: ${result.journalPath}');
  print('📦 Media packs: ${result.mediaPackPaths}');
} else {
  print('❌ Migration failed: ${result.message}');
}
```

---

## Privacy & EXIF

### EXIF Stripping (Default)

All photos are re-encoded during export, automatically stripping EXIF data:

```dart
// Original photo may have GPS, camera model, etc.
final reencoded = reencodeFull(originalBytes, ...);
// Reencoded photo has NO EXIF data
```

### Safe Metadata (Optional)

If you need to preserve creation date and orientation:

```dart
// Save minimal sidecar in media pack
final safeMeta = {
  'creationDate': photo.creationDate.toIso8601String(),
  'orientation': photo.orientation,
};

// Store in pack as assets/photos/<sha>.exif.json
```

---

## Testing

### Unit Tests

```dart
// Test hashing consistency
final sha1 = sha256Hex(imageBytes);
final sha2 = sha256Hex(imageBytes);
assert(sha1 == sha2);

// Test image processing
final reencoded = reencodeFull(largeImage, maxEdge: 2048);
assert(reencoded.bytes.length < originalBytes.length);

final thumb = makeThumbnail(reencoded.bytes, maxEdge: 768);
assert(thumb.length < reencoded.bytes.length);
```

### Integration Tests

```dart
// Export -> Import round trip
final exportService = ContentAddressedExportService(...);
final exportResult = await exportService.exportJournal(entries: testEntries);

final importService = ContentAddressedImportService(
  journalPath: exportResult.journalPath!,
  mediaPackPaths: exportResult.mediaPackPaths,
  journalRepository: journalRepo,
);
final importResult = await importService.importJournal();

assert(importResult.success);
assert(importResult.importedEntries == testEntries.length);
```

---

## File Locations

### Implementation Files

- **Models**
  - `lib/prism/mcp/models/journal_manifest.dart`
  - `lib/prism/mcp/models/media_pack_manifest.dart`

- **Image Processing**
  - `lib/prism/mcp/utils/image_processing.dart`

- **Platform Bridge**
  - `lib/platform/photo_bridge.dart` (Dart)
  - `ios/Runner/PhotoChannel.swift` (Swift)

- **ZIP Handling**
  - `lib/prism/mcp/zip/mcp_zip_writer.dart`
  - `lib/prism/mcp/zip/mcp_zip_reader.dart`

- **Services**
  - `lib/prism/mcp/export/content_addressed_export_service.dart`
  - `lib/prism/mcp/import/content_addressed_import_service.dart`
  - `lib/prism/mcp/media_resolver.dart`
  - `lib/prism/mcp/migration/photo_migration_service.dart`

- **Tests**
  - `lib/test_content_addressed.dart`

---

## Usage Examples

### Basic Export

```dart
final exportService = ContentAddressedExportService(
  bundleId: 'my_journal_2025',
  outputDir: '/exports',
);

final result = await exportService.exportJournal(
  entries: myJournalEntries,
  createMediaPacks: true,
);

print('📦 Journal: ${result.journalPath}');
print('📦 Media packs: ${result.mediaPackPaths}');
```

### Basic Import

```dart
final importService = ContentAddressedImportService(
  journalPath: '/exports/journal_v1.mcp.zip',
  mediaPackPaths: ['/exports/mcp_media_2025_01.zip'],
  journalRepository: journalRepo,
);

final result = await importService.importJournal();
print('✅ Imported ${result.importedEntries} entries');
```

### Timeline UI

```dart
class TimelineTile extends StatelessWidget {
  final MediaItem media;
  final MediaResolver resolver;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: resolver.loadThumbnail(media.sha256),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!);
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

---

## Performance Characteristics

### Journal Size (100 entries, 200 photos)

- **Entries JSON**: ~50KB
- **Thumbnails (768px)**: ~20MB (100KB each)
- **Journal total**: ~20MB

### Media Pack Size (200 photos)

- **Full photos (2048px, Q85)**: ~150MB (750KB each)
- **Manifest**: ~10KB

### Memory Usage

- **Timeline rendering**: ~20MB (thumbnails only)
- **Full photo view**: +750KB per photo
- **Resolver cache**: ~5KB per 100 photos

### Speed

- **Export**: ~100ms per photo (fetch + hash + re-encode + thumbnail)
- **Import**: ~10ms per entry (JSON parse)
- **Thumbnail load**: ~5ms (ZIP read + decompress)
- **Full photo load**: ~20ms (ZIP read + decompress)

---

## Edge Cases

### iCloud Photos Not Downloaded

```dart
// Swift PhotoChannel sets isNetworkAccessAllowed = true
// Automatically downloads from iCloud if needed
// May take 1-5 seconds for large photos
```

### Missing Media Pack

```dart
final fullBytes = await resolver.loadFullImage(sha);

if (fullBytes == null) {
  // Show CTA: "Mount media pack 2025_01 to view full resolution"
  showMountPackPrompt(packId: '2025_01');
} else {
  // Display full photo
}
```

### Duplicate Photos

```dart
// SHA-256 automatically deduplicates
// Same photo in multiple entries:
// - Single entry in media pack
// - Single thumbnail in journal
// - Multiple entries reference same SHA
```

### Format Support

Supported formats:
- JPEG ✅
- PNG ✅ (converted to JPEG)
- HEIC ✅ (converted to JPEG on export)
- WebP ✅ (if image package supports)

---

## Troubleshooting

### "Photo bytes unavailable"

**Cause**: iCloud photo not yet downloaded, or photo deleted.

**Solution**:
1. Enable `isNetworkAccessAllowed = true` in Swift bridge
2. Add retry logic with exponential backoff
3. Mark media with `export_warning = "photo_bytes_unavailable"`

### "Thumbnail not rendering"

**Cause**: SHA mismatch or corrupted ZIP.

**Solution**:
1. Verify SHA with `sha256Hex(thumbnailBytes)`
2. Check journal ZIP integrity
3. Re-export entry

### "Media pack too large"

**Cause**: Monthly pack exceeded expected size.

**Solution**:
1. Switch to size-based rotation strategy
2. Reduce `maxEdge` or `quality` settings
3. Archive old packs to external storage

---

## Future Enhancements

### Video Support

```dart
// Similar approach with video codecs
"kind": "video",
"sha256": "...",
"thumbUri": "assets/thumbs/<sha>.jpg",  // Video thumbnail
"fullRef": "mcp://video/<sha>",
```

### Cloud Sync

```dart
// Upload media packs to S3/GCS
// Journal references cloud URLs
"fullRef": "mcp://photo/<sha>?cloud=true",
"cloudUrl": "https://storage.../mcp_media_2025_01.zip",
```

### Incremental Export

```dart
// Only export new/modified entries
// Append to existing journal
// Reference existing media packs
```

---

## Summary

The Content-Addressed Media System makes MCP journals durable, portable, and privacy-preserving. By replacing fragile URIs with content hashes and separating thumbnails from full-resolution media, we achieve:

- ✅ **Fast timeline rendering** (thumbnails in journal)
- ✅ **Deduplication** (SHA-256 content addressing)
- ✅ **Privacy** (EXIF stripping)
- ✅ **Portability** (works across devices)
- ✅ **Scalability** (rolling media packs)
- ✅ **Graceful degradation** (thumbnails when packs unavailable)

The system is production-ready and can be integrated into the timeline UI and export workflows immediately.
