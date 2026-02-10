// lib/services/phase_sentinel_integration.dart
// Ensures Sentinel participates in phase determination: when applying RIVET/ATLAS
// proposals, any segment that triggers a Sentinel (crisis/cluster) alert is assigned
// Recovery phase as a safety override.

import 'package:my_app/models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/sentinel/sentinel_analyzer.dart';

/// Resolves the phase label for a segment when applying RIVET sweep proposals.
/// RIVET and ATLAS have already proposed a phase; Sentinel can override to Recovery
/// if the segment content triggers a crisis/cluster alert.
Future<PhaseLabel> resolvePhaseWithSentinel(
  PhaseSegmentProposal proposal,
  List<JournalEntry> allEntries, {
  String userId = 'default_user',
}) async {
  if (proposal.entryIds.isEmpty) return proposal.proposedLabel;

  final ids = proposal.entryIds.toSet();
  final segmentEntries = allEntries.where((e) => ids.contains(e.id)).toList();
  if (segmentEntries.isEmpty) return proposal.proposedLabel;

  final text = segmentEntries.map((e) => e.content).join('\n');
  if (text.trim().isEmpty) return proposal.proposedLabel;

  try {
    final score = await SentinelAnalyzer.calculateSentinelScore(
      userId: userId,
      currentEntryText: text,
    );
    if (score.alert) return PhaseLabel.recovery;
  } catch (_) {
    // Sentinel unavailable (e.g. offline / Firestore) — keep RIVET/ATLAS phase
  }
  return proposal.proposedLabel;
}
