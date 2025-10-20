import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/prism/mcp/media_resolver.dart';
import 'package:my_app/services/media_resolver_service.dart';

/// Widget for displaying content-addressed media (mcp://photo/<sha>)
///
/// This widget handles:
/// - Loading thumbnails from journal bundles
/// - Loading full-resolution images from media packs
/// - Fallback UI when media packs are unavailable
/// - Tap-to-view full resolution
class ContentAddressedMediaWidget extends StatefulWidget {
  final String sha256;
  final String? thumbUri;
  final String? fullRef;
  final MediaResolver? resolver;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool showFullResolutionOnTap;

  const ContentAddressedMediaWidget({
    super.key,
    required this.sha256,
    this.thumbUri,
    this.fullRef,
    this.resolver,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
    this.showFullResolutionOnTap = true,
  });

  @override
  State<ContentAddressedMediaWidget> createState() => _ContentAddressedMediaWidgetState();
}

class _ContentAddressedMediaWidgetState extends State<ContentAddressedMediaWidget> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(ContentAddressedMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sha256 != widget.sha256 || oldWidget.resolver != widget.resolver) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    // Get resolver from widget prop or service
    final resolver = widget.resolver ?? MediaResolverService.instance.resolver;

    if (resolver == null) {
      setState(() {
        _error = 'No media resolver available';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes = await resolver.loadThumbnail(widget.sha256);

      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
          if (bytes == null) {
            _error = 'Thumbnail not found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else if (widget.showFullResolutionOnTap) {
      final resolver = widget.resolver ?? MediaResolverService.instance.resolver;
      if (resolver != null) {
        _showFullResolution(resolver);
      }
    }
  }

  Future<void> _showFullResolution(MediaResolver resolver) async {
    // Show full photo viewer dialog
    showDialog(
      context: context,
      builder: (context) => FullPhotoViewerDialog(
        sha256: widget.sha256,
        resolver: resolver,
        thumbnailBytes: _thumbnailBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[300]!),
        ),
      );
    }

    if (_error != null || _thumbnailBytes == null) {
      return _buildErrorPlaceholder();
    }

    return Image.memory(
      _thumbnailBytes!,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorPlaceholder();
      },
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error ?? 'Image unavailable',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.resolver != null) ...[
            const SizedBox(height: 8),
            Text(
              'SHA: ${widget.sha256.substring(0, 8)}...',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog for viewing full-resolution photos with media pack support
class FullPhotoViewerDialog extends StatefulWidget {
  final String sha256;
  final MediaResolver resolver;
  final Uint8List? thumbnailBytes;

  const FullPhotoViewerDialog({
    super.key,
    required this.sha256,
    required this.resolver,
    this.thumbnailBytes,
  });

  @override
  State<FullPhotoViewerDialog> createState() => _FullPhotoViewerDialogState();
}

class _FullPhotoViewerDialogState extends State<FullPhotoViewerDialog> {
  Uint8List? _fullImageBytes;
  bool _isLoading = true;
  String? _error;
  bool _showingThumbnail = true;

  @override
  void initState() {
    super.initState();
    _loadFullImage();
  }

  Future<void> _loadFullImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes = await widget.resolver.loadFullImage(widget.sha256);

      if (mounted) {
        setState(() {
          _fullImageBytes = bytes;
          _isLoading = false;
          _showingThumbnail = bytes == null;
          if (bytes == null) {
            _error = 'Full image not available. Media pack may not be mounted.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _showingThumbnail = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Image display
          Center(
            child: _buildImageContent(),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Status indicator
          if (_showingThumbnail && widget.thumbnailBytes != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _buildStatusIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading full resolution...',
            style: TextStyle(color: Colors.white.withAlpha(178)),
          ),
        ],
      );
    }

    // Show full image if available
    if (_fullImageBytes != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.memory(
          _fullImageBytes!,
          fit: BoxFit.contain,
        ),
      );
    }

    // Fallback to thumbnail if full image unavailable
    if (widget.thumbnailBytes != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.memory(
          widget.thumbnailBytes!,
          fit: BoxFit.contain,
        ),
      );
    }

    // Error state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Image not available',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'SHA: ${widget.sha256.substring(0, 16)}...',
            style: TextStyle(
              color: Colors.white.withAlpha(102),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(204),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Showing Thumbnail',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _error ?? 'Mount the media pack to view full resolution',
                  style: TextStyle(
                    color: Colors.white.withAlpha(229),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null && _error!.contains('Media pack'))
            TextButton(
              onPressed: () {
                // TODO: Show media pack management dialog
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Media pack management coming soon'),
                  ),
                );
              },
              child: const Text(
                'MOUNT',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
