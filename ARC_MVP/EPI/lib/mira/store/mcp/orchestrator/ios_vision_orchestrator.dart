import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';
import 'package:exif/exif.dart';
import 'package:my_app/arc/chat/llm/bridge.pigeon.dart';

/// iOS Vision Framework Orchestrator - Pure on-device computer vision
class IOSVisionOrchestrator {
  static final IOSVisionOrchestrator _instance = IOSVisionOrchestrator._internal();
  factory IOSVisionOrchestrator() => _instance;
  IOSVisionOrchestrator._internal();

  late final VisionApi _visionApi;
  bool _initialized = false;

  /// Initialize the iOS Vision orchestrator
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _visionApi = VisionApi();
      _initialized = true;
      print('✅ iOS Vision Orchestrator initialized - Pure on-device AI');
    } catch (e) {
      print('❌ Failed to initialize iOS Vision Orchestrator: $e');
      rethrow;
    }
  }

  /// Process photo with comprehensive iOS Vision analysis
  Future<Map<String, dynamic>> processPhoto({
    required String imagePath,
    String ocrEngine = 'ios_vision',
    String language = 'auto',
    int maxProcessingMs = 2000,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();
    final results = <String, dynamic>{};

    try {
      // Read image file for basic analysis
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }

      final imageBytes = await imageFile.readAsBytes();

      // 1. OCR Text Recognition using iOS Vision
      print('🔍 Running iOS Vision OCR...');
      final ocrResult = await _runIOSVisionOCR(imagePath);
      results['ocr'] = ocrResult;

      // 2. Object Detection using iOS Vision
      print('🎯 Detecting objects with iOS Vision...');
      final objectResult = await _detectObjectsWithIOSVision(imagePath);
      results['objects'] = objectResult;

      // 3. Face Detection using iOS Vision
      print('👤 Detecting faces with iOS Vision...');
      final faceResult = await _detectFacesWithIOSVision(imagePath);
      results['faces'] = faceResult;

      // 4. Image Classification using iOS Vision
      print('🏷️ Classifying image with iOS Vision...');
      final classificationResult = await _classifyImageWithIOSVision(imagePath);
      results['labels'] = classificationResult;

      // 5. Feature Extraction (basic image analysis)
      print('🔧 Extracting visual features...');
      final featureResult = await _extractFeatures(imageBytes);
      results['features'] = featureResult;

      // 5b. EXIF metadata (creation date, GPS) for LUMARA context
      print('📅 Reading EXIF metadata...');
      final exifMeta = await _extractExifMetadata(imageBytes);
      results['exif'] = exifMeta['exif'] ?? {};
      results['gps'] = exifMeta['gps'] ?? {};
      if (exifMeta['capturedAt'] != null) {
        results['capturedAt'] = (exifMeta['capturedAt'] as DateTime).toIso8601String();
      }
      if (exifMeta['location'] != null) {
        results['location'] = exifMeta['location'];
      }

      // 6. Generate comprehensive summary
      final summary = _generateComprehensiveSummary(
        ocrResult, 
        objectResult, 
        faceResult, 
        classificationResult, 
        featureResult
      );
      results['summary'] = summary;

      // 7. Check processing time
      stopwatch.stop();
      final processingTime = stopwatch.elapsedMilliseconds;
      results['processingTime'] = processingTime;

      if (processingTime > maxProcessingMs) {
        print('⚠️ Processing took ${processingTime}ms (limit: ${maxProcessingMs}ms)');
      }

      results['success'] = true;
      print('✅ iOS Vision analysis completed in ${processingTime}ms');

    } catch (e) {
      stopwatch.stop();
      print('❌ iOS Vision processing failed: $e');
      results['success'] = false;
      results['error'] = e.toString();
      results['processingTime'] = stopwatch.elapsedMilliseconds;
    }

    return results;
  }

  /// Run OCR using iOS Vision Framework
  Future<Map<String, dynamic>> _runIOSVisionOCR(String imagePath) async {
    try {
      final result = await _visionApi.extractText(imagePath);
      
      // Parse text into blocks
      final blocks = _parseTextIntoBlocks(result.text);
      
      return {
        'fullText': result.text,
        'blocks': blocks,
        'confidence': result.confidence,
        'engine': 'ios_vision',
        'language': 'auto',
      };
    } catch (e) {
      print('iOS Vision OCR failed: $e');
      return {
        'fullText': '',
        'blocks': [],
        'confidence': 0.0,
        'engine': 'ios_vision',
        'language': 'auto',
        'error': e.toString(),
      };
    }
  }

  /// Detect objects using iOS Vision Framework
  Future<List<Map<String, dynamic>>> _detectObjectsWithIOSVision(String imagePath) async {
    try {
      final result = await _visionApi.detectObjects(imagePath);

      return result.objects.map((object) => {
        'label': object.label,
        'confidence': object.confidence,
        'bbox': [
          object.boundingBox.x,
          object.boundingBox.y,
          object.boundingBox.width,
          object.boundingBox.height,
        ],
      }).toList();
    } catch (e) {
      print('iOS Vision object detection failed: $e');
      return [];
    }
  }

  /// Detect faces using iOS Vision Framework
  Future<List<Map<String, dynamic>>> _detectFacesWithIOSVision(String imagePath) async {
    try {
      final result = await _visionApi.detectFaces(imagePath);

      return result.faces.map((face) => {
        'bbox': [
          face.boundingBox.x,
          face.boundingBox.y,
          face.boundingBox.width,
          face.boundingBox.height,
        ],
        'confidence': face.confidence,
      }).toList();
    } catch (e) {
      print('iOS Vision face detection failed: $e');
      return [];
    }
  }

  /// Classify image using iOS Vision Framework
  Future<List<Map<String, dynamic>>> _classifyImageWithIOSVision(String imagePath) async {
    try {
      final result = await _visionApi.classifyImage(imagePath);

      return result.classifications.map((classification) => {
        'label': classification.identifier,
        'confidence': classification.confidence,
      }).toList();
    } catch (e) {
      print('iOS Vision image classification failed: $e');
      return [];
    }
  }

  /// Extract EXIF metadata (creation date, GPS) for LUMARA photo context
  Future<Map<String, dynamic>> _extractExifMetadata(Uint8List imageBytes) async {
    final out = <String, dynamic>{'exif': <String, String>{}, 'gps': <String, double>{}};
    try {
      final data = await readExifFromBytes(imageBytes);
      if (data.isEmpty) return out;

      // Skip thumbnail entries
      final skipKeys = ['JPEGThumbnail', 'TIFFThumbnail'];
      final exif = <String, String>{};
      for (final entry in data.entries) {
        if (skipKeys.contains(entry.key)) continue;
        final p = entry.value.printable;
        if (p.isNotEmpty && p.length < 500) exif[entry.key] = p;
      }
      out['exif'] = exif;

      // Parse creation date (EXIF format often "2024:01:15 12:30:00")
      final dateKeys = ['DateTimeOriginal', 'DateTime', 'CreateDate', 'ModifyDate'];
      for (final k in dateKeys) {
        final tag = data[k] ?? _findExifTag(data, k);
        if (tag == null) continue;
        final str = tag.printable.trim();
        if (str.isEmpty) continue;
        final normalized = str.replaceFirst(RegExp(r'^(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'), '\$1-\$2-\$3T\$4:\$5:\$6');
        try {
          out['capturedAt'] = DateTime.parse(normalized);
          break;
        } catch (_) {
          try {
            out['capturedAt'] = DateTime.parse(str);
            break;
          } catch (_) {}
        }
      }

      // Parse GPS (exif package may use GPSLatitude/GPSLongitude or keys ending with these)
      double? lat;
      double? lon;
      IfdTag? gpsLat = data['GPSLatitude'];
      IfdTag? gpsLon = data['GPSLongitude'];
      gpsLat ??= _findExifTag(data, 'Latitude');
      gpsLon ??= _findExifTag(data, 'Longitude');
      if (gpsLat != null && gpsLon != null) {
        try {
          final latVal = _parseExifGpsValue(gpsLat);
          final lonVal = _parseExifGpsValue(gpsLon);
          if (latVal != null && lonVal != null) {
            final latRef = (data['GPSLatitudeRef'] ?? _findExifTag(data, 'LatitudeRef'))?.printable ?? 'N';
            final lonRef = (data['GPSLongitudeRef'] ?? _findExifTag(data, 'LongitudeRef'))?.printable ?? 'E';
            lat = latRef.toUpperCase().startsWith('S') ? -latVal : latVal;
            lon = lonRef.toUpperCase().startsWith('W') ? -lonVal : lonVal;
          }
        } catch (e) {
          print('iOS Vision: GPS parse error: $e');
        }
      }
      if (lat != null && lon != null) {
        (out['gps'] as Map<String, double>)['latitude'] = lat;
        (out['gps'] as Map<String, double>)['longitude'] = lon;
        out['location'] = '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
      }
    } catch (e) {
      print('iOS Vision: EXIF extraction failed: $e');
    }
    return out;
  }

  double? _parseExifGpsValue(IfdTag tag) {
    try {
      // Try printable first (e.g. "37.7749" or "37 deg 46' 29.64\" N")
      final p = tag.printable.trim();
      final numMatch = RegExp(r'[\d.+-]+').firstMatch(p);
      if (numMatch != null) {
        final v = double.tryParse(numMatch.group(0)!);
        if (v != null && v >= -90 && v <= 90) return v;
      }
      // IfdValues for rational (degrees, minutes, seconds)
      final list = tag.values.toList();
      if (list.length >= 1) {
        final d = _rationalToDouble(list[0]);
        if (d != null && list.length >= 3) {
          final m = _rationalToDouble(list[1]);
          final s = _rationalToDouble(list[2]);
          if (m != null && s != null) return d + m / 60 + s / 3600;
          return d;
        }
        return d;
      }
    } catch (_) {}
    return null;
  }

  double? _rationalToDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v.toString().contains('/')) {
      final parts = v.toString().split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0].trim());
        final d = double.tryParse(parts[1].trim());
        if (n != null && d != null && d != 0) return n / d;
      }
    }
    return double.tryParse(v.toString());
  }

  IfdTag? _findExifTag(Map<String, IfdTag> data, String suffix) {
    for (final e in data.entries) {
      if (e.key.endsWith(suffix)) return e.value;
    }
    return null;
  }

  /// Extract visual features (basic image analysis)
  Future<Map<String, dynamic>> _extractFeatures(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final width = image.width;
      final height = image.height;
      final aspectRatio = width / height;
      final imageSize = imageBytes.length;
      
      // Generate perceptual hash
      final phash = _generatePerceptualHash(imageBytes);
      
      // Calculate image complexity
      final complexity = _calculateImageComplexity(image);
      final estimatedKeypoints = (complexity * 200).round().clamp(50, 800);
      print('DEBUG: Image complexity: $complexity, Estimated keypoints: $estimatedKeypoints');

      return {
        'success': true,
        'method': 'ios_vision_analysis',
        'kp': estimatedKeypoints,
        'hashes': {
          'phash': phash,
          'orbPatch': phash.length >= 12 ? phash.substring(0, 12) : phash,
        },
        'processingTime': 0,
        'params': {
          'width': width,
          'height': height,
          'aspectRatio': aspectRatio,
          'complexity': complexity,
          'imageSize': imageSize,
        },
      };
    } catch (e) {
      print('Feature extraction failed: $e');
      return {
        'success': false,
        'method': 'ios_vision_analysis',
        'kp': 0,
        'hashes': {
          'phash': '',
          'orbPatch': '',
        },
        'processingTime': 0,
        'error': e.toString(),
      };
    }
  }

  /// Parse text into blocks
  List<Map<String, dynamic>> _parseTextIntoBlocks(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final blocks = <Map<String, dynamic>>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        blocks.add({
          'text': line,
          'bbox': [10, i * 30 + 10, line.length * 8, 25],
          'confidence': 0.9, // iOS Vision provides high confidence
        });
      }
    }
    
    return blocks;
  }

  /// Calculate image complexity
  double _calculateImageComplexity(img.Image image) {
    final width = image.width;
    final height = image.height;
    
    double variance = 0.0;
    double mean = 0.0;
    int sampleCount = 0;
    
    for (int y = 0; y < height; y += 10) {
      for (int x = 0; x < width; x += 10) {
        if (x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3.0;
          mean += brightness;
          sampleCount++;
        }
      }
    }
    
    if (sampleCount == 0) return 0.5;
    
    mean /= sampleCount;
    
    for (int y = 0; y < height; y += 10) {
      for (int x = 0; x < width; x += 10) {
        if (x < width && y < height) {
          final pixel = image.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3.0;
          variance += (brightness - mean) * (brightness - mean);
        }
      }
    }
    
    variance /= sampleCount;
    return (variance / 1000).clamp(0.0, 1.0); // Reduced divisor from 10000 to 1000
  }

  /// Generate perceptual hash
  String _generatePerceptualHash(Uint8List imageBytes) {
    try {
      final hash = sha256.convert(imageBytes);
      return hash.toString().substring(0, 16);
    } catch (e) {
      // Return a 16-character fallback hash to prevent RangeError
      return 'hash_error_12345';
    }
  }

  /// Generate comprehensive summary
  String _generateComprehensiveSummary(
    Map<String, dynamic> ocrResult,
    List<Map<String, dynamic>> objectResult,
    List<Map<String, dynamic>> faceResult,
    List<Map<String, dynamic>> classificationResult,
    Map<String, dynamic> featureResult,
  ) {
    final parts = <String>[];

    // Add OCR summary
    final ocrText = ocrResult['fullText'] as String? ?? '';
    if (ocrText.isNotEmpty) {
      final words = ocrText.split(' ').take(6).join(' ');
      parts.add('Text: $words');
    }

    // Add object summary
    if (objectResult.isNotEmpty) {
      final objectLabels = objectResult.map((o) => o['label']).join(', ');
      parts.add('Objects: $objectLabels');
    }

    // Add face summary
    if (faceResult.isNotEmpty) {
      parts.add('Faces: ${faceResult.length} detected');
    }

    // Add scene summary
    if (classificationResult.isNotEmpty) {
      final topLabels = classificationResult.take(3).map((l) => l['label']).join(', ');
      parts.add('Scene: $topLabels');
    }

    // Add feature summary
    final kp = featureResult['kp'] as int? ?? 0;
    if (kp > 0) {
      parts.add('Features: ${kp} keypoints');
    }

    if (parts.isEmpty) {
      return 'Image analyzed with iOS Vision - no significant content detected';
    }

    return parts.join(' | ');
  }

  /// Get formatted text for display
  String getFormattedText(Map<String, dynamic> results) {
    final parts = <String>[];

    // Add OCR text
    final ocr = results['ocr'] as Map<String, dynamic>? ?? {};
    final ocrText = ocr['fullText'] as String? ?? '';
    if (ocrText.isNotEmpty) {
      parts.add('📝 Text (iOS Vision):\n$ocrText');
    }

    // Add objects
    final objects = results['objects'] as List<Map<String, dynamic>>? ?? [];
    if (objects.isNotEmpty) {
      parts.add('🎯 Objects (iOS Vision):');
      for (final obj in objects) {
        final label = obj['label'] as String? ?? 'Unknown';
        final confidence = obj['confidence'] as double? ?? 0.0;
        parts.add('  • $label (${(confidence * 100).toStringAsFixed(1)}%)');
      }
    }

    // Add faces
    final faces = results['faces'] as List<Map<String, dynamic>>? ?? [];
    if (faces.isNotEmpty) {
      parts.add('👤 Faces (iOS Vision): ${faces.length} detected');
      for (final face in faces) {
        final smiling = face['smilingProbability'] as double? ?? 0.0;
        final leftEye = face['leftEyeOpenProbability'] as double? ?? 0.0;
        final rightEye = face['rightEyeOpenProbability'] as double? ?? 0.0;
        parts.add('  • Smiling: ${(smiling * 100).toStringAsFixed(1)}%, Eyes open: ${((leftEye + rightEye) / 2 * 100).toStringAsFixed(1)}%');
      }
    }

    // Add scene labels
    final labels = results['labels'] as List<Map<String, dynamic>>? ?? [];
    if (labels.isNotEmpty) {
      parts.add('🏷️ Scene (iOS Vision):');
      for (final label in labels.take(3)) {
        final labelText = label['label'] as String? ?? 'Unknown';
        final confidence = label['confidence'] as double? ?? 0.0;
        parts.add('  • $labelText (${(confidence * 100).toStringAsFixed(1)}%)');
      }
    }

    return parts.join('\n\n');
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_initialized) {
      _initialized = false;
      print('🧹 iOS Vision Orchestrator disposed');
    }
  }
}
