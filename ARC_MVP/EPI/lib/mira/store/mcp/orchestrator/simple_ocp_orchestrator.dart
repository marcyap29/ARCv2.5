import 'enhanced_ocp_services.dart';

/// Simplified OCP/PRISM orchestrator for enhanced photo analysis
class SimpleOCPOrchestrator {
  final EnhancedOcpServices _ocpServices;

  SimpleOCPOrchestrator({
    required EnhancedOcpServices ocpServices,
  }) : _ocpServices = ocpServices;

  /// Process photo with enhanced OCP analysis
  Future<Map<String, dynamic>> processPhoto({
    required String imagePath,
    String ocrEngine = 'paddle',
    String language = 'auto',
    int maxProcessingMs = 1500,
  }) async {
    try {
      final results = <String, dynamic>{};
      
      // Run OCR analysis
      final ocrResult = await _ocpServices.analyzeImageWithOCR(
        imagePath: imagePath,
        engine: ocrEngine,
        language: language,
        maxProcessingMs: maxProcessingMs,
      );
      
      if (ocrResult['success'] == true) {
        results['ocr'] = {
          'text': ocrResult['fullText'],
          'blocks': ocrResult['blocks'],
          'confidence': ocrResult['confidence'],
          'engine': ocrResult['engine'],
        };
      }

      // Run barcode detection
      final barcodeResult = await _ocpServices.detectBarcodes(imagePath);
      
      if (barcodeResult['success'] == true) {
        results['barcodes'] = barcodeResult['barcodes'];
      }

      // Run feature extraction
      final featureResult = await _ocpServices.extractFeatures(
        imagePath: imagePath,
        method: 'orb',
        params: {
          'maxKp': 500,
          'fastThreshold': 20,
        },
      );
      
      if (featureResult['success'] == true) {
        results['features'] = {
          'method': featureResult['method'],
          'kp': featureResult['kp'],
          'hashes': featureResult['hashes'],
        };
      }

      // Generate summary
      results['summary'] = _generateSummary(results);

      return {
        'success': true,
        'results': results,
        'imagePath': imagePath,
      };

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'imagePath': imagePath,
      };
    }
  }

  /// Generate intelligent summary from analysis results
  String _generateSummary(Map<String, dynamic> results) {
    final summaries = <String>[];

    // Check for barcodes first (high priority)
    final barcodes = results['barcodes'] as List? ?? [];
    if (barcodes.isNotEmpty) {
      for (final barcode in barcodes) {
        final format = barcode['format'] ?? '';
        final data = barcode['data'] ?? '';
        
        if (format == 'QR_CODE') {
          if (data.contains('http')) {
            summaries.add('QR code with link detected');
          } else {
            summaries.add('QR code: ${data.length > 50 ? data.substring(0, 50) + '...' : data}');
          }
        } else if (format == 'CODE_128' || format == 'PDF_417') {
          summaries.add('Barcode detected: ${data.length > 30 ? data.substring(0, 30) + '...' : data}');
        }
      }
    }

    // Check OCR for meaningful content
    final ocr = results['ocr'] as Map<String, dynamic>?;
    if (ocr != null) {
      final text = ocr['text'] as String? ?? '';
      if (text.isNotEmpty) {
        final words = text.split(' ').where((w) => w.length > 2).take(5).toList();
        if (words.isNotEmpty) {
          summaries.add('Text: ${words.join(' ')}');
        }
      }
    }

    // Check features
    final features = results['features'] as Map<String, dynamic>?;
    if (features != null) {
      final kp = features['kp'] as int? ?? 0;
      if (kp > 100) {
        summaries.add('Rich visual content ($kp features)');
      }
    }

    // Fallback
    if (summaries.isEmpty) {
      return 'Photo analyzed';
    }

    return summaries.join('; ');
  }

  /// Get formatted text for journal entry
  String getFormattedText(Map<String, dynamic> results) {
    final text = StringBuffer();
    
    // Add OCR text
    final ocr = results['ocr'] as Map<String, dynamic>?;
    if (ocr != null && ocr['text'] != null && (ocr['text'] as String).isNotEmpty) {
      text.writeln('📸 OCR (${ocr['engine']}): ${ocr['text']}');
    }

    // Add barcodes
    final barcodes = results['barcodes'] as List? ?? [];
    if (barcodes.isNotEmpty) {
      for (final barcode in barcodes) {
        final format = barcode['format'] as String;
        final data = barcode['data'] as String;
        text.writeln('📱 $format: $data');
      }
    }

    // Add features
    final features = results['features'] as Map<String, dynamic>?;
    if (features != null) {
      final kp = features['kp'] as int? ?? 0;
      final hashes = features['hashes'] as Map<String, dynamic>? ?? {};
      text.writeln('🔍 Features (${features['method']}): $kp keypoints, hash: ${hashes['phash']}');
    }

    return text.toString().trim();
  }
}
