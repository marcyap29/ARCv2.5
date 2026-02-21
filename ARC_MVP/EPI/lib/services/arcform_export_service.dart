import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_app/services/analytics_service.dart';

/// Service for exporting arcforms as PNG images
/// Implements P17 requirements for share/export functionality
class ArcformExportService {
  static final ArcformExportService _instance = ArcformExportService._internal();
  factory ArcformExportService() => _instance;
  ArcformExportService._internal();

  /// Export arcform as PNG and share it
  static Future<void> exportAndShareArcform({
    required GlobalKey repaintBoundaryKey,
    required String phaseName,
    required String geometryName,
    required BuildContext context,
  }) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Capture the arcform as PNG
      final pngBytes = await _captureArcformAsPng(repaintBoundaryKey);
      
      if (pngBytes == null) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar(context, 'Failed to capture arcform');
        return;
      }

      // Save to temporary file
      final tempFile = await _savePngToTempFile(pngBytes, phaseName, geometryName);
      
      // Close loading dialog
      Navigator.of(context).pop();

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'My $phaseName Arcform - $geometryName geometry',
        subject: 'LUMARA MVP - Emotional Journey Visualization',
      );

      // Track analytics
      AnalyticsService.trackArcformExport(phaseName, geometryName);

      // Show success message
      _showSuccessSnackBar(context, 'Arcform shared successfully!');

    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar(context, 'Failed to export arcform: $e');
    }
  }

  /// Capture the arcform widget as PNG bytes
  static Future<Uint8List?> _captureArcformAsPng(GlobalKey repaintBoundaryKey) async {
    try {
      final RenderRepaintBoundary boundary = 
          repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing arcform: $e');
      return null;
    }
  }

  /// Save PNG bytes to temporary file
  static Future<File> _savePngToTempFile(
    Uint8List pngBytes, 
    String phaseName, 
    String geometryName
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      // Ensure the directory exists
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'arcform_${phaseName.toLowerCase()}_${geometryName.toLowerCase()}_$timestamp.png';
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      // Fallback: try using application documents directory
      print('Temporary directory failed, trying documents directory: $e');
      final documentsDir = await getApplicationDocumentsDirectory();
      
      // Ensure the directory exists
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'arcform_${phaseName.toLowerCase()}_${geometryName.toLowerCase()}_$timestamp.png';
      final file = File('${documentsDir.path}/$fileName');
      
      await file.writeAsBytes(pngBytes);
      return file;
    }
  }

  /// Show error snackbar
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success snackbar
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Export arcform as PNG without sharing (for future use)
  static Future<File?> exportArcformAsFile({
    required GlobalKey repaintBoundaryKey,
    required String phaseName,
    required String geometryName,
  }) async {
    try {
      final pngBytes = await _captureArcformAsPng(repaintBoundaryKey);
      if (pngBytes == null) return null;
      
      return await _savePngToTempFile(pngBytes, phaseName, geometryName);
    } catch (e) {
      print('Error exporting arcform: $e');
      return null;
    }
  }
}
