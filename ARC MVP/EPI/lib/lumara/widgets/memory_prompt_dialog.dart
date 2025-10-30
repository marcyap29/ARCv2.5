// lib/lumara/widgets/memory_prompt_dialog.dart
// Dialog for prompting user about memory usage in ask_first/suggestive modes

import 'package:flutter/material.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/memory/memory_mode_service.dart';

/// Response from memory prompt dialog
class MemoryPromptResponse {
  final bool useMemories;
  final bool rememberChoice; // For "Don't ask again"

  const MemoryPromptResponse({
    required this.useMemories,
    this.rememberChoice = false,
  });
}

/// Dialog shown when memory mode requires user confirmation
class MemoryPromptDialog extends StatefulWidget {
  /// Prompt text from MemoryModeService
  final String promptText;

  /// Memory mode that triggered this prompt
  final MemoryMode mode;

  /// Number of memories available
  final int memoryCount;

  /// Memory domain (if available)
  final MemoryDomain? domain;

  /// Preview text for suggestive mode (first 3 memory previews)
  final String? previewText;

  /// Whether to show "Don't ask again" option
  final bool showRememberChoice;

  const MemoryPromptDialog({
    super.key,
    required this.promptText,
    required this.mode,
    required this.memoryCount,
    this.domain,
    this.previewText,
    this.showRememberChoice = true,
  });

  @override
  State<MemoryPromptDialog> createState() => _MemoryPromptDialogState();

  /// Show dialog and return user's choice
  static Future<MemoryPromptResponse?> show({
    required BuildContext context,
    required String promptText,
    required MemoryMode mode,
    required int memoryCount,
    MemoryDomain? domain,
    String? previewText,
    bool showRememberChoice = true,
  }) {
    return showDialog<MemoryPromptResponse>(
      context: context,
      barrierDismissible: false, // Must choose
      builder: (context) => MemoryPromptDialog(
        promptText: promptText,
        mode: mode,
        memoryCount: memoryCount,
        domain: domain,
        previewText: previewText,
        showRememberChoice: showRememberChoice,
      ),
    );
  }
}

class _MemoryPromptDialogState extends State<MemoryPromptDialog> {
  bool _rememberChoice = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      icon: Icon(
        _getIconForMode(widget.mode),
        size: 32,
        color: theme.colorScheme.primary,
      ),
      title: Text(_getTitleForMode(widget.mode)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main prompt text
            Text(
              widget.promptText,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),

            // Memory count chip
            Chip(
              avatar: const Icon(Icons.lightbulb_outline, size: 18),
              label: Text(
                '${widget.memoryCount} ${widget.memoryCount == 1 ? 'memory' : 'memories'} found',
              ),
              backgroundColor: theme.colorScheme.primaryContainer,
            ),

            // Domain chip (if available)
            if (widget.domain != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(_getDomainIcon(widget.domain!), size: 18),
                label: Text(_getDomainDisplayName(widget.domain!)),
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ],

            // Preview for suggestive mode
            if (widget.mode == MemoryMode.suggestive &&
                widget.previewText != null &&
                widget.previewText!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Preview:',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  widget.previewText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Remember choice option
            if (widget.showRememberChoice) ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _rememberChoice,
                onChanged: (value) {
                  setState(() {
                    _rememberChoice = value ?? false;
                  });
                },
                title: Text(
                  'Remember my choice for this ${widget.domain != null ? 'domain' : 'session'}',
                  style: theme.textTheme.bodySmall,
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],

            // Info about changing settings
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Change memory settings anytime in Settings',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Decline button
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              MemoryPromptResponse(
                useMemories: false,
                rememberChoice: _rememberChoice,
              ),
            );
          },
          child: Text(
            _getDeclineText(widget.mode),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),

        // Accept button
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              MemoryPromptResponse(
                useMemories: true,
                rememberChoice: _rememberChoice,
              ),
            );
          },
          icon: const Icon(Icons.check_circle_outline),
          label: Text(_getAcceptText(widget.mode)),
        ),
      ],
    );
  }

  /// Get icon for memory mode
  IconData _getIconForMode(MemoryMode mode) {
    switch (mode) {
      case MemoryMode.askFirst:
        return Icons.help_outline;
      case MemoryMode.suggestive:
        return Icons.lightbulb_outline;
      case MemoryMode.alwaysOn:
        return Icons.auto_awesome;
      case MemoryMode.highConfidenceOnly:
        return Icons.verified_outlined;
      case MemoryMode.soft:
        return Icons.blur_on;
      case MemoryMode.hard:
        return Icons.push_pin;
      case MemoryMode.disabled:
        return Icons.block;
    }
  }

  /// Get title for memory mode
  String _getTitleForMode(MemoryMode mode) {
    switch (mode) {
      case MemoryMode.askFirst:
        return 'Use Memories?';
      case MemoryMode.suggestive:
        return 'Memories Available';
      case MemoryMode.alwaysOn:
        return 'Using Memories';
      case MemoryMode.highConfidenceOnly:
        return 'High Confidence Memories';
      case MemoryMode.soft:
        return 'Memory Context';
      case MemoryMode.hard:
        return 'Authoritative Memories';
      case MemoryMode.disabled:
        return 'Memories Disabled';
    }
  }

  /// Get accept button text
  String _getAcceptText(MemoryMode mode) {
    switch (mode) {
      case MemoryMode.askFirst:
        return 'Yes, Use Memories';
      case MemoryMode.suggestive:
        return 'Apply These Memories';
      default:
        return 'Use Memories';
    }
  }

  /// Get decline button text
  String _getDeclineText(MemoryMode mode) {
    switch (mode) {
      case MemoryMode.askFirst:
        return 'No Thanks';
      case MemoryMode.suggestive:
        return 'Skip for Now';
      default:
        return 'Decline';
    }
  }

  /// Get icon for memory domain
  IconData _getDomainIcon(MemoryDomain domain) {
    switch (domain) {
      case MemoryDomain.personal:
        return Icons.person_outline;
      case MemoryDomain.work:
        return Icons.work_outline;
      case MemoryDomain.health:
        return Icons.favorite_outline;
      case MemoryDomain.creative:
        return Icons.palette_outlined;
      case MemoryDomain.relationships:
        return Icons.people_outline;
      case MemoryDomain.finance:
        return Icons.account_balance_wallet_outlined;
      case MemoryDomain.learning:
        return Icons.school_outlined;
      case MemoryDomain.spiritual:
        return Icons.self_improvement;
      case MemoryDomain.meta:
        return Icons.settings_outlined;
    }
  }

  /// Get display name for domain
  String _getDomainDisplayName(MemoryDomain domain) {
    switch (domain) {
      case MemoryDomain.personal:
        return 'Personal';
      case MemoryDomain.work:
        return 'Work';
      case MemoryDomain.health:
        return 'Health';
      case MemoryDomain.creative:
        return 'Creative';
      case MemoryDomain.relationships:
        return 'Relationships';
      case MemoryDomain.finance:
        return 'Finance';
      case MemoryDomain.learning:
        return 'Learning';
      case MemoryDomain.spiritual:
        return 'Spiritual';
      case MemoryDomain.meta:
        return 'Meta';
    }
  }
}