// lib/app/app_repos.dart
// Single access point for app-level repositories (P2-REPOS).
// Use these instead of ad-hoc JournalRepository(), Layer0Repository(), etc.
// See CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md P2-REPOS.

import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';

/// App-level repository accessors.
///
/// Prefer [journal], [chat], [layer0], [aggregation], and [changelog]
/// instead of constructing repositories directly. High-traffic call sites
/// (EnhancedLumaraApi, ChronicleManagementView, JournalScreen) use this.
abstract final class AppRepos {
  AppRepos._();

  static JournalRepository? _journal;

  /// Single shared [JournalRepository] for the app.
  static JournalRepository get journal => _journal ??= JournalRepository();

  /// Chat repository (singleton via [ChatRepoImpl.instance]).
  static ChatRepo get chat => ChatRepoImpl.instance;

  /// CHRONICLE Layer0 repository (delegates to [ChronicleRepos]).
  static Layer0Repository get layer0 => ChronicleRepos.layer0;

  /// CHRONICLE aggregation repository (delegates to [ChronicleRepos]).
  static AggregationRepository get aggregation => ChronicleRepos.aggregation;

  /// CHRONICLE changelog repository (delegates to [ChronicleRepos]).
  static ChangelogRepository get changelog => ChronicleRepos.changelog;

  /// Ensures Layer0 is initialized. Call before using [layer0] where immediate readiness is required.
  static Future<void> ensureLayer0Initialized() async {
    await ChronicleRepos.ensureLayer0Initialized();
  }

  /// Returns layer0, aggregation, and changelog with Layer0 already initialized.
  static Future<(Layer0Repository, AggregationRepository, ChangelogRepository)> get initializedChronicleRepos =>
      ChronicleRepos.initializedRepos;
}
