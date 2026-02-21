// lib/arc/phase/share/phase_share_models.dart
// Models for phase transition sharing feature

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/phase_models.dart';

/// Platform types for sharing
enum SharePlatform {
  instagram,
  linkedin,
  twitter,
  generic,
}

/// Phase timeline data for visualization
class PhaseTimelineData {
  final PhaseLabel phase;
  final DateTime start;
  final DateTime? end;
  final Color color;

  PhaseTimelineData({
    required this.phase,
    required this.start,
    this.end,
    required this.color,
  });

  Duration get duration => (end ?? DateTime.now()).difference(start);
  bool get isOngoing => end == null;
}

/// Phase share data model
class PhaseShare {
  final String phaseId;
  final PhaseLabel phaseName;
  final DateTime transitionDate;
  final String userCaption;
  
  // Optional fields (user-controlled)
  final bool includeDuration;
  final bool includePhaseCount;
  final bool includeTimeline;
  
  // Generated assets
  final Uint8List? imageBytes;
  final SharePlatform? platform;
  
  // Timeline data (last 6 months)
  final List<PhaseTimelineData> timelineData;
  
  // Phase count (e.g., "My 3rd Discovery phase")
  final int? phaseCount;
  
  // Duration in previous phase
  final Duration? previousPhaseDuration;

  PhaseShare({
    required this.phaseId,
    required this.phaseName,
    required this.transitionDate,
    required this.userCaption,
    this.includeDuration = false,
    this.includePhaseCount = false,
    this.includeTimeline = true,
    this.imageBytes,
    this.platform,
    this.timelineData = const [],
    this.phaseCount,
    this.previousPhaseDuration,
  });

  /// Get display name for phase
  String get phaseDisplayName {
    switch (phaseName) {
      case PhaseLabel.discovery:
        return 'Discovery';
      case PhaseLabel.expansion:
        return 'Expansion';
      case PhaseLabel.transition:
        return 'Transition';
      case PhaseLabel.consolidation:
        return 'Consolidation';
      case PhaseLabel.recovery:
        return 'Recovery';
      case PhaseLabel.breakthrough:
        return 'Breakthrough';
    }
  }

  /// Get formatted transition date
  String get formattedDate {
    final month = transitionDate.month.toString().padLeft(2, '0');
    final day = transitionDate.day.toString().padLeft(2, '0');
    final year = transitionDate.year;
    return '$month/$day/$year';
  }

  /// Get formatted duration string
  String? get formattedDuration {
    if (!includeDuration || previousPhaseDuration == null) return null;
    final days = previousPhaseDuration!.inDays;
    if (days == 0) return null;
    return 'After $days ${days == 1 ? 'day' : 'days'}';
  }

  /// Get formatted phase count string
  String? get formattedPhaseCount {
    if (!includePhaseCount || phaseCount == null) return null;
    final ordinal = _getOrdinal(phaseCount!);
    return 'My $ordinal $phaseDisplayName phase';
  }

  String _getOrdinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  /// Copy with method for immutability
  PhaseShare copyWith({
    String? phaseId,
    PhaseLabel? phaseName,
    DateTime? transitionDate,
    String? userCaption,
    bool? includeDuration,
    bool? includePhaseCount,
    bool? includeTimeline,
    Uint8List? imageBytes,
    SharePlatform? platform,
    List<PhaseTimelineData>? timelineData,
    int? phaseCount,
    Duration? previousPhaseDuration,
  }) {
    return PhaseShare(
      phaseId: phaseId ?? this.phaseId,
      phaseName: phaseName ?? this.phaseName,
      transitionDate: transitionDate ?? this.transitionDate,
      userCaption: userCaption ?? this.userCaption,
      includeDuration: includeDuration ?? this.includeDuration,
      includePhaseCount: includePhaseCount ?? this.includePhaseCount,
      includeTimeline: includeTimeline ?? this.includeTimeline,
      imageBytes: imageBytes ?? this.imageBytes,
      platform: platform ?? this.platform,
      timelineData: timelineData ?? this.timelineData,
      phaseCount: phaseCount ?? this.phaseCount,
      previousPhaseDuration: previousPhaseDuration ?? this.previousPhaseDuration,
    );
  }
}

