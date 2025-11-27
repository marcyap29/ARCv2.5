import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:my_app/data/models/media_item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

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
                  child: _buildMediaContent(context),
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
  
  Widget _buildMediaContent(BuildContext context) {
    switch (mediaItem.type) {
      case MediaType.audio:
        return _buildAudioContent();
      case MediaType.image:
        return _buildImageContent();
      case MediaType.video:
        return _buildVideoContent(context);
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
  
  Widget _buildVideoContent(BuildContext context) {
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
                  _playVideo(context);
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
  
  void _playVideo(BuildContext context) {
    // Navigate to a full-screen video player
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _VideoPlayerScreen(videoPath: mediaItem.uri),
      ),
    );
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

/// Fullscreen video player widget
class _VideoPlayerScreen extends StatefulWidget {
  final String videoPath;

  const _VideoPlayerScreen({required this.videoPath});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Handle ph:// URIs (photo library videos) - can't use VideoPlayerController directly
      if (widget.videoPath.startsWith('ph://')) {
        setState(() {
          _errorMessage = 'Photo library videos must be opened externally. Closing player...';
        });
        // Wait a moment to show message, then close and open externally
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop();
          // Try to open externally
          await _openVideoExternally(widget.videoPath);
        }
        return;
      }

      // Validate video URI before attempting to create controller
      if (!_isValidVideoUri(widget.videoPath)) {
        setState(() {
          _errorMessage = 'Invalid video file: Video not found or corrupted';
        });
        return;
      }

      // Create controller for local file
      _controller = VideoPlayerController.file(File(widget.videoPath));

      // Initialize the controller with timeout to prevent hanging
      try {
        await _controller!.initialize().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('Video initialization timeout after 3 seconds');
            throw TimeoutException('Video initialization timed out', const Duration(seconds: 3));
          },
        );
      } catch (e) {
        // Clean up controller on timeout or error
        await _controller?.dispose();
        _controller = null;
        throw e;
      }

      // Verify controller is initialized
      if (_controller == null || !_controller!.value.isInitialized) {
        setState(() {
          _errorMessage = 'Failed to initialize video player';
        });
        return;
      }

      setState(() {
        _isInitialized = true;
      });

      // Auto-play the video
      try {
        await _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      } catch (e) {
        print('Error playing video: $e');
        setState(() {
          _errorMessage = 'Failed to play video: $e';
        });
        return;
      }

      // Listen for video completion
      _controller!.addListener(_videoListener);
    } catch (e, stackTrace) {
      print('Error initializing video: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to load video: ${e.toString()}';
      });
      // Clean up on error
      await _controller?.dispose();
      _controller = null;
    }
  }

  void _videoListener() {
    if (_controller != null && 
        _controller!.value.isInitialized &&
        _controller!.value.position >= _controller!.value.duration &&
        _controller!.value.duration.inMilliseconds > 0) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  /// Open video externally (for ph:// URIs or when VideoPlayerController fails)
  Future<void> _openVideoExternally(String videoPath) async {
    try {
      // Try photos:// scheme for photo library videos
      if (videoPath.startsWith('ph://')) {
        final localId = videoPath.replaceFirst('ph://', '');
        final photosUri = Uri.parse('photos://$localId');
        if (await canLaunchUrl(photosUri)) {
          await launchUrl(photosUri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Try file:// scheme for local files
      final fileUri = Uri.file(videoPath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      print('Error opening video externally: $e');
    }
  }

  /// Validates if the video URI is valid and the file exists
  bool _isValidVideoUri(String videoPath) {
    // Check for placeholder URIs that indicate missing videos
    if (videoPath.startsWith('placeholder://')) {
      return false;
    }

    // ph:// URIs are valid but need external player (handled separately)
    if (videoPath.startsWith('ph://')) {
      return true; // Valid, but will be handled externally
    }

    // Check for other invalid schemes
    if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
      return false; // Remote videos not supported in this player
    }

    // For local file paths, check if file exists
    try {
      final file = File(videoPath);
      return file.existsSync();
    } catch (e) {
      print('Error checking video file existence: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // Remove listener before disposing
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized || !_controller!.value.isInitialized) {
      return; // Don't attempt to play if controller isn't ready
    }

    try {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Error toggling play/pause: $e');
      setState(() {
        _errorMessage = 'Failed to control playback: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Video Player',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: _errorMessage != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              )
            : !_isInitialized
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      // Video player
                      Center(
                        child: _controller != null && _controller!.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: VideoPlayer(_controller!),
                              )
                            : const CircularProgressIndicator(color: Colors.white),
                      ),
                      // Play/pause overlay
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            color: Colors.transparent,
                            child: Center(
                              child: AnimatedOpacity(
                                opacity: _isPlaying ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Video progress indicator
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _isInitialized && _controller != null
                            ? VideoProgressIndicator(
                                _controller!,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.red,
                                  bufferedColor: Colors.grey,
                                  backgroundColor: Colors.white30,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
      ),
    );
  }
}
