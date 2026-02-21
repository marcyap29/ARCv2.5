// lib/services/app_repos.dart
// Single access point for app-level repositories (Journal, CHRONICLE, Chat).
// Use these shared instances instead of ad-hoc JournalRepository(), etc.
// See CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md P2-REPOS.

import 'package:my_app/arc/core/journal_repository.dart';

export 'package:my_app/arc/core/journal_repository.dart' show JournalRepository;

/// Shared app repository accessors.
///
/// Prefer [journal] for JournalRepository. For CHRONICLE repos (Layer0,
/// Aggregation, Changelog) use [ChronicleRepos] from package:my_app/chronicle/core/chronicle_repos.dart.
/// For Chat sessions use ChatRepoImpl.instance (see arc/chat/chat/chat_repo_impl.dart).
abstract final class AppRepos {
  AppRepos._();

  static JournalRepository? _journal;

  /// Shared [JournalRepository]. Prefer this over constructing JournalRepository().
  static JournalRepository get journal => _journal ??= JournalRepository();
}
