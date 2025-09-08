import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'help_now_models.g.dart';

/// P34: Help Now Models
/// User-configured emergency contacts and support resources

@HiveType(typeId: 52)
class HelpNowContact extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String phoneNumber;
  
  @HiveField(3)
  final String? email;
  
  @HiveField(4)
  final ContactType type;
  
  @HiveField(5)
  final String? notes;
  
  @HiveField(6)
  final bool isActive;
  
  @HiveField(7)
  final int priority; // 1 = highest priority
  
  @HiveField(8)
  final DateTime createdAt;
  
  @HiveField(9)
  final DateTime? lastUsed;

  const HelpNowContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.type,
    this.notes,
    this.isActive = true,
    this.priority = 1,
    required this.createdAt,
    this.lastUsed,
  });

  factory HelpNowContact.create({
    required String name,
    required String phoneNumber,
    String? email,
    required ContactType type,
    String? notes,
    int priority = 1,
  }) {
    return HelpNowContact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phoneNumber: phoneNumber,
      email: email,
      type: type,
      notes: notes,
      priority: priority,
      createdAt: DateTime.now(),
    );
  }

  HelpNowContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    ContactType? type,
    String? notes,
    bool? isActive,
    int? priority,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return HelpNowContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  /// Get formatted phone number for dialing
  String get dialablePhoneNumber {
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Get contact type display name
  String get typeDisplayName {
    switch (type) {
      case ContactType.peer:
        return 'Peer Support';
      case ContactType.supervisor:
        return 'Supervisor';
      case ContactType.counselor:
        return 'Counselor';
      case ContactType.family:
        return 'Family';
      case ContactType.friend:
        return 'Friend';
      case ContactType.emergency:
        return 'Emergency';
      case ContactType.other:
        return 'Other';
    }
  }

  /// Get contact type icon
  String get typeIcon {
    switch (type) {
      case ContactType.peer:
        return '👥';
      case ContactType.supervisor:
        return '👔';
      case ContactType.counselor:
        return '🧠';
      case ContactType.family:
        return '👨‍👩‍👧‍👦';
      case ContactType.friend:
        return '👫';
      case ContactType.emergency:
        return '🚨';
      case ContactType.other:
        return '📞';
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phoneNumber,
        email,
        type,
        notes,
        isActive,
        priority,
        createdAt,
        lastUsed,
      ];
}

/// Types of help contacts
@HiveType(typeId: 53)
enum ContactType {
  @HiveField(0)
  peer,
  @HiveField(1)
  supervisor,
  @HiveField(2)
  counselor,
  @HiveField(3)
  family,
  @HiveField(4)
  friend,
  @HiveField(5)
  emergency,
  @HiveField(6)
  other,
}

/// National support resources
@HiveType(typeId: 54)
class NationalResource extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String phoneNumber;
  
  @HiveField(3)
  final String? website;
  
  @HiveField(4)
  final String description;
  
  @HiveField(5)
  final ResourceType type;
  
  @HiveField(6)
  final bool is24Hour;
  
  @HiveField(7)
  final List<String> specialties;

  const NationalResource({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.website,
    required this.description,
    required this.type,
    this.is24Hour = false,
    this.specialties = const [],
  });

  @override
  List<Object?> get props => [
        id,
        name,
        phoneNumber,
        website,
        description,
        type,
        is24Hour,
        specialties,
      ];
}

/// Types of national resources
@HiveType(typeId: 55)
enum ResourceType {
  @HiveField(0)
  crisis,
  @HiveField(1)
  peerSupport,
  @HiveField(2)
  professional,
  @HiveField(3)
  emergency,
  @HiveField(4)
  information,
}

/// Predefined national resources
class NationalResources {
  static const List<NationalResource> resources = [
    NationalResource(
      id: 'national_suicide_prevention',
      name: 'National Suicide Prevention Lifeline',
      phoneNumber: '988',
      website: 'https://suicidepreventionlifeline.org',
      description: '24/7 crisis support and suicide prevention',
      type: ResourceType.crisis,
      is24Hour: true,
      specialties: ['suicide_prevention', 'crisis_support'],
    ),
    
    NationalResource(
      id: 'crisis_text_line',
      name: 'Crisis Text Line',
      phoneNumber: 'Text HOME to 741741',
      website: 'https://crisistextline.org',
      description: '24/7 crisis support via text message',
      type: ResourceType.crisis,
      is24Hour: true,
      specialties: ['crisis_support', 'text_support'],
    ),
    
    NationalResource(
      id: 'first_responder_support',
      name: 'First Responder Support Network',
      phoneNumber: '1-888-731-3470',
      website: 'https://frstrespondersupport.org',
      description: 'Peer support and resources for first responders',
      type: ResourceType.peerSupport,
      is24Hour: false,
      specialties: ['first_responder', 'peer_support', 'ptsd'],
    ),
    
    NationalResource(
      id: 'national_ptsd_center',
      name: 'National Center for PTSD',
      phoneNumber: '1-800-273-8255',
      website: 'https://ptsd.va.gov',
      description: 'Resources and treatment for PTSD',
      type: ResourceType.professional,
      is24Hour: false,
      specialties: ['ptsd', 'trauma', 'treatment'],
    ),
    
    NationalResource(
      id: 'emergency_services',
      name: 'Emergency Services',
      phoneNumber: '911',
      description: 'Emergency services for immediate danger',
      type: ResourceType.emergency,
      is24Hour: true,
      specialties: ['emergency', 'immediate_danger'],
    ),
  ];

  /// Get resources by type
  static List<NationalResource> getByType(ResourceType type) {
    return resources.where((resource) => resource.type == type).toList();
  }

  /// Get 24/7 resources
  static List<NationalResource> get24HourResources() {
    return resources.where((resource) => resource.is24Hour).toList();
  }

  /// Get resources by specialty
  static List<NationalResource> getBySpecialty(String specialty) {
    return resources.where((resource) => 
        resource.specialties.contains(specialty)).toList();
  }
}

/// Help Now settings
@HiveType(typeId: 56)
class HelpNowSettings extends Equatable {
  @HiveField(0)
  final bool showDisclaimer;
  
  @HiveField(1)
  final bool requireConfirmation;
  
  @HiveField(2)
  final String customDisclaimer;
  
  @HiveField(3)
  final List<String> quickAccessContacts; // Contact IDs
  
  @HiveField(4)
  final bool showNationalResources;
  
  @HiveField(5)
  final bool showEmergencyWarning;

  const HelpNowSettings({
    this.showDisclaimer = true,
    this.requireConfirmation = true,
    this.customDisclaimer = 'This app does not provide emergency counseling. In case of emergency, call 911.',
    this.quickAccessContacts = const [],
    this.showNationalResources = true,
    this.showEmergencyWarning = true,
  });

  HelpNowSettings copyWith({
    bool? showDisclaimer,
    bool? requireConfirmation,
    String? customDisclaimer,
    List<String>? quickAccessContacts,
    bool? showNationalResources,
    bool? showEmergencyWarning,
  }) {
    return HelpNowSettings(
      showDisclaimer: showDisclaimer ?? this.showDisclaimer,
      requireConfirmation: requireConfirmation ?? this.requireConfirmation,
      customDisclaimer: customDisclaimer ?? this.customDisclaimer,
      quickAccessContacts: quickAccessContacts ?? this.quickAccessContacts,
      showNationalResources: showNationalResources ?? this.showNationalResources,
      showEmergencyWarning: showEmergencyWarning ?? this.showEmergencyWarning,
    );
  }

  @override
  List<Object?> get props => [
        showDisclaimer,
        requireConfirmation,
        customDisclaimer,
        quickAccessContacts,
        showNationalResources,
        showEmergencyWarning,
      ];
}

/// Help Now usage statistics
class HelpNowStatistics {
  final int totalCalls;
  final Map<String, int> contactUsage;
  final Map<String, int> resourceUsage;
  final DateTime? lastUsed;
  final List<String> mostUsedContacts;
  final double averageCallsPerWeek;

  const HelpNowStatistics({
    required this.totalCalls,
    required this.contactUsage,
    required this.resourceUsage,
    this.lastUsed,
    required this.mostUsedContacts,
    required this.averageCallsPerWeek,
  });

  /// Check if user is actively using help resources
  bool get isActivelyUsing => totalCalls > 0 && averageCallsPerWeek > 0.5;
}
