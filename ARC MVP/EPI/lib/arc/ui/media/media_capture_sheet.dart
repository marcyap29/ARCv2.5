import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/core/services/media_store.dart';
import 'package:my_app/core/services/media_sanitizer.dart';
import 'package:my_app/core/mcp/orchestrator/ios_vision_orchestrator.dart';

/// Bottom sheet for capturing media (audio, camera, gallery)
/// Provides access to microphone, camera, and photo gallery
class MediaCaptureSheet extends StatefulWidget {
  final Function(MediaItem) onMediaCaptured;
  final VoidCallback? onDismiss;
  
  const MediaCaptureSheet({
    super.key,
    required this.onMediaCaptured,
    this.onDismiss,
  });
  
  @override
  State<MediaCaptureSheet> createState() => _MediaCaptureSheetState();
}

class _MediaCaptureSheetState extends State<MediaCaptureSheet> {
  final MediaStore _mediaStore = MediaStore();
  final MediaSanitizer _mediaSanitizer = MediaSanitizer();
  // final OCRService _ocrService = OCRService(); // TODO: Implement OCR service
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isProcessing = false;
  String? _processingMessage;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121621),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Add Media',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          
          // Processing indicator
          if (_isProcessing) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (_processingMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  _processingMessage!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          
          // Media options
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Audio recording
                _buildMediaOption(
                  icon: Icons.mic,
                  title: 'Record Audio',
                  subtitle: 'Voice notes and recordings',
                  onTap: _isProcessing ? null : _recordAudio,
                ),
                
                const SizedBox(height: 12),
                
                // Camera
                _buildMediaOption(
                  icon: Icons.camera_alt,
                  title: 'Take Photo',
                  subtitle: 'Capture with camera',
                  onTap: _isProcessing ? null : _takePhoto,
                ),
                
                const SizedBox(height: 12),
                
                // Gallery
                _buildMediaOption(
                  icon: Icons.photo_library,
                  title: 'Choose from Gallery',
                  subtitle: 'Select existing photos',
                  onTap: _isProcessing ? null : _pickFromGallery,
                ),
                
                const SizedBox(height: 20),
                
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _isProcessing ? null : () {
                      Navigator.of(context).pop();
                      widget.onDismiss?.call();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMediaOption({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: title,
      hint: subtitle,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF171C29),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: onTap != null ? Colors.blue : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onTap != null ? Colors.white : Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: onTap != null ? Colors.white70 : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _recordAudio() async {
    try {
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Requesting microphone permission...';
      });
      
      // Request microphone permission
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        _showPermissionDeniedDialog('Microphone permission is required to record audio.');
        return;
      }
      
      setState(() {
        _processingMessage = 'Starting audio recording...';
      });
      
      // TODO: Integrate with actual audio recording
      // For now, simulate audio recording
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate audio data
      final simulatedAudioData = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      
      setState(() {
        _processingMessage = 'Processing audio...';
      });
      
      // Store audio
      final mediaItem = await _mediaStore.storeAudio(
        audioData: simulatedAudioData,
        duration: const Duration(seconds: 5),
        transcript: 'Simulated audio recording transcript',
      );
      
      widget.onMediaCaptured(mediaItem);
      Navigator.of(context).pop();
      
    } catch (e) {
      _showErrorDialog('Failed to record audio: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _processingMessage = null;
      });
    }
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
        _showPermissionDeniedDialog('Camera permission is required to take photos.');
        return;
      }
      
      setState(() {
        _processingMessage = 'Opening camera...';
      });
      
      // Pick image from camera
      final XFile? image = await _imagePicker.pickImage(
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
      
      setState(() {
        _processingMessage = 'Processing image...';
      });
      
      // Read image data
      final imageData = await image.readAsBytes();
      
      // Sanitize image
      final sanitizedData = await _mediaSanitizer.sanitizeImage(imageData);
      
      // Extract text with OCR
      setState(() {
        _processingMessage = 'Extracting text from image...';
      });
      
      // final ocrText = await _ocrService.extractTextWithPreprocessing(sanitizedData);
      // TODO: Implement OCR when service is available
      final ocrText = null;
      
      // Store image
      final mediaItem = await _mediaStore.storeImage(
        imageData: sanitizedData,
        ocrText: ocrText,
      );
      
      widget.onMediaCaptured(mediaItem);
      Navigator.of(context).pop();
      
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
      final XFile? image = await _imagePicker.pickImage(
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
      
      setState(() {
        _processingMessage = 'Processing image...';
      });
      
      // Read image data
      final imageData = await image.readAsBytes();
      
      // Sanitize image
      final sanitizedData = await _mediaSanitizer.sanitizeImage(imageData);
      
      // Extract text with OCR
      setState(() {
        _processingMessage = 'Extracting text from image...';
      });
      
      // final ocrText = await _ocrService.extractTextWithPreprocessing(sanitizedData);
      // TODO: Implement OCR when service is available
      final ocrText = null;
      
      // Store image
      final mediaItem = await _mediaStore.storeImage(
        imageData: sanitizedData,
        ocrText: ocrText,
      );
      
      widget.onMediaCaptured(mediaItem);
      Navigator.of(context).pop();
      
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _processingMessage = null;
      });
    }
  }
  
  void _showPermissionDeniedDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121621),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121621),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
