import 'package:my_app/chronicle/models/chronicle_index.dart';
import 'package:my_app/chronicle/storage/chronicle_index_storage.dart';
import 'package:my_app/chronicle/storage/chronicle_theme_ignore_list_storage.dart';

/// Resolves related journal entry IDs from the CHRONICLE pattern index.
/// Entries that share the same thematic cluster (vectorized pattern) are
/// considered related.
class RelatedEntriesService {
  static const int _maxRelated = 12;

  final ChronicleIndexStorage _storage = ChronicleIndexStorage();

  /// Returns journal entry IDs that are thematically related to [entryId],
  /// based on the pattern index for [userId]. Excludes [entryId] and caps at
  /// [_maxRelated]. Returns empty list if index is missing or entry is not
  /// in any cluster.
  Future<List<String>> getRelatedEntryIds({
    required String userId,
    required String entryId,
  }) async {
    final json = await _storage.read(userId);
    if (json.isEmpty || !json.containsKey('theme_clusters')) {
      return [];
    }

    var index = ChronicleIndex.fromJson(json);
    final ignored =
        (await ChronicleThemeIgnoreListStorage.getIgnored(userId)).toSet();
    index = index.withoutIgnoredThemes(ignored);
    final related = <String>{};

    for (final cluster in index.themeClusters.values) {
      for (final appearance in cluster.appearances) {
        if (!appearance.entryIds.contains(entryId)) continue;
        for (final id in appearance.entryIds) {
          if (id != entryId) related.add(id);
        }
        // Also add entry IDs from other appearances in the same cluster
        for (final other in cluster.appearances) {
          if (other == appearance) continue;
          for (final id in other.entryIds) {
            if (id != entryId) related.add(id);
          }
        }
        break; // this cluster contains our entry; we've collected from it
      }
    }

    return related.take(_maxRelated).toList();
  }

  /// Returns related entry IDs grouped by theme (canonical label).
  /// Same entry ID may appear under multiple themes. Caller can show theme
  /// words and expand to show entries (e.g. sorted by date) per theme.
  /// Returns empty map if index is missing or entry is not in any cluster.
  Future<Map<String, List<String>>> getRelatedEntriesGroupedByTheme({
    required String userId,
    required String entryId,
  }) async {
    final json = await _storage.read(userId);
    if (json.isEmpty || !json.containsKey('theme_clusters')) {
      return {};
    }

    var index = ChronicleIndex.fromJson(json);
    final ignored =
        (await ChronicleThemeIgnoreListStorage.getIgnored(userId)).toSet();
    index = index.withoutIgnoredThemes(ignored);
    final grouped = <String, List<String>>{};

    for (final cluster in index.themeClusters.values) {
      bool clusterContainsEntry = false;
      final ids = <String>{};

      for (final appearance in cluster.appearances) {
        if (appearance.entryIds.contains(entryId)) clusterContainsEntry = true;
        for (final id in appearance.entryIds) {
          if (id != entryId) ids.add(id);
        }
      }

      if (clusterContainsEntry && ids.isNotEmpty) {
        final label = cluster.canonicalLabel;
        final existing = grouped[label] ?? [];
        final combined = {...existing, ...ids}.take(_maxRelated).toList();
        grouped[label] = combined;
      }
    }

    return grouped;
  }
}
