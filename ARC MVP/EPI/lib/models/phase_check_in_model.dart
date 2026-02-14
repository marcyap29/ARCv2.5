// Phase Check-in model for monthly phase recalibration flow.
// Stored in Hive box 'phase_check_ins' for history and pattern analysis.

import 'package:hive/hive.dart';

part 'phase_check_in_model.g.dart';

@HiveType(typeId: 115)
class PhaseCheckIn extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final DateTime checkInDate;

  @HiveField(3)
  final String previousPhase;

  @HiveField(4)
  final String confirmedPhase;

  @HiveField(5)
  final bool wasConfirmed; // true if user said "yes this fits"

  @HiveField(6)
  final bool wasRecalibrated; // true if diagnostic ran

  @HiveField(7)
  final Map<String, dynamic>? diagnosticAnswers; // Q1–Q3 responses

  @HiveField(8)
  final bool wasManualOverride; // true if user picked manually

  @HiveField(9)
  final String? manualOverrideReason; // user's explanation

  @HiveField(10)
  final DateTime? nextCheckInDue;

  PhaseCheckIn({
    required this.id,
    required this.userId,
    required this.checkInDate,
    required this.previousPhase,
    required this.confirmedPhase,
    required this.wasConfirmed,
    required this.wasRecalibrated,
    this.diagnosticAnswers,
    this.wasManualOverride = false,
    this.manualOverrideReason,
    this.nextCheckInDue,
  });

  PhaseCheckIn copyWith({
    String? id,
    String? userId,
    DateTime? checkInDate,
    String? previousPhase,
    String? confirmedPhase,
    bool? wasConfirmed,
    bool? wasRecalibrated,
    Map<String, dynamic>? diagnosticAnswers,
    bool? wasManualOverride,
    String? manualOverrideReason,
    DateTime? nextCheckInDue,
  }) {
    return PhaseCheckIn(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      checkInDate: checkInDate ?? this.checkInDate,
      previousPhase: previousPhase ?? this.previousPhase,
      confirmedPhase: confirmedPhase ?? this.confirmedPhase,
      wasConfirmed: wasConfirmed ?? this.wasConfirmed,
      wasRecalibrated: wasRecalibrated ?? this.wasRecalibrated,
      diagnosticAnswers: diagnosticAnswers ?? this.diagnosticAnswers,
      wasManualOverride: wasManualOverride ?? this.wasManualOverride,
      manualOverrideReason: manualOverrideReason ?? this.manualOverrideReason,
      nextCheckInDue: nextCheckInDue ?? this.nextCheckInDue,
    );
  }
}
