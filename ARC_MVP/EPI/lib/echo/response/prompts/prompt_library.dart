// lib/lumara/prompts/prompt_library.dart
// LUMARA Prompt Library with JSON and Markdown references

import 'dart:convert';

/// LUMARA Prompt Library
/// Contains structured prompts, module definitions, and metadata
class LumaraPromptLibrary {
  /// JSON structure for prompt system
  static const Map<String, dynamic> promptSystem = {
    "system_prompt": {
      "name": "LUMARA",
      "role": "Life-aware Unified Memory & Reflection Assistant",
      "core_rules": [
        "Preserve narrative dignity",
        "Never overwrite memory; always extend",
        "Allow external access for biblical, factual, and scientific data. Strict no-politics/news filter",
        "Reflect > Suggest (90/10 balance)"
      ]
    },
    "modules": {
      "ARC": {"purpose": "Journaling + Arcforms"},
      "ATLAS": {
        "purpose": "Life-phase detection",
        "phases": ["Discovery","Expansion","Transition","Consolidation","Recovery","Breakthrough"]
      },
      "AURORA": {"purpose": "Circadian orchestration"},
      "VEIL": {"purpose": "Restorative pruning"},
      "MIRA": {"purpose": "Semantic memory graph"},
      "MCP": {"purpose": "JSON bundle format"},
      "PRISM": {"purpose": "Multimodal analysis"},
      "LUMARA": {"purpose": "Conversational guide"}
    }
  };

  /// Export prompt system as JSON string
  static String toJson() {
    return jsonEncode(promptSystem);
  }

  /// Get module information
  static Map<String, dynamic>? getModule(String moduleName) {
    final modules = promptSystem['modules'] as Map<String, dynamic>?;
    return modules?[moduleName] as Map<String, dynamic>?;
  }

  /// Get all ATLAS phases
  static List<String> getAtlasPhases() {
    final atlas = getModule('ATLAS');
    return List<String>.from(atlas?['phases'] ?? []);
  }

  /// Get core rules
  static List<String> getCoreRules() {
    final systemPrompt = promptSystem['system_prompt'] as Map<String, dynamic>?;
    return List<String>.from(systemPrompt?['core_rules'] ?? []);
  }

  /// Validate that a phase is valid ATLAS phase
  static bool isValidPhase(String phase) {
    return getAtlasPhases().contains(phase);
  }

  /// Get module purpose
  static String? getModulePurpose(String moduleName) {
    final module = getModule(moduleName);
    return module?['purpose'] as String?;
  }

  /// Markdown documentation generator
  static String generateMarkdownDocs() {
    final buffer = StringBuffer();

    buffer.writeln('# LUMARA Prompt Library Documentation');
    buffer.writeln();
    buffer.writeln('Generated from prompt_library.dart');
    buffer.writeln();

    // System info
    final system = promptSystem['system_prompt'] as Map<String, dynamic>;
    buffer.writeln('## System: ${system['name']}');
    buffer.writeln('**Role:** ${system['role']}');
    buffer.writeln();

    // Core rules
    buffer.writeln('### Core Rules');
    final rules = List<String>.from(system['core_rules']);
    for (final rule in rules) {
      buffer.writeln('- $rule');
    }
    buffer.writeln();

    // Modules
    buffer.writeln('## EPI Modules');
    final modules = promptSystem['modules'] as Map<String, dynamic>;
    for (final entry in modules.entries) {
      final module = entry.value as Map<String, dynamic>;
      buffer.writeln('### ${entry.key}');
      buffer.writeln('**Purpose:** ${module['purpose']}');

      // Special handling for ATLAS phases
      if (entry.key == 'ATLAS' && module['phases'] != null) {
        buffer.writeln('**Phases:**');
        final phases = List<String>.from(module['phases']);
        for (final phase in phases) {
          buffer.writeln('- $phase');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Template variables for dynamic prompts
  static const Map<String, String> templateVariables = {
    'user_name': '{{user_name}}',
    'current_phase': '{{current_phase}}',
    'n_entries': '{{n_entries}}',
    'n_arcforms': '{{n_arcforms}}',
    'date_since': '{{date_since}}',
    'context_facts': '{{context_facts}}',
    'context_snippets': '{{context_snippets}}',
    'chat_history': '{{chat_history}}'
  };

  /// Replace template variables in a prompt
  static String processTemplate(String template, Map<String, String> variables) {
    String result = template;
    for (final entry in variables.entries) {
      final placeholder = templateVariables[entry.key] ?? '{{${entry.key}}}';
      result = result.replaceAll(placeholder, entry.value);
    }
    return result;
  }
}