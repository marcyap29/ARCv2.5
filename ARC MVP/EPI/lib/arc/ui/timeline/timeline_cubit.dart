import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:hive/hive.dart';

class TimelineCubit extends Cubit<TimelineState> {
  final JournalRepository _journalRepository;
  static const int _pageSize = 10;
  int _currentPage = 0;
  bool _hasMore = true;

  TimelineCubit({JournalRepository? journalRepository})
      : _journalRepository = journalRepository ?? JournalRepository(),
        super(const TimelineInitial());

  Future<void> loadEntries() async {
    emit(const TimelineLoading());
    _currentPage = 0;
    _hasMore = true;
    await _loadAllEntries();
  }

  Future<void> loadMoreEntries() async {
    if (!_hasMore) return;
    _currentPage++;
    await _loadEntries();
  }

  Future<void> refreshEntries() async {
    print('DEBUG: TimelineCubit.refreshEntries() called');
    print('DEBUG: Refreshing timeline to show updated entries...');
    _currentPage = 0;
    _hasMore = true;
    await _loadAllEntries();
    print('DEBUG: Timeline refresh completed');
  }

  /// Reload all entries (used when an entry's date changes and might move pages)
  Future<void> reloadAllEntries() async {
    print('DEBUG: TimelineCubit.reloadAllEntries() called');
    print('DEBUG: Reloading all entries to handle date changes...');
    emit(const TimelineLoading());
    _currentPage = 0;
    _hasMore = true;
    await _loadAllEntries();
    print('DEBUG: All entries reload completed');
  }

  /// Check if all entries have been deleted and emit a special state
  Future<bool> checkIfAllEntriesDeleted() async {
    final journalRepository = JournalRepository();
    final count = await journalRepository.getEntryCount();
    
    if (count == 0) {
      emit(const TimelineEmpty());
      return true;
    }
    return false;
  }

  /// Update an entry's phase and geometry
  Future<void> updateEntryPhase(String entryId, String newPhase, String newGeometry) async {
    try {
      // Get the existing journal entry
      final existingEntry = _journalRepository.getJournalEntryById(entryId);
      if (existingEntry == null) {
        print('DEBUG: Entry $entryId not found for update');
        return;
      }

      // Update the journal entry with new metadata including phase
      final updatedMetadata = Map<String, dynamic>.from(existingEntry.metadata ?? {});
      updatedMetadata['phase'] = newPhase;
      updatedMetadata['geometry'] = newGeometry;
      updatedMetadata['updated_by_user'] = true;

      final updatedEntry = existingEntry.copyWith(
        metadata: updatedMetadata,
        updatedAt: DateTime.now(),
      );
      
      await _journalRepository.updateJournalEntry(updatedEntry);

      // Update the arcform snapshot with new phase/geometry
      await _updateArcformSnapshot(entryId, newPhase, newGeometry);

      // Refresh the timeline to show updated data
      emit(const TimelineLoading());
      await refreshEntries();
      
      print('DEBUG: Successfully updated entry $entryId - Phase: $newPhase, Geometry: $newGeometry');
    } catch (e) {
      print('ERROR: Failed to update entry phase: $e');
      emit(const TimelineError(message: 'Failed to update entry phase'));
    }
  }

  /// Update or create arcform snapshot with new phase/geometry
  Future<void> _updateArcformSnapshot(String entryId, String newPhase, String newGeometry) async {
    try {
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      
      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      
      // Look for existing snapshot for this entry
      ArcformSnapshot? existingSnapshot;
      String? existingKey;
      
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot != null && snapshot.arcformId == entryId) {
          existingSnapshot = snapshot;
          existingKey = key as String;
          break;
        }
      }
      
      if (existingSnapshot != null && existingKey != null) {
        // Update existing snapshot
        final updatedData = Map<String, dynamic>.from(existingSnapshot.data);
        updatedData['phase'] = newPhase;
        updatedData['geometry'] = newGeometry;
        
        final updatedSnapshot = existingSnapshot.copyWith(
          data: updatedData,
          timestamp: DateTime.now(),
        );
        
        await box.put(existingKey, updatedSnapshot);
        print('DEBUG: Updated existing arcform snapshot for entry $entryId');
      } else {
        // Create new snapshot
        final newSnapshot = ArcformSnapshot(
          id: '${entryId}_updated_${DateTime.now().millisecondsSinceEpoch}',
          arcformId: entryId,
          data: {
            'phase': newPhase,
            'geometry': newGeometry,
            'updated_by_user': true,
            'updated_at': DateTime.now().toIso8601String(),
          },
          timestamp: DateTime.now(),
          notes: 'Phase updated by user to $newPhase',
        );
        
        await box.put(newSnapshot.id, newSnapshot);
        print('DEBUG: Created new arcform snapshot for entry $entryId');
      }
    } catch (e) {
      print('ERROR: Failed to update arcform snapshot: $e');
      rethrow;
    }
  }

  Future<void> setFilter(TimelineFilter filter) async {
    if (state is TimelineLoaded) {
      final currentState = state as TimelineLoaded;
      if (currentState.filter == filter) return;

      emit(const TimelineLoading());
      _currentPage = 0;
      _hasMore = true;
      await _loadAllEntries(filter: filter);
    }
  }

  Future<void> _loadEntries({TimelineFilter? filter}) async {
    print('DEBUG: TimelineCubit._loadEntries() called with filter: $filter');
    try {
      final currentState = state is TimelineLoaded
          ? state as TimelineLoaded
          : const TimelineLoaded(
              groupedEntries: [],
              filter: TimelineFilter.all,
              hasMore: true,
            );

      final effectiveFilter = filter ?? currentState.filter;

      final newEntries = _journalRepository.getEntriesPaginatedSync(
        page: _currentPage,
        pageSize: _pageSize,
        filter: effectiveFilter,
      );

      // Check if we've reached the end
      _hasMore = newEntries.length == _pageSize;

      // Group entries by month
      // If this is the first page (refresh), start fresh; otherwise append to existing
      final List<TimelineEntry> allEntries;
      if (_currentPage == 0) {
        // Fresh load - use only new entries
        allEntries = _mapToTimelineEntries(newEntries);
      } else {
        // Paginated load - append to existing entries
        allEntries = [
          ...currentState.groupedEntries.expand((g) => g.entries),
          ..._mapToTimelineEntries(newEntries)
        ];
      }
      
      // For single scroll timeline, we don't need complex grouping
      final groupedEntries = [TimelineMonthGroup(month: 'All', entries: allEntries)];

      print('DEBUG: TimelineCubit emitting TimelineLoaded with ${groupedEntries.length} groups');
      emit(TimelineLoaded(
        groupedEntries: groupedEntries,
        filter: effectiveFilter,
        hasMore: _hasMore,
      ));
    } catch (e) {
      emit(const TimelineError(message: 'Failed to load timeline entries'));
    }
  }

  /// Load all entries without pagination (used when entry dates change)
  Future<void> _loadAllEntries({TimelineFilter? filter}) async {
    print('DEBUG: TimelineCubit._loadAllEntries() called with filter: $filter');
    try {
      final currentState = state is TimelineLoaded
          ? state as TimelineLoaded
          : const TimelineLoaded(
              groupedEntries: [],
              filter: TimelineFilter.all,
              hasMore: true,
            );

      final effectiveFilter = filter ?? currentState.filter;

      // Get all entries without pagination
      final allJournalEntries = _journalRepository.getAllJournalEntriesSync();
      
      // Apply filter
      List<JournalEntry> filteredEntries = allJournalEntries;
      switch (effectiveFilter) {
        case TimelineFilter.textOnly:
          filteredEntries = allJournalEntries.where((e) => e.content.isNotEmpty).toList();
          break;
        case TimelineFilter.withArcform:
          filteredEntries = allJournalEntries.where((e) => e.sageAnnotation != null).toList();
          break;
        case TimelineFilter.all:
        default:
          filteredEntries = allJournalEntries;
      }

      // Convert to timeline entries
      final allTimelineEntries = _mapToTimelineEntries(filteredEntries);
      
      // For single scroll timeline, we don't need complex grouping
      final groupedEntries = [TimelineMonthGroup(month: 'All', entries: allTimelineEntries)];

      print('DEBUG: TimelineCubit._loadAllEntries emitting TimelineLoaded with ${groupedEntries.length} groups');
      emit(TimelineLoaded(
        groupedEntries: groupedEntries,
        filter: effectiveFilter,
        hasMore: false, // No pagination when loading all entries
      ));
    } catch (e) {
      emit(const TimelineError(message: 'Failed to load all timeline entries'));
    }
  }

  List<TimelineMonthGroup> _groupEntriesByMonth(List<TimelineEntry> entries) {
    final groups = <String, List<TimelineEntry>>{};

    for (final entry in entries) {
      if (!groups.containsKey(entry.monthYear)) {
        groups[entry.monthYear] = [];
      }
      groups[entry.monthYear]!.add(entry);
    }

    // Sort entries within each group (earliest on left, latest on right)
    for (final group in groups.values) {
      group.sort((a, b) => a.date.compareTo(b.date));
    }

    // Convert to list and sort groups by newest month first
    return groups.entries
        .map((entry) => TimelineMonthGroup(
              month: entry.key,
              entries: entry.value,
            ))
        .toList()
        ..sort((a, b) {
          // Sort by the newest entry in each group (newest month first)
          final aNewestEntry = a.entries.last; // Last entry is newest since we sort oldest-first within groups
          final bNewestEntry = b.entries.last; // Last entry is newest since we sort oldest-first within groups
          return bNewestEntry.date.compareTo(aNewestEntry.date);
        });
  }

  List<TimelineEntry> _mapToTimelineEntries(List<JournalEntry> journalEntries) {
    return journalEntries.map((entry) {
      // Priority 1: Check if entry has user-updated metadata (highest priority - user override)
      String? phase;
      String? geometry;

      if (entry.metadata != null && entry.metadata!['updated_by_user'] == true) {
        phase = entry.metadata!['phase'] as String?;
        geometry = entry.metadata!['geometry'] as String?;
        print('DEBUG: Entry ${entry.id} - Using user-updated metadata - Phase: $phase, Geometry: $geometry');
      }

      // Priority 2: Use overall phase from arcform snapshots (authoritative source)
      if (phase == null) {
        phase = _getPhaseForEntry(entry);
        geometry = _getGeometryForEntry(entry);
        print('DEBUG: Entry ${entry.id} - Using overall phase from arcform snapshots - Phase: $phase, Geometry: $geometry');
      }

      // Priority 3: Final fallback to Discovery if no phase is found
      // Note: We removed the unreliable keyword-based phase detection
      if (phase == null) {
        phase = 'Discovery';
        print('DEBUG: Entry ${entry.id} - No phase found, using default: $phase');
      }

      print('DEBUG: Entry ${entry.id} - Final phase: $phase, Media count: ${entry.media.length}');
      
      // Check if entry has photo placeholders but no media items (legacy entry)
      List<MediaItem> finalMedia = entry.media;
      if (entry.media.isEmpty && entry.content.contains('[PHOTO:')) {
        print('DEBUG: Entry ${entry.id} has photo placeholders but no media items - attempting reconstruction');
        finalMedia = _reconstructMediaFromPlaceholders(entry.content);
        print('DEBUG: Reconstructed ${finalMedia.length} media items from placeholders');
      } else if (entry.media.isNotEmpty) {
        print('DEBUG: Entry ${entry.id} has ${entry.media.length} media items - using actual media');
        // Use the actual media items from the entry (these should have reconnected ph:// URIs)
        finalMedia = entry.media;
      }
      
      if (finalMedia.isNotEmpty) {
        for (int i = 0; i < finalMedia.length; i++) {
          final media = finalMedia[i];
          print('DEBUG: Timeline Media $i - Type: ${media.type}, URI: ${media.uri}, AnalysisData: ${media.analysisData?.keys}');
        }
      }

      return TimelineEntry(
        id: entry.id,
        date: _formatDate(entry.createdAt),
        monthYear: _formatMonthYear(entry.createdAt),
        preview: entry.content.isNotEmpty
            ? entry.content
            : 'Entry with Arcform snapshot', // Fallback if no content
        hasArcform: entry.sageAnnotation != null,
        keywords: _extractKeywords(entry),
        phase: phase,
        geometry: geometry,
        media: finalMedia, // Use reconstructed media if available
        createdAt: entry.createdAt, // Store original date for sorting
      );
    }).toList();
  }


  List<String> _extractKeywords(JournalEntry entry) {
    // Use the actual keywords that were stored in the entry
    // These should be the keywords that were auto-selected by the algorithm
    if (entry.keywords.isNotEmpty) {
      return entry.keywords;
    }
    
    // Fallback: extract keywords from sage annotation if available
    if (entry.sageAnnotation != null) {
      final annotation = entry.sageAnnotation!;
      // Extract key terms from SAGE components
      final allText = '${annotation.situation} ${annotation.action} ${annotation.growth} ${annotation.essence}';
      return _extractImportantWords(allText);
    }
    
    // Final fallback: extract simple keywords from content
    return _extractImportantWords(entry.content);
  }

  /// Reconstruct media items from photo placeholders in content
  List<MediaItem> _reconstructMediaFromPlaceholders(String content) {
    final mediaItems = <MediaItem>[];
    final photoPlaceholderRegex = RegExp(r'\[PHOTO:([^\]]+)\]');
    final matches = photoPlaceholderRegex.allMatches(content);
    
    for (final match in matches) {
      final photoId = match.group(1)!;
      print('DEBUG: Reconstructing media for placeholder: [PHOTO:$photoId]');
      
      // Try to find the original ph:// URI for this photo ID
      // This is a fallback for legacy entries that don't have media items
      final mediaItem = MediaItem(
        id: photoId,
        uri: 'placeholder://$photoId', // Placeholder URI (will show as unavailable)
        type: MediaType.image, // Default to image
        createdAt: DateTime.now(),
        altText: 'Photo unavailable - tap to remove',
        analysisData: {
          'photo_id': photoId,
          'imported': true,
          'placeholder': true,
          'unavailable': true,
        },
      );
      
      mediaItems.add(mediaItem);
    }
    
    return mediaItems;
  }

  List<String> _extractImportantWords(String text) {
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    final importantWords = words.where((word) => 
      word.length > 4 && 
      !_stopWords.contains(word)
    ).take(3).toList();
    
    return importantWords;
  }

  static const _stopWords = {
    'that', 'this', 'with', 'have', 'will', 'been', 'from', 'they', 
    'know', 'want', 'good', 'much', 'some', 'time', 'very',
    'when', 'come', 'here', 'just', 'like', 'long', 'make', 'many',
    'over', 'such', 'take', 'than', 'them', 'well', 'were'
  };

  String _formatDate(DateTime date) {
    // Format as "Month Day, Year" for better readability
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatMonthYear(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Get the geometry pattern that was active for a specific entry
  String? _getGeometryForEntry(JournalEntry entry) {
    try {
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        return null;
      }
      
      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      
      // Find the closest arcform snapshot to this entry's creation time
      ArcformSnapshot? closestSnapshot;
      Duration? smallestDifference;
      
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot != null) {
          final difference = entry.createdAt.difference(snapshot.timestamp).abs();
          
          // Only consider snapshots from before or around the same time as the entry
          if (snapshot.timestamp.isBefore(entry.createdAt.add(const Duration(hours: 1)))) {
            if (smallestDifference == null || difference < smallestDifference) {
              smallestDifference = difference;
              closestSnapshot = snapshot;
            }
          }
        }
      }
      
      if (closestSnapshot != null) {
        return closestSnapshot.data['geometry'] as String?;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the phase that was determined for a specific entry from arcform snapshots
  String? _getPhaseForEntry(JournalEntry entry) {
    try {
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        return null;
      }
      
      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      
      // First, try to find a snapshot with matching arcformId
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot != null && snapshot.arcformId == entry.id) {
          // Try to get phase from the snapshot data
          final phase = snapshot.data['phase'] as String?;
          if (phase != null) {
            print('DEBUG: Found phase for entry ${entry.id}: $phase');
            return phase;
          }
          
          // Fallback: determine phase from geometry if no explicit phase stored
          final geometry = snapshot.data['geometry'] as String?;
          if (geometry != null) {
            final derivedPhase = _geometryToPhase(geometry);
            print('DEBUG: Derived phase from geometry for entry ${entry.id}: $derivedPhase');
            return derivedPhase;
          }
        }
      }
      
      // If no exact match, find the closest arcform snapshot to this entry's creation time
      ArcformSnapshot? closestSnapshot;
      Duration? smallestDifference;
      
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot != null) {
          final difference = entry.createdAt.difference(snapshot.timestamp).abs();
          
          // Only consider snapshots from before or around the same time as the entry
          if (snapshot.timestamp.isBefore(entry.createdAt.add(const Duration(hours: 1)))) {
            if (smallestDifference == null || difference < smallestDifference) {
              smallestDifference = difference;
              closestSnapshot = snapshot;
            }
          }
        }
      }
      
      if (closestSnapshot != null) {
        // Try to get phase from the snapshot data
        final phase = closestSnapshot.data['phase'] as String?;
        if (phase != null) {
          print('DEBUG: Found phase from closest snapshot for entry ${entry.id}: $phase');
          return phase;
        }
        
        // Fallback: determine phase from geometry if no explicit phase stored
        final geometry = closestSnapshot.data['geometry'] as String?;
        if (geometry != null) {
          final derivedPhase = _geometryToPhase(geometry);
          print('DEBUG: Derived phase from closest snapshot geometry for entry ${entry.id}: $derivedPhase');
          return derivedPhase;
        }
      }
      
      print('DEBUG: No phase found for entry ${entry.id}');
      return null;
    } catch (e) {
      print('DEBUG: Error getting phase for entry ${entry.id}: $e');
      return null;
    }
  }

  /// Convert geometry name to phase name
  String _geometryToPhase(String geometry) {
    switch (geometry.toLowerCase()) {
      case 'spiral':
        return 'Discovery';
      case 'flower':
        return 'Expansion';
      case 'branch':
        return 'Transition';
      case 'weave':
        return 'Consolidation';
      case 'glowcore':
        return 'Recovery';
      case 'fractal':
        return 'Breakthrough';
      default:
        return 'Discovery';
    }
  }
}
