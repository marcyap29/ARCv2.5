import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/ui/widgets/full_image_viewer.dart';
import 'package:my_app/services/media_resolver_service.dart';

/// Renders journal entry content with inline photo thumbnails
class EntryContentRenderer extends StatelessWidget {
  final String content;
  final List<MediaItem> mediaItems;
  final TextStyle? textStyle;

  const EntryContentRenderer({
    super.key,
    required this.content,
    required this.mediaItems,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 300, // Limit height to prevent overflow
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildContentWithInlinePhotos(context),
        ),
      ),
    );
  }

  /// Build content with inline photo thumbnails
  List<Widget> _buildContentWithInlinePhotos(BuildContext context) {
    final widgets = <Widget>[];
    
    // Simply render the text content without parsing PHOTO tags
    // Photos are now displayed separately as thumbnails below the text
    if (content.trim().isNotEmpty) {
      widgets.add(Text(content, style: textStyle));
    }
    
    // Add photo thumbnails below the text if any exist
    if (mediaItems.isNotEmpty) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildPhotoThumbnailGrid(context));
    }
    
    return widgets;
  }

  /// Build photo thumbnail grid
  Widget _buildPhotoThumbnailGrid(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mediaItems.map((mediaItem) => _buildPhotoWidget(context, mediaItem)).toList(),
    );
  }

  /// Build tappable photo widget with thumbnail (smaller for grid layout)
  Widget _buildPhotoWidget(BuildContext context, MediaItem mediaItem) {
    return SizedBox(
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () {
          // Open full-screen viewer
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FullImageViewer(mediaItem: mediaItem),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                _buildThumbnailImage(mediaItem),
                
                // Tap indicator
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build thumbnail image from MediaItem (smaller for grid layout)
  Widget _buildThumbnailImage(MediaItem mediaItem) {
    // Check if MCP media (content-addressed)
    if (mediaItem.isMcpMedia && mediaItem.sha256 != null) {
      return FutureBuilder<Uint8List?>(
        future: MediaResolverService.instance.resolver?.loadThumbnail(mediaItem.sha256!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              cacheWidth: 160, // Optimize for performance
            );
          }
          return _buildPlaceholderImage();
        },
      );
    }
    
    // Try to use thumbUri if available
    if (mediaItem.thumbUri != null && mediaItem.thumbUri!.isNotEmpty) {
      final thumbPath = mediaItem.thumbUri!.startsWith('file://')
          ? mediaItem.thumbUri!.replaceFirst('file://', '')
          : mediaItem.thumbUri!;
      
      final thumbFile = File(thumbPath);
      if (thumbFile.existsSync()) {
        return Image.file(
          thumbFile,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          cacheWidth: 160, // Optimize for performance
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage();
          },
        );
      }
    }
    
    // Fallback to main URI
    if (mediaItem.uri.startsWith('file://')) {
      return Image.file(
        File(mediaItem.uri.replaceFirst('file://', '')),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        cacheWidth: 160, // Optimize for performance
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else if (!mediaItem.uri.startsWith('ph://')) {
      // Assume local file path
      return Image.file(
        File(mediaItem.uri),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        cacheWidth: 160, // Optimize for performance
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    }
    
    // Can't display ph:// URIs directly
    return _buildPlaceholderImage();
  }

  /// Build placeholder for missing or unloadable images
  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image, size: 24, color: Colors.grey),
      ),
    );
  }
}

