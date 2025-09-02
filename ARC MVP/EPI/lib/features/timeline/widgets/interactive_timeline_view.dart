import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/features/timeline/timeline_state.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
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
      child: Container(
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
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrentEntry 
            ? kcPrimaryColor.withOpacity(0.1)
            : kcSurfaceAltColor.withOpacity(0.5),
        border: Border.all(
          color: isCurrentEntry 
              ? kcPrimaryColor
              : kcSecondaryTextColor.withOpacity(0.3),
          width: isCurrentEntry ? 2 : 1,
        ),
        boxShadow: isCurrentEntry ? [
          BoxShadow(
            color: kcPrimaryColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: entry.hasArcform
          ? _buildArcformIcon(entry, isCurrentEntry)
          : _buildDefaultIcon(isCurrentEntry),
    );
  }

  Widget _buildArcformIcon(TimelineEntry entry, bool isCurrentEntry) {
    // This would ideally show the actual Arcform geometry
    // For now, we'll show a beautiful geometric pattern
    return CustomPaint(
      painter: ArcformTimelinePainter(
        isCurrentEntry: isCurrentEntry,
        entry: entry,
      ),
      size: const Size(120, 120),
    );
  }

  Widget _buildDefaultIcon(bool isCurrentEntry) {
    return Icon(
      Icons.edit_note_outlined,
      size: 40,
      color: isCurrentEntry 
          ? kcPrimaryColor
          : kcSecondaryTextColor.withOpacity(0.5),
    );
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

  ArcformTimelinePainter({
    required this.isCurrentEntry,
    required this.entry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCurrentEntry ? 2.0 : 1.0
      ..color = isCurrentEntry 
          ? kcPrimaryColor
          : kcSecondaryTextColor.withOpacity(0.4);

    // Draw a simple spiral pattern as placeholder for actual Arcform
    _drawSpiral(canvas, center, radius, paint);
    
    // Add some nodes
    _drawNodes(canvas, center, radius, paint);
  }

  void _drawSpiral(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final double goldenAngle = 2.4; // Golden angle approximation
    
    for (int i = 0; i < 20; i++) {
      final angle = i * goldenAngle;
      final r = radius * (i / 20.0);
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

  void _drawNodes(Canvas canvas, Offset center, double radius, Paint nodePaint) {
    final nodeRadius = 3.0;
    final nodePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isCurrentEntry 
          ? kcPrimaryColor
          : kcSecondaryTextColor.withOpacity(0.4);

    // Draw 3-5 nodes along the spiral
    for (int i = 0; i < 4; i++) {
      final angle = i * 2.4;
      final r = radius * (0.3 + (i * 0.2));
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      
      canvas.drawCircle(Offset(x, y), nodeRadius, nodePaint);
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
