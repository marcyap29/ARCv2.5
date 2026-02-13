import 'package:equatable/equatable.dart';

/// Evidence from CHRONICLE that LUMARA used to gently push back on a user claim.
/// Shown in the Evidence Review UI so the user can see what LUMARA is seeing.
class PushbackEvidence extends Equatable {
  /// Short summary (e.g. "5 entries in the last 30 days touch on this.")
  final String aggregationSummary;

  /// List of excerpts, typically "Date: excerpt" (e.g. "Jan 12: ...excerpt...")
  final List<String> entryExcerpts;

  const PushbackEvidence({
    required this.aggregationSummary,
    required this.entryExcerpts,
  });

  @override
  List<Object?> get props => [aggregationSummary, entryExcerpts];
}
