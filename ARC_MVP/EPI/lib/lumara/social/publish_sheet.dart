// lib/lumara/social/publish_sheet.dart
// Phase 7: Modal to select platforms and schedule before publishing.

import 'package:flutter/material.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/lumara/social/late_profile_service.dart';

const int _previewLength = 100;
const int _blueskyLimit = 300;
const int _threadsLimit = 500;

String _platformLabel(String key) {
  switch (key) {
    case 'linkedin':
      return 'LinkedIn';
    case 'bluesky':
      return 'Bluesky';
    case 'threads':
      return 'Threads';
    case 'twitter':
      return 'Twitter/X';
    case 'instagram':
      return 'Instagram';
    case 'facebook':
      return 'Facebook';
    case 'tiktok':
      return 'TikTok';
    case 'reddit':
      return 'Reddit';
    default:
      return key.isNotEmpty ? '${key[0].toUpperCase()}${key.substring(1)}' : key;
  }
}

/// Result passed to onPublish: selected accounts and optional scheduled time.
class PublishSheetResult {
  const PublishSheetResult({
    required this.accounts,
    this.scheduledFor,
  });
  final List<SocialAccount> accounts;
  final DateTime? scheduledFor;
}

/// Modal bottom sheet: draft preview, platform checkboxes, schedule toggle, Publish/Cancel.
class PublishSheet extends StatefulWidget {
  const PublishSheet({
    super.key,
    required this.draftBody,
    required this.format,
    required this.accounts,
    required this.onPublish,
  });

  final String draftBody;
  final WritingFormat format;
  final List<SocialAccount> accounts;
  final void Function(PublishSheetResult result) onPublish;

  @override
  State<PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<PublishSheet> {
  final Set<String> _selectedIds = {};
  bool _scheduleLater = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    // Select none by default; user must select at least one.
  }

  int? get _charLimit {
    switch (widget.format) {
      case WritingFormat.bluesky:
        return _blueskyLimit;
      case WritingFormat.threads:
        return _threadsLimit;
      default:
        return null;
    }
  }

  bool get _overLimit {
    final limit = _charLimit;
    if (limit == null) return false;
    return widget.draftBody.length > limit;
  }

  String? get _limitWarning {
    final limit = _charLimit;
    if (limit == null || !_overLimit) return null;
    final platform = widget.format == WritingFormat.bluesky ? 'Bluesky' : 'Threads';
    return 'This post exceeds $platform\'s character limit ($limit). It may be truncated.';
  }

  void _toggleAccount(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _scheduledDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (time != null && mounted) setState(() => _scheduledTime = time);
  }

  DateTime? get _scheduledForUtc {
    if (!_scheduleLater) return null;
    final local = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );
    return local.toUtc();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.draftBody.length > _previewLength
        ? '${widget.draftBody.substring(0, _previewLength)}…'
        : widget.draftBody;
    final selectedAccounts = widget.accounts.where((a) => _selectedIds.contains(a.id)).toList();
    final canPublish = selectedAccounts.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Publish',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preview',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                preview.isEmpty ? '(empty)' : preview,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_limitWarning != null) ...[
              const SizedBox(height: 8),
              Text(
                _limitWarning!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Platforms',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            ...widget.accounts.map((a) => CheckboxListTile(
                  value: _selectedIds.contains(a.id),
                  onChanged: (_) => _toggleAccount(a.id),
                  title: Text(_platformLabel(a.platform)),
                  subtitle: Text(a.username.isNotEmpty ? a.username : a.id),
                  controlAffinity: ListTileControlAffinity.leading,
                )),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _scheduleLater,
                  onChanged: (v) => setState(() => _scheduleLater = v ?? false),
                ),
                const SizedBox(width: 8),
                const Text('Schedule for later'),
              ],
            ),
            if (_scheduleLater) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(
                      '${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(_scheduledTime.format(context)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canPublish
                      ? () {
                          final scheduled = _scheduledForUtc;
                          widget.onPublish(PublishSheetResult(
                            accounts: selectedAccounts,
                            scheduledFor: scheduled,
                          ));
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Publish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
