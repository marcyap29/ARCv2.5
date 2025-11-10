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
  final List<Medication> medications;

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
    List<Medication>? medications,
  }) : workouts = workouts ?? const [],
       medications = medications ?? const [];

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
      "medications": medications.map((m) => m.toJson()).toList(),
    }..removeWhere((k, v) => v == null || (v is List && v.isEmpty));
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

class Medication {
  final String name;
  final String? dosage;
  final String? frequency; // e.g., "daily", "twice daily", "as needed"
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final bool isActive;

  Medication({
    required this.name,
    this.dosage,
    this.frequency,
    this.startDate,
    this.endDate,
    this.notes,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "dosage": dosage,
      "frequency": frequency,
      "start_date": startDate?.toUtc().toIso8601String(),
      "end_date": endDate?.toUtc().toIso8601String(),
      "notes": notes,
      "is_active": isActive,
    }..removeWhere((k, v) => v == null);
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name'] as String,
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date'] as String).toLocal()
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String).toLocal()
          : null,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Medication copyWith({
    String? name,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool? isActive,
  }) {
    return Medication(
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }
}


