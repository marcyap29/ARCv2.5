import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'fr_settings.dart';

class FRSettingsCubit extends Cubit<FRSettings> {
  static const hiveBox = 'fr.settings.box';
  static const hiveKey = 'fr.settings.v1';

  late final Box _box;

  FRSettingsCubit() : super(FRSettings.defaults()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(hiveBox);
    emit(load(_box));
  }

  static FRSettings load(Box box) {
    final map = (box.get(hiveKey) as Map?)?.cast<String, dynamic>();
    if (map == null) return FRSettings.defaults();
    return FRSettings(
      rapidDebrief: map['rapidDebrief'] ?? false,
      redactionEnabled: map['redactionEnabled'] ?? false,
      shiftAwareCadence: map['shiftAwareCadence'] ?? false,
      postHeavyEntryCheckIn: map['postHeavyEntryCheckIn'] ?? false,
      softVisuals: map['softVisuals'] ?? false,
      role: map['role'],
      department: map['department'],
      shiftPattern: map['shiftPattern'],
      yearsOfService: map['yearsOfService'],
      specialties: (map['specialties'] as List?)?.cast<String>() ?? [],
      autoRedactNames: map['autoRedactNames'] ?? true,
      autoRedactLocations: map['autoRedactLocations'] ?? true,
      autoRedactUnits: map['autoRedactUnits'] ?? false,
      shareByDefaultRedacted: map['shareByDefaultRedacted'] ?? true,
      requireConfirmationForShare: map['requireConfirmationForShare'] ?? true,
    );
  }

  void _persist(FRSettings s) {
    _box.put(hiveKey, {
      'rapidDebrief': s.rapidDebrief,
      'redactionEnabled': s.redactionEnabled,
      'shiftAwareCadence': s.shiftAwareCadence,
      'postHeavyEntryCheckIn': s.postHeavyEntryCheckIn,
      'softVisuals': s.softVisuals,
      'role': s.role,
      'department': s.department,
      'shiftPattern': s.shiftPattern,
      'yearsOfService': s.yearsOfService,
      'specialties': s.specialties,
      'autoRedactNames': s.autoRedactNames,
      'autoRedactLocations': s.autoRedactLocations,
      'autoRedactUnits': s.autoRedactUnits,
      'shareByDefaultRedacted': s.shareByDefaultRedacted,
      'requireConfirmationForShare': s.requireConfirmationForShare,
    });
  }

  void toggleRapidDebrief(bool v) => _update(state.copyWith(rapidDebrief: v));
  void toggleRedaction(bool v) => _update(state.copyWith(redactionEnabled: v));
  void toggleShiftAware(bool v) => _update(state.copyWith(shiftAwareCadence: v));
  void togglePostHeavyCheckIn(bool v) => _update(state.copyWith(postHeavyEntryCheckIn: v));
  void toggleSoftVisuals(bool v) => _update(state.copyWith(softVisuals: v));

  /// Toggle master first responder mode on/off
  void toggleMasterSwitch(bool enabled) {
    if (enabled) {
      // Enable with default enabled features
      _update(FRSettings.enabled());
    } else {
      // Disable all features but keep profile data
      _update(state.copyWith(
        rapidDebrief: false,
        redactionEnabled: false,
        shiftAwareCadence: false,
        postHeavyEntryCheckIn: false,
        softVisuals: false,
      ));
    }
  }

  /// Update settings with a new settings object
  void updateSettings(FRSettings settings) => _update(settings);
  
  // P27: Profile management methods
  void updateProfile({
    String? role,
    String? department,
    String? shiftPattern,
    int? yearsOfService,
    List<String>? specialties,
  }) {
    _update(state.copyWith(
      role: role,
      department: department,
      shiftPattern: shiftPattern,
      yearsOfService: yearsOfService,
      specialties: specialties,
    ));
  }
  
  // P27: Privacy settings methods
  void updatePrivacySettings({
    bool? autoRedactNames,
    bool? autoRedactLocations,
    bool? autoRedactUnits,
    bool? shareByDefaultRedacted,
    bool? requireConfirmationForShare,
  }) {
    _update(state.copyWith(
      autoRedactNames: autoRedactNames,
      autoRedactLocations: autoRedactLocations,
      autoRedactUnits: autoRedactUnits,
      shareByDefaultRedacted: shareByDefaultRedacted,
      requireConfirmationForShare: requireConfirmationForShare,
    ));
  }

  /// Static method to activate first responder mode (useful for onboarding)
  static Future<void> activateFirstResponderMode() async {
    try {
      final box = await Hive.openBox(hiveBox);
      final settings = FRSettings.defaults();
      box.put(hiveKey, {
        'rapidDebrief': settings.rapidDebrief,
        'redactionEnabled': settings.redactionEnabled,
        'shiftAwareCadence': settings.shiftAwareCadence,
        'postHeavyEntryCheckIn': settings.postHeavyEntryCheckIn,
        'softVisuals': settings.softVisuals,
        'role': settings.role,
        'department': settings.department,
        'shiftPattern': settings.shiftPattern,
        'yearsOfService': settings.yearsOfService,
        'specialties': settings.specialties,
        'autoRedactNames': settings.autoRedactNames,
        'autoRedactLocations': settings.autoRedactLocations,
        'autoRedactUnits': settings.autoRedactUnits,
        'shareByDefaultRedacted': settings.shareByDefaultRedacted,
        'requireConfirmationForShare': settings.requireConfirmationForShare,
      });
    } catch (e) {
      // Silently fail to not disrupt onboarding
    }
  }

  void _update(FRSettings s) { 
    emit(s); 
    _persist(s); 
  }
}