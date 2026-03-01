import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_app/chronicle/reviews/models/monthly_review.dart';
import 'package:my_app/chronicle/reviews/models/yearly_review.dart';

/// Generates and shares review summary cards.
/// Uses RepaintBoundary + toImage() for image capture, falls back to text share.
class ReviewShareService {
  /// Share monthly review as image (if widget provided) or text.
  Future<void> shareMonthlyReview(MonthlyReview review, [GlobalKey? repaintKey]) async {
    if (repaintKey != null) {
      final image = await _captureWidget(repaintKey);
      if (image != null) {
        await _shareImage(image, '${review.monthDisplayName} Review');
        return;
      }
    }
    await _shareMonthlyAsText(review);
  }

  /// Share yearly review as image (if widget provided) or text.
  Future<void> shareYearlyReview(YearlyReview review, [GlobalKey? repaintKey]) async {
    if (repaintKey != null) {
      final image = await _captureWidget(repaintKey);
      if (image != null) {
        await _shareImage(image, '${review.year} Year in Review');
        return;
      }
    }
    await _shareYearlyAsText(review);
  }

  Future<ByteData?> _captureWidget(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      return await image.toByteData(format: ui.ImageByteFormat.png);
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareImage(ByteData byteData, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    await Share.shareXFiles(
      [XFile(file.path)],
      text: filename,
    );
  }

  Future<void> _shareMonthlyAsText(MonthlyReview review) async {
    final buffer = StringBuffer();
    buffer.writeln('📅 ${review.monthDisplayName} Review');
    buffer.writeln();
    buffer.writeln(review.narrativeSynthesis.length > 500
        ? '${review.narrativeSynthesis.substring(0, 500)}...'
        : review.narrativeSynthesis);
    buffer.writeln();
    buffer.writeln('✨ Seed for next month:');
    buffer.writeln(review.seedForNextMonth);
    buffer.writeln();
    buffer.writeln('📊 ${review.stats.totalEntries} entries · ${review.stats.longestStreak} day streak');
    buffer.writeln();
    buffer.writeln('— LUMARA');
    await Share.share(buffer.toString(), subject: '${review.monthDisplayName} Review');
  }

  Future<void> _shareYearlyAsText(YearlyReview review) async {
    final buffer = StringBuffer();
    buffer.writeln('📅 ${review.year} Year in Review');
    buffer.writeln();
    buffer.writeln(review.yearNarrative.length > 600
        ? '${review.yearNarrative.substring(0, 600)}...'
        : review.yearNarrative);
    buffer.writeln();
    buffer.writeln('✨ Seed for next year:');
    buffer.writeln(review.seedForNextYear);
    buffer.writeln();
    buffer.writeln('📊 ${review.stats.totalEntries} entries · ${review.stats.activeMonths} active months');
    buffer.writeln();
    buffer.writeln('— LUMARA');
    await Share.share(buffer.toString(), subject: '${review.year} Year in Review');
  }
}
