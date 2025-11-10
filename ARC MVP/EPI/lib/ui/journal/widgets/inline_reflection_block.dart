import 'package:flutter/material.dart';

/// Inline reflection block that appears within journal entries
class InlineReflectionBlock extends StatelessWidget {
  final String content;
  final String intent; // ideas | think | perspective | next | analyze
  final String? phase; // e.g., "Recovery"
  final bool isLoading; // Whether LUMARA is currently generating insights
  final String? loadingMessage; // Optional loading message
  final VoidCallback onRegenerate;
  final VoidCallback onSoften;
  final VoidCallback onMoreDepth;
  final VoidCallback onContinueWithLumara;
  final VoidCallback onDelete;

  const InlineReflectionBlock({
    super.key,
    required this.content,
    required this.intent,
    this.phase,
    this.isLoading = false,
    this.loadingMessage,
    required this.onRegenerate,
    required this.onSoften,
    required this.onMoreDepth,
    required this.onContinueWithLumara,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final borderColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(width: 3, color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with LUMARA icon and phase
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'LUMARA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (phase != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      phase!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Reflection content or loading indicator with progress meter
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loadingMessage ?? 'LUMARA is thinking...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress meter
                    LinearProgressIndicator(
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              )
            else ...[
              // Reflection content (different color to distinguish from user text)
              // Split content into paragraphs for better readability
              ..._buildParagraphs(content, theme),
              const SizedBox(height: 12),
              // Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _ActionButton(
                    label: 'Regenerate',
                    icon: Icons.refresh,
                    onPressed: isLoading ? () {} : onRegenerate,
                  ),
                  _ActionButton(
                    label: 'Soften tone',
                    icon: Icons.favorite_outline,
                    onPressed: isLoading ? () {} : onSoften,
                  ),
                  _ActionButton(
                    label: 'More depth',
                    icon: Icons.insights,
                    onPressed: isLoading ? () {} : onMoreDepth,
                  ),
                  _ActionButton(
                    label: 'Continue with LUMARA',
                    icon: Icons.chat,
                    onPressed: isLoading ? () {} : onContinueWithLumara,
                    isPrimary: true,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build paragraphs from content text
  List<Widget> _buildParagraphs(String content, ThemeData theme) {
    if (content.trim().isEmpty) {
      return [const SizedBox.shrink()];
    }

    // Split by double newlines first (explicit paragraphs)
    List<String> paragraphs = content.split('\n\n');
    
    // If no double newlines, try splitting by single newlines
    if (paragraphs.length == 1) {
      paragraphs = content.split('\n');
    }
    
    // If still single paragraph, try splitting by sentence endings followed by space
    if (paragraphs.length == 1) {
      // Split by periods/exclamation/question marks followed by space and capital letter
      final sentencePattern = RegExp(r'([.!?])\s+([A-Z])');
      final matches = sentencePattern.allMatches(content);
      
      if (matches.length > 1) {
        paragraphs = [];
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            paragraphs.add(content.substring(lastIndex, match.start + 1).trim());
            lastIndex = match.start + 1;
          }
        }
        if (lastIndex < content.length) {
          paragraphs.add(content.substring(lastIndex).trim());
        }
      }
    }

    // Filter out empty paragraphs and build widgets
    final widgets = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: i < paragraphs.length - 1 ? 12 : 0),
            child: Text(
              paragraph,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: theme.colorScheme.secondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }
    }

    return widgets.isEmpty ? [
      Text(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.4,
          color: theme.colorScheme.secondary,
          fontStyle: FontStyle.italic,
        ),
      )
    ] : widgets;
  }
}

/// Action button for inline reflection block
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: isPrimary 
            ? theme.colorScheme.primary 
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isPrimary 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(44, 32), // Accessibility minimum
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
