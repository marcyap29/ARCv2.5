import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/services/data_export_service.dart';
import 'package:my_app/repositories/journal_repository.dart';

class SettingsState {
  final bool localOnlyMode;
  final bool biometricLock;
  final bool exportDataEnabled;
  final bool deleteDataEnabled;
  final bool isLoading;
  final String? error;
  
  // Personalization settings
  final String selectedTone;
  final String selectedRhythm;
  final bool colorAccessibilityEnabled;
  final bool highContrastMode;
  final double textScaleFactor;

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
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

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

  // Data export methods
  Future<void> exportAllData(JournalRepository journalRepository) async {
    setLoading(true);
    setError(null);
    
    await DataExportService.exportAllData(
      journalRepository: journalRepository,
      onProgress: (message) {
        // Could emit progress updates here if needed
      },
      onError: (error) {
        setError(error);
        setLoading(false);
      },
      onSuccess: (message) {
        setLoading(false);
        // Could emit success message here if needed
      },
    );
  }

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
    return await DataExportService.getStorageInfo(journalRepository: journalRepository);
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
}
