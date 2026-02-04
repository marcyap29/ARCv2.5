import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/atlas_phase_decision_service.dart';
import 'package:my_app/state/journal_entry_state.dart';
import 'package:hive/hive.dart';

class TimelineCubit extends Cubit<TimelineState> {
  final JournalRepository _journalRepository;
  PhaseIndex? _phaseIndex;
  PhaseRegimeService? _phaseRegimeService;
  static const int _pageSize = 20; // Load 20 entries at a time
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false; // Prevent concurrent loads

  TimelineCubit({JournalRepository? journalRepository})
      : _journalRepository = journalRepository ?? JournalRepository(),
        super(const TimelineInitial()) {
    _initializePhaseIndex();
  }

  /// Initialize phase index for regime-based phase lookup
  Future<void> _initializePhaseIndex() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      _phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await _phaseRegimeService!.initialize();
      _phaseIndex = _phaseRegimeService!.phaseIndex;
    } catch (e) {
      print('Warning: Could not initialize phase index: $e');
      // Continue without phase index - entries will fall back to explicit phase data only
    }
  }

  /// Refresh phase index when regimes have been updated
  Future<void> refreshPhaseIndex() async {
    await _initializePhaseIndex();
    // Refresh timeline to reflect updated regime assignments
    await refreshEntries();
  }

  Future<void> loadEntries() async {
    emit(const TimelineLoading());
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;
    await _loadEntries(); // Use pagination instead of loading all
  }

  Future<void> loadMoreEntries() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    _currentPage++;
    try {
    await _loadEntries();
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refreshEntries() async {
    print('DEBUG: TimelineCubit.refreshEntries() called');
    print('DEBUG: Refreshing timeline to show updated entries...');
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;
    await _loadEntries(); // Use pagination instead of loading all
    print('DEBUG: Timeline refresh completed');
  }

  /// Reload all entries (used when an entry's date changes and might move pages)
  /// Uses pagination for performance - resets to page 0 and reloads
  Future<void> reloadAllEntries() async {
    print('DEBUG: TimelineCubit.reloadAllEntries() called');
    print('DEBUG: Reloading entries to handle date changes (using pagination)...');
    emit(const TimelineLoading());
    _currentPage = 0;
    _hasMore = true;
    _isLoadingMore = false;
    await _loadEntries(); // Use pagination for performance
    print('DEBUG: Entries reload completed');
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
      final existingEntry = await _journalRepository.getJournalEntryById(entryId);
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
      await _loadAllEntries(filter: filter, searchQuery: currentState.searchQuery);
    }
  }

  /// Set search query and filter entries
  Future<void> setSearchQuery(String query) async {
    if (state is TimelineLoaded) {
      final currentState = state as TimelineLoaded;
      if (currentState.searchQuery == query) return;

      // Reload all entries with the new search query
      emit(const TimelineLoading());
      _currentPage = 0;
      _hasMore = true;
      await _loadAllEntries(
        filter: currentState.filter,
        searchQuery: query,
      );
    }
  }

  /// Apply search filter to timeline entries
  List<TimelineMonthGroup> _applySearchFilter(
    List<TimelineMonthGroup> groups,
    String query,
  ) {
    if (query.trim().isEmpty) {
      return groups;
    }

    final searchLower = query.toLowerCase().trim();
    
    // Try to parse as date (supports formats: MM/DD/YYYY, MM-DD-YYYY, YYYY-MM-DD, MM/DD, etc.)
    DateTime? searchDate;
    try {
      // Try common date formats
      final datePatterns = [
        RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})'), // MM/DD/YYYY or MM-DD-YYYY
        RegExp(r'(\d{1,2})[/-](\d{1,2})'), // MM/DD (current year)
        RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'), // YYYY-MM-DD
      ];
      
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(query);
        if (match != null) {
          if (match.groupCount == 3) {
            // Full date
            final month = int.parse(match.group(1)!);
            final day = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            searchDate = DateTime(year, month, day);
            break;
          } else if (match.groupCount == 2) {
            // Month/Day - use current year
            final month = int.parse(match.group(1)!);
            final day = int.parse(match.group(2)!);
            final now = DateTime.now();
            searchDate = DateTime(now.year, month, day);
            break;
          }
        }
      }
    } catch (e) {
      // Not a valid date, continue with text search
    }
    
    return groups.map((group) {
      final filteredEntries = group.entries.where((entry) {
        // If search is a date, match by date
        if (searchDate != null) {
          final entryDate = DateTime(
            entry.createdAt.year,
            entry.createdAt.month,
            entry.createdAt.day,
          );
          final searchDateOnly = DateTime(
            searchDate.year,
            searchDate.month,
            searchDate.day,
          );
          if (entryDate == searchDateOnly) {
            return true;
          }
        }
        
        // Search in preview text
        if (entry.preview.toLowerCase().contains(searchLower)) {
          return true;
        }
        // Search in title
        if (entry.title != null && entry.title!.toLowerCase().contains(searchLower)) {
          return true;
        }
        // Search in keywords
        if (entry.keywords.any((keyword) => keyword.toLowerCase().contains(searchLower))) {
          return true;
        }
        // Search in date string representation
        final entryDateStr = '${entry.createdAt.month}/${entry.createdAt.day}/${entry.createdAt.year}';
        if (entryDateStr.contains(query)) {
          return true;
        }
        return false;
      }).toList();

      return TimelineMonthGroup(
        month: group.month,
        entries: filteredEntries,
      );
    }).where((group) => group.entries.isNotEmpty).toList();
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
              searchQuery: '',
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
      var groupedEntries = [TimelineMonthGroup(month: 'All', entries: allEntries)];

      // Apply search filter if query exists
      if (currentState.searchQuery.isNotEmpty) {
        groupedEntries = _applySearchFilter(groupedEntries, currentState.searchQuery);
      }

      print('DEBUG: TimelineCubit emitting TimelineLoaded with ${groupedEntries.length} groups');
      emit(TimelineLoaded(
        groupedEntries: groupedEntries,
        filter: effectiveFilter,
        hasMore: _hasMore,
        searchQuery: currentState.searchQuery,
      ));
    } catch (e) {
      emit(const TimelineError(message: 'Failed to load timeline entries'));
    }
  }

  /// Load all entries without pagination (used when entry dates change)
  Future<void> _loadAllEntries({TimelineFilter? filter, String? searchQuery}) async {
    print('DEBUG: TimelineCubit._loadAllEntries() called with filter: $filter, searchQuery: $searchQuery');
    try {
      // Ensure phase index is available before resolving phases for entries
      await _initializePhaseIndex();

      final currentState = state is TimelineLoaded
          ? state as TimelineLoaded
          : const TimelineLoaded(
              groupedEntries: [],
              filter: TimelineFilter.all,
              hasMore: true,
              searchQuery: '',
            );

      final effectiveFilter = filter ?? currentState.filter;
      final effectiveSearchQuery = searchQuery ?? currentState.searchQuery;

      // Add a small delay to ensure Hive box is fully opened and metadata is deserialized
      // This is especially important after app resume/restart
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Get all entries without pagination (async to ensure Hive box opens)
      final allJournalEntries = await _journalRepository.getAllJournalEntries();

      // Rebuild phase regimes from entries with a 14-day minimum per regime to align Timeline with Rivet analysis
      try {
        if (_phaseRegimeService != null) {
          await _phaseRegimeService!.rebuildRegimesFromEntries(
            allJournalEntries,
            windowDays: 10,
          );
          _phaseIndex = _phaseRegimeService!.phaseIndex;
        }
      } catch (e) {
        print('Warning: Failed to rebuild phase regimes from entries: $e');
      }
      
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
          filteredEntries = allJournalEntries;
          break;
      }

      // Convert to timeline entries
      final allTimelineEntries = _mapToTimelineEntries(filteredEntries);
      
      // For single scroll timeline, we don't need complex grouping
      var groupedEntries = [TimelineMonthGroup(month: 'All', entries: allTimelineEntries)];

      // Apply search filter if query is provided
      if (effectiveSearchQuery.isNotEmpty) {
        groupedEntries = _applySearchFilter(groupedEntries, effectiveSearchQuery);
      }

      print('DEBUG: TimelineCubit._loadAllEntries emitting TimelineLoaded with ${groupedEntries.length} groups');
      emit(TimelineLoaded(
        groupedEntries: groupedEntries,
        filter: effectiveFilter,
        hasMore: false, // No pagination when loading all entries
        searchQuery: effectiveSearchQuery,
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
      // Priority order for phase determination:
      // 1. Entry explicit phase data (userPhaseOverride > autoPhase > legacyPhaseTag > phase)
      // 2. Active phase regime for entry timestamp
      // 3. Create/infer appropriate regime if none exists
      String? phase = _getEntryPhase(entry);
      
      // Show indicator if phase is manually overridden
      final isManual = entry.isPhaseManuallyOverridden;
      if (isManual) {
        print('DEBUG: Entry ${entry.id} - Using manual phase override: $phase');
      } else if (entry.autoPhase != null) {
        print('DEBUG: Entry ${entry.id} - Using auto-detected phase: $phase');
      } else {
        print('DEBUG: Entry ${entry.id} - Using fallback phase: $phase');
      }
      
      String? geometry;

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

      // Extract LUMARA inline blocks directly from the lumaraBlocks field
      final inlineBlocks = entry.lumaraBlocks;
      print('🔍 TIMELINE DEBUG: Entry ${entry.id} - Found ${inlineBlocks.length} LUMARA blocks in lumaraBlocks field');

      // Also check if entry has old metadata format (for debugging migration)
      if (entry.metadata != null && entry.metadata!.containsKey('inlineBlocks')) {
        final oldBlocks = entry.metadata!['inlineBlocks'];
        print('🔍 TIMELINE DEBUG: Entry ${entry.id} - Has old format metadata: ${oldBlocks.runtimeType}');
        if (oldBlocks is List && oldBlocks.isNotEmpty) {
          print('🔍 TIMELINE DEBUG: Entry ${entry.id} - Old format has ${oldBlocks.length} blocks but new field has ${inlineBlocks.length}');
        }
      }

      if (inlineBlocks.isNotEmpty) {
        print('✅ TIMELINE: Entry ${entry.id} HAS ${inlineBlocks.length} LUMARA blocks - tag should appear!');
        for (int i = 0; i < inlineBlocks.length; i++) {
          final block = inlineBlocks[i];
          print('   Block $i - type: ${block.type}, intent: ${block.intent}, hasComment: ${block.userComment != null && block.userComment!.isNotEmpty}');
        }
      } else {
        print('⚠️ TIMELINE: Entry ${entry.id} - NO LUMARA blocks in lumaraBlocks field - tag will NOT appear');
      }

      final timelineEntry = TimelineEntry(
        id: entry.id,
        date: _formatDate(entry.createdAt),
        monthYear: _formatMonthYear(entry.createdAt),
        title: entry.title.isNotEmpty ? entry.title : null,
        preview: entry.content.isNotEmpty
            ? entry.content
            : 'Entry with Arcform snapshot', // Fallback if no content
        hasArcform: entry.sageAnnotation != null,
        keywords: _extractKeywords(entry),
        phase: phase,
        geometry: geometry,
        media: finalMedia, // Use reconstructed media if available
        hasLumaraBlocks: entry.lumaraBlocks.isNotEmpty, // Check if entry has LUMARA blocks
        createdAt: entry.createdAt, // Store original date for sorting
      );
      
      return timelineEntry;
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

  /// Extract phase hashtag from text (e.g., #discovery, #transition)
  String? _extractPhaseHashtag(String text) {
    // Match hashtags followed by phase names (case-insensitive)
    final hashtagPattern = RegExp(r'#(discovery|expansion|transition|consolidation|recovery|breakthrough)', caseSensitive: false);
    final match = hashtagPattern.firstMatch(text);
    
    if (match != null) {
      final phaseName = match.group(1)?.toLowerCase();
      if (phaseName != null) {
        // Capitalize first letter to match expected format
        return phaseName[0].toUpperCase() + phaseName.substring(1);
      }
    }
    
    return null;
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

  /// Get phase for entry using regime-based lookup
  String? _getEntryPhase(JournalEntry entry) {
    // 1. Check for explicit phase data first (highest priority)
    final explicitPhase = entry.computedPhase ?? _getPhaseFromMetadata(entry.metadata);
    if (explicitPhase != null && explicitPhase.trim().isNotEmpty) {
      return _normalizePhaseName(explicitPhase);
    }

    // 2. Look up phase from regime covering this entry's timestamp
    if (_phaseIndex != null) {
      final regime = _phaseIndex!.regimeFor(entry.createdAt);
      if (regime != null) {
        return _phaseLabelToString(regime.label);
      }
    }

    // 3. Infer from content as a final fallback (keeps timeline colorful even if regimes missing)
    final inferredPhase = _inferPhaseFromEntry(entry);
    if (inferredPhase != null) {
      return inferredPhase;
    }

    // 4. Try to recover from hashtags inside the content
    final hashtagPhase = _extractPhaseHashtag(entry.content);
    if (hashtagPhase != null) {
      return hashtagPhase;
    }

    // 3. No regime exists - for now return null, could create regime in future
    // This maintains temporal stability - entries without regimes show as "No Phase"
    return null;
  }

  String? _getPhaseFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final candidates = [
      metadata['phase'],
      metadata['autoPhase'],
      metadata['phase_label'],
      metadata['phaseLabel'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String _normalizePhaseName(String raw) {
    final normalized = raw
        .replaceAll('#', '')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase();

    switch (normalized) {
      case 'discovery':
        return 'Discovery';
      case 'expansion':
        return 'Expansion';
      case 'transition':
        return 'Transition';
      case 'consolidation':
        return 'Consolidation';
      case 'recovery':
        return 'Recovery';
      case 'breakthrough':
        return 'Breakthrough';
      default:
        return raw;
    }
  }

  /// Convert PhaseLabel enum to string
  String _phaseLabelToString(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return 'Discovery';
      case PhaseLabel.expansion:
        return 'Expansion';
      case PhaseLabel.transition:
        return 'Transition';
      case PhaseLabel.consolidation:
        return 'Consolidation';
      case PhaseLabel.recovery:
        return 'Recovery';
      case PhaseLabel.breakthrough:
        return 'Breakthrough';
    }
  }

  /// Infer phase from entry using ATLAS phase decision scoring system
  /// No Discovery bias - uses score-based decisions with hysteresis
  String? _inferPhaseFromEntry(JournalEntry entry, {PhaseLabel? prevPhase}) {
    // Generate phase scores from entry content
    final scores = AtlasPhaseDecisionService.generatePhaseScores(
      content: entry.content,
      keywords: entry.keywords,
      emotion: entry.emotion,
      emotionReason: entry.emotionReason,
    );

    // Debug print scores for development
    if (entry.content.length > 50) { // Only for substantial entries
      AtlasPhaseDecisionService.debugPrintScores(scores, 'Entry ${entry.id.substring(0, 8)}');
    }

    // Use ATLAS decision logic to determine phase
    final decidedPhase = AtlasPhaseDecisionService.decidePhaseForEntry(
      scores: scores,
      prevPhase: prevPhase,
    );

    if (decidedPhase != null) {
      return _phaseLabelToString(decidedPhase);
    }

    // Display fallback: when signal is below ATLAS threshold (e.g. top score < 0.35),
    // still show the highest-scoring phase so entries are never shown as "No Phase"
    if (scores.isNotEmpty) {
      final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final fallbackPhase = _phaseLabelToString(sorted.first.key);
      print('DEBUG: Entry ${entry.id} - ATLAS below threshold, using display fallback: $fallbackPhase');
      return fallbackPhase;
    }

    return null;
  }
}
