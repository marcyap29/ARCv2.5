/// Timeline View
///
/// Year/month browser for navigating the user's journal history.
/// Shows collapsible year cards with activity bars and month rows.
/// Each month shows entry count, dominant phase, and phase-colored bar.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/core/constants/phase_colors.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';

/// Data models for timeline hierarchy

class MonthData {
  final int month;
  final int year;
  final int entryCount;
  final String dominantPhase;
  final Color phaseColor;

  const MonthData({
    required this.month,
    required this.year,
    required this.entryCount,
    required this.dominantPhase,
    required this.phaseColor,
  });
}

class YearData {
  final int year;
  final int entryCount;
  final int phaseShifts;
  final List<MonthData> months;

  const YearData({
    required this.year,
    required this.entryCount,
    required this.phaseShifts,
    required this.months,
  });
}

/// Year/month browser widget
class TimelineView extends StatefulWidget {
  final DateTime currentDate;
  final void Function(DateTime) onDateSelected;

  const TimelineView({
    super.key,
    required this.currentDate,
    required this.onDateSelected,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  List<YearData> _years = [];
  String? _expandedYear;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimelineData();
  }

  Future<void> _loadTimelineData() async {
    setState(() => _loading = true);

    try {
      final repo = JournalRepository();
      final entries = await repo.getAllJournalEntries();

      // Group entries by year → month
      final yearMonthMap = <int, Map<int, List<dynamic>>>{};
      for (final entry in entries) {
        final y = entry.createdAt.year;
        final m = entry.createdAt.month;
        yearMonthMap.putIfAbsent(y, () => {});
        yearMonthMap[y]!.putIfAbsent(m, () => []);
        yearMonthMap[y]![m]!.add(entry);
      }

      // Build YearData list sorted descending
      final years = <YearData>[];
      final sortedYears = yearMonthMap.keys.toList()..sort((a, b) => b.compareTo(a));

      for (final year in sortedYears) {
        final monthMap = yearMonthMap[year]!;
        int totalEntries = 0;
        final months = <MonthData>[];

        for (int m = 1; m <= 12; m++) {
          final monthEntries = monthMap[m] ?? [];
          totalEntries += monthEntries.length;

          // Determine dominant phase for the month
          String dominantPhase = 'Discovery';
          if (monthEntries.isNotEmpty) {
            final phaseCounts = <String, int>{};
            for (final e in monthEntries) {
              final p = (e.autoPhase ?? e.phase ?? 'Discovery') as String;
              phaseCounts[p] = (phaseCounts[p] ?? 0) + 1;
            }
            dominantPhase = phaseCounts.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
          }

          months.add(MonthData(
            month: m,
            year: year,
            entryCount: monthEntries.length,
            dominantPhase: dominantPhase,
            phaseColor: PhaseColors.getPhaseColor(dominantPhase),
          ));
        }

        years.add(YearData(
          year: year,
          entryCount: totalEntries,
          phaseShifts: _countPhaseShifts(months),
          months: months,
        ));
      }

      setState(() {
        _years = years;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TimelineView: Error loading data: $e');
      setState(() => _loading = false);
    }
  }

  int _countPhaseShifts(List<MonthData> months) {
    int shifts = 0;
    String? lastPhase;
    for (final m in months) {
      if (m.entryCount == 0) continue;
      if (lastPhase != null && lastPhase != m.dominantPhase) shifts++;
      lastPhase = m.dominantPhase;
    }
    return shifts;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kcPrimaryColor));
    }

    if (_years.isEmpty) {
      return Center(
        child: Text(
          'No entries yet',
          style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.6)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Jump to date
        GestureDetector(
          onTap: _showDatePicker,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kcSurfaceAltColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kcBorderColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: kcSecondaryTextColor.withOpacity(0.6)),
                const SizedBox(width: 12),
                Text(
                  'Jump to specific date...',
                  style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.7), fontSize: 14),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 14, color: kcSecondaryTextColor.withOpacity(0.4)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Your Journey Since ${_years.last.year}',
          style: const TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 16),

        // Year cards
        for (final year in _years) _buildYearCard(year),
      ],
    );
  }

  Widget _buildYearCard(YearData year) {
    final isExpanded = _expandedYear == year.year.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcBorderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Year header
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedYear = isExpanded ? null : year.year.toString();
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(
                    year.year.toString(),
                    style: const TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${year.entryCount} entries · ${year.phaseShifts} phase shifts',
                      style: TextStyle(
                        color: kcSecondaryTextColor.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: kcSecondaryTextColor.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),

          // Activity bar (always visible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildActivityBar(year),
          ),

          // Expanded month rows
          if (isExpanded) ...[
            Divider(color: kcBorderColor.withOpacity(0.3), height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: year.months
                    .where((m) => m.entryCount > 0)
                    .map((m) => _buildMonthRow(m))
                    .toList(),
              ),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildActivityBar(YearData year) {
    final maxCount = year.months.map((m) => m.entryCount).reduce(max).clamp(1, 999);

    return SizedBox(
      height: 32,
      child: Row(
        children: List.generate(12, (i) {
          final month = year.months[i];
          final intensity = (month.entryCount / maxCount).clamp(0.1, 1.0);

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: month.entryCount > 0
                    ? month.phaseColor.withOpacity(intensity)
                    : kcBorderColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMonthRow(MonthData month) {
    final monthName = DateFormat('MMMM').format(DateTime(month.year, month.month));

    return InkWell(
      onTap: () {
        widget.onDateSelected(DateTime(month.year, month.month, 1));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                monthName,
                style: const TextStyle(
                  color: kcPrimaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: month.phaseColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 24,
              child: Text(
                '${month.entryCount}',
                style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.6), fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: Text(
                month.dominantPhase,
                style: TextStyle(color: month.phaseColor, fontSize: 12),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: kcSecondaryTextColor.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: widget.currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kcPrimaryColor,
              surface: kcSurfaceColor,
            ),
          ),
          child: child!,
        );
      },
    ).then((date) {
      if (date != null) {
        widget.onDateSelected(date);
      }
    });
  }
}
