import 'package:equatable/equatable.dart';

/// P29: AAR-SAGE Incident Template models
/// Structured incident documentation following After Action Review principles

enum IncidentType {
  fire,
  medical,
  rescue,
  hazmat,
  mva,
  law,
  other,
}

extension IncidentTypeExtension on IncidentType {
  String get displayName {
    switch (this) {
      case IncidentType.fire: return 'Structure Fire';
      case IncidentType.medical: return 'Medical Emergency';
      case IncidentType.rescue: return 'Rescue Operation';
      case IncidentType.hazmat: return 'Hazmat Incident';
      case IncidentType.mva: return 'Motor Vehicle Accident';
      case IncidentType.law: return 'Law Enforcement';
      case IncidentType.other: return 'Other';
    }
  }

  String get abbreviation {
    switch (this) {
      case IncidentType.fire: return 'FIRE';
      case IncidentType.medical: return 'EMS';
      case IncidentType.rescue: return 'RESCUE';
      case IncidentType.hazmat: return 'HAZMAT';
      case IncidentType.mva: return 'MVA';
      case IncidentType.law: return 'LAW';
      case IncidentType.other: return 'OTHER';
    }
  }

  List<String> get commonActions {
    switch (this) {
      case IncidentType.fire:
        return [
          'Size-up',
          'Water supply',
          'Ventilation',
          'Search & rescue',
          'Fire attack',
          'Overhaul',
        ];
      case IncidentType.medical:
        return [
          'Scene safety',
          'Patient assessment',
          'Airway management',
          'IV access',
          'Medication admin',
          'Transport prep',
        ];
      case IncidentType.rescue:
        return [
          'Scene assessment',
          'Safety perimeter',
          'Equipment setup',
          'Patient access',
          'Stabilization',
          'Extraction',
        ];
      case IncidentType.hazmat:
        return [
          'Identification',
          'Containment',
          'Decon setup',
          'Entry team',
          'Monitoring',
          'Mitigation',
        ];
      case IncidentType.mva:
        return [
          'Scene safety',
          'Vehicle stabilization',
          'Patient triage',
          'Extrication',
          'Medical care',
          'Traffic control',
        ];
      case IncidentType.law:
        return [
          'Scene control',
          'Witness statements',
          'Evidence collection',
          'Suspect apprehension',
          'Report writing',
          'Community liaison',
        ];
      case IncidentType.other:
        return [];
    }
  }
}

enum IncidentPriority {
  routine,
  urgent, 
  emergency,
  critical,
}

extension IncidentPriorityExtension on IncidentPriority {
  String get displayName {
    switch (this) {
      case IncidentPriority.routine: return 'Routine';
      case IncidentPriority.urgent: return 'Urgent';
      case IncidentPriority.emergency: return 'Emergency';
      case IncidentPriority.critical: return 'Critical';
    }
  }
}

class IncidentTemplate extends Equatable {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Basic incident info
  final IncidentType type;
  final IncidentPriority priority;
  final String incidentNumber;
  final DateTime dispatchTime;
  final DateTime? arrivalTime;
  final DateTime? clearTime;
  
  // Location (will be redacted)
  final String location;
  final String? crossStreets;
  
  // SAGE Framework
  final String situation;          // What happened? Facts only
  final String awareness;          // What did you observe/assess?
  final List<String> goals;        // What were you trying to achieve?
  final String environment;        // Conditions, hazards, constraints
  
  // Actions & Outcomes
  final List<String> actionsCompleted;
  final List<String> challengesFaced;
  final List<String> resourcesUsed;
  final String outcome;
  
  // Learning & Improvement
  final List<String> wentWell;
  final List<String> couldImprove;
  final String keyLearning;
  final String futureConsiderations;
  
  // Team & Communications
  final List<String> unitsInvolved;
  final String communicationNotes;
  final List<String> keyDecisionPoints;
  
  const IncidentTemplate({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.type,
    required this.priority,
    required this.incidentNumber,
    required this.dispatchTime,
    this.arrivalTime,
    this.clearTime,
    required this.location,
    this.crossStreets,
    required this.situation,
    required this.awareness,
    required this.goals,
    required this.environment,
    required this.actionsCompleted,
    required this.challengesFaced,
    required this.resourcesUsed,
    required this.outcome,
    required this.wentWell,
    required this.couldImprove,
    required this.keyLearning,
    required this.futureConsiderations,
    required this.unitsInvolved,
    required this.communicationNotes,
    required this.keyDecisionPoints,
  });

  IncidentTemplate copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    IncidentType? type,
    IncidentPriority? priority,
    String? incidentNumber,
    DateTime? dispatchTime,
    DateTime? arrivalTime,
    DateTime? clearTime,
    String? location,
    String? crossStreets,
    String? situation,
    String? awareness,
    List<String>? goals,
    String? environment,
    List<String>? actionsCompleted,
    List<String>? challengesFaced,
    List<String>? resourcesUsed,
    String? outcome,
    List<String>? wentWell,
    List<String>? couldImprove,
    String? keyLearning,
    String? futureConsiderations,
    List<String>? unitsInvolved,
    String? communicationNotes,
    List<String>? keyDecisionPoints,
  }) {
    return IncidentTemplate(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      incidentNumber: incidentNumber ?? this.incidentNumber,
      dispatchTime: dispatchTime ?? this.dispatchTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      clearTime: clearTime ?? this.clearTime,
      location: location ?? this.location,
      crossStreets: crossStreets ?? this.crossStreets,
      situation: situation ?? this.situation,
      awareness: awareness ?? this.awareness,
      goals: goals ?? this.goals,
      environment: environment ?? this.environment,
      actionsCompleted: actionsCompleted ?? this.actionsCompleted,
      challengesFaced: challengesFaced ?? this.challengesFaced,
      resourcesUsed: resourcesUsed ?? this.resourcesUsed,
      outcome: outcome ?? this.outcome,
      wentWell: wentWell ?? this.wentWell,
      couldImprove: couldImprove ?? this.couldImprove,
      keyLearning: keyLearning ?? this.keyLearning,
      futureConsiderations: futureConsiderations ?? this.futureConsiderations,
      unitsInvolved: unitsInvolved ?? this.unitsInvolved,
      communicationNotes: communicationNotes ?? this.communicationNotes,
      keyDecisionPoints: keyDecisionPoints ?? this.keyDecisionPoints,
    );
  }

  @override
  List<Object?> get props => [
    id, createdAt, updatedAt, type, priority, incidentNumber,
    dispatchTime, arrivalTime, clearTime, location, crossStreets,
    situation, awareness, goals, environment, actionsCompleted,
    challengesFaced, resourcesUsed, outcome, wentWell, couldImprove,
    keyLearning, futureConsiderations, unitsInvolved, communicationNotes,
    keyDecisionPoints,
  ];
}

enum IncidentTemplateStep {
  basicInfo,
  situation,
  awareness,
  goals,
  environment,
  actions,
  outcome,
  learning,
  communication,
  review,
}

extension IncidentTemplateStepExtension on IncidentTemplateStep {
  String get title {
    switch (this) {
      case IncidentTemplateStep.basicInfo: return 'Basic Info';
      case IncidentTemplateStep.situation: return 'Situation';
      case IncidentTemplateStep.awareness: return 'Awareness';
      case IncidentTemplateStep.goals: return 'Goals';
      case IncidentTemplateStep.environment: return 'Environment';
      case IncidentTemplateStep.actions: return 'Actions';
      case IncidentTemplateStep.outcome: return 'Outcome';
      case IncidentTemplateStep.learning: return 'Learning';
      case IncidentTemplateStep.communication: return 'Communication';
      case IncidentTemplateStep.review: return 'Review';
    }
  }

  String get prompt {
    switch (this) {
      case IncidentTemplateStep.basicInfo:
        return 'Enter incident details and timeline';
      case IncidentTemplateStep.situation:
        return 'What happened? Stick to facts only.';
      case IncidentTemplateStep.awareness:
        return 'What did you observe and assess on arrival?';
      case IncidentTemplateStep.goals:
        return 'What were you trying to achieve?';
      case IncidentTemplateStep.environment:
        return 'Describe conditions, hazards, and constraints';
      case IncidentTemplateStep.actions:
        return 'What actions did you take? What challenges arose?';
      case IncidentTemplateStep.outcome:
        return 'What was the final outcome?';
      case IncidentTemplateStep.learning:
        return 'What went well? What could be improved?';
      case IncidentTemplateStep.communication:
        return 'Notes on communications and key decisions';
      case IncidentTemplateStep.review:
        return 'Review and save your incident report';
    }
  }

  String get microcopy {
    switch (this) {
      case IncidentTemplateStep.basicInfo:
        return 'All fields except times are required';
      case IncidentTemplateStep.situation:
        return 'Objective facts only, no opinions';
      case IncidentTemplateStep.awareness:
        return 'Size-up findings and initial assessment';
      case IncidentTemplateStep.goals:
        return 'Primary and secondary objectives';
      case IncidentTemplateStep.environment:
        return 'Weather, terrain, hazards, resource limitations';
      case IncidentTemplateStep.actions:
        return 'Chronological sequence preferred';
      case IncidentTemplateStep.outcome:
        return 'Patient status, property saved, etc.';
      case IncidentTemplateStep.learning:
        return 'For continuous improvement';
      case IncidentTemplateStep.communication:
        return 'Radio issues, coordination notes';
      case IncidentTemplateStep.review:
        return 'Check for completeness and accuracy';
    }
  }

  int get estimatedMinutes {
    switch (this) {
      case IncidentTemplateStep.basicInfo: return 2;
      case IncidentTemplateStep.situation: return 3;
      case IncidentTemplateStep.awareness: return 3;
      case IncidentTemplateStep.goals: return 2;
      case IncidentTemplateStep.environment: return 2;
      case IncidentTemplateStep.actions: return 4;
      case IncidentTemplateStep.outcome: return 2;
      case IncidentTemplateStep.learning: return 3;
      case IncidentTemplateStep.communication: return 2;
      case IncidentTemplateStep.review: return 2;
    }
  }
}

/// Predefined action chips for different incident types
class IncidentActionChips {
  static const Map<IncidentType, List<String>> challengeChips = {
    IncidentType.fire: [
      'Limited water supply',
      'Ventilation issues',
      'Personnel shortage',
      'Equipment failure',
      'Access problems',
      'Structural concerns',
      'Weather conditions',
    ],
    IncidentType.medical: [
      'Difficult airway',
      'IV access issues',
      'Patient cooperation',
      'Family interference',
      'Language barrier',
      'Time pressure',
      'Equipment shortage',
    ],
    IncidentType.rescue: [
      'Access limitations',
      'Weight restrictions',
      'Time constraints',
      'Weather conditions',
      'Equipment issues',
      'Patient condition',
      'Scene safety',
    ],
    IncidentType.hazmat: [
      'Unknown substance',
      'Leak containment',
      'Decon challenges',
      'Evacuation issues',
      'PPE limitations',
      'Weather dispersion',
      'Resource shortage',
    ],
    IncidentType.mva: [
      'Vehicle instability',
      'Entrapment severity',
      'Multiple patients',
      'Traffic hazards',
      'Weather conditions',
      'Equipment access',
      'Power line hazards',
    ],
    IncidentType.law: [
      'Suspect cooperation',
      'Crowd control',
      'Evidence preservation',
      'Witness availability',
      'Language barriers',
      'Legal complexity',
      'Resource coordination',
    ],
  };

  static const Map<IncidentType, List<String>> resourceChips = {
    IncidentType.fire: [
      'Engine companies',
      'Ladder trucks',
      'Tanker/water supply',
      'Chief officers',
      'EMS units',
      'Utilities',
      'Mutual aid',
    ],
    IncidentType.medical: [
      'Ambulance',
      'Paramedic unit',
      'Supervisor',
      'Fire department',
      'Flight crew',
      'Hospital staff',
      'Family members',
    ],
    IncidentType.rescue: [
      'Technical rescue team',
      'Heavy equipment',
      'Rope rescue gear',
      'Confined space equipment',
      'Medical team',
      'Command staff',
      'Specialized units',
    ],
    IncidentType.hazmat: [
      'Hazmat team',
      'Detection equipment',
      'Decon equipment',
      'Chemical references',
      'Protective equipment',
      'Environmental agencies',
      'Specialized contractors',
    ],
    IncidentType.mva: [
      'Fire/rescue units',
      'EMS personnel',
      'Extrication tools',
      'Towing services',
      'Law enforcement',
      'Traffic control',
      'Utility companies',
    ],
    IncidentType.law: [
      'Patrol units',
      'Detectives',
      'Crime scene techs',
      'K9 units',
      'SWAT team',
      'Command staff',
      'DA investigators',
    ],
  };
}