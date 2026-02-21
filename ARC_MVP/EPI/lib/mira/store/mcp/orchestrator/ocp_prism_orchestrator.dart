import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'orchestrator_command_mapper.dart';
import 'mcp_pointer_service.dart';
import 'enhanced_ocp_services.dart';

/// OCP/PRISM: OCR + Feature Recognition Orchestrator
/// Converts photos and videos into derived text + metadata only
/// Stores MCP nodes with pointers to external media
class OCPPrismOrchestrator {
  final OrchestratorCommandMapper _commandMapper;
  final McpPointerService _pointerService;
  final EnhancedOcpServices _ocpServices;

  OCPPrismOrchestrator({
    required OrchestratorCommandMapper commandMapper,
    required McpPointerService pointerService,
    required EnhancedOcpServices ocpServices,
  }) : _commandMapper = commandMapper,
       _pointerService = pointerService,
       _ocpServices = ocpServices;

  /// Process photos with OCR + barcodes + features
  Future<Map<String, dynamic>> processPhotos({
    bool multiSelect = true,
    String ocrEngine = 'paddle',
    String language = 'auto',
    int maxProcessingMs = 1500,
  }) async {
    final commands = <Map<String, dynamic>>[];

    // Request permissions
    commands.add({
      'type': 'REQUEST_PERMISSIONS',
      'target': 'photos',
    });

    // Open photo picker
    commands.add({
      'type': 'OPEN_PICKER',
      'kind': 'photo',
      'multi': multiSelect,
    });

    return {'commands': commands};
  }

  /// Process videos with scene detection + keyframes + OCR
  Future<Map<String, dynamic>> processVideos({
    bool multiSelect = true,
    String sceneAlgo = 'content',
    double minSceneLenS = 2.0,
    Map<String, dynamic>? keyframePolicy,
  }) async {
    final commands = <Map<String, dynamic>>[];

    // Request permissions
    commands.add({
      'type': 'REQUEST_PERMISSIONS',
      'target': 'photos',
    });

    // Open video picker
    commands.add({
      'type': 'OPEN_PICKER',
      'kind': 'video',
      'multi': multiSelect,
    });

    return {'commands': commands};
  }

  /// Execute OCP commands for a single photo
  Future<Map<String, dynamic>> executePhotoOCP({
    required String photoUri,
    String ocrEngine = 'paddle',
    String language = 'auto',
    int maxProcessingMs = 1500,
    String featureMethod = 'orb',
    Map<String, dynamic>? featureParams,
  }) async {
    final commands = <Map<String, dynamic>>[];

    // Run OCR
    commands.add({
      'type': 'RUN_OCP_OCR',
      'uri': photoUri,
      'engine': ocrEngine,
      'lang': language,
      'maxMs': maxProcessingMs,
    });

    // Run barcode detection
    commands.add({
      'type': 'RUN_OCP_BARCODES',
      'uri': photoUri,
    });

    // Run feature detection
    commands.add({
      'type': 'RUN_OCP_FEATURES',
      'uri': photoUri,
      'method': featureMethod,
      'params': featureParams ?? {
        'maxKp': 500,
        'fastThreshold': 20,
      },
    });

    return {'commands': commands};
  }

  /// Execute OCP commands for a video
  Future<Map<String, dynamic>> executeVideoOCP({
    required String videoUri,
    String sceneAlgo = 'content',
    double minSceneLenS = 2.0,
    Map<String, dynamic>? keyframePolicy,
    List<String>? trackClasses,
  }) async {
    final commands = <Map<String, dynamic>>[];

    // Run scene detection
    commands.add({
      'type': 'RUN_SCENE_DETECT',
      'uri': videoUri,
      'algo': sceneAlgo,
      'minSceneLenS': minSceneLenS,
    });

    // Extract keyframes
    commands.add({
      'type': 'EXTRACT_KEYFRAMES',
      'uri': videoUri,
      'policy': keyframePolicy ?? {
        'short_s': 2,
        'medium_s': 4,
        'long_s': 8,
        'thresholds': {
          'short_lt_s': 60,
          'long_gt_s': 300,
        },
      },
    });

    // Optional ByteTrack for object tracking
    if (trackClasses != null && trackClasses.isNotEmpty) {
      commands.add({
        'type': 'RUN_BYTE_TRACK',
        'frames': [], // Will be populated with keyframes
        'classes': trackClasses,
        'maxMs': 1000,
      });
    }

    return {'commands': commands};
  }

  /// Create MCP node with enhanced metadata
  Future<Map<String, dynamic>> createEnhancedMcpNode({
    required String mediaUri,
    required String mediaType,
    required Map<String, dynamic> ocrResult,
    required Map<String, dynamic> barcodeResult,
    required Map<String, dynamic> featureResult,
    Map<String, dynamic>? sceneResult,
    Map<String, dynamic>? trackResult,
    String? summaryText,
  }) async {
    final now = DateTime.now();
    final nodeId = 'mcp_${now.toIso8601String()}_${now.millisecondsSinceEpoch % 1000}';

    // Create pointer
    final pointer = await McpPointerService.createPointer(
      uri: mediaUri,
      mediaType: mediaType,
      descriptor: {
        'mime': mediaType == 'image' ? 'image/jpeg' : 'video/mp4',
        'sizeBytes': 0, // Will be filled by actual file size
      },
      integrity: {
        'sha256': '', // Will be calculated
      },
      privacy: {
        'scope': 'user-library',
      },
      samplingManifest: {
        'thumbnails': [],
        'keyframes': [],
        'sceneCuts': [],
      },
    );

    // Build enhanced metadata
    final meta = <String, dynamic>{
      'source': 'OCP',
      'exif': {},
      'gps': {
        'lat': null,
        'lon': null,
        'acc_m': null,
      },
      'ocr': {
        'fullText': ocrResult['fullText'] ?? '',
        'blocks': ocrResult['blocks'] ?? [],
      },
      'barcodes': barcodeResult['barcodes'] ?? [],
      'features': {
        'method': featureResult['method'] ?? 'orb',
        'kp': featureResult['kp'] ?? 0,
        'hashes': {
          'phash': featureResult['phash'] ?? '',
          'orbPatch': featureResult['orbPatch'] ?? '',
        },
      },
      'scenes': sceneResult?['scenes'] ?? [],
      'tracks': trackResult?['tracks'] ?? [],
      'symbols': [],
      'arc_sage': {
        'S': '',
        'A': '',
        'G': '',
        'E': '',
      },
      'privacy': {
        'raw_cached_until': now.add(const Duration(minutes: 5)).toIso8601String(),
        'scope': 'on-device',
      },
    };

    // Generate summary text
    final text = summaryText ?? _generateSummaryText(ocrResult, barcodeResult, sceneResult);

    final node = {
      'id': nodeId,
      'ts': now.toIso8601String(),
      'kind': mediaType,
      'pointers': [
        {
          'ref': pointer.id,
          'role': 'primary',
        }
      ],
      'text': text,
      'meta': meta,
    };

    return {
      'commands': [
        {
          'type': 'COMMIT_MCP_NODE',
          'node': node,
        },
        {
          'type': 'RENDER_INLINE_THUMBNAIL',
          'pointerRef': pointer.id,
          'size': 'mini',
        },
        {
          'type': 'ENABLE_EMBED_POPUP',
          'pointerRef': pointer.id,
          'behavior': 'openPopup',
          'withData': 'extractedData',
        },
      ],
    };
  }

  /// Generate intelligent summary text from analysis results
  String _generateSummaryText(
    Map<String, dynamic> ocrResult,
    Map<String, dynamic> barcodeResult,
    Map<String, dynamic>? sceneResult,
  ) {
    final summaries = <String>[];

    // Check for barcodes first (high priority)
    final barcodes = barcodeResult['barcodes'] as List? ?? [];
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
    final fullText = ocrResult['fullText'] as String? ?? '';
    if (fullText.isNotEmpty) {
      final words = fullText.split(' ').where((w) => w.length > 2).take(5).toList();
      if (words.isNotEmpty) {
        summaries.add('Text: ${words.join(' ')}');
      }
    }

    // Check for scenes in video
    if (sceneResult != null) {
      final scenes = sceneResult['scenes'] as List? ?? [];
      if (scenes.length > 1) {
        summaries.add('${scenes.length} scenes detected');
      }
    }

    // Fallback
    if (summaries.isEmpty) {
      return 'Media attachment added';
    }

    return summaries.join('; ');
  }

  /// Execute complete photo processing workflow
  Future<Map<String, dynamic>> processPhotoWorkflow({
    required String photoUri,
    String ocrEngine = 'paddle',
    String language = 'auto',
    int maxProcessingMs = 1500,
  }) async {
    try {
      // Run OCP analysis
      final ocpResult = await executePhotoOCP(
        photoUri: photoUri,
        ocrEngine: ocrEngine,
        language: language,
        maxProcessingMs: maxProcessingMs,
      );

      // Simulate OCP results (in production, these would come from actual OCR engines)
      final ocrResult = {
        'fullText': 'Sample text extracted from photo',
        'blocks': [
          {
            'text': 'Sample text',
            'bbox': [0, 0, 100, 20],
          }
        ],
      };

      final barcodeResult = {
        'barcodes': [],
      };

      final featureResult = {
        'method': 'orb',
        'kp': 150,
        'phash': 'abc123def456',
        'orbPatch': 'orb_patch_data',
      };

      // Create MCP node
      final mcpResult = await createEnhancedMcpNode(
        mediaUri: photoUri,
        mediaType: 'image',
        ocrResult: ocrResult,
        barcodeResult: barcodeResult,
        featureResult: featureResult,
      );

      // Combine commands
      final allCommands = <Map<String, dynamic>>[];
      allCommands.addAll(ocpResult['commands'] as List<Map<String, dynamic>>);
      allCommands.addAll(mcpResult['commands'] as List<Map<String, dynamic>>);

      // Add cache scrubbing
      allCommands.add({
        'type': 'CACHE_SCRUB',
        'uris': [photoUri],
      });

      return {'commands': allCommands};

    } catch (e) {
      // Fallback: create minimal MCP node
      return await createEnhancedMcpNode(
        mediaUri: photoUri,
        mediaType: 'image',
        ocrResult: {'fullText': '', 'blocks': []},
        barcodeResult: {'barcodes': []},
        featureResult: {'method': 'orb', 'kp': 0, 'phash': '', 'orbPatch': ''},
        summaryText: 'Attachment added; analysis pending.',
      );
    }
  }

  /// Execute complete video processing workflow
  Future<Map<String, dynamic>> processVideoWorkflow({
    required String videoUri,
    String sceneAlgo = 'content',
    double minSceneLenS = 2.0,
  }) async {
    try {
      // Run OCP analysis
      final ocpResult = await executeVideoOCP(
        videoUri: videoUri,
        sceneAlgo: sceneAlgo,
        minSceneLenS: minSceneLenS,
      );

      // Simulate OCP results
      final sceneResult = {
        'scenes': [
          {
            'tStart': 0.0,
            'tEnd': 4.0,
            'keyframe': 'kf_0001.jpg',
            'ocr': 'Scene 1 text',
            'barcode': null,
          },
          {
            'tStart': 4.0,
            'tEnd': 8.0,
            'keyframe': 'kf_0002.jpg',
            'ocr': 'Scene 2 text',
            'barcode': null,
          },
        ],
      };

      final ocrResult = {
        'fullText': 'Video content analysis',
        'blocks': [],
      };

      final barcodeResult = {
        'barcodes': [],
      };

      final featureResult = {
        'method': 'orb',
        'kp': 200,
        'phash': 'video_hash_123',
        'orbPatch': 'video_orb_patch',
      };

      // Create MCP node
      final mcpResult = await createEnhancedMcpNode(
        mediaUri: videoUri,
        mediaType: 'video',
        ocrResult: ocrResult,
        barcodeResult: barcodeResult,
        featureResult: featureResult,
        sceneResult: sceneResult,
      );

      // Combine commands
      final allCommands = <Map<String, dynamic>>[];
      allCommands.addAll(ocpResult['commands'] as List<Map<String, dynamic>>);
      allCommands.addAll(mcpResult['commands'] as List<Map<String, dynamic>>);

      // Add cache scrubbing
      allCommands.add({
        'type': 'CACHE_SCRUB',
        'uris': [videoUri],
      });

      return {'commands': allCommands};

    } catch (e) {
      // Fallback: create minimal MCP node
      return await createEnhancedMcpNode(
        mediaUri: videoUri,
        mediaType: 'video',
        ocrResult: {'fullText': '', 'blocks': []},
        barcodeResult: {'barcodes': []},
        featureResult: {'method': 'orb', 'kp': 0, 'phash': '', 'orbPatch': ''},
        summaryText: 'Video attachment added; analysis pending.',
      );
    }
  }
}
