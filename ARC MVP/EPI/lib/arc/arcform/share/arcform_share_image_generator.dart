// lib/arc/arcform/share/arcform_share_image_generator.dart
// Platform-specific image generation for Arcform sharing
// Implements "Identity Signaling Through Artifact" framework

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'arcform_share_models.dart';

/// Service for generating platform-specific Arcform share images
class ArcformShareImageGenerator {
  /// Generate Arcform share image with platform-specific dimensions and layout
  static Future<Uint8List?> generateArcformImage({
    required Uint8List arcformImageBytes, // Captured Arcform 3D visualization
    required ArcformSharePayload payload,
    required SocialPlatform platform,
  }) async {
    try {
      // Get platform dimensions
      final size = _getPlatformSize(platform);
      
      // Decode base Arcform image
      final codec = await ui.instantiateImageCodec(arcformImageBytes);
      final frame = await codec.getNextFrame();
      final arcformImage = frame.image;
      
      // Create canvas with platform dimensions
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();
      
      // Draw background (white or subtle gradient)
      _drawBackground(canvas, size, paint);
      
      // Layout based on platform
      switch (platform) {
        case SocialPlatform.instagramStory:
          await _drawInstagramStoryLayout(
            canvas,
            size,
            arcformImage,
            payload,
            paint,
          );
          break;
        case SocialPlatform.instagramFeed:
          await _drawInstagramFeedLayout(
            canvas,
            size,
            arcformImage,
            payload,
            paint,
          );
          break;
        case SocialPlatform.linkedinFeed:
          await _drawLinkedInFeedLayout(
            canvas,
            size,
            arcformImage,
            payload,
            paint,
          );
          break;
        case SocialPlatform.linkedinCarousel:
          await _drawLinkedInFeedLayout(
            canvas,
            size,
            arcformImage,
            payload,
            paint,
          );
          break;
      }
      
      // Add watermark
      _drawWatermark(canvas, size, paint);
      
      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      // Clean up
      arcformImage.dispose();
      image.dispose();
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error generating Arcform image: $e');
      return null;
    }
  }

  /// Get platform-specific dimensions
  static Size _getPlatformSize(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagramStory:
        return const Size(1080, 1920); // 9:16 vertical
      case SocialPlatform.instagramFeed:
        return const Size(1080, 1080); // 1:1 square
      case SocialPlatform.linkedinFeed:
        return const Size(1200, 627); // Landscape
      case SocialPlatform.linkedinCarousel:
        return const Size(1080, 1080); // 1:1 square
    }
  }

  /// Draw background (black)
  static void _drawBackground(Canvas canvas, Size size, Paint paint) {
    // Black background
    paint.color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  /// Draw Instagram Story layout (vertical, 9:16)
  static Future<void> _drawInstagramStoryLayout(
    Canvas canvas,
    Size size,
    ui.Image arcformImage,
    ArcformSharePayload payload,
    Paint paint,
  ) async {
    const padding = 40.0;
    const topMargin = 120.0;
    
    // Phase name at top
    final phaseName = _formatPhaseName(payload.phase);
    _drawPhaseName(canvas, phaseName, Offset(size.width / 2, topMargin), paint);
    
    // Arcform visualization (centered, takes most of space)
    // Reduced border - use more of the available space
    final arcformWidth = size.width * 0.95; // Increased from 85% to 95% - trim border
    final arcformHeight = size.height * 0.65; // Increased from 50% to 65% - trim border
    final arcformRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: arcformWidth,
      height: arcformHeight,
    );
    _drawArcformImage(canvas, arcformImage, arcformRect, paint);
    
    // Timeline below Arcform (if date range enabled)
    if (payload.includeDateRange && payload.timelineData != null) {
      final timelineY = size.height * 0.75;
      _drawTimeline(
        canvas,
        payload.timelineData!,
        Offset(padding, timelineY),
        Size(size.width - padding * 2, 100),
        paint,
        true, // vertical
      );
    }
    
    // Caption at bottom (if not quiet mode) - moved up, reduced bottom border
    if (payload.shareMode != ArcShareMode.quiet && payload.userCaption != null) {
      // Cut bottom by 2/3: was 200px from bottom, now 200/3 = ~67px from bottom
      final captionY = size.height - 67;
      _drawCaption(
        canvas,
        payload.userCaption!,
        Offset(padding, captionY),
        Size(size.width - padding * 2, 50), // Reduced height from 150 to 50
        paint,
      );
    }
    
    // Optional metrics (duration, phase count) - moved up, reduced bottom border
    if (payload.includeDuration || payload.includePhaseCount) {
      // Cut bottom by 2/3: was 80px from bottom, now 80/3 = ~27px from bottom
      final metricsY = size.height - 27;
      _drawMetrics(
        canvas,
        payload,
        Offset(size.width / 2, metricsY),
        paint,
      );
    }
  }

  /// Draw Instagram Feed layout (square, 1:1)
  static Future<void> _drawInstagramFeedLayout(
    Canvas canvas,
    Size size,
    ui.Image arcformImage,
    ArcformSharePayload payload,
    Paint paint,
  ) async {
    const padding = 40.0;
    
    // Phase name at top
    final phaseName = _formatPhaseName(payload.phase);
    _drawPhaseName(canvas, phaseName, Offset(size.width / 2, 60), paint);
    
    // Arcform visualization (centered)
    // Reduced border - use more of the available space
    final arcformSize = size.width * 0.85; // Increased from 70% to 85% - trim border
    final arcformRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: arcformSize,
      height: arcformSize,
    );
    _drawArcformImage(canvas, arcformImage, arcformRect, paint);
    
    // Timeline below Arcform (horizontal)
    if (payload.includeDateRange && payload.timelineData != null) {
      final timelineY = size.height * 0.75;
      _drawTimeline(
        canvas,
        payload.timelineData!,
        Offset(padding, timelineY),
        Size(size.width - padding * 2, 80),
        paint,
        false, // vertical
      );
    }
    
    // Caption at bottom (if not quiet mode) - moved up, reduced bottom border
    if (payload.shareMode != ArcShareMode.quiet && payload.userCaption != null) {
      // Cut bottom by 2/3: was 120px from bottom, now 120/3 = 40px from bottom
      final captionY = size.height - 40;
      _drawCaption(
        canvas,
        payload.userCaption!,
        Offset(padding, captionY),
        Size(size.width - padding * 2, 27), // Reduced height from 80 to 27 (80/3)
        paint,
      );
    }
  }

  /// Draw LinkedIn Feed layout (landscape, 1200x627) - Centered composition
  static Future<void> _drawLinkedInFeedLayout(
    Canvas canvas,
    Size size,
    ui.Image arcformImage,
    ArcformSharePayload payload,
    Paint paint,
  ) async {
    // Centered layout: Phase name at top, Arcform in center, content below
    // Reduce left/right canvas by 2/3: reduce side margins by 2/3
    // Original side margins were ~20% each (40% total), reduce by 2/3 = ~6.67% each (13.33% total)
    // So effective width = 100% - 13.33% = 86.67% of canvas width
    final effectiveWidth = size.width * 0.8667; // Use 86.67% of width (reduced margins by 2/3)
    final centerX = size.width / 2;
    
    // Phase name at top (centered) - moved higher for greater separation
    final phaseName = _formatPhaseName(payload.phase);
    _drawPhaseName(canvas, phaseName, Offset(centerX, 40), paint);
    
    // Arcform visualization - use narrower width due to reduced canvas
    final arcformWidth = effectiveWidth * 0.32; // 32% of effective width (was 27.5% of full width)
    final arcformHeight = effectiveWidth * 0.32; // Square aspect
    final arcformRect = Rect.fromCenter(
      center: Offset(centerX, size.height * 0.4), // Moved up slightly since we're cropping bottom
      width: arcformWidth,
      height: arcformHeight,
    );
    _drawArcformImage(canvas, arcformImage, arcformRect, paint);
    
    // Timeline below Arcform (centered, horizontal) - use effective width
    if (payload.includeDateRange && payload.timelineData != null) {
      final timelineY = size.height * 0.7; // Moved down from 0.55 to 0.7
      final timelineWidth = effectiveWidth * 0.7; // 70% of effective width
      _drawTimeline(
        canvas,
        payload.timelineData!,
        Offset(centerX - timelineWidth / 2, timelineY),
        Size(timelineWidth, 60),
        paint,
        false, // horizontal
      );
    }
    
    // Caption below timeline (if not quiet mode) - use effective width, reduce bottom by 1/2
    if (payload.shareMode != ArcShareMode.quiet && payload.userCaption != null) {
      // Reduce bottom by 1/2: was 0.8 (80% from top), now calculate from reduced bottom
      // Original bottom margin was size.height - (size.height * 0.8) = size.height * 0.2
      // Reduce by 1/2: new bottom margin = size.height * 0.1
      // So captionY = size.height - (size.height * 0.1) = size.height * 0.9
      final captionY = size.height * 0.9; // Moved up from 0.8 to 0.9 (reduced bottom by 1/2)
      final captionWidth = effectiveWidth * 0.8; // 80% of effective width
      _drawCaption(
        canvas,
        payload.userCaption!,
        Offset(centerX - captionWidth / 2, captionY),
        Size(captionWidth, 40), // Reduced height from 80 to 40 (reduced by 1/2)
        paint,
      );
    }
    
    // Metrics at bottom (centered) - reduce bottom by 1/2
    if (payload.includeDuration || payload.includePhaseCount) {
      // Original was 30px from bottom, reduce by 1/2 = 15px from bottom
      final metricsY = size.height - 15; // Reduced from 30 to 15 (reduced by 1/2)
      _drawMetrics(
        canvas,
        payload,
        Offset(centerX, metricsY),
        paint,
      );
    }
  }

  /// Draw phase name
  static void _drawPhaseName(
    Canvas canvas,
    String phaseName,
    Offset position,
    Paint paint,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: phaseName,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w600,
          color: Colors.white, // White text on black background
          fontFamily: 'SF Pro Display',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy),
    );
  }

  /// Draw Arcform image with aspect ratio preserved (BoxFit.contain logic)
  static void _drawArcformImage(
    Canvas canvas,
    ui.Image arcformImage,
    Rect rect,
    Paint paint,
  ) {
    // Calculate aspect ratios
    final imageAspect = arcformImage.width / arcformImage.height;
    final rectAspect = rect.width / rect.height;
    
    // Calculate fitted size (maintain aspect ratio, fit within rect)
    double fittedWidth, fittedHeight;
    if (imageAspect > rectAspect) {
      // Image is wider - fit to width
      fittedWidth = rect.width;
      fittedHeight = rect.width / imageAspect;
    } else {
      // Image is taller - fit to height
      fittedHeight = rect.height;
      fittedWidth = rect.height * imageAspect;
    }
    
    // Center the fitted image within the rect
    final fittedRect = Rect.fromCenter(
      center: rect.center,
      width: fittedWidth,
      height: fittedHeight,
    );
    
    // Draw with rounded corners
    final rrect = RRect.fromRectAndRadius(fittedRect, const Radius.circular(16));
    canvas.clipRRect(rrect);
    canvas.drawImageRect(
      arcformImage,
      Rect.fromLTWH(0, 0, arcformImage.width.toDouble(), arcformImage.height.toDouble()),
      fittedRect,
      paint,
    );
    canvas.restore();
  }

  /// Draw timeline visualization
  static void _drawTimeline(
    Canvas canvas,
    List<PhaseTimelineData> timelineData,
    Offset position,
    Size size,
    Paint paint,
    bool vertical,
  ) {
    if (timelineData.isEmpty) return;
    
    // Draw phase blocks
    final blockCount = timelineData.length;
    final blockSize = vertical ? size.height / blockCount : size.width / blockCount;
    
    for (int i = 0; i < timelineData.length; i++) {
      final phase = timelineData[i];
      final blockRect = vertical
          ? Rect.fromLTWH(
              position.dx,
              position.dy + i * blockSize,
              size.width,
              blockSize,
            )
          : Rect.fromLTWH(
              position.dx + i * blockSize,
              position.dy,
              blockSize,
              size.height,
            );
      
      // Draw phase block
      paint.color = phase.color;
      canvas.drawRect(blockRect, paint);
      
      // Draw phase name
      paint.color = Colors.white;
      final textPainter = TextPainter(
        text: TextSpan(
          text: phase.phaseName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          blockRect.center.dx - textPainter.width / 2,
          blockRect.center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  /// Draw caption text
  static void _drawCaption(
    Canvas canvas,
    String caption,
    Offset position,
    Size size,
    Paint paint,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: caption,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: Colors.white, // White text on black background
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
    );
    textPainter.layout(maxWidth: size.width);
    textPainter.paint(canvas, position);
  }

  /// Draw optional metrics (duration, phase count)
  static void _drawMetrics(
    Canvas canvas,
    ArcformSharePayload payload,
    Offset position,
    Paint paint,
  ) {
    final metrics = <String>[];
    
    if (payload.includeDuration && payload.previousPhaseDuration != null) {
      final days = payload.previousPhaseDuration!.inDays;
      metrics.add('After $days days');
    }
    
    if (payload.includePhaseCount && payload.phaseCount != null) {
      final ordinal = _getOrdinal(payload.phaseCount!);
      metrics.add('$ordinal ${payload.phase} phase');
    }
    
    if (metrics.isEmpty) return;
    
    final text = metrics.join(' • ');
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFFCCCCCC), // Light gray text on black background
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy),
    );
  }

  /// Draw watermark
  static void _drawWatermark(
    Canvas canvas,
    Size size,
    Paint paint,
  ) {
    const watermark = 'Created with ARC';
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: watermark,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0x99FFFFFF), // 60% opacity white on black background
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Bottom right corner - reduced bottom padding (was 20, now 10 for Instagram)
    final position = Offset(
      size.width - textPainter.width - 20,
      size.height - textPainter.height - 10, // Reduced from 20 to 10 to remove bottom border
    );
    textPainter.paint(canvas, position);
  }

  /// Format phase name for display
  static String _formatPhaseName(String phase) {
    if (phase.isEmpty) return phase;
    return phase[0].toUpperCase() + phase.substring(1);
  }

  /// Get ordinal suffix
  static String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }
}

