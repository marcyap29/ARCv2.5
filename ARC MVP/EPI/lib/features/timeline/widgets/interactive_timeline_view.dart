import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/features/timeline/timeline_state.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/features/arcforms/services/emotional_valence_service.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'dart:math' as math;

class InteractiveTimelineView extends StatefulWidget {
  const InteractiveTimelineView({super.key});

  @override
  State<InteractiveTimelineView> createState() => _InteractiveTimelineViewState();
}

class _InteractiveTimelineViewState extends State<InteractiveTimelineView>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _currentIndex = 0;
  List<TimelineEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.6, // Show partial views of adjacent entries
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineCubit, TimelineState>(
      builder: (context, state) {
        if (state is TimelineLoaded) {
          _entries = _getFilteredEntries(state);
          
          if (_entries.isEmpty) {
            return Center(
              child: Text(
                'No entries yet',
                style: bodyStyle(context),
              ),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                _buildTimelineHeader(),
                Expanded(
                  child: _buildInteractiveTimeline(),
                ),
                _buildTimelineFooter(),
              ],
            ),
          );
        }

        if (state is TimelineLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is TimelineError) {
          return Center(
            child: Text(
              state.message,
              style: bodyStyle(context),
            ),
          );
        }

        return Container();
      },
    );
  }

  Widget _buildTimelineHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Your Sacred Journey',
        style: heading1Style(context).copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w300,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInteractiveTimeline() {
    return Stack(
      children: [
        // Horizontal timeline line
        _buildTimelineLine(),
        
        // PageView with entries
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _entries.length,
          itemBuilder: (context, index) {
            return _buildTimelineEntry(index);
          },
        ),
      ],
    );
  }

  Widget _buildTimelineLine() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.4, // Center vertically
      left: 0,
      right: 0,
      child: SizedBox(
        height: 2,
        child: CustomPaint(
          painter: TimelineLinePainter(
            currentIndex: _currentIndex,
            totalEntries: _entries.length,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildTimelineEntry(int index) {
    final entry = _entries[index];
    final isCurrentEntry = index == _currentIndex;
    final distance = (index - _currentIndex).abs();
    
    // Calculate opacity based on distance from current entry
    double opacity = 1.0;
    if (distance > 0) {
      opacity = math.max(0.3, 1.0 - (distance * 0.3));
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isCurrentEntry ? 1.0 : 0.8,
          child: Opacity(
            opacity: opacity * _fadeAnimation.value,
            child: GestureDetector(
              onTap: () => _onEntryTapped(entry, index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Arcform visualization
                    _buildArcformVisualization(entry, isCurrentEntry),
                    
                    const SizedBox(height: 24),
                    
                    // Entry details
                    _buildEntryDetails(entry, isCurrentEntry),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onEntryTapped(TimelineEntry entry, int index) {
    // Navigate to entry editing view
    Navigator.of(context).pushNamed(
      '/journal-edit',
      arguments: {
        'entry': entry,
        'entryIndex': index,
      },
    );
  }

  Widget _buildArcformVisualization(TimelineEntry entry, bool isCurrentEntry) {
    final phaseColor = _getPhaseColor(entry.phase);
    final phaseGeometry = _getPhaseGeometry(entry.phase);
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrentEntry 
            ? phaseColor.withOpacity(0.1)
            : phaseColor.withOpacity(0.05),
        border: Border.all(
          color: phaseColor.withOpacity(isCurrentEntry ? 0.8 : 0.4),
          width: isCurrentEntry ? 3 : 2,
        ),
        boxShadow: isCurrentEntry ? [
          BoxShadow(
            color: phaseColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Stack(
        children: [
          // Main content - Arcform or default icon
          Center(
            child: entry.hasArcform
                ? _buildArcformIcon(entry, isCurrentEntry, phaseColor, phaseGeometry)
                : _buildDefaultIcon(isCurrentEntry, phaseColor),
          ),
          // Phase indicator in bottom-right corner
          if (entry.phase != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: phaseColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.phase!.substring(0, 3).toUpperCase(),
                  style: const TextStyle(
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

  Widget _buildArcformIcon(TimelineEntry entry, bool isCurrentEntry, Color phaseColor, GeometryPattern? phaseGeometry) {
    return CustomPaint(
      painter: ArcformTimelinePainter(
        isCurrentEntry: isCurrentEntry,
        entry: entry,
        phaseColor: phaseColor,
        phaseGeometry: phaseGeometry ?? GeometryPattern.spiral,
      ),
      size: const Size(120, 120),
    );
  }

  Widget _buildDefaultIcon(bool isCurrentEntry, Color phaseColor) {
    return Icon(
      Icons.edit_note_outlined,
      size: 40,
      color: isCurrentEntry 
          ? phaseColor
          : phaseColor.withOpacity(0.5),
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

  GeometryPattern? _getPhaseGeometry(String? phase) {
    if (phase == null) return null;
    
    switch (phase.toLowerCase()) {
      case 'discovery':
        return GeometryPattern.spiral;
      case 'expansion':
        return GeometryPattern.flower;
      case 'transition':
        return GeometryPattern.branch;
      case 'consolidation':
        return GeometryPattern.weave;
      case 'recovery':
        return GeometryPattern.glowCore;
      case 'breakthrough':
        return GeometryPattern.fractal;
      default:
        return GeometryPattern.spiral;
    }
  }

  Widget _buildEntryDetails(TimelineEntry entry, bool isCurrentEntry) {
    return Column(
      children: [
        // Entry type label
        Text(
          'JOURNAL ENTRY',
          style: captionStyle(context).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: isCurrentEntry 
                ? kcPrimaryTextColor
                : kcSecondaryTextColor.withOpacity(0.7),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Date
        Text(
          entry.date,
          style: bodyStyle(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isCurrentEntry 
                ? kcPrimaryTextColor
                : kcSecondaryTextColor.withOpacity(0.6),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Preview text (only for current entry)
        if (isCurrentEntry) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcSurfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: kcPrimaryColor.withOpacity(0.2),
              ),
            ),
            child: Text(
              entry.preview,
              style: bodyStyle(context).copyWith(
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Swipe hint
          Text(
            'Swipe to explore',
            style: captionStyle(context).copyWith(
              color: kcSecondaryTextColor.withOpacity(0.6),
            ),
          ),
          
          // Entry counter
          Text(
            '${_currentIndex + 1} of ${_entries.length}',
            style: captionStyle(context).copyWith(
              color: kcSecondaryTextColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  List<TimelineEntry> _getFilteredEntries(TimelineLoaded state) {
    // Flatten all entries from grouped data
    List<TimelineEntry> allEntries = [];
    for (final group in state.groupedEntries) {
      allEntries.addAll(group.entries);
    }
    
    // Apply filter
    switch (state.filter) {
      case TimelineFilter.all:
        return allEntries;
      case TimelineFilter.textOnly:
        return allEntries.where((entry) => !entry.hasArcform).toList();
      case TimelineFilter.withArcform:
        return allEntries.where((entry) => entry.hasArcform).toList();
    }
  }
}

class ArcformTimelinePainter extends CustomPainter {
  final bool isCurrentEntry;
  final TimelineEntry entry;
  final Color phaseColor;
  final GeometryPattern phaseGeometry;

  ArcformTimelinePainter({
    required this.isCurrentEntry,
    required this.entry,
    required this.phaseColor,
    required this.phaseGeometry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCurrentEntry ? 2.5 : 1.5
      ..color = isCurrentEntry 
          ? phaseColor
          : phaseColor.withOpacity(0.6);

    // Draw phase-specific geometry pattern
    if (entry.keywords.isEmpty) {
      _drawSimpleCircle(canvas, center, radius, paint);
    } else {
      _drawPhaseGeometry(canvas, center, radius, paint);
    }
  }

  void _drawSimpleCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius * 0.6, paint);
  }

  void _drawPhaseGeometry(Canvas canvas, Offset center, double radius, Paint paint) {
    final keywordCount = entry.keywords.length;
    
    switch (phaseGeometry) {
      case GeometryPattern.spiral:
        _drawSpiral(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.flower:
        _drawFlower(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.branch:
        _drawBranch(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.weave:
        _drawWeave(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.glowCore:
        _drawGlowCore(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.fractal:
        _drawFractal(canvas, center, radius, paint, keywordCount);
        break;
    }
  }

  void _drawSpiral(Canvas canvas, Offset center, double radius, Paint paint, int keywordCount) {
    final path = Path();
    const double goldenAngle = 2.39996; // Golden angle
    final spiralPoints = math.max(12, keywordCount * 2);
    
    for (int i = 0; i < spiralPoints; i++) {
      final angle = i * goldenAngle;
      final r = radius * math.sqrt(i / spiralPoints.toDouble()) * 0.8;
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

  void _drawFlower(Canvas canvas, Offset center, double radius, Paint paint, int keywordCount) {
    final petalCount = math.max(5, keywordCount);
    final angleStep = (2 * math.pi) / petalCount;
    
    for (int i = 0; i < petalCount; i++) {
      final angle = i * angleStep;
      final petalRadius = radius * 0.7;
      final x = center.dx + petalRadius * math.cos(angle);
      final y = center.dy + petalRadius * math.sin(angle);
      
      canvas.drawLine(center, Offset(x, y), paint);
    }
    canvas.drawCircle(center, radius * 0.15, paint);
  }

  void _drawBranch(Canvas canvas, Offset center, double radius, Paint paint, int keywordCount) {
    // Main trunk
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.4),
      Offset(center.dx, center.dy - radius * 0.6),
      paint,
    );
    
    // Branches
    final branchCount = math.min(keywordCount, 4);
    for (int i = 0; i < branchCount; i++) {
      final angle = -math.pi + (i * math.pi / (branchCount + 1));
      final branchLength = radius * 0.5;
      final x = center.dx + branchLength * math.cos(angle);
      final y = center.dy + branchLength * math.sin(angle);
      
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  void _drawWeave(Canvas canvas, Offset center, double radius, Paint paint, int keywordCount) {
    final gridSize = math.max(2, math.sqrt(keywordCount).ceil());
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

  void _drawGlowCore(Canvas canvas, Offset center, double radius, Paint paint, int keywordCount) {
    canvas.drawCircle(center, radius * 0.2, paint);
    
    final rayCount = math.min(keywordCount, 8);
    for (int i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi * i) / rayCount;
      final x = center.dx + radius * 0.7 * math.cos(angle);
      final y = center.dy + radius * 0.7 * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  void _drawFractal(Canvas canvas, Offset center, double radius, Paint paint, int keywordCount) {
    _drawFractalBranch(canvas, center, -math.pi / 2, radius * 0.6, 0, paint);
  }

  void _drawFractalBranch(Canvas canvas, Offset start, double angle, double length, int depth, Paint paint) {
    if (depth > 2 || length < 10) return;
    
    final endX = start.dx + length * math.cos(angle);
    final endY = start.dy + length * math.sin(angle);
    final end = Offset(endX, endY);
    
    canvas.drawLine(start, end, paint);
    
    final newLength = length * 0.7;
    _drawFractalBranch(canvas, end, angle - math.pi / 4, newLength, depth + 1, paint);
    _drawFractalBranch(canvas, end, angle + math.pi / 4, newLength, depth + 1, paint);
  }

  void _drawNodes(Canvas canvas, Offset center, double radius, Paint nodePaint) {
    const nodeRadius = 3.0;
    final emotionalService = EmotionalValenceService();

    // Use actual number of keywords from the entry
    final keywordCount = entry.keywords.length;
    final maxNodes = math.min(keywordCount, 8); // Cap at 8 for visual clarity
    
    // Draw nodes based on actual keywords with emotional coloring
    for (int i = 0; i < maxNodes; i++) {
      final keyword = entry.keywords[i];
      final angle = i * (2 * math.pi / maxNodes); // Evenly distribute around circle
      final r = radius * (0.4 + (i * 0.1)); // Vary radius slightly for visual interest
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      
      // Get emotional color for this specific keyword
      final emotionalColor = emotionalService.getEmotionalColor(keyword);
      final nodePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isCurrentEntry 
            ? emotionalColor
            : emotionalColor.withOpacity(0.6);
      
      canvas.drawCircle(Offset(x, y), nodeRadius, nodePaint);
    }
  }

  /// Convert valence score to color (same logic as EmotionalValenceService)
  Color _valenceToColor(double valence) {
    if (valence > 0.7) {
      // Very positive: Golden/warm yellow
      return const Color(0xFFFFD700);
    } else if (valence > 0.4) {
      // Positive: Warm orange
      return const Color(0xFFFF8C42);
    } else if (valence > 0.1) {
      // Slightly positive: Soft coral
      return const Color(0xFFFF6B6B);
    } else if (valence > -0.1) {
      // Neutral: Soft purple (app's primary color)
      return const Color(0xFFD1B3FF);
    } else if (valence > -0.4) {
      // Slightly negative: Cool blue
      return const Color(0xFF4A90E2);
    } else if (valence > -0.7) {
      // Negative: Deeper blue
      return const Color(0xFF2E86AB);
    } else {
      // Very negative: Cool teal
      return const Color(0xFF4ECDC4);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ArcformTimelinePainter &&
        (oldDelegate.isCurrentEntry != isCurrentEntry ||
         oldDelegate.entry != entry);
  }
}

class TimelineLinePainter extends CustomPainter {
  final int currentIndex;
  final int totalEntries;

  TimelineLinePainter({
    required this.currentIndex,
    required this.totalEntries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalEntries <= 1) return;

    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Calculate the width of each segment
    final segmentWidth = size.width / totalEntries;
    
    // Draw the main timeline line
    for (int i = 0; i < totalEntries - 1; i++) {
      final startX = (i + 0.5) * segmentWidth;
      final endX = (i + 1.5) * segmentWidth;
      final centerY = size.height / 2;
      
      // Determine line color based on position relative to current entry
      if (i < currentIndex) {
        // Past entries - lighter color
        paint.color = kcSecondaryTextColor.withOpacity(0.3);
      } else if (i == currentIndex) {
        // Current entry - primary color
        paint.color = kcPrimaryColor;
      } else {
        // Future entries - lighter color
        paint.color = kcSecondaryTextColor.withOpacity(0.3);
      }
      
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(endX, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is TimelineLinePainter &&
        (oldDelegate.currentIndex != currentIndex ||
         oldDelegate.totalEntries != totalEntries);
  }
}
