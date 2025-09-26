import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../privacy/privacy_controls.dart';

part 'hive_storage_settings.g.dart';

/// Storage profile enum for Hive
@HiveType(typeId: 40)
enum StorageProfile {
  @HiveField(0)
  @JsonValue('minimal')
  minimal,
  
  @HiveField(1)
  @JsonValue('balanced')
  balanced,
  
  @HiveField(2)
  @JsonValue('hifi')
  hifi,
}

/// Enhanced storage settings with Hive persistence
@HiveType(typeId: 41)
@JsonSerializable()
class HiveStorageSettings extends HiveObject {
  @HiveField(0)
  StorageProfile global;
  
  @HiveField(1)
  Map<String, StorageProfile> perMode;
  
  @HiveField(2)
  int retentionDays;
  
  @HiveField(3)
  bool enableAutoOffload;
  
  @HiveField(4)
  int autoOffloadDays;
  
  @HiveField(5)
  bool enableRetentionPruner;
  
  @HiveField(6)
  String retentionStrategy;
  
  @HiveField(7)
  Map<String, dynamic> privacySettings;
  
  @HiveField(8)
  DateTime lastUpdated;
  
  @HiveField(9)
  int version;

  HiveStorageSettings({
    this.global = StorageProfile.minimal,
    Map<String, StorageProfile>? perMode,
    this.retentionDays = 30,
    this.enableAutoOffload = true,
    this.autoOffloadDays = 30,
    this.enableRetentionPruner = true,
    this.retentionStrategy = 'lru',
    Map<String, dynamic>? privacySettings,
    DateTime? lastUpdated,
    this.version = 1,
  })  : perMode = perMode ?? _defaultModeSettings(),
        privacySettings = privacySettings ?? _defaultPrivacySettings(),
        lastUpdated = lastUpdated ?? DateTime.now();

  factory HiveStorageSettings.fromJson(Map<String, dynamic> json) => _$HiveStorageSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$HiveStorageSettingsToJson(this);

  /// Default per-mode storage settings
  static Map<String, StorageProfile> _defaultModeSettings() {
    return {
      'personal': StorageProfile.minimal,
      'first_responder': StorageProfile.hifi,
      'coach': StorageProfile.hifi,
    };
  }

  /// Default privacy settings
  static Map<String, dynamic> _defaultPrivacySettings() {
    return PrivacySettings.balanced.toJson();
  }

  /// Get effective storage profile for a mode
  StorageProfile effectiveProfile({
    required String mode,
    StorageProfile? perImportOverride,
  }) {
    if (perImportOverride != null) return perImportOverride;
    return perMode[mode] ?? global;
  }

  /// Get privacy settings
  PrivacySettings getPrivacySettings() {
    try {
      return PrivacySettings.fromJson(privacySettings);
    } catch (e) {
      print('HiveStorageSettings: Error parsing privacy settings, using defaults: $e');
      return PrivacySettings.balanced;
    }
  }

  /// Update privacy settings
  void updatePrivacySettings(PrivacySettings settings) {
    privacySettings = settings.toJson();
    lastUpdated = DateTime.now();
    save(); // Persist to Hive
  }

  /// Update storage profile for a mode
  void updateModeProfile(String mode, StorageProfile profile) {
    perMode[mode] = profile;
    lastUpdated = DateTime.now();
    save(); // Persist to Hive
  }

  /// Update retention settings
  void updateRetentionSettings({
    int? retentionDays,
    bool? enableAutoOffload,
    int? autoOffloadDays,
    bool? enableRetentionPruner,
    String? retentionStrategy,
  }) {
    if (retentionDays != null) this.retentionDays = retentionDays;
    if (enableAutoOffload != null) this.enableAutoOffload = enableAutoOffload;
    if (autoOffloadDays != null) this.autoOffloadDays = autoOffloadDays;
    if (enableRetentionPruner != null) this.enableRetentionPruner = enableRetentionPruner;
    if (retentionStrategy != null) this.retentionStrategy = retentionStrategy;
    
    lastUpdated = DateTime.now();
    save(); // Persist to Hive
  }

  /// Get storage statistics summary
  Map<String, dynamic> getStorageSummary() {
    return {
      'global_profile': global.toString().split('.').last,
      'mode_profiles': perMode.map((k, v) => MapEntry(k, v.toString().split('.').last)),
      'retention_days': retentionDays,
      'auto_offload_enabled': enableAutoOffload,
      'auto_offload_days': autoOffloadDays,
      'pruner_enabled': enableRetentionPruner,
      'retention_strategy': retentionStrategy,
      'privacy_level': _calculatePrivacyLevel(),
      'last_updated': lastUpdated.toIso8601String(),
      'version': version,
    };
  }

  String _calculatePrivacyLevel() {
    final privacy = getPrivacySettings();
    if (!privacy.detectFaces && 
        privacy.locationPrecision == LocationPrecision.none &&
        privacy.redactExif &&
        privacy.autoBlurFaces) {
      return 'high';
    } else if (privacy.locationPrecision == LocationPrecision.city &&
               privacy.redactExif) {
      return 'medium';
    } else {
      return 'low';
    }
  }

  @override
  String toString() => 'HiveStorageSettings(global: $global, modes: ${perMode.length}, retention: ${retentionDays}d)';
}

/// Media settings manager with Hive persistence
class MediaSettingsManager {
  static const String _boxName = 'media_settings';
  static const String _settingsKey = 'storage_settings';
  
  static Box<HiveStorageSettings>? _box;

  /// Initialize the settings manager
  static Future<void> initialize() async {
    try {
      // Register Hive adapters if not already registered
      if (!Hive.isAdapterRegistered(40)) {
        Hive.registerAdapter(StorageProfileAdapter());
      }
      if (!Hive.isAdapterRegistered(41)) {
        Hive.registerAdapter(HiveStorageSettingsAdapter());
      }

      // Open the settings box
      _box = await Hive.openBox<HiveStorageSettings>(_boxName);
      
      // Ensure default settings exist
      if (_box!.isEmpty) {
        await _box!.put(_settingsKey, HiveStorageSettings());
        print('MediaSettingsManager: Created default settings');
      }
      
      print('MediaSettingsManager: Initialized with ${_box!.length} entries');
    } catch (e) {
      print('MediaSettingsManager: Initialization error: $e');
      throw Exception('Failed to initialize media settings: $e');
    }
  }

  /// Get current storage settings
  static HiveStorageSettings getSettings() {
    if (_box == null) {
      throw StateError('MediaSettingsManager not initialized');
    }
    
    return _box!.get(_settingsKey) ?? HiveStorageSettings();
  }

  /// Update storage settings
  static Future<void> updateSettings(HiveStorageSettings settings) async {
    if (_box == null) {
      throw StateError('MediaSettingsManager not initialized');
    }
    
    settings.lastUpdated = DateTime.now();
    await _box!.put(_settingsKey, settings);
    print('MediaSettingsManager: Updated settings');
  }

  /// Get effective profile for mode with override
  static StorageProfile getEffectiveProfile({
    required String mode,
    StorageProfile? perImportOverride,
  }) {
    final settings = getSettings();
    return settings.effectiveProfile(
      mode: mode,
      perImportOverride: perImportOverride,
    );
  }

  /// Update mode-specific profile
  static Future<void> updateModeProfile(String mode, StorageProfile profile) async {
    final settings = getSettings();
    settings.updateModeProfile(mode, profile);
    await updateSettings(settings);
  }

  /// Update privacy settings
  static Future<void> updatePrivacySettings(PrivacySettings privacySettings) async {
    final settings = getSettings();
    settings.updatePrivacySettings(privacySettings);
    await updateSettings(settings);
  }

  /// Get privacy settings for mode
  static PrivacySettings getPrivacySettingsForMode(String mode) {
    final settings = getSettings();
    final basePrivacy = settings.getPrivacySettings();
    
    // Apply mode-specific overrides
    switch (mode) {
      case 'first_responder':
        return basePrivacy.copyWith(
          detectFaces: true,
          enablePiiDetection: true,
        );
      case 'coach':
        return basePrivacy.copyWith(
          locationPrecision: LocationPrecision.city,
          redactExif: true,
        );
      default:
        return basePrivacy;
    }
  }

  /// Update retention settings
  static Future<void> updateRetentionSettings({
    int? retentionDays,
    bool? enableAutoOffload,
    int? autoOffloadDays,
    bool? enableRetentionPruner,
    String? retentionStrategy,
  }) async {
    final settings = getSettings();
    settings.updateRetentionSettings(
      retentionDays: retentionDays,
      enableAutoOffload: enableAutoOffload,
      autoOffloadDays: autoOffloadDays,
      enableRetentionPruner: enableRetentionPruner,
      retentionStrategy: retentionStrategy,
    );
    await updateSettings(settings);
  }

  /// Get storage usage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    final settings = getSettings();
    
    // In a real implementation, this would query CAS storage
    // For now, return summary with settings
    return {
      'settings': settings.getStorageSummary(),
      'estimated_usage': {
        'total_files': 0,
        'total_mb': 0.0,
        'by_profile': <String, double>{},
      },
      'last_cleanup': null,
      'next_cleanup': settings.enableRetentionPruner 
          ? DateTime.now().add(const Duration(days: 1)).toIso8601String()
          : null,
    };
  }

  /// Reset settings to defaults
  static Future<void> resetToDefaults() async {
    final defaultSettings = HiveStorageSettings();
    await updateSettings(defaultSettings);
    print('MediaSettingsManager: Reset to default settings');
  }

  /// Export settings as JSON
  static Map<String, dynamic> exportSettings() {
    final settings = getSettings();
    return {
      'version': settings.version,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
    };
  }

  /// Import settings from JSON
  static Future<void> importSettings(Map<String, dynamic> json) async {
    try {
      final settingsData = json['settings'] as Map<String, dynamic>;
      final settings = HiveStorageSettings.fromJson(settingsData);
      settings.version = json['version'] ?? 1;
      settings.lastUpdated = DateTime.now();
      
      await updateSettings(settings);
      print('MediaSettingsManager: Imported settings from JSON');
    } catch (e) {
      throw Exception('Failed to import settings: $e');
    }
  }

  /// Close the settings box
  static Future<void> close() async {
    if (_box != null) {
      await _box!.close();
      _box = null;
      print('MediaSettingsManager: Closed settings box');
    }
  }

  /// Get settings change stream
  static Stream<BoxEvent> get settingsStream {
    if (_box == null) {
      throw StateError('MediaSettingsManager not initialized');
    }
    return _box!.watch(key: _settingsKey);
  }
}

/// Consent record for tracking user choices
@HiveType(typeId: 42)
@JsonSerializable()
class ConsentRecord extends HiveObject {
  @HiveField(0)
  final String entryId;
  
  @HiveField(1)
  final String userId;
  
  @HiveField(2)
  final String deviceId;
  
  @HiveField(3)
  final StorageProfile selectedProfile;
  
  @HiveField(4)
  final StorageProfile? perImportOverride;
  
  @HiveField(5)
  final DateTime timestamp;
  
  @HiveField(6)
  final String appMode;
  
  @HiveField(7)
  final Map<String, dynamic> privacyChoices;
  
  @HiveField(8)
  final String consentVersion;

  ConsentRecord({
    required this.entryId,
    required this.userId,
    required this.deviceId,
    required this.selectedProfile,
    this.perImportOverride,
    required this.timestamp,
    required this.appMode,
    required this.privacyChoices,
    required this.consentVersion,
  });

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => _$ConsentRecordFromJson(json);
  Map<String, dynamic> toJson() => _$ConsentRecordToJson(this);

  @override
  String toString() => 'ConsentRecord($entryId, $selectedProfile, $timestamp)';
}

/// Consent tracking manager
class ConsentTrackingManager {
  static const String _boxName = 'consent_records';
  static Box<ConsentRecord>? _box;

  /// Initialize consent tracking
  static Future<void> initialize() async {
    try {
      if (!Hive.isAdapterRegistered(42)) {
        Hive.registerAdapter(ConsentRecordAdapter());
      }

      _box = await Hive.openBox<ConsentRecord>(_boxName);
      print('ConsentTrackingManager: Initialized with ${_box!.length} records');
    } catch (e) {
      print('ConsentTrackingManager: Initialization error: $e');
      throw Exception('Failed to initialize consent tracking: $e');
    }
  }

  /// Record user consent choice
  static Future<void> recordConsent({
    required String entryId,
    required String userId,
    required String deviceId,
    required StorageProfile selectedProfile,
    StorageProfile? perImportOverride,
    required String appMode,
    required Map<String, dynamic> privacyChoices,
    String consentVersion = '1.0',
  }) async {
    if (_box == null) {
      throw StateError('ConsentTrackingManager not initialized');
    }

    final record = ConsentRecord(
      entryId: entryId,
      userId: userId,
      deviceId: deviceId,
      selectedProfile: selectedProfile,
      perImportOverride: perImportOverride,
      timestamp: DateTime.now(),
      appMode: appMode,
      privacyChoices: privacyChoices,
      consentVersion: consentVersion,
    );

    await _box!.add(record);
    print('ConsentTrackingManager: Recorded consent for entry $entryId');
  }

  /// Get consent records for user
  static List<ConsentRecord> getConsentRecords(String userId) {
    if (_box == null) {
      throw StateError('ConsentTrackingManager not initialized');
    }

    return _box!.values.where((record) => record.userId == userId).toList();
  }

  /// Get consent audit trail
  static Map<String, dynamic> getAuditTrail(String entryId) {
    if (_box == null) {
      throw StateError('ConsentTrackingManager not initialized');
    }

    final records = _box!.values.where((record) => record.entryId == entryId).toList();
    
    return {
      'entry_id': entryId,
      'consent_records': records.map((r) => r.toJson()).toList(),
      'total_records': records.length,
      'latest_consent': records.isNotEmpty 
          ? records.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b).toJson()
          : null,
    };
  }

  /// Close the consent box
  static Future<void> close() async {
    if (_box != null) {
      await _box!.close();
      _box = null;
      print('ConsentTrackingManager: Closed consent box');
    }
  }
}