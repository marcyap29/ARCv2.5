import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/core/services/mcp_photo_relink_service.dart';

/// Widget that prompts users to relink photos for imported journal entries
class PhotoRelinkPrompt extends StatefulWidget {
  final String entryTitle;
  final List<MediaItem> originalMedia;
  final Function(List<MediaItem>) onPhotosRelinked;
  final VoidCallback onDismiss;

  const PhotoRelinkPrompt({
    super.key,
    required this.entryTitle,
    required this.originalMedia,
    required this.onPhotosRelinked,
    required this.onDismiss,
  });

  @override
  State<PhotoRelinkPrompt> createState() => _PhotoRelinkPromptState();
}

class _PhotoRelinkPromptState extends State<PhotoRelinkPrompt> {
  bool _isRelinking = false;
  List<MediaItem> _relinkedMedia = [];

  @override
  void initState() {
    super.initState();
    _relinkedMedia = List.from(widget.originalMedia);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_library,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Relink Photos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Entry: ${widget.entryTitle}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This imported entry had ${widget.originalMedia.length} photo(s) that need to be relinked. Please select the same photos from your gallery.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_isRelinking) ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRelinking ? null : _startPhotoRelinking,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Relink Photos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: _isRelinking ? null : _skipRelinking,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPhotoRelinking() async {
    setState(() {
      _isRelinking = true;
    });

    try {
      // Create photo relink service
      final photoRelinkService = McpPhotoRelinkService(
        mediaStore: MediaStore(),
        mediaSanitizer: MediaSanitizer(),
        ocrService: OcrService(),
      );

      // Relink photos
      final relinkedMedia = await photoRelinkService.relinkPhotosForEntry(
        context: context,
        entryTitle: widget.entryTitle,
        originalMedia: widget.originalMedia,
      );

      setState(() {
        _relinkedMedia = relinkedMedia;
      });

      // Notify parent with relinked media
      widget.onPhotosRelinked(relinkedMedia);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to relink photos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRelinking = false;
        });
      }
    }
  }

  void _skipRelinking() {
    // Keep original media and notify parent
    widget.onPhotosRelinked(widget.originalMedia);
  }
}

/// Service dependencies for photo relinking
class MediaStore {
  Future<MediaItem> storeImage({
    required List<int> imageData,
    String? ocrText,
  }) async {
    // This would be implemented with the actual MediaStore service
    throw UnimplementedError('MediaStore not implemented');
  }
}

class MediaSanitizer {
  Future<List<int>> sanitizeImage(List<int> imageData) async {
    // This would be implemented with the actual MediaSanitizer service
    return imageData;
  }
}

class OcrService {
  Future<String?> extractTextWithPreprocessing(List<int> imageData) async {
    // This would be implemented with the actual OcrService
    return null;
  }
}
