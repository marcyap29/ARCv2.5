// lib/ui/phase/phase_timeline_view.dart
// Phase timeline with colored bands and edit controls

import 'package:flutter/material.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'arcform_timeline_view.dart';

class PhaseTimelineView extends StatefulWidget {
  final PhaseIndex phaseIndex;
  final Function(PhaseRegime)? onRegimeTap;
  final Function(PhaseRegime, String)? onRegimeAction;

  const PhaseTimelineView({
    super.key,
    required this.phaseIndex,
    this.onRegimeTap,
    this.onRegimeAction,
  });

  @override
  State<PhaseTimelineView> createState() => _PhaseTimelineViewState();
}

class _PhaseTimelineViewState extends State<PhaseTimelineView> {
  DateTime _visibleStart = DateTime.now().subtract(const Duration(days: 365));
  DateTime _visibleEnd = DateTime.now().add(const Duration(days: 30));
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    // Adjust visible range based on actual regime dates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustVisibleRange();
    });
  }

  @override
  void didUpdateWidget(PhaseTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If phaseIndex changed (check by comparing regime counts or IDs), recalculate visible range
    final oldRegimes = oldWidget.phaseIndex.allRegimes;
    final newRegimes = widget.phaseIndex.allRegimes;
    
    // Check if regimes changed by comparing counts or first regime ID
    final regimesChanged = oldRegimes.length != newRegimes.length ||
        (oldRegimes.isNotEmpty && newRegimes.isNotEmpty && 
         oldRegimes.first.id != newRegimes.first.id);
    
    if (regimesChanged) {
      print('DEBUG: PhaseTimelineView - Regimes changed, recalculating visible range');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _adjustVisibleRange();
        }
      });
    }
  }

  void _adjustVisibleRange() {
    final regimes = widget.phaseIndex.allRegimes;
    if (regimes.isEmpty) {
      // Reset to default range if no regimes
      setState(() {
        _visibleStart = DateTime.now().subtract(const Duration(days: 365));
        _visibleEnd = DateTime.now().add(const Duration(days: 30));
      });
      return;
    }

    // Find the earliest and latest regime dates
    DateTime? earliestStart;
    DateTime? latestEnd;

    for (final regime in regimes) {
      if (earliestStart == null || regime.start.isBefore(earliestStart)) {
        earliestStart = regime.start;
      }
      final regimeEnd = regime.end ?? DateTime.now();
      if (latestEnd == null || regimeEnd.isAfter(latestEnd)) {
        latestEnd = regimeEnd;
      }
    }

    if (earliestStart != null && latestEnd != null) {
      // Add padding before and after
      setState(() {
        _visibleStart = earliestStart!.subtract(const Duration(days: 30));
        _visibleEnd = latestEnd!.add(const Duration(days: 30));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
    final theme = Theme.of(context);
    final regimes = widget.phaseIndex.allRegimes;

      // Debug: Log regimes for troubleshooting
      print('DEBUG: PhaseTimelineView.build() - Total regimes: ${regimes.length}');
      print('DEBUG: PhaseTimelineView.build() - Visible range: $_visibleStart to $_visibleEnd');
      print('DEBUG: PhaseTimelineView.build() - PhaseIndex: ${widget.phaseIndex}');
      for (final regime in regimes) {
        print('DEBUG: Regime - ${_getPhaseLabelName(regime.label)}: ${regime.start} to ${regime.end ?? 'ongoing'}');
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ArcformTimelineView(
                phaseIndex: widget.phaseIndex,
              ),
            ),
            const SizedBox(height: 12),
            _buildCombinedTimelineCard(theme, regimes),
          ],
        ),
      );
    } catch (e, stackTrace) {
      print('ERROR: PhaseTimelineView.build() failed: $e');
      print('ERROR: Stack trace: $stackTrace');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading timeline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
        ),
      ],
          ),
        ),
    );
    }
  }

  Widget _buildCombinedTimelineCard(ThemeData theme, List<PhaseRegime> regimes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section (from Phase Timeline card)
            Row(
              children: [
                Icon(Icons.timeline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Phase Timeline',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineStats(theme),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Timeline Visualization section
            Row(
              children: [
                Icon(Icons.view_timeline, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Timeline Visualization',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Timeline visualization content
            if (regimes.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No phase regimes yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Run Phase Analysis to detect phases automatically',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _buildTimelineAxis(theme),
              const SizedBox(height: 8),
              Container(
                height: 60, // Reduced by 1/2 from 120 to 60
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: PhaseTimelinePainter(
                      regimes: regimes,
                      visibleStart: _visibleStart,
                      visibleEnd: _visibleEnd,
                      zoomLevel: _zoomLevel,
                      theme: theme,
                    ),
                    child: GestureDetector(
                      onTapDown: (details) => _handleTimelineTap(details, regimes),
                      child: Container(
                        width: double.infinity,
                        height: 60, // Reduced by 1/2 from 120 to 60
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildTimelineLabels(theme),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Phase Regimes List section
            Row(
              children: [
                Icon(Icons.list, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Phase Regimes (${regimes.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Change Phase and Add New Regime buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showPhaseChangeDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Change Phase'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddRegimeDialog,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add New Regime'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showApplyPhaseByDateRangeDialog,
                icon: const Icon(Icons.batch_prediction, size: 18),
                label: const Text('Apply phase by date range'),
              ),
            ),
            const SizedBox(height: 12),
            // Regime list
            ..._buildRegimeListItems(regimes, theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRegimeListItems(List<PhaseRegime> regimes, ThemeData theme) {
    if (regimes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 32, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'No phase regimes yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final sortedRegimes = List<PhaseRegime>.from(regimes)
      ..sort((a, b) => b.start.compareTo(a.start)); // Newest first

    final items = <Widget>[];
    for (final regime in sortedRegimes.take(10)) {
      items.add(_buildRegimeCard(regime, theme));
    }
    
    if (regimes.length > 10) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Center(
            child: Text(
              '+ ${regimes.length - 10} more regimes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }
    
    return items;
  }


  Widget _buildTimelineStats(ThemeData theme) {
    final stats = widget.phaseIndex.stats;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatItem('Total Phases', stats.totalRegimes.toString(), theme),
          const SizedBox(width: 16),
          _buildStatItem('User Set', stats.userRegimes.toString(), theme),
          const SizedBox(width: 16),
          _buildStatItem('RIVET', stats.rivetRegimes.toString(), theme),
          const SizedBox(width: 16),
          _buildStatItem('Duration', '${stats.totalDuration.inDays} days', theme),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }


  Widget _buildTimelineAxis(ThemeData theme) {
    return Row(
      children: [
        Text(
          _formatDate(_visibleStart),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4), // Reduced from 8 to 4
            color: theme.dividerColor,
          ),
        ),
        Text(
          'NOW',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4), // Reduced from 8 to 4
            color: theme.dividerColor,
          ),
        ),
        Text(
          _formatDate(_visibleEnd),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineLabels(ThemeData theme) {
    final now = DateTime.now();
    final totalDuration = _visibleEnd.difference(_visibleStart);
    final nowProgress = now.difference(_visibleStart).inMilliseconds / totalDuration.inMilliseconds;

    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          if (nowProgress >= 0 && nowProgress <= 1)
            Positioned(
              left: (MediaQuery.of(context).size.width - 64) * nowProgress * 0.75, // More conservative positioning
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Reduced padding
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'TODAY',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 9, // Reduced from 10 to 9
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildRegimeCard(PhaseRegime regime, ThemeData theme) {
    final color = _getPhaseColor(regime.label);
    final duration = regime.duration;
    final isOngoing = regime.isOngoing;

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        color: color.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOngoing ? Icons.play_circle_filled : Icons.check_circle,
              color: color,
              size: 20,
            ),
            if (regime.source == PhaseSource.user)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Text(
              _getPhaseLabelName(regime.label).toUpperCase(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (regime.confidence != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(regime.confidence!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(regime.confidence! * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          isOngoing
              ? '${_formatDate(regime.start)} - Ongoing (${duration.inDays}d)'
              : '${_formatDate(regime.start)} - ${_formatDate(regime.end!)} (${duration.inDays}d)',
          style: theme.textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, size: 20),
          onPressed: () => _showRegimeActions(regime),
        ),
        onTap: () => widget.onRegimeTap?.call(regime),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }


  void _handleTimelineTap(TapDownDetails details, List<PhaseRegime> regimes) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    
    // Calculate timestamp from position
    final timelineWidth = box.size.width;
    final progress = localPosition.dx / timelineWidth;
    final duration = _visibleEnd.difference(_visibleStart);
    final timestamp = _visibleStart.add(Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    ));
    
    // Find regime at this timestamp
    final regime = widget.phaseIndex.regimeFor(timestamp);
    if (regime != null) {
      widget.onRegimeTap?.call(regime);
      _showRegimeActions(regime);
    }
  }

  void _showRegimeActions(PhaseRegime regime) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Phase: ${_getPhaseLabelName(regime.label).toUpperCase()}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Edit Dates'),
              onTap: () {
                Navigator.pop(context);
                _showEditDatesDialog(regime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Relabel'),
              onTap: () {
                Navigator.pop(context);
                _showRelabelDialog(regime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cut),
              title: const Text('Split Here'),
              onTap: () {
                Navigator.pop(context);
                _showSplitDialog(regime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.merge),
              title: const Text('Merge with Next'),
              onTap: () {
                Navigator.pop(context);
                _mergeWithNext(regime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop),
              title: const Text('End Phase Here'),
              onTap: () {
                Navigator.pop(context);
                _endPhaseHere(regime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.batch_prediction),
              title: const Text('Apply this phase to all entries in this period'),
              onTap: () {
                Navigator.pop(context);
                _applyPhaseToAllEntriesInRegime(regime);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Phase', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(regime);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPhaseChangeDialog() {
    // Determine current phase for highlighting
    final currentLabel = widget.phaseIndex.currentRegime?.label;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Change Phase',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Your current phase will end today and the new one begins now.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ...PhaseLabel.values.map((label) {
                final isCurrent = label == currentLabel;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: isCurrent ? _getPhaseColor(label).withOpacity(0.12) : null,
                  leading: Icon(Icons.circle, color: _getPhaseColor(label), size: 16),
                  title: Text(
                    _getPhaseLabelName(label).toUpperCase(),
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isCurrent
                      ? const Chip(label: Text('Current', style: TextStyle(fontSize: 11)), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)
                      : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: isCurrent ? null : () {
                    Navigator.pop(ctx);
                    _changeCurrentPhase(label);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showRelabelDialog(PhaseRegime regime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Relabel Phase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PhaseLabel.values.map((label) => ListTile(
            title: Text(_getPhaseLabelName(label).toUpperCase()),
            leading: Radio<PhaseLabel>(
              value: label,
              groupValue: regime.label,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  _relabelRegime(regime, value);
                }
              },
            ),
          )).toList(),
        ),
      ),
    );
  }

  void _showEditDatesDialog(PhaseRegime regime) {
    DateTime startDate = regime.start;
    DateTime? endDate = regime.end;
    bool isOngoing = regime.isOngoing;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Regime Dates'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatDate(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: !isOngoing,
                      onChanged: (value) {
                        setDialogState(() {
                          isOngoing = value == false;
                          if (isOngoing) {
                            endDate = null;
                          } else if (endDate == null) {
                            endDate = DateTime.now();
                          }
                        });
                      },
                    ),
                    const Text('Set end date'),
                  ],
                ),
                if (!isOngoing) ...[
                  const SizedBox(height: 8),
                  const Text('End Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(endDate != null ? _formatDate(endDate!) : 'Select date'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _editRegimeDates(regime, startDate, isOngoing ? null : endDate);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplyPhaseByDateRangeDialog() {
    PhaseLabel selectedPhase = PhaseLabel.discovery;
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Apply phase by date range'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All entries between the start and end dates will get this phase and be locked.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text('Phase:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...PhaseLabel.values.map((label) => RadioListTile<PhaseLabel>(
                  title: Text(_getPhaseLabelName(label).toUpperCase()),
                  value: label,
                  groupValue: selectedPhase,
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedPhase = value);
                  },
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 16),
                const Text('Start date:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatDate(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                const Text('End date:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatDate(endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => endDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyPhaseByDateRange(startDate, endDate, selectedPhase);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRegimeDialog() {
    PhaseLabel selectedPhase = PhaseLabel.discovery;
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime? endDate;
    bool isOngoing = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Regime'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phase:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...PhaseLabel.values.map((label) => RadioListTile<PhaseLabel>(
                  title: Text(_getPhaseLabelName(label).toUpperCase()),
                  value: label,
                  groupValue: selectedPhase,
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedPhase = value;
                      });
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                )),
                const SizedBox(height: 16),
                const Text('Start Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatDate(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: !isOngoing,
                      onChanged: (value) {
                        setDialogState(() {
                          isOngoing = value == false;
                          if (isOngoing) {
                            endDate = null;
                          } else if (endDate == null) {
                            endDate = DateTime.now();
                          }
                        });
                      },
                    ),
                    const Text('Set end date'),
                  ],
                ),
                if (!isOngoing) ...[
                  const SizedBox(height: 8),
                  const Text('End Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(endDate != null ? _formatDate(endDate!) : 'Select date'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addNewRegime(selectedPhase, startDate, isOngoing ? null : endDate);
              },
              child: const Text('Add Regime'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSplitDialog(PhaseRegime regime) {
    showDialog(
      context: context,
      builder: (context) => _SplitPhaseDialog(
        regime: regime,
        onSplit: (splitDate, newPhaseLabel) {
          Navigator.pop(context);
          _splitRegime(regime, splitDate, newPhaseLabel);
        },
        getPhaseLabelName: _getPhaseLabelName,
        formatDate: _formatDate,
      ),
    );
  }

  Future<void> _splitRegime(PhaseRegime regime, DateTime splitDate, PhaseLabel newPhaseLabel) async {
    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      // Validate split date
      if (splitDate.isBefore(regime.start) || 
          (regime.end != null && splitDate.isAfter(regime.end!))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Split date must be within the phase date range'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Split the regime
      final splitRegimes = await phaseRegimeService.splitRegime(regime.id, splitDate);
      
      if (splitRegimes.length > 1) {
        // Update the second regime with new label
        final updatedRegime = splitRegimes[1].copyWith(
          label: newPhaseLabel,
          source: PhaseSource.user,
          updatedAt: DateTime.now(),
        );
        
        // Count entries that would be affected
        final entryCount = phaseRegimeService.countEntriesForRegime(updatedRegime);
        
        // Show confirmation dialog for hashtag update
        final shouldUpdateHashtags = await _showHashtagUpdateConfirmation(
          'Split Phase',
          'This will split ${_getPhaseLabelName(regime.label).toUpperCase()} phase at ${_formatDate(splitDate)}.\n\n'
          'Phase before split: ${_getPhaseLabelName(regime.label).toUpperCase()}\n'
          'Phase after split: ${_getPhaseLabelName(newPhaseLabel).toUpperCase()}\n\n'
          'Would you like to update hashtags in ${entryCount > 0 ? "$entryCount entries" : "entries"}?',
          entryCount,
        );
        
        if (shouldUpdateHashtags == null) return; // User cancelled
        
        await phaseRegimeService.updateRegime(
          updatedRegime,
          updateHashtags: shouldUpdateHashtags == true,
          oldLabel: regime.label,
        );
        
        // Refresh UI
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phase split at ${_formatDate(splitDate)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to split phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeCurrentPhase(PhaseLabel newLabel) async {
    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      // Change phase immediately — no extra confirmation needed (user already picked from list)
      await phaseRegimeService.changeCurrentPhase(newLabel, updateHashtags: false);
      
      // Persist to UserProfile so display phase updates everywhere (splash, preview, Gantt)
      final raw = _getPhaseLabelName(newLabel);
      final phaseString = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      await UserPhaseService.forceUpdatePhase(phaseString);
      
      // Notify phase preview and Gantt card to refresh immediately
      PhaseRegimeService.regimeChangeNotifier.value = DateTime.now();
      UserPhaseService.phaseChangeNotifier.value = DateTime.now();
      
      // Refresh this view's data
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phase changed to ${_getPhaseLabelName(newLabel).toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _relabelRegime(PhaseRegime regime, PhaseLabel newLabel) async {
    if (regime.label == newLabel) return; // No change needed
    
    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      // Count entries that would be affected
      final entryCount = phaseRegimeService.countEntriesForRegime(regime);
      
      // Show confirmation dialog
      final shouldUpdateHashtags = await _showHashtagUpdateConfirmation(
        'Relabel Phase',
        'This will change the phase label from ${_getPhaseLabelName(regime.label).toUpperCase()} to ${_getPhaseLabelName(newLabel).toUpperCase()}.\n\n'
        'Would you like to update hashtags in ${entryCount > 0 ? "$entryCount entries" : "entries"}?',
        entryCount,
      );
      
      if (shouldUpdateHashtags == null) return; // User cancelled
      
      // Update regime
      final updatedRegime = regime.copyWith(
        label: newLabel,
        source: PhaseSource.user,
        updatedAt: DateTime.now(),
      );
      await phaseRegimeService.updateRegime(
        updatedRegime,
        updateHashtags: shouldUpdateHashtags,
        oldLabel: regime.label,
      );
      
      // Refresh UI
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phase relabeled to ${_getPhaseLabelName(newLabel).toUpperCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to relabel phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Apply this regime's phase to all journal entries in its date range (bulk edit from Gantt).
  /// Sets userPhaseOverride and isPhaseLocked on each entry so phase stays fixed.
  Future<void> _applyPhaseToAllEntriesInRegime(PhaseRegime regime) async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      final entries = phaseRegimeService.getEntriesForRegime(regime);
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No entries in this period'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final raw = _getPhaseLabelName(regime.label);
      final phaseString = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Apply phase to all entries'),
          content: Text(
            'Apply $phaseString to ${entries.length} entry(ies) in this period?\n\n'
            'Each entry\'s phase will be set and locked so it won\'t change on reload or import.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final journalRepo = JournalRepository();
      int updated = 0;
      for (final entry in entries) {
        final updatedEntry = entry.copyWith(
          userPhaseOverride: phaseString,
          isPhaseLocked: true,
          updatedAt: DateTime.now(),
        );
        await journalRepo.updateJournalEntry(updatedEntry);
        updated++;
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied $phaseString to $updated entr${updated == 1 ? 'y' : 'ies'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Apply a phase to all journal entries in a date range (bulk apply by dates).
  Future<void> _applyPhaseByDateRange(DateTime start, DateTime end, PhaseLabel phase) async {
    if (end.isBefore(start)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date must be on or after start date'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      final entries = phaseRegimeService.getEntriesInDateRange(start, end);
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No entries between ${_formatDate(start)} and ${_formatDate(end)}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final raw = _getPhaseLabelName(phase);
      final phaseString = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      final journalRepo = JournalRepository();
      int updated = 0;
      for (final entry in entries) {
        final updatedEntry = entry.copyWith(
          userPhaseOverride: phaseString,
          isPhaseLocked: true,
          updatedAt: DateTime.now(),
        );
        await journalRepo.updateJournalEntry(updatedEntry);
        updated++;
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied $phaseString to $updated entr${updated == 1 ? 'y' : 'ies'} (${_formatDate(start)} – ${_formatDate(end)})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _mergeWithNext(PhaseRegime regime) async {
    // Find next regime
    final regimes = widget.phaseIndex.allRegimes;
    final regimeIndex = regimes.indexWhere((r) => r.id == regime.id);
    if (regimeIndex == -1 || regimeIndex >= regimes.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No next regime to merge with'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final nextRegime = regimes[regimeIndex + 1];
    
    // Show confirmation dialog with both regimes clearly displayed
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Phases'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are about to merge these two phases:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // First regime
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getPhaseColor(regime.label).withOpacity(0.1),
                  border: Border.all(color: _getPhaseColor(regime.label)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getPhaseColor(regime.label),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getPhaseLabelName(regime.label).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(regime.start)} - ${regime.end != null ? _formatDate(regime.end!) : "Ongoing"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Arrow indicator
              Center(
                child: Icon(Icons.arrow_downward, color: Colors.grey[400]),
              ),
              const SizedBox(height: 12),
              // Second regime
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getPhaseColor(nextRegime.label).withOpacity(0.1),
                  border: Border.all(color: _getPhaseColor(nextRegime.label)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getPhaseColor(nextRegime.label),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getPhaseLabelName(nextRegime.label).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(nextRegime.start)} - ${nextRegime.end != null ? _formatDate(nextRegime.end!) : "Ongoing"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Result: A single ${_getPhaseLabelName(regime.label).toUpperCase()} phase from ${_formatDate(regime.start)} to ${nextRegime.end != null ? _formatDate(nextRegime.end!) : "Ongoing"}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge Phases'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return; // User cancelled
    
    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      // Merge regimes
      final mergedRegime = await phaseRegimeService.mergeRegimes(regime.id, nextRegime.id);
      
      if (mergedRegime != null) {
        // Count entries that would be affected
        final entryCount = phaseRegimeService.countEntriesForRegime(mergedRegime);
        
        // Show confirmation dialog for hashtag update
        final shouldUpdateHashtags = await _showHashtagUpdateConfirmation(
          'Merge Phases',
          'Phases merged successfully.\n\n'
          'Would you like to update hashtags in ${entryCount > 0 ? "$entryCount entries" : "entries"}?',
          entryCount,
        );
        
        if (shouldUpdateHashtags == true) {
          await phaseRegimeService.updateHashtagsForRegime(mergedRegime);
        }
        
        // Refresh UI
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phases merged successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to merge phases: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endPhaseHere(PhaseRegime regime) async {
    if (!regime.isOngoing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This phase is already ended'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    DateTime endDate = DateTime.now();
    
    // Show dialog to confirm end date
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('End Phase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Phase: ${_getPhaseLabelName(regime.label).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Started: ${_formatDate(regime.start)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text('End Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatDate(endDate)),
                  subtitle: const Text(
                    'Select the date when this phase ended',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: regime.start,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        endDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Duration: ${endDate.difference(regime.start).inDays} days',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End Phase'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed != true) return; // User cancelled
    
    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      // End the regime
      final endedRegime = regime.copyWith(
        end: endDate,
        updatedAt: DateTime.now(),
      );
      await phaseRegimeService.updateRegime(endedRegime);
      
      // Refresh UI
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phase ended on ${_formatDate(endDate)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show confirmation dialog for hashtag updates
  /// Returns true if user wants to update hashtags, false if not, null if cancelled
  Future<bool?> _showHashtagUpdateConfirmation(String title, String message, int entryCount) async {
    if (entryCount == 0) {
      // No entries to update, skip confirmation
      return false;
    }
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              'Updating hashtags will modify the content of your journal entries to reflect the phase change.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update Hashtags'),
          ),
        ],
      ),
    );
  }

  String _getPhaseLabelName(PhaseLabel label) {
    return label.toString().split('.').last;
  }

  Future<void> _editRegimeDates(PhaseRegime regime, DateTime newStart, DateTime? newEnd) async {
    // Validate dates
    if (newEnd != null && newEnd.isBefore(newStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      // Check if dates changed
      final datesChanged = regime.start != newStart || regime.end != newEnd;
      if (!datesChanged) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes made'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Count entries that would be affected by the new date range
      final newRegime = regime.copyWith(
        start: newStart,
        end: newEnd,
        updatedAt: DateTime.now(),
      );
      final entryCount = phaseRegimeService.countEntriesForRegime(newRegime);

      // Show confirmation dialog for hashtag updates
      final shouldUpdateHashtags = await _showHashtagUpdateConfirmation(
        'Edit Regime Dates',
        'This will change the date range from ${_formatDate(regime.start)} - ${regime.end != null ? _formatDate(regime.end!) : "Ongoing"} to ${_formatDate(newStart)} - ${newEnd != null ? _formatDate(newEnd) : "Ongoing"}.\n\n'
        'Would you like to update hashtags in ${entryCount > 0 ? "$entryCount entries" : "entries"}?',
        entryCount,
      );

      if (shouldUpdateHashtags == null) return; // User cancelled

      // Update regime dates
      if (shouldUpdateHashtags) {
        // Update hashtags, handling entries that moved in/out of the regime
        // Pass oldLabel to ensure proper hashtag replacement
        await phaseRegimeService.updateHashtagsForRegime(
          newRegime,
          oldLabel: regime.label, // Ensure old hashtags are removed
          oldRegime: regime, // Handle entries that moved in/out of date range
        );
      }
      
      await phaseRegimeService.updateRegime(
        newRegime,
        updateHashtags: false, // We already handled hashtags above
      );

      // Refresh UI
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Regime dates updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update dates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addNewRegime(PhaseLabel phaseLabel, DateTime startDate, DateTime? endDate) async {
    // Validate dates
    if (endDate != null && endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();

      // Count entries that would be affected
      final tempRegime = PhaseRegime(
        id: 'temp',
        label: phaseLabel,
        start: startDate,
        end: endDate,
        source: PhaseSource.user,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final entryCount = phaseRegimeService.countEntriesForRegime(tempRegime);

      // Show confirmation dialog for hashtag updates
      final shouldUpdateHashtags = await _showHashtagUpdateConfirmation(
        'Add New Regime',
        'This will create a new ${_getPhaseLabelName(phaseLabel).toUpperCase()} phase from ${_formatDate(startDate)} to ${endDate != null ? _formatDate(endDate) : "Ongoing"}.\n\n'
        'Would you like to update hashtags in ${entryCount > 0 ? "$entryCount entries" : "entries"}?',
        entryCount,
      );

      if (shouldUpdateHashtags == null) return; // User cancelled

      // Create new regime
      final newRegime = await phaseRegimeService.createRegime(
        label: phaseLabel,
        start: startDate,
        end: endDate,
        source: PhaseSource.user,
      );

      // Update hashtags if requested
      if (shouldUpdateHashtags) {
        await phaseRegimeService.updateHashtagsForRegime(newRegime);
      }

      // Refresh UI
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New ${_getPhaseLabelName(phaseLabel).toUpperCase()} regime added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add regime: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(PhaseRegime regime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Phase'),
        content: Text(
          'Are you sure you want to delete this ${_getPhaseLabelName(regime.label).toUpperCase()} phase?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRegime(regime);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRegime(PhaseRegime regime) async {
    try {
      // Get PhaseRegimeService
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      // Delete the regime
      await phaseRegimeService.deleteRegime(regime.id);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getPhaseLabelName(regime.label).toUpperCase()} phase deleted'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the UI
        setState(() {});
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete phase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Color _getPhaseColor(PhaseLabel label) {
    const colors = {
      PhaseLabel.discovery: Colors.blue,
      PhaseLabel.expansion: Colors.green,
      PhaseLabel.transition: Colors.orange,
      PhaseLabel.consolidation: Colors.purple,
      PhaseLabel.recovery: Colors.red,
      PhaseLabel.breakthrough: Colors.amber,
    };
    return colors[label] ?? Colors.grey;
  }
}

/// Dialog for splitting a phase regime
class _SplitPhaseDialog extends StatefulWidget {
  final PhaseRegime regime;
  final Function(DateTime, PhaseLabel) onSplit;
  final String Function(PhaseLabel) getPhaseLabelName;
  final String Function(DateTime) formatDate;

  const _SplitPhaseDialog({
    required this.regime,
    required this.onSplit,
    required this.getPhaseLabelName,
    required this.formatDate,
  });

  @override
  State<_SplitPhaseDialog> createState() => _SplitPhaseDialogState();
}

class _SplitPhaseDialogState extends State<_SplitPhaseDialog> {
  late DateTime _splitDate;
  late PhaseLabel _newPhaseLabel;

  @override
  void initState() {
    super.initState();
    _splitDate = widget.regime.start.add(Duration(
      days: widget.regime.duration.inDays ~/ 2,
    ));
    _newPhaseLabel = widget.regime.label;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Split Phase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Phase: ${widget.getPhaseLabelName(widget.regime.label).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.formatDate(widget.regime.start)} - ${widget.regime.end != null ? widget.formatDate(widget.regime.end!) : "Ongoing"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Split Date:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.formatDate(_splitDate)),
              subtitle: Text(
                'This phase will end on this date',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _splitDate,
                  firstDate: widget.regime.start,
                  lastDate: widget.regime.end ?? DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _splitDate = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('New Phase After Split:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...PhaseLabel.values.map((label) => RadioListTile<PhaseLabel>(
              title: Text(widget.getPhaseLabelName(label).toUpperCase()),
              value: label,
              groupValue: _newPhaseLabel,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _newPhaseLabel = value;
                  });
                }
              },
              contentPadding: EdgeInsets.zero,
            )),
            const SizedBox(height: 8),
            Text(
              'The phase from ${widget.formatDate(_splitDate)} onwards will be ${widget.getPhaseLabelName(_newPhaseLabel).toUpperCase()}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSplit(_splitDate, _newPhaseLabel);
          },
          child: const Text('Split Phase'),
        ),
      ],
    );
  }
}

class PhaseTimelinePainter extends CustomPainter {
  final List<PhaseRegime> regimes;
  final DateTime visibleStart;
  final DateTime visibleEnd;
  final double zoomLevel;
  final ThemeData theme;

  PhaseTimelinePainter({
    required this.regimes,
    required this.visibleStart,
    required this.visibleEnd,
    required this.zoomLevel,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final totalDuration = visibleEnd.difference(visibleStart).inMilliseconds;
    
    for (final regime in regimes) {
      // Calculate position
      final startProgress = regime.start.difference(visibleStart).inMilliseconds / totalDuration;
      final endProgress = (regime.end ?? visibleEnd).difference(visibleStart).inMilliseconds / totalDuration;
      
      if (startProgress >= 1.0 || endProgress <= 0.0) continue;
      
      final startX = startProgress * size.width;
      final endX = endProgress * size.width;
      final width = endX - startX;
      
      if (width <= 0) continue;
      
      // Draw phase band
      paint.color = _getPhaseColor(regime.label).withOpacity(0.7);
      canvas.drawRect(
        Rect.fromLTWH(startX, 0, width, size.height),
        paint,
      );
      
      // Draw regime label
      if (width > 60) {
        final phaseName = regime.label.toString().split('.').last.toUpperCase();
        final textPainter = TextPainter(
          text: TextSpan(
            text: phaseName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        if (textPainter.width <= width - 8) {
          textPainter.paint(
            canvas,
            Offset(startX + 4, size.height / 2 - textPainter.height / 2),
          );
        }
      }
      
      // Draw source indicator
      if (regime.source == PhaseSource.user) {
        paint.color = Colors.white;
        canvas.drawCircle(
          Offset(startX + 8, 8),
          3,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  Color _getPhaseColor(PhaseLabel label) {
    const colors = {
      PhaseLabel.discovery: Colors.blue,
      PhaseLabel.expansion: Colors.green,
      PhaseLabel.transition: Colors.orange,
      PhaseLabel.consolidation: Colors.purple,
      PhaseLabel.recovery: Colors.red,
      PhaseLabel.breakthrough: Colors.amber,
    };
    return colors[label] ?? Colors.grey;
  }
}
