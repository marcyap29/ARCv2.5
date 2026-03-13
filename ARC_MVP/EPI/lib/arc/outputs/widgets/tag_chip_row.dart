// lib/arc/outputs/widgets/tag_chip_row.dart
//
// Phase 5a: Inline tag display; user tags editable (tap opens editor).

import 'package:flutter/material.dart';
import 'package:my_app/arc/outputs/output_tagging.dart';
import 'package:my_app/shared/app_colors.dart';

class TagChipRow extends StatelessWidget {
  final List<String> autoTags;
  final List<String> userTags;
  final bool editable;
  final ValueChanged<List<String>>? onUserTagsChanged;

  const TagChipRow({
    super.key,
    required this.autoTags,
    required this.userTags,
    this.editable = false,
    this.onUserTagsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in autoTags) _Chip(label: t, isUser: false),
        for (final t in userTags)
          editable && onUserTagsChanged != null
              ? _EditableChip(
                  label: t,
                  onRemove: () {
                    final next = List<String>.from(userTags)..remove(t);
                    onUserTagsChanged!(next);
                  },
                )
              : _Chip(label: t, isUser: true),
        if (editable && onUserTagsChanged != null)
          _AddTagChip(
            onAdd: (tag) {
              final normalised = normaliseUserTag(tag);
              if (normalised.isEmpty) return;
              if (userTags.length >= maxUserTagsPerItem) return;
              if (userTags.contains(normalised)) return;
              onUserTagsChanged!(List.from(userTags)..add(normalised));
            },
            canAdd: userTags.length < maxUserTagsPerItem,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isUser;

  const _Chip({required this.label, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUser
            ? kcPrimaryColor.withOpacity(0.2)
            : kcSecondaryTextColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isUser ? kcPrimaryColor : kcSecondaryTextColor,
            ),
      ),
    );
  }
}

class _EditableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _EditableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: kcPrimaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: kcPrimaryColor),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: kcPrimaryColor),
          ],
        ),
      ),
    );
  }
}

class _AddTagChip extends StatefulWidget {
  final void Function(String) onAdd;
  final bool canAdd;

  const _AddTagChip({required this.onAdd, required this.canAdd});

  @override
  State<_AddTagChip> createState() => _AddTagChipState();
}

class _AddTagChipState extends State<_AddTagChip> {
  bool _expanded = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canAdd) return const SizedBox.shrink();
    if (_expanded) {
      return SizedBox(
        width: 120,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: kcPrimaryTextColor),
          decoration: InputDecoration(
            hintText: 'Tag',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            widget.onAdd(v);
            _controller.clear();
            setState(() => _expanded = false);
          },
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: kcPrimaryColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: kcPrimaryColor),
            const SizedBox(width: 4),
            Text(
              'Add tag',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: kcPrimaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
