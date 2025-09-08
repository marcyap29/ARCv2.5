import 'package:equatable/equatable.dart';

class FRSettings extends Equatable {
  // Core features
  final bool rapidDebrief;          // P29
  final bool redactionEnabled;      // P28 gate (master)
  final bool shiftAwareCadence;     // P33
  final bool postHeavyEntryCheckIn; // P31
  final bool softVisuals;
  
  // P27: Profile fields
  final String? role;               // 'firefighter', 'paramedic', 'police', 'dispatcher', 'other'
  final String? department;
  final String? shiftPattern;       // '24/48', '12/12', '8/40', 'custom'
  final int? yearsOfService;
  final List<String> specialties;   // ['trauma', 'hazmat', 'rescue', 'flight', etc.]
  
  // P27: Privacy defaults
  final bool autoRedactNames;
  final bool autoRedactLocations;
  final bool autoRedactUnits;
  final bool shareByDefaultRedacted;
  final bool requireConfirmationForShare;

  const FRSettings({
    required this.rapidDebrief,
    required this.redactionEnabled,
    required this.shiftAwareCadence,
    required this.postHeavyEntryCheckIn,
    required this.softVisuals,
    this.role,
    this.department,
    this.shiftPattern,
    this.yearsOfService,
    this.specialties = const [],
    this.autoRedactNames = true,
    this.autoRedactLocations = true,
    this.autoRedactUnits = false,
    this.shareByDefaultRedacted = true,
    this.requireConfirmationForShare = true,
  });

  factory FRSettings.defaults() => const FRSettings(
    rapidDebrief: true,
    redactionEnabled: true,
    shiftAwareCadence: true,
    postHeavyEntryCheckIn: true,
    softVisuals: true,
    role: null,
    department: null,
    shiftPattern: null,
    yearsOfService: null,
    specialties: [],
    autoRedactNames: true,
    autoRedactLocations: true,
    autoRedactUnits: false,
    shareByDefaultRedacted: true,
    requireConfirmationForShare: true,
  );

  FRSettings copyWith({
    bool? rapidDebrief,
    bool? redactionEnabled,
    bool? shiftAwareCadence,
    bool? postHeavyEntryCheckIn,
    bool? softVisuals,
    String? role,
    String? department,
    String? shiftPattern,
    int? yearsOfService,
    List<String>? specialties,
    bool? autoRedactNames,
    bool? autoRedactLocations,
    bool? autoRedactUnits,
    bool? shareByDefaultRedacted,
    bool? requireConfirmationForShare,
  }) => FRSettings(
    rapidDebrief: rapidDebrief ?? this.rapidDebrief,
    redactionEnabled: redactionEnabled ?? this.redactionEnabled,
    shiftAwareCadence: shiftAwareCadence ?? this.shiftAwareCadence,
    postHeavyEntryCheckIn: postHeavyEntryCheckIn ?? this.postHeavyEntryCheckIn,
    softVisuals: softVisuals ?? this.softVisuals,
    role: role ?? this.role,
    department: department ?? this.department,
    shiftPattern: shiftPattern ?? this.shiftPattern,
    yearsOfService: yearsOfService ?? this.yearsOfService,
    specialties: specialties ?? this.specialties,
    autoRedactNames: autoRedactNames ?? this.autoRedactNames,
    autoRedactLocations: autoRedactLocations ?? this.autoRedactLocations,
    autoRedactUnits: autoRedactUnits ?? this.autoRedactUnits,
    shareByDefaultRedacted: shareByDefaultRedacted ?? this.shareByDefaultRedacted,
    requireConfirmationForShare: requireConfirmationForShare ?? this.requireConfirmationForShare,
  );

  /// Check if any first responder features are enabled
  bool get isEnabled => rapidDebrief || redactionEnabled || shiftAwareCadence || postHeavyEntryCheckIn || softVisuals;
  
  /// Check if profile is complete
  bool get hasCompleteProfile => role != null && department != null && shiftPattern != null;
  
  /// Get display role
  String get displayRole {
    switch (role) {
      case 'firefighter': return 'Firefighter';
      case 'paramedic': return 'Paramedic';
      case 'police': return 'Police Officer';
      case 'dispatcher': return 'Dispatcher';
      case 'other': return 'Other';
      default: return 'First Responder';
    }
  }
  
  /// Get shift pattern display
  String get displayShiftPattern {
    switch (shiftPattern) {
      case '24/48': return '24 on / 48 off';
      case '12/12': return '12 on / 12 off';
      case '8/40': return '8 hour / 40 week';
      case 'custom': return 'Custom';
      default: return 'Not specified';
    }
  }

  @override
  List<Object?> get props => [
    rapidDebrief, redactionEnabled, shiftAwareCadence, postHeavyEntryCheckIn, softVisuals,
    role, department, shiftPattern, yearsOfService, specialties,
    autoRedactNames, autoRedactLocations, autoRedactUnits, shareByDefaultRedacted, requireConfirmationForShare
  ];
}