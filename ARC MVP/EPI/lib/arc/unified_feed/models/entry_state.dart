/// Entry lifecycle state for unified feed entries.
///
/// Tracks whether a conversation/entry is in draft, saving, saved,
/// or error state. Used by the UI to show appropriate indicators.

import 'package:equatable/equatable.dart';

/// Possible lifecycle states for a feed entry
enum EntryLifecycle {
  /// Entry is actively being composed (unsaved conversation)
  draft,

  /// Entry is currently being auto-saved or manually saved
  saving,

  /// Entry has been persisted to journal storage
  saved,

  /// Entry save failed - needs retry
  error,
}

/// Immutable state object for feed entry lifecycle.
class EntryState extends Equatable {
  /// The current lifecycle phase
  final EntryLifecycle lifecycle;

  /// Error message if lifecycle == error
  final String? errorMessage;

  /// Timestamp of last successful save
  final DateTime? lastSavedAt;

  /// Whether the entry has unsaved changes since lastSavedAt
  final bool hasUnsavedChanges;

  /// Number of auto-save attempts so far
  final int saveAttemptCount;

  const EntryState({
    required this.lifecycle,
    this.errorMessage,
    this.lastSavedAt,
    this.hasUnsavedChanges = false,
    this.saveAttemptCount = 0,
  });

  /// Convenience constructors
  const EntryState.draft()
      : lifecycle = EntryLifecycle.draft,
        errorMessage = null,
        lastSavedAt = null,
        hasUnsavedChanges = true,
        saveAttemptCount = 0;

  const EntryState.saving({this.lastSavedAt})
      : lifecycle = EntryLifecycle.saving,
        errorMessage = null,
        hasUnsavedChanges = true,
        saveAttemptCount = 0;

  const EntryState.saved({DateTime? savedAt})
      : lifecycle = EntryLifecycle.saved,
        errorMessage = null,
        lastSavedAt = savedAt,
        hasUnsavedChanges = false,
        saveAttemptCount = 0;

  EntryState.error({required String message, this.saveAttemptCount = 0})
      : lifecycle = EntryLifecycle.error,
        errorMessage = message,
        lastSavedAt = null,
        hasUnsavedChanges = true;

  bool get isDraft => lifecycle == EntryLifecycle.draft;
  bool get isSaving => lifecycle == EntryLifecycle.saving;
  bool get isSaved => lifecycle == EntryLifecycle.saved;
  bool get isError => lifecycle == EntryLifecycle.error;

  EntryState copyWith({
    EntryLifecycle? lifecycle,
    String? errorMessage,
    DateTime? lastSavedAt,
    bool? hasUnsavedChanges,
    int? saveAttemptCount,
  }) {
    return EntryState(
      lifecycle: lifecycle ?? this.lifecycle,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      saveAttemptCount: saveAttemptCount ?? this.saveAttemptCount,
    );
  }

  @override
  List<Object?> get props => [
        lifecycle,
        errorMessage,
        lastSavedAt,
        hasUnsavedChanges,
        saveAttemptCount,
      ];
}
