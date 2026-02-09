/// Compact media thumbnail strip for feed cards.
/// Shows a horizontal row of thumbnails for entry media (photos, video, file).

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/ui/widgets/full_image_viewer.dart';
import 'package:my_app/services/media_resolver_service.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/shared/app_colors.dart';

/// Horizontal strip of media thumbnails (e.g. for ReflectionCard).
class FeedMediaThumbnails extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final double size;
  final int maxCount;

  const FeedMediaThumbnails({
    super.key,
    required this.mediaItems,
    this.size = 48,
    this.maxCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) return const SizedBox.shrink();

    final toShow = mediaItems.take(maxCount).toList();
    return SizedBox(
      height: size + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: toShow.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = toShow[index];
          return FeedMediaThumbnailTile(
            mediaItem: item,
            size: size,
            onTap: () => _onTap(context, item),
          );
        },
      ),
    );
  }

  void _onTap(BuildContext context, MediaItem item) {
    if (item.type == MediaType.image) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullImageViewer(mediaItem: item),
        ),
      );
    }
    // Video/file could open in external viewer; for now tap does nothing
  }
}

/// Single media thumbnail tile. Uses same resolution as timeline/journal:
/// MCP, thumbUri, file://, ph:// (PhotoLibraryService), then raw file path.
/// Reuse in feed strip and expanded entry media grid.
class FeedMediaThumbnailTile extends StatelessWidget {
  final MediaItem mediaItem;
  final double size;
  final VoidCallback? onTap;

  const FeedMediaThumbnailTile({
    super.key,
    required this.mediaItem,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: kcSurfaceAltColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(),
              if (mediaItem.type == MediaType.video)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: Icon(Icons.videocam, color: Colors.white, size: 14),
                ),
              if (mediaItem.type == MediaType.file)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: Icon(Icons.insert_drive_file, color: Colors.white, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (mediaItem.type != MediaType.image && mediaItem.type != MediaType.video) {
      return _placeholder();
    }

    if (mediaItem.isMcpMedia && mediaItem.sha256 != null) {
      return FutureBuilder<Uint8List?>(
        future: MediaResolverService.instance.resolver?.loadThumbnail(mediaItem.sha256!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 2).toInt(),
            );
          }
          return _placeholder();
        },
      );
    }

    if (mediaItem.thumbUri != null && mediaItem.thumbUri!.isNotEmpty) {
      final path = mediaItem.thumbUri!.startsWith('file://')
          ? mediaItem.thumbUri!.replaceFirst('file://', '')
          : mediaItem.thumbUri!;
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (mediaItem.uri.startsWith('file://')) {
      final path = mediaItem.uri.replaceFirst('file://', '');
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (mediaItem.uri.startsWith('ph://')) {
      return FutureBuilder<String?>(
        future: PhotoLibraryService.getPhotoThumbnail(mediaItem.uri, size: (size * 2).toInt()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: size,
              height: size,
              color: kcSurfaceColor,
              child: Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kcSecondaryTextColor.withOpacity(0.5),
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.file(
              File(snapshot.data!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 2).toInt(),
              errorBuilder: (_, __, ___) => _placeholder(),
            );
          }
          return _placeholder();
        },
      );
    }

    // Raw file path (same as journal/timeline: try Image.file, errorBuilder on failure)
    return Image.file(
      File(mediaItem.uri),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * 2).toInt(),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: kcSurfaceColor,
      child: Icon(
        mediaItem.type == MediaType.video ? Icons.videocam : Icons.image,
        size: size * 0.4,
        color: kcSecondaryTextColor.withOpacity(0.5),
      ),
    );
  }
}
