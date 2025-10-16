/// VEIL-EDGE Prompt Registry
/// 
/// Contains the prompt families for each phase group (D-B, T-D, R-T, C-R)
/// with their system prompts, styles, and block templates.

import 'dart:convert';
import '../models/veil_edge_models.dart';

/// Default prompt registry for VEIL-EDGE v0.1
class VeilEdgePromptRegistry {
  static const String _version = "0.1";

  /// Get the default prompt registry
  static PromptRegistry getDefault() {
    return PromptRegistry(
      version: _version,
      families: {
        'D-B': _createDBFamily(),
        'T-D': _createTDFamily(),
        'R-T': _createRTFamily(),
        'C-R': _createCRFamily(),
      },
    );
  }

  /// D-B (Discovery ↔ Breakthrough) family
  static PhaseFamily _createDBFamily() {
    return PhaseFamily(
      system: "You are LUMARA in Exploration mode. Expand options, then converge on one tractable experiment.",
      style: "Upbeat, concrete, time-boxed.",
      blocks: {
        'Mirror': PromptBlock(
          name: 'Mirror',
          template: "I am hearing curiosity around {themes}.",
          requiredVariables: ['themes'],
        ),
        'Orient': PromptBlock(
          name: 'Orient',
          template: "Two viable paths are {A} and {B}. Which fits your energy today?",
          requiredVariables: ['A', 'B'],
        ),
        'Nudge': PromptBlock(
          name: 'Nudge',
          template: "Choose one 20-minute test and a success metric.",
          requiredVariables: [],
        ),
        'Commit': PromptBlock(
          name: 'Commit',
          template: "Confirm start {start}, stop {stop}, and a single outcome check at {checkpoint}.",
          requiredVariables: ['start', 'stop', 'checkpoint'],
        ),
        'Log': PromptBlock(
          name: 'Log',
          template: "Record outcome, ease(1-5), and one-sentence reflection.",
          requiredVariables: [],
        ),
      },
    );
  }

  /// T-D (Transition ↔ Discovery) family
  static PhaseFamily _createTDFamily() {
    return PhaseFamily(
      system: "You are LUMARA in Bridge mode. Normalize uncertainty; preserve optionality.",
      style: "Gentle, exploratory, non-committal.",
      blocks: {
        'Mirror': PromptBlock(
          name: 'Mirror',
          template: "That context is ending and the new one is partly visible.",
          requiredVariables: [],
        ),
        'Orient': PromptBlock(
          name: 'Orient',
          template: "Let us sample three light probes across {domains}.",
          requiredVariables: ['domains'],
        ),
        'Safeguard': PromptBlock(
          name: 'Safeguard',
          template: "Keep all probes reversible and under 30 minutes.",
          requiredVariables: [],
        ),
        'Nudge': PromptBlock(
          name: 'Nudge',
          template: "Pick one probe for today; we will only observe and note.",
          requiredVariables: [],
        ),
        'Log': PromptBlock(
          name: 'Log',
          template: "Capture signal without judgment.",
          requiredVariables: [],
        ),
      },
    );
  }

  /// R-T (Recovery ↔ Transition) family
  static PhaseFamily _createRTFamily() {
    return PhaseFamily(
      system: "You are LUMARA in Restore mode. Prioritize body-first restoration.",
      style: "Compassionate, grounding, restorative.",
      blocks: {
        'Mirror': PromptBlock(
          name: 'Mirror',
          template: "Your system needs replenishment.",
          requiredVariables: [],
        ),
        'Safeguard': PromptBlock(
          name: 'Safeguard',
          template: "Choose one restorative action in 10 minutes or less.",
          requiredVariables: [],
        ),
        'Nudge': PromptBlock(
          name: 'Nudge',
          template: "Afterward, take a 5-minute look at a low-friction next step.",
          requiredVariables: [],
        ),
        'Commit': PromptBlock(
          name: 'Commit',
          template: "Set a check-in later today.",
          requiredVariables: [],
        ),
        'Log': PromptBlock(
          name: 'Log',
          template: "Mood, energy, ease(1-5).",
          requiredVariables: [],
        ),
      },
    );
  }

  /// C-R (Consolidation ↔ Recovery) family
  static PhaseFamily _createCRFamily() {
    return PhaseFamily(
      system: "You are LUMARA in Consolidate mode. Lock gains and document playbooks.",
      style: "Methodical, reflective, systematic.",
      blocks: {
        'Mirror': PromptBlock(
          name: 'Mirror',
          template: "These practices are yielding steady results.",
          requiredVariables: [],
        ),
        'Orient': PromptBlock(
          name: 'Orient',
          template: "Let us document the weekly loop for {area}.",
          requiredVariables: ['area'],
        ),
        'Nudge': PromptBlock(
          name: 'Nudge',
          template: "Pick one practice to templatize today.",
          requiredVariables: [],
        ),
        'Commit': PromptBlock(
          name: 'Commit',
          template: "Create a recurring checkpoint.",
          requiredVariables: [],
        ),
        'Log': PromptBlock(
          name: 'Log',
          template: "Variance, exceptions, rollback plan.",
          requiredVariables: [],
        ),
      },
    );
  }

  /// Get the registry as JSON string
  static String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(getDefault().toJson());
  }

  /// Load registry from JSON string
  static PromptRegistry fromJsonString(String jsonString) {
    final json = const JsonDecoder().convert(jsonString) as Map<String, dynamic>;
    return PromptRegistry.fromJson(json);
  }
}

/// Prompt renderer for generating final LLM prompts
class VeilEdgePromptRenderer {
  final PromptRegistry _registry;

  VeilEdgePromptRenderer({PromptRegistry? registry}) 
      : _registry = registry ?? VeilEdgePromptRegistry.getDefault();

  /// Render a complete prompt for a phase group
  String renderPrompt({
    required String phaseGroup,
    required String variant,
    required List<String> blocks,
    required Map<String, String> variables,
  }) {
    final family = _registry.getFamily(phaseGroup);
    if (family == null) {
      throw ArgumentError('Unknown phase group: $phaseGroup');
    }

    final buffer = StringBuffer();
    
    // Add system prompt
    buffer.writeln(family.system);
    buffer.writeln();
    
    // Add style guidance
    buffer.writeln('Style: ${family.style}');
    buffer.writeln();

    // Add blocks
    for (final blockName in blocks) {
      final block = family.blocks[blockName];
      if (block != null) {
        final renderedBlock = block.render(variables);
        buffer.writeln('[$blockName] $renderedBlock');
        buffer.writeln();
      }
    }

    // Add variant-specific instructions
    if (variant == ':safe') {
      buffer.writeln('Note: This is a safe mode session. Keep all suggestions gentle and reversible.');
    } else if (variant == ':alert') {
      buffer.writeln('Note: This is an alert mode session. Focus on immediate safety and grounding.');
    }

    return buffer.toString().trim();
  }

  /// Extract variables from user signals for prompt rendering
  Map<String, String> extractVariables(UserSignals signals) {
    return {
      'themes': signals.words.take(3).join(', '),
      'domains': signals.actions.take(2).join(', '),
      'area': signals.outcomes.isNotEmpty ? signals.outcomes.first : 'current focus',
      'A': _generateOption(signals, 1),
      'B': _generateOption(signals, 2),
      'start': _formatTime(DateTime.now()),
      'stop': _formatTime(DateTime.now().add(const Duration(minutes: 20))),
      'checkpoint': _formatTime(DateTime.now().add(const Duration(minutes: 10))),
    };
  }

  /// Generate an option based on signals
  String _generateOption(UserSignals signals, int optionNumber) {
    if (signals.actions.isNotEmpty) {
      return signals.actions[optionNumber % signals.actions.length];
    } else if (signals.words.isNotEmpty) {
      return signals.words[optionNumber % signals.words.length];
    }
    return 'option $optionNumber';
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
