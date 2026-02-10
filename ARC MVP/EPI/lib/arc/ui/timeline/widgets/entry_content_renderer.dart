import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/ui/widgets/full_image_viewer.dart';
import 'package:my_app/services/media_resolver_service.dart';
import 'package:my_app/core/services/photo_library_service.dart';

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
    // Remove maxHeight constraint to allow photos to display fully
    // The SingleChildScrollView will handle overflow
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildContentWithInlinePhotos(context),
      ),
    );
  }

  /// Build paragraph widgets (double newlines = paragraph break; single = line break).
  List<Widget> _buildParagraphs(BuildContext context) {
    if (content.trim().isEmpty) return [];
    List<String> paragraphs = content.split('\n\n');
    paragraphs = paragraphs.map((p) => p.replaceAll('\n', ' ').trim()).where((p) => p.isNotEmpty).toList();
    if (paragraphs.length == 1 && content.contains('\n')) {
      paragraphs = content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    final style = textStyle ?? Theme.of(context).textTheme.bodyMedium;
    final result = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      result.add(Padding(
        padding: EdgeInsets.only(bottom: i < paragraphs.length - 1 ? 12 : 0),
        child: Text(paragraphs[i], style: style?.copyWith(height: 1.5)),
      ));
    }
    return result.isEmpty ? [Text(content, style: style)] : result;
  }

  /// Build content with inline photo thumbnails
  List<Widget> _buildContentWithInlinePhotos(BuildContext context) {
    final widgets = <Widget>[];
    
    // Debug logging
    print('🖼️ EntryContentRenderer: Building content with ${mediaItems.length} media items');
    if (mediaItems.isNotEmpty) {
      for (int i = 0; i < mediaItems.length; i++) {
        final media = mediaItems[i];
        print('🖼️ EntryContentRenderer: Media $i - id=${media.id}, type=${media.type.name}, uri=${media.uri}');
      }
    }
    
    // Simply render the text content without parsing PHOTO tags
    // Photos are now displayed separately as thumbnails below the text
    if (content.trim().isNotEmpty) {
      widgets.addAll(_buildParagraphs(context));
    }

    // Add photo thumbnails below the text if any exist
    if (mediaItems.isNotEmpty) {
      print('🖼️ EntryContentRenderer: Adding photo thumbnail grid with ${mediaItems.length} items');
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildPhotoThumbnailGrid(context));
    } else {
      print('🖼️ EntryContentRenderer: No media items to display');
    }
    
    return widgets;
  }

  /// Build photo thumbnail grid
  Widget _buildPhotoThumbnailGrid(BuildContext context) {
    print('🖼️ EntryContentRenderer: Building thumbnail grid for ${mediaItems.length} items');
    if (mediaItems.isEmpty) {
      print('🖼️ EntryContentRenderer: WARNING - mediaItems is empty in _buildPhotoThumbnailGrid');
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mediaItems.map((mediaItem) {
        print('🖼️ EntryContentRenderer: Creating widget for media: ${mediaItem.id}, uri: ${mediaItem.uri}');
        return _buildPhotoWidget(context, mediaItem);
      }).toList(),
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
    print('🖼️ EntryContentRenderer: Building thumbnail for media: id=${mediaItem.id}, uri=${mediaItem.uri}, type=${mediaItem.type.name}');
    
    // Check if MCP media (content-addressed)
    if (mediaItem.isMcpMedia && mediaItem.sha256 != null) {
      print('🖼️ EntryContentRenderer: Detected MCP media with sha256: ${mediaItem.sha256}');
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
    } else if (mediaItem.uri.startsWith('ph://')) {
      // Load thumbnail from photo library
      print('🖼️ EntryContentRenderer: Loading photo library thumbnail for: ${mediaItem.uri}');
      return FutureBuilder<String?>(
        future: PhotoLibraryService.getPhotoThumbnail(mediaItem.uri, size: 160),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('🖼️ EntryContentRenderer: ERROR loading photo library thumbnail: ${snapshot.error}');
          }
          if (snapshot.hasData) {
            print('🖼️ EntryContentRenderer: Photo library thumbnail loaded: ${snapshot.data}');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey[300],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            return Image.file(
              File(snapshot.data!),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              cacheWidth: 160,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            );
          }
          
          return _buildPlaceholderImage();
        },
      );
    } else {
      // Assume local file path
      print('🖼️ EntryContentRenderer: Loading local file: ${mediaItem.uri}');
      final file = File(mediaItem.uri);
      if (!file.existsSync()) {
        print('🖼️ EntryContentRenderer: WARNING - File does not exist: ${mediaItem.uri}');
      }
      return Image.file(
        file,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        cacheWidth: 160, // Optimize for performance
        errorBuilder: (context, error, stackTrace) {
          print('🖼️ EntryContentRenderer: ERROR loading image file: $error');
          print('🖼️ EntryContentRenderer: Stack trace: $stackTrace');
          return _buildPlaceholderImage();
        },
      );
    }
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

