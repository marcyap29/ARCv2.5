/// Models for CHRONICLE edit validation and intelligent pushback.
/// Used by ChronicleEditingService and EditValidator.

/// Type of warning when a user edit may break temporal intelligence.
enum EditWarningType {
  /// User is removing a theme/pattern that appears in many source entries.
  patternSuppression,

  /// User's edited content contradicts specific journal entries.
  factualContradiction,
}

/// A pattern (e.g. theme) that appears in source entries but is being removed in the edit.
class SuppressedPattern {
  /// Label of the pattern (e.g. "anxiety", "imposter syndrome").
  final String pattern;

  /// Share of entries (0.0–1.0) that contain this pattern.
  final double frequency;

  /// Entry IDs that contain this pattern.
  final List<String> entryIds;

  const SuppressedPattern({
    required this.pattern,
    required this.frequency,
    required this.entryIds,
  });
}

/// A claim in the edited content that contradicts a specific journal entry.
class EditContradiction {
  /// Short description of what the user claimed (e.g. "haven't thought about leaving job").
  final String claim;

  /// Date of the contradicting entry.
  final DateTime date;

  /// Short excerpt from the entry.
  final String excerpt;

  /// Entry ID of the contradicting entry.
  final String entryId;

  const EditContradiction({
    required this.claim,
    required this.date,
    required this.excerpt,
    required this.entryId,
  });
}

/// Result of validating an edit against source entries.
sealed class EditValidationResult {
  const EditValidationResult();

  bool get isApproved => this is EditApproved;
  bool get isWarning => this is EditWarning;
  bool get isConflict => this is EditConflict;

  static EditValidationResult approved() => const EditApproved();

  static EditValidationResult warning({
    required EditWarningType type,
    required String message,
    List<String> affectedEntryIds = const [],
  }) =>
      EditWarning(type: type, message: message, affectedEntryIds: affectedEntryIds);

  static EditValidationResult conflict({
    required EditWarningType type,
    required String message,
    List<String> affectedEntryIds = const [],
  }) =>
      EditConflict(type: type, message: message, affectedEntryIds: affectedEntryIds);
}

/// Edit is fine; no pushback needed.
class EditApproved extends EditValidationResult {
  const EditApproved();
}

/// Edit may affect pattern detection; surface a warning but allow proceed.
class EditWarning extends EditValidationResult {
  final EditWarningType type;
  final String message;
  final List<String> affectedEntryIds;

  const EditWarning({
    required this.type,
    required this.message,
    this.affectedEntryIds = const [],
  });
}

/// Edit conflicts with journal record; suggest review before proceeding.
class EditConflict extends EditValidationResult {
  final EditWarningType type;
  final String message;
  final List<String> affectedEntryIds;

  const EditConflict({
    required this.type,
    required this.message,
    this.affectedEntryIds = const [],
  });
}
