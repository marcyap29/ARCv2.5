import '../editing/edit_validation_models.dart';
import '../editing/edit_validator.dart';
import '../storage/layer0_repository.dart';
import 'package:intl/intl.dart';

/// Service for validating user edits to CHRONICLE content (e.g. monthly summaries)
/// and surfacing intelligent pushback when edits suppress patterns or contradict entries.
class ChronicleEditingService {
  final EditValidator _validator = EditValidator();

  /// Validates an edit against the source entries used to build the content.
  ///
  /// Returns [EditApproved] if no issues, [EditWarning] for pattern suppression,
  /// or [EditConflict] for factual contradictions. UI can show the message and
  /// offer: keep pattern with different wording, add a note, or proceed anyway.
  Future<EditValidationResult> validateEdit({
    required String originalContent,
    required String editedContent,
    required List<ChronicleRawEntry> sourceEntries,
  }) async {
    if (sourceEntries.isEmpty) {
      return EditValidationResult.approved();
    }

    // Check for pattern suppression first
    final suppressedPatterns = _validator.detectSuppressedPatterns(
      original: originalContent,
      edited: editedContent,
      entries: sourceEntries,
    );

    if (suppressedPatterns.isNotEmpty) {
      final first = suppressedPatterns.first;
      final frequencyPercent = (first.frequency * 100).round();
      final bulletList = suppressedPatterns
          .map((p) => '• ${p.pattern} (${p.entryIds.length} entries)')
          .join('\n');
      return EditValidationResult.warning(
        type: EditWarningType.patternSuppression,
        message: '''
You're removing patterns that appear in $frequencyPercent% of entries:

$bulletList

This might affect LUMARA's pattern detection. Three options:

1. Keep pattern, change wording (e.g., "anxiety" → "heightened awareness")
2. Note explicitly why you're removing it ("This wasn't actually X, it was Y")
3. Proceed anyway (I'll respect your authority, but may affect future synthesis)
''',
        affectedEntryIds: suppressedPatterns.first.entryIds,
      );
    }

    // Check for factual contradictions
    final contradictions = _validator.detectContradictions(
      edited: editedContent,
      entries: sourceEntries,
    );

    if (contradictions.isNotEmpty) {
      final dateFormat = DateFormat('MMM d, yyyy');
      final bulletList = contradictions
          .map((c) => '• ${c.claim} contradicts entry from ${dateFormat.format(c.date)}: "${c.excerpt}"')
          .join('\n');
      return EditValidationResult.conflict(
        type: EditWarningType.factualContradiction,
        message: '''
Your edit conflicts with specific journal entries:

$bulletList

Want to:
1. Review those entries first?
2. Add a note explaining the contradiction?
3. Proceed (I'll flag this inconsistency in future queries)
''',
        affectedEntryIds: contradictions.map((c) => c.entryId).toList(),
      );
    }

    return EditValidationResult.approved();
  }
}
