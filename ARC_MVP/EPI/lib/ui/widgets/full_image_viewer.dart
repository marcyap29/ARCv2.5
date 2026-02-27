import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/services/media_resolver_service.dart';

/// Full-screen image viewer with pinch-to-zoom and metadata display
class FullImageViewer extends StatefulWidget {
  final MediaItem mediaItem;

  const FullImageViewer({
    super.key,
    required this.mediaItem,
  });

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  bool _isLoading = true;
  Uint8List? _fullResImageData;
  String? _fallbackPath;
  String? _error;
  bool _showMetadata = false;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadFullResolution();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadFullResolution() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // If media item is MCP media, resolve via SHA-256
      if (widget.mediaItem.isMcpMedia) {
        final sha256 = widget.mediaItem.sha256!;
        print('🖼️ Loading full-res image for SHA-256: $sha256');
        
        // Try to resolve from mounted media packs
        final resolver = MediaResolverService.instance.resolver;
        if (resolver != null) {
          final imageData = await resolver.loadFullImage(sha256);
          
          if (imageData != null) {
            setState(() {
              _fullResImageData = imageData;
              _isLoading = false;
            });
            print('✅ Full-res image loaded: ${imageData.length} bytes');
          } else {
            // Fallback to original URI if resolution fails
            print('⚠️ Could not resolve SHA-256, falling back to original URI');
            setState(() {
              _fallbackPath = widget.mediaItem.uri;
              _isLoading = false;
            });
          }
        } else {
          // No resolver available, use fallback
          print('⚠️ MediaResolver not initialized, using fallback URI');
          setState(() {
            _fallbackPath = widget.mediaItem.uri;
            _isLoading = false;
          });
        }
      } else {
        // Non-MCP media, use URI directly
        setState(() {
          _fallbackPath = widget.mediaItem.uri;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      print('❌ Error loading full-res image: $e');
      print('Stack trace: $st');
      setState(() {
        _error = 'Failed to load image: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        title: const Text('Image Viewer'),
        actions: [
          if (widget.mediaItem.analysisData != null || widget.mediaItem.ocrText != null)
            IconButton(
              icon: Icon(_showMetadata ? Icons.info : Icons.info_outline),
              onPressed: () {
                setState(() {
                  _showMetadata = !_showMetadata;
                });
              },
              tooltip: 'Show metadata',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading image...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFullResolution,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_fullResImageData == null && _fallbackPath == null) {
      return const Center(
        child: Text(
          'No image available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Stack(
      children: [
        // Zoomable image
        Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: _buildImage(),
          ),
        ),
        
        // Metadata overlay
        if (_showMetadata)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildMetadataOverlay(),
          ),
      ],
    );
  }

  Widget _buildImage() {
    // Prefer full-res image data if available
    if (_fullResImageData != null) {
      return Image.memory(
        _fullResImageData!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        },
      );
    }
    
    // Fallback to file path
    if (_fallbackPath != null) {
      // Handle different URI schemes
      if (_fallbackPath!.startsWith('ph://')) {
        // Photo library URI - would need platform-specific handling
        return const Center(
          child: Text(
            'Photo library images not yet supported in viewer',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        );
      } else if (_fallbackPath!.startsWith('file://')) {
        return Image.file(
          File(_fallbackPath!.replaceFirst('file://', '')),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // Assume local file path
        return Image.file(
          File(_fallbackPath!),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        );
      }
    }
    
    // No image available
    return const Center(
      child: Text(
        'No image available',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildMetadataOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.mediaItem.altText != null) ...[
              const Text(
                'Description:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.mediaItem.altText!,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.mediaItem.ocrText != null && widget.mediaItem.ocrText!.isNotEmpty) ...[
              const Text(
                'Text in Image:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.mediaItem.ocrText!,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            
            if (widget.mediaItem.isMcpMedia) ...[
              const Text(
                'Technical Info:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SHA-256: ${widget.mediaItem.sha256?.substring(0, 16)}...',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (widget.mediaItem.sizeBytes != null)
                Text(
                  'Size: ${_formatBytes(widget.mediaItem.sizeBytes!)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

