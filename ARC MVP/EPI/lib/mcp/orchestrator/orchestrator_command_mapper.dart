import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';

import 'multimodal_orchestrator_commands.dart';
import 'ocp_services.dart';
import 'mcp_pointer_service.dart';
import '../models/mcp_schemas.dart';

/// Helper service to map orchestrator commands to concrete Flutter calls
class OrchestratorCommandMapper {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Map command to concrete implementation
  static Future<CommandExecutionResult> executeCommand(
    OrchestratorCommand command,
  ) async {
    try {
      switch (command.type) {
        case OrchestratorCommandType.requestPermissions:
          return await _executeRequestPermissions(command as RequestPermissionsCommand);
        case OrchestratorCommandType.openPicker:
          return await _executeOpenPicker(command as OpenPickerCommand);
        case OrchestratorCommandType.runOcpImage:
          return await _executeRunOcpImage(command as RunOcpImageCommand);
        case OrchestratorCommandType.runOcpVideo:
          return await _executeRunOcpVideo(command as RunOcpVideoCommand);
        case OrchestratorCommandType.runStt:
          return await _executeRunStt(command as RunSttCommand);
        case OrchestratorCommandType.createPointer:
          return await _executeCreatePointer(command as CreatePointerCommand);
        case OrchestratorCommandType.commitMcpNode:
          return await _executeCommitMcpNode(command as CommitMcpNodeCommand);
        case OrchestratorCommandType.renderInlineThumbnail:
          return await _executeRenderInlineThumbnail(command as RenderInlineThumbnailCommand);
        case OrchestratorCommandType.enableEmbedPopup:
          return await _executeEnableEmbedPopup(command as EnableEmbedPopupCommand);
        case OrchestratorCommandType.buildGallery:
          return await _executeBuildGallery(command as BuildGalleryCommand);
        case OrchestratorCommandType.cacheScrub:
          return await _executeCacheScrub(command as CacheScrubCommand);
      }
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: true,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute permission request
  static Future<CommandExecutionResult> _executeRequestPermissions(
    RequestPermissionsCommand command,
  ) async {
    try {
      Permission permission;
      switch (command.target) {
        case 'photos':
          permission = Permission.photos;
          break;
        case 'microphone':
          permission = Permission.microphone;
          break;
        case 'files':
          permission = Permission.storage;
          break;
        default:
          throw Exception('Unknown permission target: ${command.target}');
      }

      final status = await permission.request();
      final granted = status == PermissionStatus.granted;

      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: granted,
            error: granted ? null : 'Permission denied for ${command.target}',
            critical: !granted,
            data: {'permission': command.target, 'granted': granted},
          ),
        ],
        overallSuccess: granted,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: true,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute media picker
  static Future<CommandExecutionResult> _executeOpenPicker(
    OpenPickerCommand command,
  ) async {
    try {
      List<String> selectedUris = [];

      switch (command.kind) {
        case 'photo':
          if (command.multi) {
            final images = await _imagePicker.pickMultiImage();
            selectedUris = images.map((img) => img.path).toList();
          } else {
            final image = await _imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              selectedUris = [image.path];
            }
          }
          break;
        case 'video':
          final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
          if (video != null) {
            selectedUris = [video.path];
          }
          break;
        case 'audio':
          final result = await FilePicker.platform.pickFiles(
            type: FileType.audio,
            allowMultiple: command.multi,
          );
          if (result != null) {
            selectedUris = result.files.map((file) => file.path!).toList();
          }
          break;
      }

      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: true,
            error: null,
            critical: false,
            data: {'selectedUris': selectedUris, 'count': selectedUris.length},
          ),
        ],
        overallSuccess: true,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: true,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute image OCP analysis
  static Future<CommandExecutionResult> _executeRunOcpImage(
    RunOcpImageCommand command,
  ) async {
    try {
      final result = await OcpImageService.analyzeImage(command.uri);

      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: result.error == null,
            error: result.error,
            critical: false,
            data: _convertOcpImageResultToData(result),
          ),
        ],
        overallSuccess: result.error == null,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute video OCP analysis
  static Future<CommandExecutionResult> _executeRunOcpVideo(
    RunOcpVideoCommand command,
  ) async {
    try {
      final keyframePolicy = KeyframePolicy(
        shortS: command.keyframePolicy['short_s'] ?? 2,
        mediumS: command.keyframePolicy['medium_s'] ?? 4,
        longS: command.keyframePolicy['long_s'] ?? 8,
        thresholds: Map<String, int>.from(command.keyframePolicy['thresholds'] ?? {}),
      );

      final result = await OcpVideoService.analyzeVideo(command.uri, keyframePolicy);

      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: result.error == null,
            error: result.error,
            critical: false,
            data: _convertOcpVideoResultToData(result),
          ),
        ],
        overallSuccess: result.error == null,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute speech-to-text
  static Future<CommandExecutionResult> _executeRunStt(
    RunSttCommand command,
  ) async {
    try {
      final result = await SttService.transcribeAudio(command.uri, command.modelHint);

      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: result.error == null,
            error: result.error,
            critical: false,
            data: _convertSttResultToData(result),
          ),
        ],
        overallSuccess: result.error == null,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute pointer creation
  static Future<CommandExecutionResult> _executeCreatePointer(
    CreatePointerCommand command,
  ) async {
    try {
      final pointer = await McpPointerService.createPointer(
        uri: command.uri,
        mediaType: command.mediaType,
        descriptor: command.descriptor,
        integrity: command.integrity,
        privacy: command.privacy,
        samplingManifest: command.samplingManifest,
      );

      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: true,
            error: null,
            critical: false,
            data: {'pointer': pointer.toJson()},
          ),
        ],
        overallSuccess: true,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute MCP node commit
  static Future<CommandExecutionResult> _executeCommitMcpNode(
    CommitMcpNodeCommand command,
  ) async {
    try {
      // TODO: Implement actual MCP node writing to Hive storage
      // For now, return success
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: true,
            error: null,
            critical: false,
            data: {'node': command.node},
          ),
        ],
        overallSuccess: true,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute thumbnail rendering
  static Future<CommandExecutionResult> _executeRenderInlineThumbnail(
    RenderInlineThumbnailCommand command,
  ) async {
    try {
      // TODO: Implement actual thumbnail rendering
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: true,
            error: null,
            critical: false,
            data: {
              'thumbnailUri': 'placeholder_thumbnail_${command.pointerRef}_${command.size}',
              'size': command.size,
            },
          ),
        ],
        overallSuccess: true,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute embed popup
  static Future<CommandExecutionResult> _executeEnableEmbedPopup(
    EnableEmbedPopupCommand command,
  ) async {
    try {
      // TODO: Implement actual popup UI
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: true,
            error: null,
            critical: false,
            data: {
              'popupEnabled': true,
              'behavior': command.behavior,
              'withData': command.with,
            },
          ),
        ],
        overallSuccess: true,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute gallery building
  static Future<CommandExecutionResult> _executeBuildGallery(
    BuildGalleryCommand command,
  ) async {
    try {
      // TODO: Implement actual gallery UI
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: true,
            error: null,
            critical: false,
            data: {
              'galleryBuilt': true,
              'pointerCount': command.pointerRefs.length,
            },
          ),
        ],
        overallSuccess: true,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  /// Execute cache scrubbing
  static Future<CommandExecutionResult> _executeCacheScrub(
    CacheScrubCommand command,
  ) async {
    try {
      await McpPointerService.cleanupTempFiles(command.uris);

      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: true,
            error: null,
            critical: false,
            data: {
              'cleanedUris': command.uris,
              'count': command.uris.length,
            },
          ),
        ],
        overallSuccess: true,
      );
    } catch (e) {
      return CommandExecutionResult(
        results: [
          CommandResult(
            command: command,
            success: false,
            error: e.toString(),
            critical: false,
            data: {},
          ),
        ],
        overallSuccess: false,
      );
    }
  }

  // Helper methods to convert OCP results to data maps

  static Map<String, dynamic> _convertOcpImageResultToData(OcpImageResult result) {
    return {
      'analysis': {
        'summary': result.summary,
        'exif': result.exif,
        'gps': result.gps,
        'objects': result.objects.map((obj) => {
          'category': obj.category,
          'confidence': obj.confidence,
          'label': obj.label,
        }).toList(),
        'people': result.people.map((person) => {
          'category': person.category,
          'confidence': person.confidence,
          'label': person.label,
        }).toList(),
        'ocrText': result.ocrText,
        'symbols': result.symbols,
        'sage': {
          'situation': result.sage.situation,
          'action': result.sage.action,
          'growth': result.sage.growth,
          'essence': result.sage.essence,
        },
        'perceptualHash': result.perceptualHash,
      },
    };
  }

  static Map<String, dynamic> _convertOcpVideoResultToData(OcpVideoResult result) {
    return {
      'analysis': {
        'duration': result.duration.inMilliseconds,
        'sceneSummary': result.sceneSummary,
        'ocrAggregate': result.ocrAggregate,
        'objects': result.objects.map((obj) => {
          'category': obj.category,
          'confidence': obj.confidence,
          'label': obj.label,
        }).toList(),
        'symbols': result.symbols,
        'sage': {
          'situation': result.sage.situation,
          'action': result.sage.action,
          'growth': result.sage.growth,
          'essence': result.sage.essence,
        },
        'keyframes': result.keyframes.map((kf) => {
          'uri': kf.uri,
          'timestamp': kf.timestamp.inMilliseconds,
          'frameNumber': kf.frameNumber,
        }).toList(),
        'scenes': result.scenes.map((scene) => {
          'timestamp': scene.timestamp.inMilliseconds,
          'uri': scene.uri,
          'ocrText': scene.ocrText,
          'summary': scene.summary,
        }).toList(),
      },
    };
  }

  static Map<String, dynamic> _convertSttResultToData(SttResult result) {
    return {
      'transcription': {
        'transcript': result.transcript,
        'confidence': result.confidence,
        'duration': result.duration.inMilliseconds,
        'prosody': {
          'pitch': result.prosody.pitch,
          'pace': result.prosody.pace,
          'volume': result.prosody.volume,
          'features': result.prosody.features,
        },
        'sentiment': {
          'valence': result.sentiment.valence,
          'arousal': result.sentiment.arousal,
          'emotion': result.sentiment.emotion,
        },
        'symbols': result.symbols,
      },
    };
  }
}

