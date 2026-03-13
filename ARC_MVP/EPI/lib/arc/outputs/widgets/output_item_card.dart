// lib/arc/outputs/widgets/output_item_card.dart
//
// Phase 5a: Single output item card (title, date, tags; long-press menu).
// For scans: shows a leading thumbnail when thumbnailUrl is a local path.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/widgets/tag_chip_row.dart';
import 'package:my_app/shared/app_colors.dart';

class OutputItemCard extends StatelessWidget {
  final OutputItem item;
  final VoidCallback onTap;
  final void Function(List<String> userTags)? onUserTagsChanged;
  final VoidCallback? onDelete;

  const OutputItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onUserTagsChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().format(item.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.thumbnailUrl != null &&
                      item.thumbnailUrl!.isNotEmpty &&
                      item.thumbnailUrl!.contains('/')) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(item.thumbnailUrl!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(
                            Icons.photo_outlined,
                            color: kcSecondaryTextColor.withOpacity(0.5),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: kcPrimaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kcSecondaryTextColor.withOpacity(0.8),
                    ),
              ),
              if (item.autoTags.isNotEmpty || item.userTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                TagChipRow(
                  autoTags: item.autoTags,
                  userTags: item.userTags,
                  editable: onUserTagsChanged != null,
                  onUserTagsChanged: onUserTagsChanged,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View'),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            ),
            if (onUserTagsChanged != null)
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('Edit tags'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTagEditor(context);
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete output?'),
                      content: Text('Delete "${item.title}"? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showTagEditor(BuildContext context) {
    // Full-screen tag editor: existing as removable chips + add new
    showDialog<void>(
      context: context,
      builder: (ctx) => _TagEditorDialog(
        initialUserTags: List.from(item.userTags),
        onSave: (tags) {
          onUserTagsChanged!(tags);
          Navigator.pop(ctx);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }
}

class _TagEditorDialog extends StatefulWidget {
  final List<String> initialUserTags;
  final void Function(List<String>) onSave;
  final VoidCallback onCancel;

  const _TagEditorDialog({
    required this.initialUserTags,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late List<String> _tags;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.initialUserTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag() {
    final v = _controller.text.trim();
    _controller.clear();
    if (v.isEmpty) return;
    final n = v.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    if (n.length > 30) return;
    if (_tags.length >= 20) return;
    if (_tags.contains(n)) return;
    setState(() => _tags.add(n));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit tags'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TagChipRow(
              autoTags: const [],
              userTags: _tags,
              editable: true,
              onUserTagsChanged: (t) => setState(() => _tags = t),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'New tag (lowercase, no spaces)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addTag(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        FilledButton(
          onPressed: () => widget.onSave(_tags),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
