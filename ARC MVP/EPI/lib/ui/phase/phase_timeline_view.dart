// lib/ui/phase/phase_timeline_view.dart
// Phase timeline with colored bands and edit controls

import 'package:flutter/material.dart';
import '../../models/phase_models.dart';
import '../../services/phase_index.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regimes = widget.phaseIndex.allRegimes;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildTimelineHeader(theme),
                const SizedBox(height: 16),
                _buildPhaseLegend(theme),
                const SizedBox(height: 16),
                _buildTimelineVisualization(theme, regimes),
                const SizedBox(height: 16),
                _buildRegimeList(theme, regimes),
                const SizedBox(height: 16),
                _buildTimelineControls(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineHeader(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Phase Timeline',
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                _buildCurrentPhaseChip(theme),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineStats(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPhaseChip(ThemeData theme) {
    final currentRegime = widget.phaseIndex.currentRegime;
    if (currentRegime == null) {
      return const Chip(
        label: Text('No Phase'),
        backgroundColor: Colors.grey,
      );
    }
    
    return Chip(
      label: Text(currentRegime.label.name.toUpperCase()),
      backgroundColor: _getPhaseColor(currentRegime.label).withOpacity(0.2),
      side: BorderSide(color: _getPhaseColor(currentRegime.label)),
      onDeleted: () => _showPhaseChangeDialog(),
    );
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

  Widget _buildPhaseLegend(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Phase Legend',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: PhaseLabel.values.map((label) {
                return _buildLegendItem(label, theme);
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSourceIndicator(PhaseSource.user, theme),
                const SizedBox(width: 16),
                _buildSourceIndicator(PhaseSource.rivet, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(PhaseLabel label, ThemeData theme) {
    final color = _getPhaseColor(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.name.toUpperCase(),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSourceIndicator(PhaseSource source, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: source == PhaseSource.user ? Colors.white : Colors.transparent,
            border: Border.all(
              color: source == PhaseSource.user ? theme.colorScheme.primary : Colors.grey,
              width: 2,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          source == PhaseSource.user ? 'User Set' : 'RIVET Detected',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTimelineVisualization(ThemeData theme, List<PhaseRegime> regimes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _buildTimelineAxis(theme),
            const SizedBox(height: 8),
            Container(
              height: 120,
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
                      height: 120,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildTimelineLabels(theme),
          ],
        ),
      ),
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
            margin: const EdgeInsets.symmetric(horizontal: 8),
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
            margin: const EdgeInsets.symmetric(horizontal: 8),
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
              left: (MediaQuery.of(context).size.width - 32) * nowProgress * 0.85, // Account for padding
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TODAY',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegimeList(ThemeData theme, List<PhaseRegime> regimes) {
    if (regimes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
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
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sortedRegimes = List<PhaseRegime>.from(regimes)
      ..sort((a, b) => b.start.compareTo(a.start)); // Newest first

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ...sortedRegimes.take(10).map((regime) => _buildRegimeCard(regime, theme)),
            if (regimes.length > 10)
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
          ],
        ),
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
              regime.label.name.toUpperCase(),
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

  Widget _buildTimelineControls(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            IconButton(
              onPressed: _zoomOut,
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom Out',
            ),
            Expanded(
              child: Slider(
                value: _zoomLevel,
                min: 0.1,
                max: 3.0,
                onChanged: (value) {
                  setState(() {
                    _zoomLevel = value;
                  });
                },
              ),
            ),
            IconButton(
              onPressed: _zoomIn,
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom In',
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _showPhaseChangeDialog,
              icon: const Icon(Icons.add),
              label: const Text('Change Phase'),
            ),
          ],
        ),
      ),
    );
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
              'Phase: ${regime.label.name.toUpperCase()}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }

  void _showPhaseChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Current Phase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a new phase:'),
            const SizedBox(height: 16),
            ...PhaseLabel.values.map((label) => ListTile(
              title: Text(label.name.toUpperCase()),
              leading: Icon(
                Icons.circle,
                color: _getPhaseColor(label),
              ),
              onTap: () {
                Navigator.pop(context);
                _changeCurrentPhase(label);
              },
            )),
          ],
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
            title: Text(label.name.toUpperCase()),
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

  void _showSplitDialog(PhaseRegime regime) {
    // This would show a date picker for split point
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split Phase'),
        content: const Text('Date picker for split point would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement split logic
            },
            child: const Text('Split'),
          ),
        ],
      ),
    );
  }

  void _changeCurrentPhase(PhaseLabel newLabel) {
    // End current regime and start new one
    // Implementation would go here
  }

  void _relabelRegime(PhaseRegime regime, PhaseLabel newLabel) {
    // Update regime label
    // Implementation would go here
  }

  void _mergeWithNext(PhaseRegime regime) {
    // Merge with next regime
    // Implementation would go here
  }

  void _endPhaseHere(PhaseRegime regime) {
    // End the regime at current time
    // Implementation would go here
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel * 1.2).clamp(0.1, 3.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel / 1.2).clamp(0.1, 3.0);
    });
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
        final textPainter = TextPainter(
          text: TextSpan(
            text: regime.label.name.toUpperCase(),
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
