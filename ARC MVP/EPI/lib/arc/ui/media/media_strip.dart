import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';

/// Horizontal strip showing attached media items with preview and delete functionality
class MediaStrip extends StatelessWidget {
  final List<MediaItem> mediaItems;
  final Function(MediaItem) onMediaTapped;
  final Function(MediaItem) onMediaDeleted;
  final bool isReadOnly;
  
  const MediaStrip({
    super.key,
    required this.mediaItems,
    required this.onMediaTapped,
    required this.onMediaDeleted,
    this.isReadOnly = false,
  });
  
  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mediaItems.length,
        itemBuilder: (context, index) {
          final mediaItem = mediaItems[index];
          return _buildMediaThumbnail(mediaItem);
        },
      ),
    );
  }
  
  Widget _buildMediaThumbnail(MediaItem mediaItem) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // Media thumbnail
          Semantics(
            label: _getMediaSemanticLabel(mediaItem),
            button: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              child: InkWell(
                onTap: () => onMediaTapped(mediaItem),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF171C29),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: _buildMediaContent(mediaItem),
                ),
              ),
            ),
          ),
          
          // Delete button (if not read-only)
          if (!isReadOnly)
            Positioned(
              top: 4,
              right: 4,
              child: Semantics(
                label: 'Delete ${_getMediaTypeName(mediaItem.type)}',
                button: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  child: InkWell(
                    onTap: () => _showDeleteConfirmation(mediaItem),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Media type indicator
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getMediaTypeIcon(mediaItem.type),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMediaContent(MediaItem mediaItem) {
    switch (mediaItem.type) {
      case MediaType.audio:
        return _buildAudioThumbnail(mediaItem);
      case MediaType.image:
        return _buildImageThumbnail(mediaItem);
      case MediaType.video:
        return _buildVideoThumbnail(mediaItem);
      case MediaType.file:
        return _buildFileThumbnail(mediaItem);
    }
  }
  
  Widget _buildAudioThumbnail(MediaItem mediaItem) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.audiotrack,
          color: Colors.blue,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          _formatDuration(mediaItem.duration!),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
        if (mediaItem.transcript != null && mediaItem.transcript!.isNotEmpty)
          const Icon(
            Icons.text_fields,
            color: Colors.green,
            size: 12,
          ),
      ],
    );
  }
  
  Widget _buildImageThumbnail(MediaItem mediaItem) {
    // TODO: Implement actual image thumbnail loading
    // For now, show a placeholder
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.image,
          color: Colors.green,
          size: 24,
        ),
        if (mediaItem.ocrText != null && mediaItem.ocrText!.isNotEmpty)
          const Icon(
            Icons.text_fields,
            color: Colors.blue,
            size: 12,
          ),
      ],
    );
  }
  
  Widget _buildVideoThumbnail(MediaItem mediaItem) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.videocam,
          color: Colors.purple,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          _formatDuration(mediaItem.duration!),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFileThumbnail(MediaItem mediaItem) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.insert_drive_file,
          color: Colors.orange,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          _formatFileSize(mediaItem.sizeBytes),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  String _getMediaSemanticLabel(MediaItem mediaItem) {
    final typeName = _getMediaTypeName(mediaItem.type);
    final duration = mediaItem.duration != null 
        ? ' (${_formatDuration(mediaItem.duration!)})'
        : '';
    final hasTranscript = mediaItem.transcript != null && mediaItem.transcript!.isNotEmpty;
    final hasOcrText = mediaItem.ocrText != null && mediaItem.ocrText!.isNotEmpty;
    final extraInfo = hasTranscript || hasOcrText ? ' with text' : '';
    
    return '$typeName$duration$extraInfo';
  }
  
  String _getMediaTypeName(MediaType type) {
    switch (type) {
      case MediaType.audio:
        return 'Audio';
      case MediaType.image:
        return 'Image';
      case MediaType.video:
        return 'Video';
      case MediaType.file:
        return 'File';
    }
  }
  
  String _getMediaTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.audio:
        return '🎵';
      case MediaType.image:
        return '📷';
      case MediaType.video:
        return '🎥';
      case MediaType.file:
        return '📄';
    }
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String _formatFileSize(int? sizeBytes) {
    if (sizeBytes == null) return '';
    
    if (sizeBytes < 1024) {
      return '${sizeBytes}B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  
  void _showDeleteConfirmation(MediaItem mediaItem) {
    // TODO: Implement delete confirmation dialog
    // For now, directly delete
    onMediaDeleted(mediaItem);
  }
}
