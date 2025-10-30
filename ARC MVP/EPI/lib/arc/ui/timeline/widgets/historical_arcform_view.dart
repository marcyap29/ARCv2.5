import 'package:flutter/material.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:hive/hive.dart';
import 'dart:math' as math;

class HistoricalArcformView extends StatefulWidget {
  final TimelineEntry entry;

  const HistoricalArcformView({
    super.key,
    required this.entry,
  });

  @override
  State<HistoricalArcformView> createState() => _HistoricalArcformViewState();
}

class _HistoricalArcformViewState extends State<HistoricalArcformView> {
  ArcformSnapshot? _historicalSnapshot;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistoricalArcform();
  }

  Future<void> _loadHistoricalArcform() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Parse the entry date to get the timestamp
      final dateParts = widget.entry.date.split('/');
      final entryDate = DateTime(
        int.parse(dateParts[2]), // year
        int.parse(dateParts[0]), // month
        int.parse(dateParts[1]), // day
      );

      // Find the arcform snapshot closest to this entry's date
      final snapshot = await _findClosestArcformSnapshot(entryDate);
      
      setState(() {
        _historicalSnapshot = snapshot;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load historical arcform: $e';
        _isLoading = false;
      });
    }
  }

  Future<ArcformSnapshot?> _findClosestArcformSnapshot(DateTime targetDate) async {
    try {
      // Check if box is already open, if not open it
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      
      ArcformSnapshot? closestSnapshot;
      Duration? smallestDifference;
      
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot != null) {
          final difference = targetDate.difference(snapshot.timestamp).abs();
          
          // Only consider snapshots from before or around the same time as the entry
          if (snapshot.timestamp.isBefore(targetDate.add(const Duration(days: 1)))) {
            if (smallestDifference == null || difference < smallestDifference) {
              smallestDifference = difference;
              closestSnapshot = snapshot;
            }
          }
        }
      }
      
      return closestSnapshot;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('Historical Arcform', style: heading1Style(context)),
        actions: [
          if (_historicalSnapshot != null)
            IconButton(
              onPressed: _showSnapshotInfo,
              icon: const Icon(Icons.info_outline),
              tooltip: 'Snapshot Info',
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: kcDangerColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Arcform',
                style: heading1Style(context).copyWith(
                  color: kcDangerColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: bodyStyle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadHistoricalArcform,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcPrimaryColor,
                ),
                child: Text('Retry', style: buttonStyle(context)),
              ),
            ],
          ),
        ),
      );
    }

    if (_historicalSnapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_outlined,
                size: 80,
                color: kcSecondaryTextColor.withOpacity(0.6),
              ),
              const SizedBox(height: 24),
              Text(
                'No Historical Arcform',
                style: heading1Style(context).copyWith(
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No arcform snapshot was found for this journal entry date.',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _buildHistoricalArcform();
  }

  Widget _buildHistoricalArcform() {
    final snapshot = _historicalSnapshot!;
    final phase = snapshot.data['phase'] as String?;
    final geometry = snapshot.data['geometry'] as String?;
    final keywords = (snapshot.data['keywords'] as List?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Entry context header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: kcPrimaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arcform from ${widget.entry.date}',
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is how your arcform looked when you wrote this journal entry.',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // Phase info
          _buildInfoCard(
            'Phase',
            phase ?? 'Unknown',
            Icons.psychology,
            _getPhaseColor(phase),
          ),

          const SizedBox(height: 24),

          // Keywords section
          if (keywords.isNotEmpty) ...[
            Text(
              'Keywords',
              style: heading1Style(context).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((keyword) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kcPrimaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  keyword,
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),
          ],

          // Arcform visualization
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: kcSurfaceColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: HistoricalArcformPainter(
                  snapshot: snapshot,
                  keywords: keywords,
                  phase: phase,
                  geometry: geometry,
                ),
                size: const Size(300, 300),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Journal entry preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: kcSurfaceAltColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kcPrimaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journal Entry',
                  style: heading1Style(context).copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.entry.preview,
                  style: bodyStyle(context).copyWith(
                    fontSize: 14,
                    height: 1.6,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: captionStyle(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: bodyStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }


  Color _getPhaseColor(String? phase) {
    if (phase == null) return kcSecondaryTextColor;
    
    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5); // Blue
      case 'expansion':
        return const Color(0xFF7C3AED); // Purple  
      case 'transition':
        return const Color(0xFF059669); // Green
      case 'consolidation':
        return const Color(0xFFD97706); // Orange
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFF7C2D12); // Brown
      default:
        return kcSecondaryTextColor;
    }
  }

  void _showSnapshotInfo() {
    final snapshot = _historicalSnapshot!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text('Snapshot Info', style: heading1Style(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${snapshot.id}', style: bodyStyle(context)),
            const SizedBox(height: 8),
            Text('Created: ${_formatDateTime(snapshot.timestamp)}', style: bodyStyle(context)),
            const SizedBox(height: 8),
            Text('Notes: ${snapshot.notes}', style: bodyStyle(context)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: buttonStyle(context).copyWith(color: kcPrimaryColor)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class HistoricalArcformPainter extends CustomPainter {
  final ArcformSnapshot snapshot;
  final List<String> keywords;
  final String? phase;
  final String? geometry;

  HistoricalArcformPainter({
    required this.snapshot,
    required this.keywords,
    required this.phase,
    required this.geometry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;
    
    // Draw the geometry pattern
    _drawGeometryPattern(canvas, center, radius);
    
    // Draw keyword nodes
    _drawKeywordNodes(canvas, center, radius);
  }

  void _drawGeometryPattern(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = _getPhaseColor().withOpacity(0.8);

    switch (geometry?.toLowerCase()) {
      case 'spiral':
        _drawSpiral(canvas, center, radius, paint);
        break;
      case 'flower':
        _drawFlower(canvas, center, radius, paint);
        break;
      case 'branch':
        _drawBranch(canvas, center, radius, paint);
        break;
      case 'weave':
        _drawWeave(canvas, center, radius, paint);
        break;
      case 'glowcore':
        _drawGlowCore(canvas, center, radius, paint);
        break;
      case 'fractal':
        _drawFractal(canvas, center, radius, paint);
        break;
      default:
        _drawSpiral(canvas, center, radius, paint);
    }
  }

  void _drawKeywordNodes(Canvas canvas, Offset center, double radius) {
    if (keywords.isEmpty) return;

    final nodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _getPhaseColor();

    for (int i = 0; i < keywords.length && i < 8; i++) {
      final angle = i * (2 * 3.14159) / keywords.length;
      final nodeRadius = radius * (0.6 + (i * 0.1));
      final x = center.dx + nodeRadius * math.cos(angle);
      final y = center.dy + nodeRadius * math.sin(angle);
      
      canvas.drawCircle(Offset(x, y), 6.0, nodePaint);
    }
  }

  Color _getPhaseColor() {
    if (phase == null) return const Color(0xFF6B7280);
    
    switch (phase!.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5);
      case 'expansion':
        return const Color(0xFF7C3AED);
      case 'transition':
        return const Color(0xFF059669);
      case 'consolidation':
        return const Color(0xFFD97706);
      case 'recovery':
        return const Color(0xFFDC2626);
      case 'breakthrough':
        return const Color(0xFF7C2D12);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _drawSpiral(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const spiralPoints = 50;
    
    for (int i = 0; i < spiralPoints; i++) {
      final angle = i * 0.3;
      final r = radius * (i / spiralPoints) * 0.8;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawFlower(Canvas canvas, Offset center, double radius, Paint paint) {
    final petalCount = math.max(5, keywords.length);
    for (int i = 0; i < petalCount; i++) {
      final angle = i * (2 * 3.14159) / petalCount;
      final x = center.dx + radius * 0.7 * math.cos(angle);
      final y = center.dy + radius * 0.7 * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
    canvas.drawCircle(center, radius * 0.15, paint);
  }

  void _drawBranch(Canvas canvas, Offset center, double radius, Paint paint) {
    // Main trunk
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.4),
      Offset(center.dx, center.dy - radius * 0.6),
      paint,
    );
    
    // Branches
    for (int i = 0; i < 4; i++) {
      final angle = -3.14159 + (i * 3.14159 / 5);
      final x = center.dx + radius * 0.5 * math.cos(angle);
      final y = center.dy + radius * 0.5 * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  void _drawWeave(Canvas canvas, Offset center, double radius, Paint paint) {
    const gridSize = 3;
    final spacing = radius * 0.4 / gridSize;
    
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final x = center.dx + (i - gridSize / 2) * spacing;
        final y = center.dy + (j - gridSize / 2) * spacing;
        
        if (j < gridSize - 1) {
          canvas.drawLine(Offset(x, y), Offset(x, y + spacing), paint);
        }
        if (i < gridSize - 1) {
          canvas.drawLine(Offset(x, y), Offset(x + spacing, y), paint);
        }
      }
    }
  }

  void _drawGlowCore(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius * 0.2, paint);
    
    for (int i = 0; i < 8; i++) {
      final angle = (2 * 3.14159 * i) / 8;
      final x = center.dx + radius * 0.7 * math.cos(angle);
      final y = center.dy + radius * 0.7 * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  void _drawFractal(Canvas canvas, Offset center, double radius, Paint paint) {
    _drawFractalBranch(canvas, center, -3.14159 / 2, radius * 0.6, 0, paint);
  }

  void _drawFractalBranch(Canvas canvas, Offset start, double angle, double length, int depth, Paint paint) {
    if (depth > 2 || length < 20) return;
    
    final endX = start.dx + length * math.cos(angle);
    final endY = start.dy + length * math.sin(angle);
    final end = Offset(endX, endY);
    
    canvas.drawLine(start, end, paint);
    
    final newLength = length * 0.7;
    _drawFractalBranch(canvas, end, angle - 3.14159 / 4, newLength, depth + 1, paint);
    _drawFractalBranch(canvas, end, angle + 3.14159 / 4, newLength, depth + 1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}