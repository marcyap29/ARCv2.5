import 'package:equatable/equatable.dart';

/// Core command types for the Multimodal MCP Orchestrator
enum OrchestratorCommandType {
  requestPermissions,
  openPicker,
  runOcpImage,
  runOcpVideo,
  runStt,
  createPointer,
  commitMcpNode,
  renderInlineThumbnail,
  enableEmbedPopup,
  buildGallery,
  cacheScrub,
}

/// Base class for all orchestrator commands
abstract class OrchestratorCommand extends Equatable {
  final OrchestratorCommandType type;
  
  const OrchestratorCommand({required this.type});
  
  Map<String, dynamic> toJson();
  
  @override
  List<Object?> get props => [type];
}

/// Request permissions for media access
class RequestPermissionsCommand extends OrchestratorCommand {
  final String target; // "photos" | "microphone" | "files"
  
  const RequestPermissionsCommand({
    required this.target,
  }) : super(type: OrchestratorCommandType.requestPermissions);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'target': target,
  };
  
  @override
  List<Object?> get props => [type, target];
}

/// Open media picker for user selection
class OpenPickerCommand extends OrchestratorCommand {
  final String kind; // "photo" | "video" | "audio"
  final bool multi;
  
  const OpenPickerCommand({
    required this.kind,
    required this.multi,
  }) : super(type: OrchestratorCommandType.openPicker);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'kind': kind,
    'multi': multi,
  };
  
  @override
  List<Object?> get props => [type, kind, multi];
}

/// Run Optical Character Processing on image
class RunOcpImageCommand extends OrchestratorCommand {
  final String uri;
  
  const RunOcpImageCommand({
    required this.uri,
  }) : super(type: OrchestratorCommandType.runOcpImage);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'uri': uri,
  };
  
  @override
  List<Object?> get props => [type, uri];
}

/// Run Optical Character Processing on video with keyframe policy
class RunOcpVideoCommand extends OrchestratorCommand {
  final String uri;
  final Map<String, dynamic> keyframePolicy;
  
  const RunOcpVideoCommand({
    required this.uri,
    required this.keyframePolicy,
  }) : super(type: OrchestratorCommandType.runOcpVideo);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'uri': uri,
    'keyframePolicy': keyframePolicy,
  };
  
  @override
  List<Object?> get props => [type, uri, keyframePolicy];
}

/// Run Speech-to-Text processing
class RunSttCommand extends OrchestratorCommand {
  final String uri;
  final String modelHint; // "fast" | "balanced" | "accurate"
  
  const RunSttCommand({
    required this.uri,
    required this.modelHint,
  }) : super(type: OrchestratorCommandType.runStt);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'uri': uri,
    'modelHint': modelHint,
  };
  
  @override
  List<Object?> get props => [type, uri, modelHint];
}

/// Create MCP pointer for media reference
class CreatePointerCommand extends OrchestratorCommand {
  final String uri;
  final String mediaType;
  final Map<String, dynamic> descriptor;
  final Map<String, dynamic> integrity;
  final Map<String, dynamic> privacy;
  final Map<String, dynamic>? samplingManifest;
  
  const CreatePointerCommand({
    required this.uri,
    required this.mediaType,
    required this.descriptor,
    required this.integrity,
    required this.privacy,
    this.samplingManifest,
  }) : super(type: OrchestratorCommandType.createPointer);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'uri': uri,
    'mediaType': mediaType,
    'descriptor': descriptor,
    'integrity': integrity,
    'privacy': privacy,
    'samplingManifest': samplingManifest,
  };
  
  @override
  List<Object?> get props => [type, uri, mediaType, descriptor, integrity, privacy, samplingManifest];
}

/// Commit MCP node with analysis results
class CommitMcpNodeCommand extends OrchestratorCommand {
  final Map<String, dynamic> node;
  
  const CommitMcpNodeCommand({
    required this.node,
  }) : super(type: OrchestratorCommandType.commitMcpNode);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'node': node,
  };
  
  @override
  List<Object?> get props => [type, node];
}

/// Render inline thumbnail for UI display
class RenderInlineThumbnailCommand extends OrchestratorCommand {
  final String pointerRef;
  final String size; // "mini" | "small" | "medium"
  
  const RenderInlineThumbnailCommand({
    required this.pointerRef,
    required this.size,
  }) : super(type: OrchestratorCommandType.renderInlineThumbnail);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'pointerRef': pointerRef,
    'size': size,
  };
  
  @override
  List<Object?> get props => [type, pointerRef, size];
}

/// Enable embed popup for rich media display
class EnableEmbedPopupCommand extends OrchestratorCommand {
  final String pointerRef;
  final String behavior; // "openPopup"
  final String withData; // "extractedData"
  
  const EnableEmbedPopupCommand({
    required this.pointerRef,
    required this.behavior,
    required this.withData,
  }) : super(type: OrchestratorCommandType.enableEmbedPopup);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'pointerRef': pointerRef,
    'behavior': behavior,
    'withData': withData,
  };
  
  @override
  List<Object?> get props => [type, pointerRef, behavior, withData];
}

/// Build gallery view for multiple media items
class BuildGalleryCommand extends OrchestratorCommand {
  final List<String> pointerRefs;
  
  const BuildGalleryCommand({
    required this.pointerRefs,
  }) : super(type: OrchestratorCommandType.buildGallery);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'pointerRefs': pointerRefs,
  };
  
  @override
  List<Object?> get props => [type, pointerRefs];
}

/// Scrub temporary cache files
class CacheScrubCommand extends OrchestratorCommand {
  final List<String> uris;
  
  const CacheScrubCommand({
    required this.uris,
  }) : super(type: OrchestratorCommandType.cacheScrub);
  
  @override
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'uris': uris,
  };
  
  @override
  List<Object?> get props => [type, uris];
}

/// Command envelope containing ordered commands
class OrchestratorCommandEnvelope extends Equatable {
  final List<OrchestratorCommand> commands;
  
  const OrchestratorCommandEnvelope({
    required this.commands,
  });
  
  Map<String, dynamic> toJson() => {
    'commands': commands.map((cmd) => cmd.toJson()).toList(),
  };
  
  @override
  List<Object?> get props => [commands];
}

/// Result of command execution
class CommandResult extends Equatable {
  final OrchestratorCommand command;
  final bool success;
  final String? error;
  final bool critical;
  final Map<String, dynamic> data;

  const CommandResult({
    required this.command,
    required this.success,
    required this.error,
    required this.critical,
    required this.data,
  });

  @override
  List<Object?> get props => [command, success, error, critical, data];
}

/// Result of command sequence execution
class CommandExecutionResult extends Equatable {
  final List<CommandResult> results;
  final bool overallSuccess;

  const CommandExecutionResult({
    required this.results,
    required this.overallSuccess,
  });

  @override
  List<Object?> get props => [results, overallSuccess];
}