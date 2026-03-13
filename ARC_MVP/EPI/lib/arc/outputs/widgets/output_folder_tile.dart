// lib/arc/outputs/widgets/output_folder_tile.dart
//
// Phase 5a: Expandable folder row; when expanded shows item cards.
// Supports multi-select (timeline pattern) and swipe-left-to-delete via Dismissible.

import 'package:flutter/material.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/widgets/output_item_card.dart';
import 'package:my_app/shared/app_colors.dart';

class OutputFolderTile extends StatefulWidget {
  final OutputFolder folder;
  final List<OutputItem> items;
  final bool sortByTitle;
  final bool selectionModeEnabled;
  final Set<String> selectedItemIds;
  final void Function(OutputItem) onToggleSelect;
  final void Function(OutputItem) onItemTap;
  final void Function(OutputItem item, List<String> userTags)? onItemTagsChanged;
  final void Function(OutputItem)? onItemDelete;

  const OutputFolderTile({
    super.key,
    required this.folder,
    required this.items,
    required this.sortByTitle,
    required this.selectionModeEnabled,
    required this.selectedItemIds,
    required this.onToggleSelect,
    required this.onItemTap,
    this.onItemTagsChanged,
    this.onItemDelete,
  });

  @override
  State<OutputFolderTile> createState() => _OutputFolderTileState();
}

class _OutputFolderTileState extends State<OutputFolderTile> {
  bool _expanded = false;

  List<OutputItem> get _sortedItems {
    final list = List<OutputItem>.from(widget.items);
    if (widget.sortByTitle) {
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  /// Wraps the card in Dismissible (swipe left to delete) and/or selection overlay (timeline pattern).
  Widget _buildItemWithSwipeAndSelection(OutputItem item) {
    final isSelectionMode = widget.selectionModeEnabled;
    final isSelected = widget.selectedItemIds.contains(item.id);
    final useSelectionTap = isSelectionMode;

    final card = OutputItemCard(
      item: item,
      onTap: useSelectionTap ? () => widget.onToggleSelect(item) : () => widget.onItemTap(item),
      onUserTagsChanged: widget.onItemTagsChanged != null
          ? (tags) => widget.onItemTagsChanged!(item, tags)
          : null,
      onDelete: widget.onItemDelete != null ? () => widget.onItemDelete!(item) : null,
    );

    Widget wrapped = card;
    if (!isSelectionMode && widget.onItemDelete != null) {
      wrapped = Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        confirmDismiss: (direction) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete output?'),
              content: const Text(
                'This output will be permanently deleted. This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          return confirmed == true;
        },
        onDismissed: (_) => widget.onItemDelete!(item),
        child: card,
      );
    }

    if (isSelectionMode) {
      wrapped = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onToggleSelect(item),
        child: Stack(
          children: [
            wrapped,
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? kcPrimaryColor : kcSurfaceColor,
                  border: Border.all(color: kcBorderColor),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.circle_outlined,
                  size: 24,
                  color: isSelected ? Colors.white : kcSecondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return wrapped;
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  color: kcSecondaryTextColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Icon(Icons.folder_outlined, color: kcPrimaryColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.folder.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  '${widget.items.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kcSecondaryTextColor,
                      ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 12, 16, 24),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, size: 40, color: kcSecondaryTextColor.withOpacity(0.5)),
                  const SizedBox(width: 12),
                  Text(
                    'Nothing here yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kcSecondaryTextColor.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _sortedItems.map((item) => _buildItemWithSwipeAndSelection(item)).toList(),
              ),
            ),
        ],
      ],
    );
  }
}
