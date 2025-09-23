import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'aurora_lite_models.dart';
import '../checkin/checkin_models.dart';
import '../debrief/debrief_models.dart';
import '../incident_template/incident_report_models.dart';

/// P33: AURORA-Lite Shift Rhythm Service
/// Manages shift-aware prompts and recovery recommendations
class AuroraLiteService {
  static final AuroraLiteService _instance = AuroraLiteService._internal();
  factory AuroraLiteService() => _instance;
  
  late final Box<ShiftSchedule> _shiftBox;
  late final Box<CheckIn> _checkInBox;
  late final Box<DebriefRecord> _debriefBox;
  late final Box<IncidentReport> _incidentBox;

  AuroraLiteService._internal() {
    // Initialize with default empty boxes - in real implementation, these would be injected
    _shiftBox = Hive.box<ShiftSchedule>('shift_schedules');
    _checkInBox = Hive.box<CheckIn>('check_ins');
    _debriefBox = Hive.box<DebriefRecord>('debriefs');
    _incidentBox = Hive.box<IncidentReport>('incidents');
  }

  /// Get current shift status
  Future<ShiftStatus> getCurrentShiftStatus() async {
    final currentTime = DateTime.now();
    final activeSchedule = await getActiveShiftSchedule();
    
    if (activeSchedule == null) {
      return const ShiftStatus(
        isOnShift: false,
        timeUntilNextShift: null,
        timeSinceLastShift: null,
        currentPhase: ShiftPhase.offDuty,
        recommendedActions: [],
      );
    }

    final isOnShift = _isCurrentlyOnShift(activeSchedule, currentTime);
    final timeUntilNextShift = _getTimeUntilNextShift(activeSchedule, currentTime);
    final timeSinceLastShift = _getTimeSinceLastShift(activeSchedule, currentTime);
    final currentPhase = _getCurrentPhase(activeSchedule, currentTime);
    final recommendedActions = await _getRecommendedActions(activeSchedule, currentPhase);

    return ShiftStatus(
      isOnShift: isOnShift,
      timeUntilNextShift: timeUntilNextShift,
      timeSinceLastShift: timeSinceLastShift,
      currentPhase: currentPhase,
      recommendedActions: recommendedActions,
    );
  }

  /// Get active shift schedule
  Future<ShiftSchedule?> getActiveShiftSchedule() async {
    final schedules = _shiftBox.values.where((schedule) => schedule.isActive).toList();
    if (schedules.isEmpty) return null;
    
    // Return the most recently created active schedule
    schedules.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return schedules.first;
  }

  /// Create or update shift schedule
  Future<void> setShiftSchedule(ShiftSchedule schedule) async {
    // Deactivate all existing schedules
    for (final existingSchedule in _shiftBox.values) {
      if (existingSchedule.isActive) {
        await _shiftBox.put(existingSchedule.id, existingSchedule.copyWith(isActive: false));
      }
    }
    
    // Save new schedule
    await _shiftBox.put(schedule.id, schedule);
  }

  /// Get shift-aware prompts
  Future<List<ShiftPrompt>> getShiftPrompts() async {
    final status = await getCurrentShiftStatus();
    final prompts = <ShiftPrompt>[];

    // Check-in prompts
    if (status.isOnShift) {
      // During shift prompts
      prompts.addAll(_getDuringShiftPrompts(status));
    } else {
      // Off-duty prompts
      prompts.addAll(_getOffDutyPrompts(status));
    }

    // Recovery prompts based on recent activity
    final recoveryPrompts = await _getRecoveryPrompts();
    prompts.addAll(recoveryPrompts);

    // Sort by priority and return
    prompts.sort((a, b) => b.priority.compareTo(a.priority));
    return prompts;
  }

  /// Get recovery recommendations
  Future<RecoveryRecommendation> getRecoveryRecommendation() async {
    final status = await getCurrentShiftStatus();
    final recentActivity = await _analyzeRecentActivity();
    
    return RecoveryRecommendation(
      stressLevel: recentActivity.averageStress,
      sleepQuality: recentActivity.averageSleep,
      incidentCount: recentActivity.recentIncidents,
      debriefCount: recentActivity.recentDebriefs,
      recommendations: _generateRecoveryRecommendations(recentActivity, status),
      urgencyLevel: _calculateUrgencyLevel(recentActivity),
    );
  }

  /// Get shift statistics
  Future<ShiftStatistics> getShiftStatistics({int days = 30}) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    
    final checkIns = _checkInBox.values
        .where((checkIn) => checkIn.timestamp.isAfter(startDate))
        .toList();
    
    final debriefs = _debriefBox.values
        .where((debrief) => debrief.createdAt.isAfter(startDate))
        .toList();
    
    final incidents = _incidentBox.values
        .where((incident) => incident.createdAt.isAfter(startDate))
        .toList();

    return ShiftStatistics(
      periodDays: days,
      totalCheckIns: checkIns.length,
      totalDebriefs: debriefs.length,
      totalIncidents: incidents.length,
      averageStress: _calculateAverageStress(checkIns),
      averageSleep: _calculateAverageSleep(checkIns),
      highStressDays: checkIns.where((c) => c.stressLevel >= 7).length,
      recoveryDays: _calculateRecoveryDays(checkIns),
      trendAnalysis: _analyzeTrends(checkIns, debriefs, incidents),
    );
  }

  // Private helper methods

  bool _isCurrentlyOnShift(ShiftSchedule schedule, DateTime currentTime) {
    final currentDay = currentTime.weekday;
    final currentTimeOfDay = TimeOfDay.fromDateTime(currentTime);
    
    for (final shift in schedule.shifts) {
      if (shift.daysOfWeek.contains(currentDay)) {
        final shiftStart = TimeOfDay(hour: shift.startHour, minute: shift.startMinute);
        final shiftEnd = TimeOfDay(hour: shift.endHour, minute: shift.endMinute);
        
        if (_isTimeInRange(currentTimeOfDay, shiftStart, shiftEnd)) {
          return true;
        }
      }
    }
    
    return false;
  }

  Duration? _getTimeUntilNextShift(ShiftSchedule schedule, DateTime currentTime) {
    final nextShift = _findNextShift(schedule, currentTime);
    if (nextShift == null) return null;
    
    final nextShiftDateTime = _getNextShiftDateTime(nextShift, currentTime);
    return nextShiftDateTime.difference(currentTime);
  }

  Duration? _getTimeSinceLastShift(ShiftSchedule schedule, DateTime currentTime) {
    final lastShift = _findLastShift(schedule, currentTime);
    if (lastShift == null) return null;
    
    final lastShiftDateTime = _getLastShiftDateTime(lastShift, currentTime);
    return currentTime.difference(lastShiftDateTime);
  }

  ShiftPhase _getCurrentPhase(ShiftSchedule schedule, DateTime currentTime) {
    final isOnShift = _isCurrentlyOnShift(schedule, currentTime);
    
    if (isOnShift) {
      return ShiftPhase.onDuty;
    }
    
    final timeSinceLastShift = _getTimeSinceLastShift(schedule, currentTime);
    if (timeSinceLastShift == null) {
      return ShiftPhase.offDuty;
    }
    
    if (timeSinceLastShift.inHours < 12) {
      return ShiftPhase.immediateRecovery;
    } else if (timeSinceLastShift.inDays < 2) {
      return ShiftPhase.shortTermRecovery;
    } else {
      return ShiftPhase.longTermRecovery;
    }
  }

  Future<List<ShiftAction>> _getRecommendedActions(ShiftSchedule schedule, ShiftPhase phase) async {
    final actions = <ShiftAction>[];
    
    switch (phase) {
      case ShiftPhase.onDuty:
        actions.addAll(_getOnDutyActions());
        break;
      case ShiftPhase.immediateRecovery:
        actions.addAll(_getImmediateRecoveryActions());
        break;
      case ShiftPhase.shortTermRecovery:
        actions.addAll(_getShortTermRecoveryActions());
        break;
      case ShiftPhase.longTermRecovery:
        actions.addAll(_getLongTermRecoveryActions());
        break;
      case ShiftPhase.offDuty:
        actions.addAll(_getOffDutyActions());
        break;
    }
    
    return actions;
  }

  List<ShiftAction> _getOnDutyActions() {
    return [
      const ShiftAction(
        id: 'check_in_during_shift',
        title: 'Check In',
        description: 'How are you feeling right now?',
        type: ActionType.checkIn,
        priority: 8,
        estimatedMinutes: 2,
      ),
      const ShiftAction(
        id: 'quick_debrief_after_call',
        title: 'Quick Debrief',
        description: 'Brief reflection after a call',
        type: ActionType.debrief,
        priority: 7,
        estimatedMinutes: 5,
      ),
    ];
  }

  List<ShiftAction> _getImmediateRecoveryActions() {
    return [
      const ShiftAction(
        id: 'end_of_shift_check_in',
        title: 'End of Shift Check-in',
        description: 'Reflect on your shift',
        type: ActionType.checkIn,
        priority: 9,
        estimatedMinutes: 3,
      ),
      const ShiftAction(
        id: 'full_debrief',
        title: 'Full Debrief',
        description: 'Complete debrief process',
        type: ActionType.debrief,
        priority: 8,
        estimatedMinutes: 15,
      ),
      const ShiftAction(
        id: 'grounding_exercise',
        title: 'Grounding Exercise',
        description: 'Calm your nervous system',
        type: ActionType.grounding,
        priority: 7,
        estimatedMinutes: 5,
      ),
    ];
  }

  List<ShiftAction> _getShortTermRecoveryActions() {
    return [
      const ShiftAction(
        id: 'recovery_check_in',
        title: 'Recovery Check-in',
        description: 'How is your recovery going?',
        type: ActionType.checkIn,
        priority: 6,
        estimatedMinutes: 2,
      ),
      const ShiftAction(
        id: 'wellness_activity',
        title: 'Wellness Activity',
        description: 'Engage in a wellness activity',
        type: ActionType.wellness,
        priority: 5,
        estimatedMinutes: 30,
      ),
    ];
  }

  List<ShiftAction> _getLongTermRecoveryActions() {
    return [
      const ShiftAction(
        id: 'general_check_in',
        title: 'General Check-in',
        description: 'How are you doing overall?',
        type: ActionType.checkIn,
        priority: 4,
        estimatedMinutes: 2,
      ),
      const ShiftAction(
        id: 'reflection_exercise',
        title: 'Reflection Exercise',
        description: 'Reflect on recent experiences',
        type: ActionType.reflection,
        priority: 3,
        estimatedMinutes: 10,
      ),
    ];
  }

  List<ShiftAction> _getOffDutyActions() {
    return [
      const ShiftAction(
        id: 'general_wellness',
        title: 'General Wellness',
        description: 'Maintain your wellness routine',
        type: ActionType.wellness,
        priority: 2,
        estimatedMinutes: 15,
      ),
    ];
  }

  List<ShiftPrompt> _getDuringShiftPrompts(ShiftStatus status) {
    return [
      const ShiftPrompt(
        id: 'shift_check_in',
        title: 'Shift Check-in',
        message: 'How are you feeling during your shift?',
        type: PromptType.checkIn,
        priority: 8,
        estimatedMinutes: 2,
      ),
      const ShiftPrompt(
        id: 'post_call_debrief',
        title: 'Post-Call Debrief',
        message: 'Take a moment to reflect after that call',
        type: PromptType.debrief,
        priority: 7,
        estimatedMinutes: 5,
      ),
    ];
  }

  List<ShiftPrompt> _getOffDutyPrompts(ShiftStatus status) {
    final prompts = <ShiftPrompt>[];
    
    if (status.timeSinceLastShift != null) {
      final hoursSince = status.timeSinceLastShift!.inHours;
      
      if (hoursSince < 2) {
        prompts.add(const ShiftPrompt(
          id: 'immediate_recovery',
          title: 'Immediate Recovery',
          message: 'Take time to decompress after your shift',
          type: PromptType.recovery,
          priority: 9,
          estimatedMinutes: 15,
        ));
      } else if (hoursSince < 24) {
        prompts.add(const ShiftPrompt(
          id: 'short_term_recovery',
          title: 'Short-term Recovery',
          message: 'How is your recovery going?',
          type: PromptType.checkIn,
          priority: 6,
          estimatedMinutes: 3,
        ));
      }
    }
    
    return prompts;
  }

  Future<List<ShiftPrompt>> _getRecoveryPrompts() async {
    final recentActivity = await _analyzeRecentActivity();
    final prompts = <ShiftPrompt>[];
    
    if (recentActivity.averageStress > 6) {
      prompts.add(const ShiftPrompt(
        id: 'high_stress_recovery',
        title: 'High Stress Recovery',
        message: 'You\'ve had some stressful shifts. Consider extra recovery time.',
        type: PromptType.recovery,
        priority: 8,
        estimatedMinutes: 20,
      ));
    }
    
    if (recentActivity.recentIncidents > 3) {
      prompts.add(const ShiftPrompt(
        id: 'high_incident_recovery',
        title: 'High Incident Recovery',
        message: 'You\'ve had several incidents recently. How are you processing them?',
        type: PromptType.debrief,
        priority: 7,
        estimatedMinutes: 10,
      ));
    }
    
    return prompts;
  }

  Future<RecentActivity> _analyzeRecentActivity() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 7));
    
    final checkIns = _checkInBox.values
        .where((checkIn) => checkIn.timestamp.isAfter(startDate))
        .toList();
    
    final debriefs = _debriefBox.values
        .where((debrief) => debrief.createdAt.isAfter(startDate))
        .toList();
    
    final incidents = _incidentBox.values
        .where((incident) => incident.createdAt.isAfter(startDate))
        .toList();

    return RecentActivity(
      averageStress: _calculateAverageStress(checkIns),
      averageSleep: _calculateAverageSleep(checkIns),
      recentDebriefs: debriefs.length,
      recentIncidents: incidents.length,
      highStressDays: checkIns.where((c) => c.stressLevel >= 7).length,
    );
  }

  double _calculateAverageStress(List<CheckIn> checkIns) {
    if (checkIns.isEmpty) return 0.0;
    return checkIns.fold(0.0, (sum, checkIn) => sum + checkIn.stressLevel) / checkIns.length;
  }

  double _calculateAverageSleep(List<CheckIn> checkIns) {
    if (checkIns.isEmpty) return 0.0;
    return checkIns.fold(0.0, (sum, checkIn) => sum + checkIn.sleepHours) / checkIns.length;
  }

  int _calculateRecoveryDays(List<CheckIn> checkIns) {
    // Count days where stress level was low (<= 4) and sleep was good (>= 7 hours)
    final recoveryDays = checkIns.where((checkIn) => 
        checkIn.stressLevel <= 4 && checkIn.sleepHours >= 7).length;
    return recoveryDays;
  }

  List<String> _generateRecoveryRecommendations(RecentActivity activity, ShiftStatus status) {
    final recommendations = <String>[];
    
    if (activity.averageStress > 6) {
      recommendations.add('Consider taking extra recovery time between shifts');
      recommendations.add('Practice grounding exercises daily');
    }
    
    if (activity.averageSleep < 6) {
      recommendations.add('Focus on improving sleep quality and duration');
      recommendations.add('Establish a consistent sleep routine');
    }
    
    if (activity.recentIncidents > 3) {
      recommendations.add('Consider scheduling additional debrief sessions');
      recommendations.add('Connect with peer support resources');
    }
    
    if (activity.highStressDays > 3) {
      recommendations.add('Monitor your stress levels closely');
      recommendations.add('Consider speaking with a counselor or supervisor');
    }
    
    return recommendations;
  }

  UrgencyLevel _calculateUrgencyLevel(RecentActivity activity) {
    if (activity.averageStress > 7 || activity.highStressDays > 5) {
      return UrgencyLevel.high;
    } else if (activity.averageStress > 5 || activity.highStressDays > 3) {
      return UrgencyLevel.medium;
    } else {
      return UrgencyLevel.low;
    }
  }

  TrendAnalysis _analyzeTrends(List<CheckIn> checkIns, List<DebriefRecord> debriefs, List<IncidentReport> incidents) {
    // Simple trend analysis - in a real implementation, this would be more sophisticated
    final stressTrend = _calculateTrend(checkIns.map((c) => c.stressLevel.toDouble()).toList());
    final sleepTrend = _calculateTrend(checkIns.map((c) => c.sleepHours.toDouble()).toList());
    
    return TrendAnalysis(
      stressTrend: stressTrend,
      sleepTrend: sleepTrend,
      debriefFrequency: debriefs.length / 30.0, // per day
      incidentFrequency: incidents.length / 30.0, // per day
    );
  }

  TrendDirection _calculateTrend(List<double> values) {
    if (values.length < 2) return TrendDirection.stable;
    
    final firstHalf = values.take(values.length ~/ 2).fold(0.0, (sum, val) => sum + val) / (values.length ~/ 2);
    final secondHalf = values.skip(values.length ~/ 2).fold(0.0, (sum, val) => sum + val) / (values.length - values.length ~/ 2);
    
    final difference = secondHalf - firstHalf;
    if (difference > 0.5) return TrendDirection.increasing;
    if (difference < -0.5) return TrendDirection.decreasing;
    return TrendDirection.stable;
  }

  // Additional helper methods for shift calculations
  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Shift crosses midnight
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  Shift? _findNextShift(ShiftSchedule schedule, DateTime currentTime) {
    // Implementation would find the next upcoming shift
    // This is a simplified version
    return schedule.shifts.isNotEmpty ? schedule.shifts.first : null;
  }

  Shift? _findLastShift(ShiftSchedule schedule, DateTime currentTime) {
    // Implementation would find the most recent completed shift
    // This is a simplified version
    return schedule.shifts.isNotEmpty ? schedule.shifts.first : null;
  }

  DateTime _getNextShiftDateTime(Shift shift, DateTime currentTime) {
    // Implementation would calculate the exact datetime of the next shift
    // This is a simplified version
    return currentTime.add(const Duration(hours: 8));
  }

  DateTime _getLastShiftDateTime(Shift shift, DateTime currentTime) {
    // Implementation would calculate the exact datetime of the last shift
    // This is a simplified version
    return currentTime.subtract(const Duration(hours: 8));
  }
}
