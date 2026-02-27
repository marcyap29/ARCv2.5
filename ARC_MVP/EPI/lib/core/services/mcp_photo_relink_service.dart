import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/core/services/media_store.dart';
import 'package:my_app/core/services/media_sanitizer.dart';

/// Service for handling mandatory photo relinking during MCP import
class McpPhotoRelinkService {
  final MediaStore _mediaStore;
  final MediaSanitizer _mediaSanitizer;
  // final OCRService _ocrService; // Disabled - OCR dependencies not available
  final ImagePicker _imagePicker = ImagePicker();

  McpPhotoRelinkService({
    required MediaStore mediaStore,
    required MediaSanitizer mediaSanitizer,
    // required OCRService ocrService, // Disabled
  })  : _mediaStore = mediaStore,
        _mediaSanitizer = mediaSanitizer;
        // _ocrService = ocrService; // Disabled

  /// Show a dialog asking user to relink photos for a journal entry
  Future<List<MediaItem>> relinkPhotosForEntry({
    required BuildContext context,
    required String entryTitle,
    required List<MediaItem> originalMedia,
  }) async {
    if (originalMedia.isEmpty) {
      return [];
    }

    final relinkedMedia = <MediaItem>[];

    for (final mediaItem in originalMedia) {
      if (mediaItem.type == MediaType.image) {
        final relinkedItem = await _showPhotoRelinkDialog(
          context: context,
          entryTitle: entryTitle,
          originalMedia: mediaItem,
        );
        
        if (relinkedItem != null) {
          relinkedMedia.add(relinkedItem);
        }
      } else {
        // Keep non-image media as-is
        relinkedMedia.add(mediaItem);
      }
    }

    return relinkedMedia;
  }

  /// Show dialog for relinking a single photo
  Future<MediaItem?> _showPhotoRelinkDialog({
    required BuildContext context,
    required String entryTitle,
    required MediaItem originalMedia,
  }) async {
    return await showDialog<MediaItem>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PhotoRelinkDialog(
        entryTitle: entryTitle,
        originalMedia: originalMedia,
        onPhotoRelinked: (mediaItem) => Navigator.of(context).pop(mediaItem),
        onSkip: () => Navigator.of(context).pop(originalMedia),
        onRemove: () => Navigator.of(context).pop(null),
        mediaStore: _mediaStore,
        mediaSanitizer: _mediaSanitizer,
        // ocrService: _ocrService, // Disabled
      ),
    );
  }
}

/// Dialog for relinking a photo during MCP import
class PhotoRelinkDialog extends StatefulWidget {
  final String entryTitle;
  final MediaItem originalMedia;
  final Function(MediaItem) onPhotoRelinked;
  final VoidCallback onSkip;
  final VoidCallback onRemove;
  final MediaStore mediaStore;
  final MediaSanitizer mediaSanitizer;
  // final OCRService ocrService; // Disabled - OCR dependencies not available

  const PhotoRelinkDialog({
    super.key,
    required this.entryTitle,
    required this.originalMedia,
    required this.onPhotoRelinked,
    required this.onSkip,
    required this.onRemove,
    required this.mediaStore,
    required this.mediaSanitizer,
    // required this.ocrService, // Disabled
  });

  @override
  State<PhotoRelinkDialog> createState() => _PhotoRelinkDialogState();
}

class _PhotoRelinkDialogState extends State<PhotoRelinkDialog> {
  bool _isProcessing = false;
  String? _processingMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Relink Photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entry: ${widget.entryTitle}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'This entry had a photo that needs to be relinked. Please select the same photo from your gallery or take a new one.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_isProcessing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            if (_processingMessage != null)
              Text(
                _processingMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : widget.onRemove,
          child: const Text('Remove Photo'),
        ),
        TextButton(
          onPressed: _isProcessing ? null : widget.onSkip,
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _pickFromGallery,
          child: const Text('Select from Gallery'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _takePhoto,
          child: const Text('Take Photo'),
        ),
      ],
    );
  }

  Future<void> _takePhoto() async {
    try {
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Requesting camera permission...';
      });

      // Request camera permission
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        _showErrorDialog('Camera permission is required to take photos.');
        return;
      }

      setState(() {
        _processingMessage = 'Opening camera...';
      });

      // Pick image from camera
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() {
          _isProcessing = false;
          _processingMessage = null;
        });
        return;
      }

      await _processImage(image);
    } catch (e) {
      _showErrorDialog('Failed to take photo: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _processingMessage = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Opening gallery...';
      });

      // Pick image from gallery
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() {
          _isProcessing = false;
          _processingMessage = null;
        });
        return;
      }

      await _processImage(image);
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _processingMessage = null;
      });
    }
  }

  Future<void> _processImage(XFile image) async {
    try {
      setState(() {
        _processingMessage = 'Processing image...';
      });

      // Read image data
      final imageData = await image.readAsBytes();

      // Sanitize image
      final sanitizedData = await widget.mediaSanitizer.sanitizeImage(imageData);

      // Extract text with OCR
      setState(() {
        _processingMessage = 'Extracting text from image...';
      });

      // OCR disabled - dependencies not available
      // final ocrText = await widget.ocrService.extractTextWithPreprocessing(sanitizedData);
      const ocrText = ''; // Placeholder - OCR disabled

      // Store image
      final mediaItem = await widget.mediaStore.storeImage(
        imageData: sanitizedData,
        ocrText: ocrText,
      );

      widget.onPhotoRelinked(mediaItem);
    } catch (e) {
      _showErrorDialog('Failed to process image: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
