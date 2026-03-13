// lib/arc/outputs/output_detail_screen.dart
//
// Phase 5a: Full content view for an OutputItem.
// For scanner/scans: shows photo gallery (reflection-style) + extracted text.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/widgets/tag_chip_row.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/ui/journal/widgets/full_screen_photo_viewer.dart';

class OutputDetailScreen extends StatelessWidget {
  final OutputItem item;

  const OutputDetailScreen({super.key, required this.item});

  /// Parse scan content: returns (rawText, list of image paths) if scan format.
  static ({String? rawText, List<String> imagePaths}) parseScanContent(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return (rawText: null, imagePaths: []);
    try {
      final map = jsonDecode(contentJson) as Map<String, dynamic>?;
      if (map == null) return (rawText: null, imagePaths: []);
      final rawText = map['raw_text'] as String?;
      final paths = <String>[];
      final single = map['image_path'] as String?;
      if (single != null && single.isNotEmpty) paths.add(single);
      final list = map['image_paths'] as List<dynamic>?;
      if (list != null) {
        for (final e in list) {
          if (e is String && e.isNotEmpty && !paths.contains(e)) paths.add(e);
        }
      }
      return (rawText: rawText, imagePaths: paths);
    } catch (_) {
      return (rawText: null, imagePaths: []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScan = item.agentKey == 'scanner' && item.folderKey == 'scans';
    final scanData = isScan ? parseScanContent(item.contentJson) : (rawText: null, imagePaths: <String>[]);
    final hasScanImages = scanData.imagePaths.isNotEmpty;

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        title: Text(
          item.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMd().add_Hm().format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
            if (item.autoTags.isNotEmpty || item.userTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              TagChipRow(
                autoTags: item.autoTags,
                userTags: item.userTags,
                editable: false,
              ),
            ],
            // Scan gallery (reflection-style): horizontal thumbnails, tap for full screen
            if (hasScanImages) ...[
              const SizedBox(height: 20),
              Text(
                'Scan',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: scanData.imagePaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = scanData.imagePaths[index];
                    return _ScanThumbnail(
                      imagePath: path,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (ctx) => FullScreenPhotoViewer(
                              photos: scanData.imagePaths
                                  .map((p) => PhotoData(imagePath: p))
                                  .toList(),
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            // Extracted text (scans) or generic content
            if (item.contentJson != null && item.contentJson!.isNotEmpty) ...[
              if (!isScan || (scanData.rawText != null && scanData.rawText!.isNotEmpty)) ...[
                const SizedBox(height: 20),
                Text(
                  isScan ? 'Extracted text' : 'Content',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kcSurfaceAltColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    isScan ? (scanData.rawText ?? '') : item.contentJson!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kcPrimaryTextColor,
                        ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Thumbnail for a scan image (file path); tap opens full-screen viewer.
/// Restore step-by-step: uncomment one block at a time and run `flutter build ios --release` until it fails, then fix that block.
class _ScanThumbnail extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;

  const _ScanThumbnail({required this.imagePath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    // Minimal working: tap target with placeholder. Uncomment below blocks one at a time to restore full UI.
    return Material(
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 120,
            height: 120,
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 32,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
