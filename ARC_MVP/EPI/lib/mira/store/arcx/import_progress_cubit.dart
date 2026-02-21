/// Cubit for global import progress (mini status bar in HomeView, status screen in Settings).
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/mira/store/arcx/services/arcx_import_service_v2.dart';

/// Status of a single file in a multi-file import.
enum ImportFileStatus {
  pending,
  importing,
  completed,
  failed,
}

/// One file in the import list (for status screen).
class ImportFileItem {
  final String fileName;
  final ImportFileStatus status;

  const ImportFileItem({required this.fileName, required this.status});
}

class ImportProgressState {
  final bool isActive;
  final String message;
  final double fraction;
  final String? error;
  final bool completed;
  /// Per-file status for multi-file import; null for single-file or when inactive.
  final List<ImportFileItem>? fileItems;
  /// Last successful ARCX import result (for showing success dialog when completed).
  final ARCXImportResultV2? completedImportResult;

  const ImportProgressState({
    this.isActive = false,
    this.message = '',
    this.fraction = 0.0,
    this.error,
    this.completed = false,
    this.fileItems,
    this.completedImportResult,
  });

  ImportProgressState copyWith({
    bool? isActive,
    String? message,
    double? fraction,
    String? error,
    bool? completed,
    List<ImportFileItem>? fileItems,
    ARCXImportResultV2? completedImportResult,
  }) {
    return ImportProgressState(
      isActive: isActive ?? this.isActive,
      message: message ?? this.message,
      fraction: fraction ?? this.fraction,
      error: error ?? this.error,
      completed: completed ?? this.completed,
      fileItems: fileItems ?? this.fileItems,
      completedImportResult: completedImportResult ?? this.completedImportResult,
    );
  }
}

class ImportProgressCubit extends Cubit<ImportProgressState> {
  ImportProgressCubit() : super(const ImportProgressState());

  void start() {
    emit(const ImportProgressState(
      isActive: true,
      message: 'Starting import...',
      fraction: 0.0,
    ));
  }

  /// Start a multi-file import with per-file status for the status screen.
  void startWithFiles(List<String> filePaths) {
    final items = filePaths
        .map((p) => ImportFileItem(fileName: p.split(RegExp(r'[/\\]')).last, status: ImportFileStatus.pending))
        .toList();
    emit(ImportProgressState(
      isActive: true,
      message: 'Importing 1 of ${items.length} archives...',
      fraction: 0.0,
      fileItems: items,
    ));
  }

  void update(String message, [double fraction = 0.0]) {
    if (!state.isActive) return;
    emit(state.copyWith(message: message, fraction: fraction.clamp(0.0, 1.0)));
  }

  /// Set status for one file in a multi-file import (for status screen).
  void updateFileStatus(int index, ImportFileStatus status) {
    if (!state.isActive || state.fileItems == null || index < 0 || index >= state.fileItems!.length) return;
    final list = List<ImportFileItem>.from(state.fileItems!);
    list[index] = ImportFileItem(fileName: list[index].fileName, status: status);
    emit(state.copyWith(fileItems: list));
  }

  void complete([ARCXImportResultV2? result]) {
    emit(state.copyWith(
      isActive: false,
      message: 'Import complete',
      fraction: 1.0,
      completed: true,
      completedImportResult: result,
    ));
  }

  void fail(String? error) {
    emit(state.copyWith(
      isActive: false,
      message: error ?? 'Import failed',
      error: error,
    ));
  }

  void clearCompleted() {
    if (state.completed || state.error != null) {
      emit(const ImportProgressState());
    }
  }
}
