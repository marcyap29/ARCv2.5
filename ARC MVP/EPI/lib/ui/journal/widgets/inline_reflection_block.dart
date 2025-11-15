import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/polymeta/memory/enhanced_memory_schema.dart';
import 'package:my_app/arc/chat/widgets/attribution_display_widget.dart';

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
  final List<AttributionTrace>? attributionTraces; // Memory attribution traces

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
    this.attributionTraces,
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
          mainAxisSize: MainAxisSize.min,
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
              ],
            ),
            const SizedBox(height: 8),
            // Reflection content or loading indicator with progress meter
            // Unified with in-chat LUMARA loading indicator UI/UX
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                            'LUMARA is thinking...',
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
              
              // Attribution display (if available)
              if (attributionTraces != null && attributionTraces!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    print('InlineReflectionBlock: Rendering AttributionDisplayWidget with ${attributionTraces!.length} traces');
                    return AttributionDisplayWidget(
                      traces: attributionTraces!,
                      responseId: 'journal_${DateTime.now().millisecondsSinceEpoch}',
                    );
                  },
                ),
              ] else if (attributionTraces != null) ...[
                // Debug: Show why attributions aren't showing
                Builder(
                  builder: (context) {
                    print('InlineReflectionBlock: Attribution traces is null or empty (null: ${attributionTraces == null}, empty: ${attributionTraces?.isEmpty ?? true})');
                    return const SizedBox.shrink();
                  },
                ),
              ],
              
              // Copy and delete buttons (lower left - unified with in-chat UX)
              if (!isLoading && content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('LUMARA response copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
              
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

  /// Build paragraphs from content text with improved mobile readability
  List<Widget> _buildParagraphs(String content, ThemeData theme) {
    if (content.trim().isEmpty) {
      return [const SizedBox.shrink()];
    }

    // Split by double newlines first (explicit paragraphs)
    List<String> paragraphs = content.split('\n\n');
    
    // Clean up paragraphs - remove single newlines within paragraphs
    paragraphs = paragraphs.map((p) => p.replaceAll('\n', ' ').trim()).toList();
    
    // If no double newlines, try splitting by single newlines
    if (paragraphs.length == 1 && content.contains('\n')) {
      paragraphs = content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    
    // If still single paragraph, try splitting by sentence endings for better readability
    if (paragraphs.length == 1) {
      // Split by periods/exclamation/question marks followed by space and capital letter
      // This creates natural paragraph breaks for long responses
      final sentencePattern = RegExp(r'([.!?])\s+([A-Z])');
      final matches = sentencePattern.allMatches(content);
      
      if (matches.length >= 2) {
        paragraphs = [];
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            final sentence = content.substring(lastIndex, match.start + 1).trim();
            if (sentence.isNotEmpty) {
              paragraphs.add(sentence);
            }
            lastIndex = match.start + 1;
          }
        }
        if (lastIndex < content.length) {
          final remaining = content.substring(lastIndex).trim();
          if (remaining.isNotEmpty) {
            paragraphs.add(remaining);
          }
        }
      }
    }

    // Filter out empty paragraphs and build widgets with improved spacing
    final widgets = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: i < paragraphs.length - 1 ? 16 : 0),
            child: SelectableText(
              paragraph,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6, // Increased line height for better mobile readability
                fontSize: 15, // Slightly larger font for mobile
                color: theme.colorScheme.secondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }
    }

    return widgets.isEmpty ? [
      SelectableText(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          fontSize: 15,
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
