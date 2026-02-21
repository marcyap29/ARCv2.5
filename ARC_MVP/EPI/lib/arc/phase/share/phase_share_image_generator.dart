// lib/arc/phase/share/phase_share_image_generator.dart
// Image generation service for phase transition shares

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'phase_share_models.dart';
import '../../../models/phase_models.dart';

/// Service for generating shareable phase transition images
class PhaseShareImageGenerator {
  /// Get phase color
  static Color _getPhaseColor(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return const Color(0xFF7C3AED);
      case PhaseLabel.expansion:
        return const Color(0xFF059669);
      case PhaseLabel.transition:
        return const Color(0xFFD97706);
      case PhaseLabel.consolidation:
        return const Color(0xFF2563EB);
      case PhaseLabel.recovery:
        return const Color(0xFFDC2626);
      case PhaseLabel.breakthrough:
        return const Color(0xFFFBBF24);
    }
  }

  /// Generate image for a specific platform
  static Future<Uint8List> generateImage(
    PhaseShare share,
    SharePlatform platform,
  ) async {
    final size = _getPlatformSize(platform);
    return _generateImageInternal(share, size.width, size.height);
  }

  /// Get platform-specific image size
  static Size _getPlatformSize(SharePlatform platform) {
    switch (platform) {
      case SharePlatform.instagram:
        return const Size(1080, 1080); // Square
      case SharePlatform.linkedin:
        return const Size(1200, 627); // Rectangle
      case SharePlatform.twitter:
        return const Size(1200, 675); // Rectangle
      case SharePlatform.generic:
        return const Size(1080, 1080); // Square default
    }
  }

  /// Internal image generation
  static Future<Uint8List> _generateImageInternal(
    PhaseShare share,
    double width,
    double height,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background - white or subtle gradient
    final backgroundPaint = Paint()
      ..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    // Padding
    const padding = 60.0;
    final contentWidth = width - (padding * 2);

    // Phase name (large text at top)
    final phaseNameStyle = TextStyle(
      fontSize: _getScaledFontSize(width, 64),
      fontWeight: FontWeight.bold,
      color: _getPhaseColor(share.phaseName),
      letterSpacing: -1,
    );
    final phaseNamePainter = TextPainter(
      text: TextSpan(
        text: share.phaseDisplayName,
        style: phaseNameStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    phaseNamePainter.layout(maxWidth: contentWidth);
    phaseNamePainter.paint(
      canvas,
      Offset(
        padding + (contentWidth - phaseNamePainter.width) / 2,
        padding + 40,
      ),
    );

    // Timeline (if enabled)
    double currentY = padding + 40 + phaseNamePainter.height + 60;
    if (share.includeTimeline && share.timelineData.isNotEmpty) {
      currentY = _drawTimeline(
        canvas,
        share,
        Offset(padding, currentY),
        contentWidth,
        120,
      );
      currentY += 40;
    }

    // Optional metadata (duration, phase count)
    if (share.includeDuration && share.formattedDuration != null) {
      currentY = _drawMetadata(
        canvas,
        share.formattedDuration!,
        Offset(padding, currentY),
        contentWidth,
        Colors.grey.shade600,
      );
      currentY += 20;
    }
    if (share.includePhaseCount && share.formattedPhaseCount != null) {
      currentY = _drawMetadata(
        canvas,
        share.formattedPhaseCount!,
        Offset(padding, currentY),
        contentWidth,
        Colors.grey.shade600,
      );
      currentY += 20;
    }

    // Transition date
    currentY += 20;
    final dateText = 'Entered ${share.phaseDisplayName} on ${share.formattedDate}';
    currentY = _drawMetadata(
      canvas,
      dateText,
      Offset(padding, currentY),
      contentWidth,
      Colors.grey.shade700,
    );

    // User caption (if space allows)
    final remainingHeight = height - currentY - 100; // Leave space for branding
    if (remainingHeight > 80 && share.userCaption.isNotEmpty) {
      currentY += 40;
      _drawCaption(
        canvas,
        share.userCaption,
        Offset(padding, currentY),
        contentWidth,
        remainingHeight - 40,
      );
    }

    // Branding at bottom
    final brandingY = height - padding - 40;
    _drawBranding(
      canvas,
      Offset(padding, brandingY),
      contentWidth,
    );

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Draw timeline visualization
  static double _drawTimeline(
    Canvas canvas,
    PhaseShare share,
    Offset offset,
    double width,
    double height,
  ) {
    final timelineData = share.timelineData;
    if (timelineData.isEmpty) return offset.dy;

    // Calculate time range (last 6 months)
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
    final startDate = timelineData.first.start.isBefore(sixMonthsAgo)
        ? sixMonthsAgo
        : timelineData.first.start;
    final endDate = now;
    final totalDuration = endDate.difference(startDate).inMilliseconds;

    if (totalDuration == 0) return offset.dy;

    // Draw timeline background
    final timelineRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      width,
      height,
    );
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade100;
    canvas.drawRRect(
      RRect.fromRectAndRadius(timelineRect, const Radius.circular(8)),
      backgroundPaint,
    );

    // Draw phase blocks
    final blockHeight = height - 20;
    final blockY = offset.dy + 10;
    double currentX = offset.dx + 10;

    for (int i = 0; i < timelineData.length; i++) {
      final phase = timelineData[i];
      final phaseStart = phase.start.isBefore(startDate) ? startDate : phase.start;
      final phaseEnd = phase.end ?? endDate;
      
      final phaseDuration = phaseEnd.difference(phaseStart).inMilliseconds;
      final phaseWidth = (phaseDuration / totalDuration) * (width - 20);
      
      if (phaseWidth < 2) continue; // Skip too small blocks

      // Draw phase block
      final blockPaint = Paint()
        ..color = phase.color;
      final blockRect = Rect.fromLTWH(
        currentX,
        blockY,
        phaseWidth,
        blockHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(blockRect, const Radius.circular(4)),
        blockPaint,
      );

      // Draw divider if not last
      if (i < timelineData.length - 1) {
        final dividerPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2;
        canvas.drawLine(
          Offset(currentX + phaseWidth, blockY),
          Offset(currentX + phaseWidth, blockY + blockHeight),
          dividerPaint,
        );
      }

      currentX += phaseWidth;
    }

    // Draw month labels below timeline
    final monthLabelY = offset.dy + height - 5;
    _drawMonthLabels(canvas, startDate, endDate, offset.dx, monthLabelY, width);

    return offset.dy + height;
  }

  /// Draw month labels
  static void _drawMonthLabels(
    Canvas canvas,
    DateTime start,
    DateTime end,
    double x,
    double y,
    double width,
  ) {
    final months = <DateTime>[];
    var current = DateTime(start.year, start.month, 1);
    while (current.isBefore(end) || current.month == end.month) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }

    if (months.isEmpty) return;

    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final totalDuration = end.difference(start).inMilliseconds;
    final labelStyle = TextStyle(
      fontSize: 10,
      color: Colors.grey.shade600,
      fontWeight: FontWeight.w500,
    );

    for (final month in months) {
      final monthProgress = month.difference(start).inMilliseconds / totalDuration;
      final monthX = x + (monthProgress * width);
      
      if (monthX < x || monthX > x + width) continue;

      final monthName = monthNames[month.month - 1];
      final painter = TextPainter(
        text: TextSpan(text: monthName, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(monthX - painter.width / 2, y),
      );
    }
  }

  /// Draw metadata text
  static double _drawMetadata(
    Canvas canvas,
    String text,
    Offset offset,
    double maxWidth,
    Color color,
  ) {
    final style = TextStyle(
      fontSize: 16,
      color: color,
      fontWeight: FontWeight.w500,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    painter.layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(offset.dx + (maxWidth - painter.width) / 2, offset.dy),
    );
    return offset.dy + painter.height;
  }

  /// Draw user caption
  static void _drawCaption(
    Canvas canvas,
    String caption,
    Offset offset,
    double maxWidth,
    double maxHeight,
  ) {
    final style = TextStyle(
      fontSize: 18,
      color: Colors.grey.shade800,
      height: 1.4,
    );
    
    // Truncate if too long
    final textSpan = TextSpan(text: caption, style: style);
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    );
    painter.layout(maxWidth: maxWidth);
    
    if (painter.height <= maxHeight) {
      painter.paint(
        canvas,
        Offset(offset.dx + (maxWidth - painter.width) / 2, offset.dy),
      );
    }
  }

  /// Draw branding
  static void _drawBranding(
    Canvas canvas,
    Offset offset,
    double width,
  ) {
    final style = TextStyle(
      fontSize: 14,
      color: Colors.grey.shade500,
      fontWeight: FontWeight.w500,
    );
    final text = 'Tracked with ARC';
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(offset.dx + (width - painter.width) / 2, offset.dy),
    );
  }

  /// Get scaled font size based on image width
  static double _getScaledFontSize(double width, double baseSize) {
    // Scale font size proportionally to image width
    return (width / 1080) * baseSize;
  }
}

