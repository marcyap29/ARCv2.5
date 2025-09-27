import 'package:flutter/material.dart';

/// Inline reflection block that appears within journal entries
class InlineReflectionBlock extends StatelessWidget {
  final String content;
  final String intent; // ideas | think | perspective | next | analyze
  final String? phase; // e.g., "Recovery"
  final VoidCallback onRegenerate;
  final VoidCallback onSoften;
  final VoidCallback onMoreDepth;
  final VoidCallback onContinueWithLumara;

  const InlineReflectionBlock({
    super.key,
    required this.content,
    required this.intent,
    this.phase,
    required this.onRegenerate,
    required this.onSoften,
    required this.onMoreDepth,
    required this.onContinueWithLumara,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceVariant.withOpacity(0.3);
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
              ],
            ),
            const SizedBox(height: 8),
            // Reflection content
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _ActionButton(
                  label: 'Regenerate',
                  icon: Icons.refresh,
                  onPressed: onRegenerate,
                ),
                _ActionButton(
                  label: 'Soften tone',
                  icon: Icons.favorite_outline,
                  onPressed: onSoften,
                ),
                _ActionButton(
                  label: 'More depth',
                  icon: Icons.insights,
                  onPressed: onMoreDepth,
                ),
                _ActionButton(
                  label: 'Continue with LUMARA',
                  icon: Icons.chat,
                  onPressed: onContinueWithLumara,
                  isPrimary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
