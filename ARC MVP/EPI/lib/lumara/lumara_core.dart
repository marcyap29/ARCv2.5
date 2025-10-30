// lib/lumara/lumara_core.dart
// LUMARA Core Integration - Universal system with Bundle Doctor

import 'prompts/lumara_system_prompt.dart';
import 'prompts/prompt_library.dart';
import 'package:my_app/core/mcp/bundle_doctor/mcp_models.dart';

export 'prompts/lumara_system_prompt.dart';
export 'prompts/prompt_library.dart';
export 'package:my_app/core/mcp/bundle_doctor/bundle_doctor.dart';
export 'package:my_app/core/mcp/bundle_doctor/mcp_models.dart';

/// LUMARA Core Integration
///
/// This file provides a unified export of all LUMARA-related functionality:
/// - Universal system prompts
/// - Prompt library with JSON/Markdown generation
/// - MCP Bundle Doctor for validation and repair
/// - MCP data models and types
///
/// Usage:
/// ```dart
/// import 'package:my_app/lumara/lumara_core.dart';
///
/// // Use system prompts
/// final prompt = LumaraSystemPrompt.buildPrompt('chat', context: {'user': 'Alice'});
///
/// // Generate documentation
/// final docs = LumaraPromptLibrary.generateMarkdownDocs();
///
/// // Repair and validate MCP bundles
/// final bundle = BundleDoctor.repair(inputData);
/// final validation = BundleDoctor.validate(bundle);
/// ```
class LumaraCore {
  /// Version of the LUMARA system
  static const String version = '1.2.2';

  /// Schema version for MCP bundles
  static const String mcpSchemaVersion = 'mcp-1.0';

  /// Get system information
  static Map<String, dynamic> getSystemInfo() {
    return {
      'lumara_version': version,
      'mcp_schema_version': mcpSchemaVersion,
      'modules': LumaraPromptLibrary.promptSystem['modules'],
      'supported_phases': LumaraSystemPrompt.atlasPhases,
      'supported_node_types': [
        MCPNodeType.entry,
        MCPNodeType.keyword,
        MCPNodeType.phase,
        MCPNodeType.emotion,
        MCPNodeType.arcform,
        MCPNodeType.chat,
        MCPNodeType.reflection,
      ],
      'supported_edge_types': [
        MCPEdgeType.mentions,
        MCPEdgeType.phaseHint,
        MCPEdgeType.emotionHint,
        MCPEdgeType.contains,
        MCPEdgeType.relatesTo,
        MCPEdgeType.followsFrom,
      ],
    };
  }
}