import 'dart:io';
import 'package:flutter/material.dart';

/// Photo data model for gallery viewer
class PhotoData {
  final String imagePath;
  final String? analysisText;

  PhotoData({
    required this.imagePath,
    this.analysisText,
  });
}

/// Full-screen photo viewer for journal attachments
///
/// Displays photos in an immersive full-screen view with:
/// - Pinch-to-zoom functionality
/// - Pan/drag to explore zoomed images
/// - Horizontal swipe to navigate between images
/// - Smooth animations and transitions
/// - Close button with safe area compliance
class FullScreenPhotoViewer extends StatefulWidget {
  final List<PhotoData> photos;
  final int initialIndex;

  const FullScreenPhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  /// Convenience constructor for single photo (backward compatibility)
  factory FullScreenPhotoViewer.single({
    required String imagePath,
    String? analysisText,
  }) {
    return FullScreenPhotoViewer(
      photos: [PhotoData(imagePath: imagePath, analysisText: analysisText)],
      initialIndex: 0,
    );
  }

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformationControllers = {};
  bool _showAnalysis = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    // Initialize transformation controller for initial page
    _transformationControllers[_currentIndex] = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose all transformation controllers
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getTransformationController(int index) {
    if (!_transformationControllers.containsKey(index)) {
      _transformationControllers[index] = TransformationController();
    }
    return _transformationControllers[index]!;
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _showAnalysis = false; // Hide analysis when switching images
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPhoto = widget.photos[_currentIndex];
    final photoExists = File(currentPhoto.imagePath).existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView for swiping between photos
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.photos.length,
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final photoExists = File(photo.imagePath).existsSync();
                final transformationController = _getTransformationController(index);

                return Center(
                  child: photoExists
                      ? InteractiveViewer(
                          transformationController: transformationController,
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.file(
                            File(photo.imagePath),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[900],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        size: 64,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Unable to load image',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (photo.analysisText != null && photo.analysisText!.isNotEmpty) ...[
                                        const SizedBox(height: 24),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 32),
                                          child: Text(
                                            photo.analysisText!,
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 5,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          color: Colors.grey[900],
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 80,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Photo no longer available',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (photo.analysisText != null && photo.analysisText!.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Photo description:',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      photo.analysisText!,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                );
              },
            ),

            // Top bar with close button and info toggle
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.4),
                      ),
                    ),

                    // Photo counter (if multiple photos)
                    if (widget.photos.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Info toggle (if analysis text available)
                    if (currentPhoto.analysisText != null && currentPhoto.analysisText!.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showAnalysis = !_showAnalysis;
                          });
                        },
                        icon: Icon(
                          _showAnalysis ? Icons.info : Icons.info_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                        tooltip: _showAnalysis ? 'Hide analysis' : 'Show analysis',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Analysis overlay (bottom)
            if (_showAnalysis && currentPhoto.analysisText != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              color: Colors.white.withOpacity(0.9),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Photo Analysis',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentPhoto.analysisText!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Zoom hint (bottom center) - only show if photo exists
            if (!_showAnalysis && photoExists)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pinch,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pinch to zoom',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
