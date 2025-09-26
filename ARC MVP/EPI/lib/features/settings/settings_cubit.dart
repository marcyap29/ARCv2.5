import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/core/services/audio_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';

class SettingsState {
  final bool localOnlyMode;
  final bool biometricLock;
  final bool exportDataEnabled; // legacy JSON export removed; flag retained for compatibility
  final bool deleteDataEnabled;
  final bool isLoading;
  final String? error;
  
  // Personalization settings
  final String selectedTone;
  final String selectedRhythm;
  final bool colorAccessibilityEnabled;
  final bool highContrastMode;
  final double textScaleFactor;
  final bool introAudioMuted;

  const SettingsState({
    this.localOnlyMode = false,
    this.biometricLock = false,
    this.exportDataEnabled = true,
    this.deleteDataEnabled = true,
    this.isLoading = false,
    this.error,
    // Personalization defaults
    this.selectedTone = 'calm',
    this.selectedRhythm = 'daily',
    this.colorAccessibilityEnabled = false,
    this.highContrastMode = false,
    this.textScaleFactor = 1.0,
    this.introAudioMuted = false,
  });

  SettingsState copyWith({
    bool? localOnlyMode,
    bool? biometricLock,
    bool? exportDataEnabled,
    bool? deleteDataEnabled,
    bool? isLoading,
    String? error,
    // Personalization fields
    String? selectedTone,
    String? selectedRhythm,
    bool? colorAccessibilityEnabled,
    bool? highContrastMode,
    double? textScaleFactor,
    bool? introAudioMuted,
  }) {
    return SettingsState(
      localOnlyMode: localOnlyMode ?? this.localOnlyMode,
      biometricLock: biometricLock ?? this.biometricLock,
      exportDataEnabled: exportDataEnabled ?? this.exportDataEnabled,
      deleteDataEnabled: deleteDataEnabled ?? this.deleteDataEnabled,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      // Personalization fields
      selectedTone: selectedTone ?? this.selectedTone,
      selectedRhythm: selectedRhythm ?? this.selectedRhythm,
      colorAccessibilityEnabled: colorAccessibilityEnabled ?? this.colorAccessibilityEnabled,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      introAudioMuted: introAudioMuted ?? this.introAudioMuted,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  final AudioService _audioService = AudioService();
  
  SettingsCubit() : super(const SettingsState()) {
    _loadAudioSettings();
  }

  Future<void> _loadAudioSettings() async {
    await _audioService.initialize();
    emit(state.copyWith(introAudioMuted: _audioService.isMuted));
  }

  void toggleLocalOnlyMode(bool value) {
    emit(state.copyWith(localOnlyMode: value));
  }

  void toggleBiometricLock(bool value) {
    emit(state.copyWith(biometricLock: value));
  }

  void toggleExportData(bool value) {
    emit(state.copyWith(exportDataEnabled: value));
  }

  void toggleDeleteData(bool value) {
    emit(state.copyWith(deleteDataEnabled: value));
  }

  void setLoading(bool loading) {
    emit(state.copyWith(isLoading: loading));
  }

  void setError(String? error) {
    emit(state.copyWith(error: error));
  }

  // Legacy JSON export removed

  Future<void> deleteAllData(JournalRepository journalRepository) async {
    setLoading(true);
    setError(null);
    
    try {
      await journalRepository.deleteAllEntries();
      setLoading(false);
    } catch (e) {
      setError('Failed to delete data: $e');
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>> getStorageInfo(JournalRepository journalRepository) async {
    // Minimal local summary without legacy service dependency
    try {
      final entries = journalRepository.getAllJournalEntries();
      final total = entries.length;
      return {
        'total_entries': total,
        'total_snapshots': 0,
        'estimated_size_bytes': total * 500,
        'estimated_size_mb': ((total * 500) / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {
        'error': 'Failed to get storage info: $e',
        'total_entries': 0,
        'total_snapshots': 0,
        'estimated_size_bytes': 0,
        'estimated_size_mb': '0.00',
      };
    }
  }

  // Personalization methods
  void setTone(String tone) {
    emit(state.copyWith(selectedTone: tone));
  }

  void setRhythm(String rhythm) {
    emit(state.copyWith(selectedRhythm: rhythm));
  }

  void toggleColorAccessibility() {
    emit(state.copyWith(colorAccessibilityEnabled: !state.colorAccessibilityEnabled));
  }

  void toggleHighContrast() {
    emit(state.copyWith(highContrastMode: !state.highContrastMode));
  }

  void setTextScaleFactor(double scaleFactor) {
    emit(state.copyWith(textScaleFactor: scaleFactor));
  }

  Future<void> toggleIntroAudio() async {
    await _audioService.toggleMute();
    emit(state.copyWith(introAudioMuted: _audioService.isMuted));
  }
}
