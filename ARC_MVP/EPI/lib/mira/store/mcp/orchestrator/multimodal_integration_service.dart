import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';

import '../models/mcp_schemas.dart';

/// Simple integration service for multimodal functionality
class MultimodalIntegrationService {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Handle photo selection from gallery
  static Future<List<McpPointer>> selectPhotos({bool multi = true}) async {
    try {
      // Request permissions
      final permission = await Permission.photos.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Photo permission denied');
      }

      // Pick images
      List<XFile> images;
      if (multi) {
        images = await _imagePicker.pickMultiImage();
      } else {
        final image = await _imagePicker.pickImage(source: ImageSource.gallery);
        images = image != null ? [image] : [];
      }

      if (images.isEmpty) {
        return [];
      }

      // Process each image
      final List<McpPointer> pointers = [];
      for (final image in images) {
        try {
          final pointer = await _createImagePointer(image.path);
          pointers.add(pointer);
        } catch (e) {
          print('Failed to process image ${image.path}: $e');
        }
      }

      return pointers;
    } catch (e) {
      throw Exception('Failed to select photos: $e');
    }
  }

  /// Handle camera capture
  static Future<McpPointer?> capturePhoto() async {
    try {
      // Request permissions
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Camera permission denied');
      }

      // Capture image
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null) {
        return null;
      }

      // Create pointer
      return await _createImagePointer(image.path);
    } catch (e) {
      throw Exception('Failed to capture photo: $e');
    }
  }

  /// Handle audio recording
  static Future<McpPointer?> recordAudio() async {
    try {
      // Request permissions
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Microphone permission denied');
      }

      // TODO: Implement actual audio recording
      // For now, return a placeholder
      return _createPlaceholderAudioPointer();
    } catch (e) {
      throw Exception('Failed to record audio: $e');
    }
  }

  /// Create MCP pointer for image
  static Future<McpPointer> _createImagePointer(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file does not exist: $imagePath');
    }

    // Get file info
    final stat = await file.stat();
    final mimeType = lookupMimeType(imagePath) ?? 'image/jpeg';
    
    // Calculate hash
    final fileBytes = await file.readAsBytes();
    final hash = sha256.convert(fileBytes);
    
    // Create descriptor
    final descriptor = McpDescriptor(
      mimeType: mimeType,
      length: stat.size,
      metadata: {
        'width': 0, // TODO: Extract actual dimensions
        'height': 0,
      },
    );
    
    // Create integrity
    final integrity = McpIntegrity(
      contentHash: hash.toString(),
      bytes: stat.size,
      mime: mimeType,
      createdAt: stat.modified,
    );
    
    // Create privacy settings
    const privacy = McpPrivacy(
      containsPii: false,
      facesDetected: false,
      sharingPolicy: 'private',
    );
    
    // Create provenance
    const provenance = McpProvenance(
      source: 'EPI_Multimodal_Integration',
      device: 'EPI_Device',
    );
    
    // Create sampling manifest
    const samplingManifest = McpSamplingManifest(
      keyframes: [],
      spans: [],
      metadata: {},
    );
    
    // Create pointer
    return McpPointer(
      id: 'img_${DateTime.now().millisecondsSinceEpoch}',
      mediaType: 'image',
      sourceUri: imagePath,
      descriptor: descriptor,
      integrity: integrity,
      privacy: privacy,
      provenance: provenance,
      samplingManifest: samplingManifest,
      createdAt: DateTime.now(),
    );
  }

  /// Create placeholder audio pointer
  static McpPointer _createPlaceholderAudioPointer() {
    // This is a simplified version - in reality you'd record actual audio
    return McpPointer(
      id: 'audio_${DateTime.now().millisecondsSinceEpoch}',
      mediaType: 'audio',
      sourceUri: 'placeholder://audio',
      descriptor: const McpDescriptor(
        mimeType: 'audio/m4a',
        length: 0,
        metadata: {},
      ),
      integrity: McpIntegrity(
        contentHash: '',
        bytes: 0,
        createdAt: DateTime.now(),
      ),
      privacy: const McpPrivacy(
        containsPii: false,
        facesDetected: false,
        sharingPolicy: 'private',
      ),
      provenance: const McpProvenance(
        source: 'EPI_Multimodal_Integration',
        device: 'EPI_Device',
      ),
      samplingManifest: const McpSamplingManifest(
        keyframes: [],
        spans: [],
        metadata: {},
      ),
      createdAt: DateTime.now(),
    );
  }
}

/// Simple widget for testing multimodal integration
class MultimodalTestWidget extends StatefulWidget {
  const MultimodalTestWidget({super.key});

  @override
  State<MultimodalTestWidget> createState() => _MultimodalTestWidgetState();
}

class _MultimodalTestWidgetState extends State<MultimodalTestWidget> {
  final List<McpPointer> _pointers = [];
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multimodal Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Multimodal Integration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _selectPhotos,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select Photos'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _capturePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _recordAudio,
                icon: const Icon(Icons.mic),
                label: const Text('Record Audio'),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Status
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $_error',
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            
            // Results
            if (_pointers.isNotEmpty) ...[
              const Text(
                'Attached Media:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _pointers.length,
                  itemBuilder: (context, index) {
                    final pointer = _pointers[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          pointer.mediaType == 'image' 
                              ? Icons.image 
                              : Icons.audiotrack,
                        ),
                        title: Text(pointer.mediaType.toUpperCase()),
                        subtitle: Text(pointer.sourceUri ?? 'No URI'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _pointers.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectPhotos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pointers = await MultimodalIntegrationService.selectPhotos();
      setState(() {
        _pointers.addAll(pointers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pointer = await MultimodalIntegrationService.capturePhoto();
      if (pointer != null) {
        setState(() {
          _pointers.add(pointer);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _recordAudio() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pointer = await MultimodalIntegrationService.recordAudio();
      if (pointer != null) {
        setState(() {
          _pointers.add(pointer);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}
