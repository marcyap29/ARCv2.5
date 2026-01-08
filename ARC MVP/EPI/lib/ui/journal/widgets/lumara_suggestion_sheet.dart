import 'package:flutter/material.dart';

/// LUMARA intent types for different reflection styles
/// Maps to v2.3 ConversationMode
enum LumaraIntent { 
  ideas,      // Maps to ConversationMode.ideas
  think,      // Maps to ConversationMode.think
  perspective, // Maps to ConversationMode.perspective
  next,       // Maps to ConversationMode.nextSteps
  analyze,    // Maps to ConversationMode.reflectDeeply (More Depth)
}

typedef OnIntent = void Function(LumaraIntent intent);

/// Bottom sheet with LUMARA reflection suggestions
class LumaraSuggestionSheet extends StatelessWidget {
  final OnIntent onSelect;

  const LumaraSuggestionSheet({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = <_SuggestionItem>[
      _SuggestionItem(
        'Suggest some ideas',
        LumaraIntent.ideas,
        Icons.lightbulb_outline,
      ),
      _SuggestionItem(
        'Help me think this through',
        LumaraIntent.think,
        Icons.psychology,
      ),
      _SuggestionItem(
        'Offer a different perspective',
        LumaraIntent.perspective,
        Icons.visibility,
      ),
      _SuggestionItem(
        'Suggest next steps',
        LumaraIntent.next,
        Icons.navigate_next,
      ),
      // Note: "Reflect more deeply" has been moved to default action buttons
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reflect with LUMARA',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Suggestion items
            ...items.map((item) => _SuggestionTile(
              item: item,
              onTap: () {
                Navigator.of(context).maybePop();
                onSelect(item.intent);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Individual suggestion tile
class _SuggestionTile extends StatelessWidget {
  final _SuggestionItem item;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      ),
      title: Text(
        item.title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

/// Suggestion item data
class _SuggestionItem {
  final String title;
  final LumaraIntent intent;
  final IconData icon;

  _SuggestionItem(this.title, this.intent, this.icon);
}
