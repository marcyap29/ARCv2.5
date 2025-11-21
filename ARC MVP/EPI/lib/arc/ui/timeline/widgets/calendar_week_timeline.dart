// lib/arc/ui/timeline/widgets/calendar_week_timeline.dart
// Calendar week view for timeline visualization

import 'package:flutter/material.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/shared/app_colors.dart';

class CalendarWeekTimeline extends StatefulWidget {
  const CalendarWeekTimeline({super.key});

  @override
  State<CalendarWeekTimeline> createState() => _CalendarWeekTimelineState();
}

class _CalendarWeekTimelineState extends State<CalendarWeekTimeline> {
  PhaseIndex? _phaseIndex;
  DateTime _currentWeekStart = _getWeekStart(DateTime.now());
  bool _isLoading = true;

  static DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    _loadPhaseData();
  }

  Future<void> _loadPhaseData() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      setState(() {
        _phaseIndex = phaseRegimeService.phaseIndex;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading phase data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getPhaseColor(PhaseLabel? label) {
    if (label == null) return Colors.grey;
    switch (label) {
      case PhaseLabel.discovery:
        return Colors.blue;
      case PhaseLabel.transition:
        return Colors.purple;
      case PhaseLabel.growth:
        return Colors.green;
      case PhaseLabel.integration:
        return Colors.orange;
      case PhaseLabel.mastery:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final regimes = _phaseIndex?.allRegimes ?? [];
    final weekDays = List.generate(7, (index) => _currentWeekStart.add(Duration(days: index)));

    return Container(
      height: 60, // Reduced height
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: kcBorderColor),
        borderRadius: BorderRadius.circular(8),
        color: kcSurfaceAltColor.withOpacity(0.3),
      ),
      child: Row(
        children: [
          // Week navigation
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () {
              setState(() {
                _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          // Calendar squares
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: weekDays.map((day) {
                final regime = _phaseIndex?.regimeFor(day);
                final phaseColor = _getPhaseColor(regime?.label);
                final isToday = day.year == DateTime.now().year &&
                    day.month == DateTime.now().month &&
                    day.day == DateTime.now().day;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Could navigate to that day's entries
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: phaseColor.withOpacity(0.3),
                        border: Border.all(
                          color: isToday ? Colors.white : phaseColor.withOpacity(0.5),
                          width: isToday ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getDayName(day.weekday),
                            style: TextStyle(
                              fontSize: 8,
                              color: kcPrimaryTextColor.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 12,
                              color: kcPrimaryTextColor,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () {
              setState(() {
                _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}

