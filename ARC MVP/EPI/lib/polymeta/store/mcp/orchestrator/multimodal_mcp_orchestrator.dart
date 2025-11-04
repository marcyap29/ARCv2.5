import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'multimodal_orchestrator_commands.dart';
import 'ocp_services.dart';
import 'mcp_pointer_service.dart';
import '../models/mcp_schemas.dart';
import '../adapters/mira_writer.dart';

/// Multimodal MCP Orchestrator - Main service for handling multimodal content
class MultimodalMcpOrchestrator {
  static const _uuid = Uuid();
  final ImagePicker _imagePicker = ImagePicker();
  final MiraWriter _miraWriter = MiraWriter();

  /// Process user intent and generate command sequence
  Future<OrchestratorCommandEnvelope> processUserIntent(String intent) async {
    switch (intent.toLowerCase()) {
      case 'user tapped photo icon in journal entry':
        return _generatePhotoFlow();
      case 'user tapped video icon in journal entry':
        return _generateVideoFlow();
      case 'user tapped audio icon in journal entry':
        return _generateAudioFlow();
      default:
        return OrchestratorCommandEnvelope(commands: []);
    }
  }

  /// Execute command sequence
  Future<CommandExecutionResult> executeCommands(
    OrchestratorCommandEnvelope envelope,
  ) async {
    final results = <CommandResult>[];
    
    for (final command in envelope.commands) {
      try {
        final result = await _executeCommand(command);
        results.add(result);
        
        // Stop execution if command failed critically
        if (!result.success && result.critical) {
          break;
        }
      } catch (e) {
        results.add(CommandResult(
          command: command,
          success: false,
          error: e.toString(),
          critical: true,
          data: {},
        ));
        break;
      }
    }
    
    return CommandExecutionResult(
      results: results,
      overallSuccess: results.every((r) => r.success),
    );
  }

  /// Generate photo attachment flow
  OrchestratorCommandEnvelope _generatePhotoFlow() {
    return OrchestratorCommandEnvelope(
      commands: [
        RequestPermissionsCommand(target: 'photos'),
        OpenPickerCommand(kind: 'photo', multi: true),
        // Additional commands will be generated dynamically based on user selection
      ],
    );
  }

  /// Generate video attachment flow
  OrchestratorCommandEnvelope _generateVideoFlow() {
    return OrchestratorCommandEnvelope(
      commands: [
        RequestPermissionsCommand(target: 'photos'),
        OpenPickerCommand(kind: 'video', multi: true),
        // Additional commands will be generated dynamically based on user selection
      ],
    );
  }

  /// Generate audio attachment flow
  OrchestratorCommandEnvelope _generateAudioFlow() {
    return OrchestratorCommandEnvelope(
      commands: [
        RequestPermissionsCommand(target: 'microphone'),
        OpenPickerCommand(kind: 'audio', multi: false),
        // Additional commands will be generated dynamically based on user selection
      ],
    );
  }

  /// Execute individual command
  Future<CommandResult> _executeCommand(OrchestratorCommand command) async {
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
  }

  /// Execute permission request
  Future<CommandResult> _executeRequestPermissions(RequestPermissionsCommand command) async {
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
      
      return CommandResult(
        command: command,
        success: granted,
        error: granted ? null : 'Permission denied for ${command.target}',
        critical: !granted,
        data: {'permission': command.target, 'granted': granted},
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: true,
        data: {},
      );
    }
  }

  /// Execute media picker
  Future<CommandResult> _executeOpenPicker(OpenPickerCommand command) async {
    try {
      List<String> selectedUris = [];
      
      switch (command.kind) {
        case 'photo':
          final images = await _imagePicker.pickMultiImage();
          selectedUris = images.map((img) => img.path).toList();
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
      
      return CommandResult(
        command: command,
        success: true,
        error: null,
        critical: false,
        data: {'selectedUris': selectedUris, 'count': selectedUris.length},
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: true,
        data: {},
      );
    }
  }

  /// Execute image OCP analysis
  Future<CommandResult> _executeRunOcpImage(RunOcpImageCommand command) async {
    try {
      final result = await OcpImageService.analyzeImage(command.uri);
      
      return CommandResult(
        command: command,
        success: result.error == null,
        error: result.error,
        critical: false,
        data: {
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
        },
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute video OCP analysis
  Future<CommandResult> _executeRunOcpVideo(RunOcpVideoCommand command) async {
    try {
      final keyframePolicy = KeyframePolicy(
        shortS: command.keyframePolicy['short_s'] ?? 2,
        mediumS: command.keyframePolicy['medium_s'] ?? 4,
        longS: command.keyframePolicy['long_s'] ?? 8,
        thresholds: Map<String, int>.from(command.keyframePolicy['thresholds'] ?? {}),
      );
      
      final result = await OcpVideoService.analyzeVideo(command.uri, keyframePolicy);
      
      return CommandResult(
        command: command,
        success: result.error == null,
        error: result.error,
        critical: false,
        data: {
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
        },
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute speech-to-text
  Future<CommandResult> _executeRunStt(RunSttCommand command) async {
    try {
      final result = await SttService.transcribeAudio(command.uri, command.modelHint);
      
      return CommandResult(
        command: command,
        success: result.error == null,
        error: result.error,
        critical: false,
        data: {
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
        },
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute pointer creation
  Future<CommandResult> _executeCreatePointer(CreatePointerCommand command) async {
    try {
      final pointer = await McpPointerService.createPointer(
        uri: command.uri,
        mediaType: command.mediaType,
        descriptor: command.descriptor,
        integrity: command.integrity,
        privacy: command.privacy,
        samplingManifest: command.samplingManifest,
      );
      
      return CommandResult(
        command: command,
        success: true,
        error: null,
        critical: false,
        data: {'pointer': pointer.toJson()},
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute MCP node commit
  Future<CommandResult> _executeCommitMcpNode(CommitMcpNodeCommand command) async {
    try {
      // Generate node ID
      final nodeId = 'mcp_${DateTime.now().toIso8601String()}_${_uuid.v4()}';
      
      // Create MCP node from command data
      final nodeData = Map<String, dynamic>.from(command.node);
      nodeData['id'] = nodeId;
      nodeData['ts'] = DateTime.now().toIso8601String();
      
      // Create McpNode object
      final mcpNode = McpNode.fromJson(nodeData);
      
      // Write to MIRA storage
      await _miraWriter.writeNode(mcpNode);
      
      return CommandResult(
        command: command,
        success: true,
        error: null,
        critical: false,
        data: {'nodeId': nodeId, 'node': mcpNode.toJson()},
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute thumbnail rendering
  Future<CommandResult> _executeRenderInlineThumbnail(RenderInlineThumbnailCommand command) async {
    try {
      // TODO: Implement actual thumbnail rendering
      // For now, return placeholder
      return CommandResult(
        command: command,
        success: true,
        error: null,
        critical: false,
        data: {
          'thumbnailUri': 'placeholder_thumbnail_${command.pointerRef}_${command.size}',
          'size': command.size,
        },
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute embed popup
  Future<CommandResult> _executeEnableEmbedPopup(EnableEmbedPopupCommand command) async {
    try {
      // TODO: Implement actual popup UI
      return CommandResult(
        command: command,
        success: true,
        error: null,
        critical: false,
        data: {
          'popupEnabled': true,
          'behavior': command.behavior,
          'withData': command.withData,
        },
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute gallery building
  Future<CommandResult> _executeBuildGallery(BuildGalleryCommand command) async {
    try {
      // TODO: Implement actual gallery UI
      return CommandResult(
        command: command,
        success: true,
        error: null,
        critical: false,
        data: {
          'galleryBuilt': true,
          'pointerCount': command.pointerRefs.length,
        },
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }

  /// Execute cache scrubbing
  Future<CommandResult> _executeCacheScrub(CacheScrubCommand command) async {
    try {
      await McpPointerService.cleanupTempFiles(command.uris);
      
      return CommandResult(
        command: command,
        success: true,
        error: null,
        critical: false,
        data: {
          'cleanedUris': command.uris,
          'count': command.uris.length,
        },
      );
    } catch (e) {
      return CommandResult(
        command: command,
        success: false,
        error: e.toString(),
        critical: false,
        data: {},
      );
    }
  }
}

// CommandResult and CommandExecutionResult are defined in multimodal_orchestrator_commands.dart

