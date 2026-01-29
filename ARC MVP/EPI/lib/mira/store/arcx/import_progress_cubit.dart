/// Cubit for global import progress (mini status bar in HomeView).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

class ImportProgressState {
  final bool isActive;
  final String message;
  final double fraction;
  final String? error;
  final bool completed;

  const ImportProgressState({
    this.isActive = false,
    this.message = '',
    this.fraction = 0.0,
    this.error,
    this.completed = false,
  });

  ImportProgressState copyWith({
    bool? isActive,
    String? message,
    double? fraction,
    String? error,
    bool? completed,
  }) {
    return ImportProgressState(
      isActive: isActive ?? this.isActive,
      message: message ?? this.message,
      fraction: fraction ?? this.fraction,
      error: error ?? this.error,
      completed: completed ?? this.completed,
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

  void update(String message, [double fraction = 0.0]) {
    if (!state.isActive) return;
    emit(state.copyWith(message: message, fraction: fraction.clamp(0.0, 1.0)));
  }

  void complete() {
    emit(state.copyWith(
      isActive: false,
      message: 'Import complete',
      fraction: 1.0,
      completed: true,
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
