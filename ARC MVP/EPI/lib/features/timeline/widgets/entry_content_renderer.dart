import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/ui/widgets/full_image_viewer.dart';

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
    final photoPlaceholderRegex = RegExp(r'\[PHOTO:([^\]]+)\]');
    
    int lastIndex = 0;
    final matches = photoPlaceholderRegex.allMatches(content);
    
    if (matches.isEmpty) {
      // No photos, just render text
      widgets.add(Text(content, style: textStyle));
      return widgets;
    }
    
    for (final match in matches) {
      // Add text before the photo
      if (match.start > lastIndex) {
        final textBefore = content.substring(lastIndex, match.start);
        if (textBefore.trim().isNotEmpty) {
          widgets.add(Text(textBefore, style: textStyle));
          widgets.add(const SizedBox(height: 8));
        }
      }
      
      // Find and add the photo
      final photoId = match.group(1)!;
      final mediaItem = _findMediaItemByPhotoId(photoId);
      
      if (mediaItem != null) {
        widgets.add(_buildPhotoWidget(context, mediaItem));
        widgets.add(const SizedBox(height: 12));
      } else {
        // Photo not found, show placeholder
        widgets.add(_buildMissingPhotoPlaceholder(photoId));
        widgets.add(const SizedBox(height: 8));
      }
      
      lastIndex = match.end;
    }
    
    // Add remaining text after last photo
    if (lastIndex < content.length) {
      final textAfter = content.substring(lastIndex);
      if (textAfter.trim().isNotEmpty) {
        widgets.add(Text(textAfter, style: textStyle));
      }
    }
    
    return widgets;
  }

  /// Find media item by photo ID
  MediaItem? _findMediaItemByPhotoId(String photoId) {
    try {
      return mediaItems.firstWhere((item) => item.id == photoId);
    } catch (e) {
      return null;
    }
  }

  /// Build tappable photo widget with thumbnail
  Widget _buildPhotoWidget(BuildContext context, MediaItem mediaItem) {
    return GestureDetector(
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
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              _buildThumbnailImage(mediaItem),
              
              // Overlay with alt text if available
              if (mediaItem.altText != null && mediaItem.altText!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      mediaItem.altText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              
              // Tap indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build thumbnail image from MediaItem
  Widget _buildThumbnailImage(MediaItem mediaItem) {
    // Try to use thumbUri if available
    if (mediaItem.thumbUri != null && mediaItem.thumbUri!.isNotEmpty) {
      final thumbPath = mediaItem.thumbUri!.startsWith('file://')
          ? mediaItem.thumbUri!.replaceFirst('file://', '')
          : mediaItem.thumbUri!;
      
      final thumbFile = File(thumbPath);
      if (thumbFile.existsSync()) {
        return Image.file(
          thumbFile,
          fit: BoxFit.cover,
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
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else if (!mediaItem.uri.startsWith('ph://')) {
      // Assume local file path
      return Image.file(
        File(mediaItem.uri),
        fit: BoxFit.cover,
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
      height: 200,
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Build placeholder for missing photos
  Widget _buildMissingPhotoPlaceholder(String photoId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Photo missing: $photoId',
              style: TextStyle(
                color: Colors.orange[900],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

