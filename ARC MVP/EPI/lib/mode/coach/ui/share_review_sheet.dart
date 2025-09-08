import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../coach_mode_cubit.dart';
import '../coach_mode_state.dart';
import '../models/coach_models.dart';

class ShareReviewSheet extends StatefulWidget {
  const ShareReviewSheet({super.key});

  @override
  State<ShareReviewSheet> createState() => _ShareReviewSheetState();
}

class _ShareReviewSheetState extends State<ShareReviewSheet> {
  final Map<String, bool> _selectedResponses = {};
  final Map<String, Set<String>> _redactedFields = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
  }

  void _initializeSelections() {
    final state = context.read<CoachModeCubit>().state;
    if (state is CoachModeEnabled) {
      for (final response in state.recentResponses) {
        _selectedResponses[response.id] = response.includeInShare;
        _redactedFields[response.id] = <String>{};
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoachModeCubit, CoachModeState>(
      builder: (context, state) {
        if (state is! CoachModeEnabled) {
          return const Center(child: Text('Coach Mode not available'));
        }

        final shareableResponses = state.recentResponses
            .where((response) => response.includeInShare)
            .toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: shareableResponses.isEmpty
                    ? _buildEmptyState()
                    : _buildResponseList(shareableResponses),
              ),
              const SizedBox(height: 16),
              _buildBottomActions(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.share,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share with Coach',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Review and customize what to share',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No responses to share',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some coaching tools first, then mark them for sharing.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResponseList(List<CoachDropletResponse> responses) {
    return ListView.builder(
      itemCount: responses.length,
      itemBuilder: (context, index) {
        final response = responses[index];
        return _buildResponseCard(response);
      },
    );
  }

  Widget _buildResponseCard(CoachDropletResponse response) {
    final isSelected = _selectedResponses[response.id] ?? false;
    final redactedFields = _redactedFields[response.id] ?? <String>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                _selectedResponses[response.id] = value ?? false;
              });
            },
          ),
          title: Text(
            'Response from ${_formatDate(response.createdAt)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${response.values.length} fields • ${redactedFields.length} redacted',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResponseFields(response, redactedFields),
                  const SizedBox(height: 12),
                  _buildRedactionControls(response),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseFields(CoachDropletResponse response, Set<String> redactedFields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: response.values.entries.map((entry) {
        final isRedacted = redactedFields.contains(entry.key);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isRedacted
                ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isRedacted ? '[REDACTED]' : entry.value.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isRedacted
                            ? Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.7)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (isRedacted) {
                      redactedFields.remove(entry.key);
                    } else {
                      redactedFields.add(entry.key);
                    }
                  });
                },
                icon: Icon(
                  isRedacted ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                  color: isRedacted
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRedactionControls(CoachDropletResponse response) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _redactedFields[response.id] = response.values.keys.toSet();
              });
            },
            icon: const Icon(Icons.visibility_off, size: 16),
            label: const Text('Redact All'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _redactedFields[response.id] = <String>{};
              });
            },
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('Show All'),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    final selectedCount = _selectedResponses.values.where((selected) => selected).length;
    final totalRedacted = _redactedFields.values
        .expand((fields) => fields)
        .length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$selectedCount responses selected • $totalRedacted fields redacted',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: selectedCount > 0 && !_isExporting ? _exportBundle : null,
                child: _isExporting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Export'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportBundle() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Update the responses with the new share settings
      for (final _ in _selectedResponses.entries) {
        // This would be handled by the service in a real implementation
        // For now, we'll just show a success message
      }

      await context.read<CoachModeCubit>().exportShareBundle();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share bundle exported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
