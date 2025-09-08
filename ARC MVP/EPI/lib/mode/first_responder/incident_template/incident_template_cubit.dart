import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'incident_template_models.dart';
import 'incident_report_models.dart';

/// P29: AAR-SAGE Incident Template Cubit
/// Manages state for incident template creation and editing
class IncidentTemplateCubit extends Cubit<IncidentTemplateState> {
  final Box<IncidentReport> _incidentBox;

  IncidentTemplateCubit({required Box<IncidentReport> incidentBox})
      : _incidentBox = incidentBox,
        super(const IncidentTemplateState());

  /// Set incident type
  void setIncidentType(IncidentType type) {
    emit(state.copyWith(incidentType: type));
  }

  /// Set incident ID
  void setIncidentId(String id) {
    emit(state.copyWith(incidentId: id));
  }

  /// Update AAR data
  void updateAARData(AARData aarData) {
    emit(state.copyWith(aarData: aarData));
  }

  /// Update SAGE data
  void updateSAGEData(SAGEData sageData) {
    emit(state.copyWith(sageData: sageData));
  }

  /// Toggle incident tag
  void toggleTag(IncidentTag tag) {
    final currentTags = List<IncidentTag>.from(state.selectedTags);
    if (currentTags.contains(tag)) {
      currentTags.remove(tag);
    } else {
      currentTags.add(tag);
    }
    emit(state.copyWith(selectedTags: currentTags));
  }

  /// Set custom tags
  void setCustomTags(List<String> customTags) {
    emit(state.copyWith(customTags: customTags));
  }

  /// Set stress level
  void setStressLevel(int level) {
    emit(state.copyWith(stressLevel: level));
  }

  /// Set severity level
  void setSeverityLevel(SeverityLevel level) {
    emit(state.copyWith(severityLevel: level));
  }

  /// Set location
  void setLocation(String location) {
    emit(state.copyWith(location: location));
  }

  /// Set duration
  void setDuration(Duration duration) {
    emit(state.copyWith(duration: duration));
  }

  /// Set personnel involved
  void setPersonnelInvolved(List<String> personnel) {
    emit(state.copyWith(personnelInvolved: personnel));
  }

  /// Set equipment used
  void setEquipmentUsed(List<String> equipment) {
    emit(state.copyWith(equipmentUsed: equipment));
  }

  /// Set lessons learned
  void setLessonsLearned(String lessons) {
    emit(state.copyWith(lessonsLearned: lessons));
  }

  /// Set recommendations
  void setRecommendations(String recommendations) {
    emit(state.copyWith(recommendations: recommendations));
  }

  /// Save incident report
  Future<void> saveIncident() async {
    if (state.incidentType == null) {
      throw Exception('Incident type is required');
    }

    final incident = IncidentReport(
      id: state.incidentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: state.incidentType!,
      aarData: state.aarData,
      sageData: state.sageData,
      tags: state.selectedTags,
      customTags: state.customTags,
      stressLevel: state.stressLevel,
      severityLevel: state.severityLevel,
      location: state.location,
      duration: state.duration,
      personnelInvolved: state.personnelInvolved,
      equipmentUsed: state.equipmentUsed,
      lessonsLearned: state.lessonsLearned,
      recommendations: state.recommendations,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _incidentBox.put(incident.id, incident);
    
    // Reset state after successful save
    emit(const IncidentTemplateState());
  }

  /// Load existing incident for editing
  void loadIncident(String incidentId) {
    final incident = _incidentBox.get(incidentId);
    if (incident != null) {
      emit(IncidentTemplateState(
        incidentType: incident.type,
        incidentId: incident.id,
        aarData: incident.aarData,
        sageData: incident.sageData,
        selectedTags: incident.tags,
        customTags: incident.customTags,
        stressLevel: incident.stressLevel,
        severityLevel: incident.severityLevel,
        location: incident.location,
        duration: incident.duration,
        personnelInvolved: incident.personnelInvolved,
        equipmentUsed: incident.equipmentUsed,
        lessonsLearned: incident.lessonsLearned,
        recommendations: incident.recommendations,
      ));
    }
  }

  /// Get all incidents
  List<IncidentReport> getAllIncidents() {
    return _incidentBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get incidents by type
  List<IncidentReport> getIncidentsByType(IncidentType type) {
    return _incidentBox.values
        .where((incident) => incident.type == type)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get incidents by tag
  List<IncidentReport> getIncidentsByTag(IncidentTag tag) {
    return _incidentBox.values
        .where((incident) => incident.tags.contains(tag))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Delete incident
  Future<void> deleteIncident(String incidentId) async {
    await _incidentBox.delete(incidentId);
  }

  /// Get incident statistics
  Map<String, dynamic> getIncidentStatistics() {
    final incidents = _incidentBox.values.toList();
    
    if (incidents.isEmpty) {
      return {
        'total': 0,
        'byType': {},
        'byTag': {},
        'averageStress': 0.0,
        'averageSeverity': 0.0,
      };
    }

    // Count by type
    final byType = <IncidentType, int>{};
    for (final incident in incidents) {
      byType[incident.type] = (byType[incident.type] ?? 0) + 1;
    }

    // Count by tag
    final byTag = <IncidentTag, int>{};
    for (final incident in incidents) {
      for (final tag in incident.tags) {
        byTag[tag] = (byTag[tag] ?? 0) + 1;
      }
    }

    // Calculate averages
    final totalStress = incidents.fold<int>(0, (sum, incident) => sum + incident.stressLevel);
    final averageStress = totalStress / incidents.length;

    final severityValues = incidents.map((incident) => incident.severityLevel.index + 1).toList();
    final totalSeverity = severityValues.fold<int>(0, (sum, value) => sum + value);
    final averageSeverity = totalSeverity / incidents.length;

    return {
      'total': incidents.length,
      'byType': byType.map((key, value) => MapEntry(key.name, value)),
      'byTag': byTag.map((key, value) => MapEntry(key.name, value)),
      'averageStress': averageStress,
      'averageSeverity': averageSeverity,
    };
  }
}

/// State for incident template creation/editing
class IncidentTemplateState extends Equatable {
  final IncidentType? incidentType;
  final String? incidentId;
  final AARData aarData;
  final SAGEData sageData;
  final List<IncidentTag> selectedTags;
  final List<String> customTags;
  final int stressLevel;
  final SeverityLevel severityLevel;
  final String location;
  final Duration duration;
  final List<String> personnelInvolved;
  final List<String> equipmentUsed;
  final String lessonsLearned;
  final String recommendations;

  const IncidentTemplateState({
    this.incidentType,
    this.incidentId,
    this.aarData = const AARData(),
    this.sageData = const SAGEData(),
    this.selectedTags = const [],
    this.customTags = const [],
    this.stressLevel = 5,
    this.severityLevel = SeverityLevel.medium,
    this.location = '',
    this.duration = Duration.zero,
    this.personnelInvolved = const [],
    this.equipmentUsed = const [],
    this.lessonsLearned = '',
    this.recommendations = '',
  });

  IncidentTemplateState copyWith({
    IncidentType? incidentType,
    String? incidentId,
    AARData? aarData,
    SAGEData? sageData,
    List<IncidentTag>? selectedTags,
    List<String>? customTags,
    int? stressLevel,
    SeverityLevel? severityLevel,
    String? location,
    Duration? duration,
    List<String>? personnelInvolved,
    List<String>? equipmentUsed,
    String? lessonsLearned,
    String? recommendations,
  }) {
    return IncidentTemplateState(
      incidentType: incidentType ?? this.incidentType,
      incidentId: incidentId ?? this.incidentId,
      aarData: aarData ?? this.aarData,
      sageData: sageData ?? this.sageData,
      selectedTags: selectedTags ?? this.selectedTags,
      customTags: customTags ?? this.customTags,
      stressLevel: stressLevel ?? this.stressLevel,
      severityLevel: severityLevel ?? this.severityLevel,
      location: location ?? this.location,
      duration: duration ?? this.duration,
      personnelInvolved: personnelInvolved ?? this.personnelInvolved,
      equipmentUsed: equipmentUsed ?? this.equipmentUsed,
      lessonsLearned: lessonsLearned ?? this.lessonsLearned,
      recommendations: recommendations ?? this.recommendations,
    );
  }

  @override
  List<Object?> get props => [
        incidentType,
        incidentId,
        aarData,
        sageData,
        selectedTags,
        customTags,
        stressLevel,
        severityLevel,
        location,
        duration,
        personnelInvolved,
        equipmentUsed,
        lessonsLearned,
        recommendations,
      ];
}
