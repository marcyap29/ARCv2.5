// lib/chronicle/core/chronicle_repos.dart
// Single access point for CHRONICLE repositories (Layer0, Aggregation, Changelog).
// Use these shared instances instead of ad-hoc `new Layer0Repository()` etc.
// See CODE_SIMPLIFIER_CONSOLIDATION_PLAN.md P1-CHRONICLE.

import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';

/// Shared CHRONICLE repository accessors.
///
/// Prefer using [layer0], [aggregation], and [changelog] (or [initializedRepos])
/// instead of constructing repositories directly.
abstract final class ChronicleRepos {
  ChronicleRepos._();

  static Layer0Repository? _layer0;
  static AggregationRepository? _aggregation;
  static ChangelogRepository? _changelog;

  static Layer0Repository get layer0 => _layer0 ??= Layer0Repository();
  static AggregationRepository get aggregation => _aggregation ??= AggregationRepository();
  static ChangelogRepository get changelog => _changelog ??= ChangelogRepository();

  /// Ensures Layer0Repository is initialized (Hive box open). Call before using [layer0]
  /// in code that relies on it being ready immediately.
  static Future<void> ensureLayer0Initialized() async {
    await layer0.initialize();
  }

  /// Returns all three repositories with Layer0 already initialized.
  /// Use in factories and services that need layer0 + aggregation + changelog.
  static Future<(Layer0Repository, AggregationRepository, ChangelogRepository)> get initializedRepos async {
    await ensureLayer0Initialized();
    return (layer0, aggregation, changelog);
  }
}
