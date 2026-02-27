import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/thumbnail_cache_service.dart';

class CachedThumbnail extends StatefulWidget {
  final String imagePath;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final bool showTapIndicator;

  const CachedThumbnail({
    super.key,
    required this.imagePath,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.showTapIndicator = false,
  });

  @override
  State<CachedThumbnail> createState() => _CachedThumbnailState();
}

class _CachedThumbnailState extends State<CachedThumbnail> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;
  final ThumbnailCacheService _cacheService = ThumbnailCacheService();

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(CachedThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final thumbnail = await _cacheService.getThumbnail(
        widget.imagePath,
        size: widget.width.round(),
      );

      if (mounted) {
        setState(() {
          _thumbnailData = thumbnail;
          _isLoading = false;
          _hasError = thumbnail == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    // Clean up thumbnail from cache when widget is disposed
    _cacheService.clearThumbnail(widget.imagePath, size: widget.width.round());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget thumbnailWidget;

    if (_isLoading) {
      thumbnailWidget = Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: widget.borderRadius,
        ),
        child: widget.placeholder ?? const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_hasError || _thumbnailData == null) {
      thumbnailWidget = Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: widget.borderRadius,
        ),
        child: widget.errorWidget ?? const Center(
          child: Icon(Icons.error, color: Colors.grey),
        ),
      );
    } else {
      thumbnailWidget = Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          image: DecorationImage(
            image: MemoryImage(_thumbnailData!),
            fit: widget.fit,
          ),
        ),
      );
    }

    // Wrap with InkWell if onTap is provided
    if (widget.onTap != null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: Stack(
          children: [
            thumbnailWidget,
            if (widget.showTapIndicator)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.open_in_new,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return thumbnailWidget;
  }
}
