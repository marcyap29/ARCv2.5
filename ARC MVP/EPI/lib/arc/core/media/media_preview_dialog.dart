import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';

/// Full-screen dialog for previewing media items
class MediaPreviewDialog extends StatelessWidget {
  final MediaItem mediaItem;
  final VoidCallback? onDelete;
  final bool canDelete;
  
  const MediaPreviewDialog({
    super.key,
    required this.mediaItem,
    this.onDelete,
    this.canDelete = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Full screen content
          Positioned.fill(
            child: Column(
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getMediaTypeName(mediaItem.type),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          if (canDelete && onDelete != null)
                            Semantics(
                              label: 'Delete ${_getMediaTypeName(mediaItem.type)}',
                              button: true,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    onDelete!();
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: 'Close preview',
                            button: true,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Media content
                Expanded(
                  child: _buildMediaContent(),
                ),
                
                // Footer with metadata
                Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildMetadata(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMediaContent() {
    switch (mediaItem.type) {
      case MediaType.audio:
        return _buildAudioContent();
      case MediaType.image:
        return _buildImageContent();
      case MediaType.video:
        return _buildVideoContent();
      case MediaType.file:
        return _buildFileContent();
    }
  }
  
  Widget _buildAudioContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.audiotrack,
            color: Colors.blue,
            size: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'Audio Recording',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (mediaItem.duration != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDuration(mediaItem.duration!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Play button
          Semantics(
            label: 'Play audio recording',
            button: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 60,
                minHeight: 60,
              ),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement audio playback
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImageContent() {
    // TODO: Implement actual image display
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            color: Colors.green,
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            'Image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Preview not implemented yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam,
            color: Colors.purple,
            size: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (mediaItem.duration != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDuration(mediaItem.duration!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Play button
          Semantics(
            label: 'Play video',
            button: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 60,
                minHeight: 60,
              ),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement video playback
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: Colors.orange,
            size: 80,
          ),
          SizedBox(height: 16),
          Text(
            'File',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Preview not available',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetadata() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetadataRow('Type', _getMediaTypeName(mediaItem.type)),
          _buildMetadataRow('Created', _formatDateTime(mediaItem.createdAt)),
          if (mediaItem.duration != null)
            _buildMetadataRow('Duration', _formatDuration(mediaItem.duration!)),
          if (mediaItem.sizeBytes != null)
            _buildMetadataRow('Size', _formatFileSize(mediaItem.sizeBytes!)),
          if (mediaItem.transcript != null && mediaItem.transcript!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Transcript:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mediaItem.transcript!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
          if (mediaItem.ocrText != null && mediaItem.ocrText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Extracted Text:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mediaItem.ocrText!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
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
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String _formatFileSize(int sizeBytes) {
    if (sizeBytes < 1024) {
      return '${sizeBytes}B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}
