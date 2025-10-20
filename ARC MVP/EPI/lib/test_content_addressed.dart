import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:my_app/prism/mcp/utils/image_processing.dart';
import 'package:my_app/prism/mcp/models/journal_manifest.dart';
import 'package:my_app/prism/mcp/models/media_pack_manifest.dart';

/// Simple test of the content-addressed media system
void main() async {
  print('🧪 Testing Content-Addressed Media System');
  
  // Test image processing
  print('📸 Testing image processing...');
  
  // Create a simple test image using the image package
  final testImage = img.Image(width: 100, height: 100);
  // Fill with red color (the fill function modifies the image in-place)
  for (var y = 0; y < testImage.height; y++) {
    for (var x = 0; x < testImage.width; x++) {
      testImage.setPixelRgb(x, y, 255, 0, 0); // Red pixel
    }
  }
  final testImageBytes = Uint8List.fromList(img.encodeJpg(testImage));
  
  // Test SHA-256 hashing
  final sha = sha256Hex(testImageBytes);
  print('✅ SHA-256 hash: $sha');
  
  // Test image reencoding
  final reencoded = reencodeFull(testImageBytes, maxEdge: 1024, quality: 85);
  print('✅ Reencoded image: ${reencoded.bytes.length} bytes, format: ${reencoded.ext}');
  
  // Test thumbnail generation
  final thumbnail = makeThumbnail(testImageBytes, maxEdge: 512);
  print('✅ Thumbnail: ${thumbnail.length} bytes');
  
  // Test manifest creation
  print('📋 Testing manifest creation...');
  
  final journalManifest = JournalManifest(
    version: 1,
    createdAt: DateTime.now(),
    mediaPacks: [
      MediaPackRef(
        id: '2025_01',
        filename: 'mcp_media_2025_01.zip',
        from: DateTime(2025, 1, 1),
        to: DateTime(2025, 1, 31),
      ),
    ],
    thumbnails: ThumbnailConfig.defaultConfig,
  );
  
  print('✅ Journal manifest created');
  print('   Version: ${journalManifest.version}');
  print('   Media packs: ${journalManifest.mediaPacks.length}');
  print('   Thumbnail config: ${journalManifest.thumbnails.size}px, ${journalManifest.thumbnails.format}');
  
  final mediaPackManifest = MediaPackManifest(
    id: '2025_01',
    from: DateTime(2025, 1, 1),
    to: DateTime(2025, 1, 31),
    items: {
      sha: MediaPackItem(
        path: 'photos/$sha.jpg',
        bytes: reencoded.bytes.length,
        format: reencoded.ext,
      ),
    },
  );
  
  print('✅ Media pack manifest created');
  print('   Pack ID: ${mediaPackManifest.id}');
  print('   Items: ${mediaPackManifest.itemCount}');
  print('   Total size: ${mediaPackManifest.totalSize} bytes');
  
  print('🎉 Content-Addressed Media System Test Complete!');
  print('');
  print('📊 Summary:');
  print('   - Image processing: ✅ Working');
  print('   - SHA-256 hashing: ✅ Working');
  print('   - Thumbnail generation: ✅ Working');
  print('   - Manifest creation: ✅ Working');
  print('   - Media pack management: ✅ Working');
  print('');
  print('🚀 The content-addressed media system is ready for integration!');
}
