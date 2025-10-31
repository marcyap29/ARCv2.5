import 'dart:convert';

class HealthSummary {
  final DateTime startIso;
  final DateTime endIso;
  final HealthMetrics metrics;
  final HealthFeatures features;
  final HealthVisibility visibility;
  final String source; // "apple_healthkit" | "android_health_connect"

  HealthSummary({
    required this.startIso,
    required this.endIso,
    required this.metrics,
    required this.features,
    required this.visibility,
    required this.source,
  });

  Map<String, dynamic> toMcpJson() {
    return {
      "type": "mcp.health.summary.v1",
      "source": source,
      "start_iso": startIso.toUtc().toIso8601String(),
      "end_iso": endIso.toUtc().toIso8601String(),
      "metrics": metrics.toJson(),
      "features": features.toJson(),
      "visibility": visibility.toJson(),
    };
  }

  String toMcpJsonLine() => jsonEncode(toMcpJson());
}

class HealthMetrics {
  final SleepMetrics? sleep;
  final double? restingHrBpm;
  final double? hrvRmssdMs;
  final int? steps;
  final int? exerciseMinutes;
  final double? activeEnergyKcal;
  final double? restingEnergyKcal;
  final double? weightKg;
  final List<Map<String, dynamic>> workouts;

  HealthMetrics({
    this.sleep,
    this.restingHrBpm,
    this.hrvRmssdMs,
    this.steps,
    this.exerciseMinutes,
    this.activeEnergyKcal,
    this.restingEnergyKcal,
    this.weightKg,
    List<Map<String, dynamic>>? workouts,
  }) : workouts = workouts ?? const [];

  Map<String, dynamic> toJson() {
    return {
      "sleep": sleep?.toJson(),
      "resting_hr_bpm": restingHrBpm,
      "hrv_rmssd_ms": hrvRmssdMs,
      "steps": steps,
      "exercise_minutes": exerciseMinutes,
      "active_energy_kcal": activeEnergyKcal,
      "resting_energy_kcal": restingEnergyKcal,
      "weight_kg": weightKg,
      "workouts": workouts,
    }..removeWhere((k, v) => v == null);
  }
}

class SleepMetrics {
  final int totalMinutes;
  final int? asleepMinutes;
  final int? efficiencyPct;
  final Map<String, int>? stageBreakdown;

  SleepMetrics({
    required this.totalMinutes,
    this.asleepMinutes,
    this.efficiencyPct,
    this.stageBreakdown,
  });

  Map<String, dynamic> toJson() {
    return {
      "total_minutes": totalMinutes,
      "asleep_minutes": asleepMinutes,
      "efficiency_pct": efficiencyPct,
      "stage_breakdown": stageBreakdown,
    }..removeWhere((k, v) => v == null);
  }
}

class HealthFeatures {
  final double? sleepZ;
  final double? hrvZ;
  final double? rhrZ;
  final List<String> flags;

  HealthFeatures({this.sleepZ, this.hrvZ, this.rhrZ, List<String>? flags})
      : flags = flags ?? const [];

  Map<String, dynamic> toJson() {
    return {
      "sleep_z": sleepZ,
      "hrv_z": hrvZ,
      "rhr_z": rhrZ,
      "flags": flags,
    }..removeWhere((k, v) => v == null);
  }
}

class HealthVisibility {
  final bool canShowInChat;
  final bool canShowValuesInChat;

  HealthVisibility({required this.canShowInChat, required this.canShowValuesInChat});

  Map<String, dynamic> toJson() {
    return {
      "can_show_in_chat": canShowInChat,
      "can_show_values_in_chat": canShowValuesInChat,
    };
  }
}

class HealthLinkRecord {
  final String entryId;
  final int windowHours;
  final Map<String, dynamic> affect;
  final List<String> linkedHealthIds;
  final List<String> explanations;

  HealthLinkRecord({
    required this.entryId,
    required this.windowHours,
    required this.affect,
    required this.linkedHealthIds,
    required this.explanations,
  });

  Map<String, dynamic> toMcpJson() {
    return {
      "type": "mcp.health.link.v1",
      "entry_id": entryId,
      "window_hours": windowHours,
      "affect": affect,
      "linked_health_ids": linkedHealthIds,
      "explanations": explanations,
    };
  }
}


