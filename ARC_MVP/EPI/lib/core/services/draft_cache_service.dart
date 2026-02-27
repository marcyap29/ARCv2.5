/// Draft Cache Service
///
/// Provides automatic persistence of journal drafts to prevent data loss
/// when users switch away, shut down, or experience app crashes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/data/models/media_item.dart';
import 'journal_version_service.dart' show JournalVersionService, DraftAIContent, DraftMediaItem, ConflictInfo;

/// Represents a cached journal draft with all associated data
class JournalDraft {
  final String id;
  final String content;
  final List<MediaItem> mediaItems;
  final String? initialEmotion;
  final String? initialReason;
  final DateTime createdAt;
  final DateTime lastModified;
  final Map<String, dynamic> metadata;
  final String? linkedEntryId; // ID of the original entry this draft is linked to (for editing existing entries)
  final List<Map<String, dynamic>> lumaraBlocks; // LUMARA inline reflection blocks

  JournalDraft({
    required this.id,
    required this.content,
    required this.mediaItems,
    this.initialEmotion,
    this.initialReason,
    required this.createdAt,
    required this.lastModified,
    this.metadata = const {},
    this.linkedEntryId,
    this.lumaraBlocks = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'mediaItems': mediaItems.map((item) => {
        'id': item.id,
        'uri': item.uri,
        'type': item.type.toString(),
        'duration': item.duration?.inMilliseconds,
        'sizeBytes': item.sizeBytes,
        'createdAt': item.createdAt.millisecondsSinceEpoch,
        'transcript': item.transcript,
        'ocrText': item.ocrText,
      }).toList(),
      'initialEmotion': initialEmotion,
      'initialReason': initialReason,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'metadata': metadata,
      'linkedEntryId': linkedEntryId,
      'lumaraBlocks': lumaraBlocks, // Persist LUMARA blocks
    };
  }

  factory JournalDraft.fromJson(Map<String, dynamic> json) {
    return JournalDraft(
      id: json['id'] as String,
      content: json['content'] as String,
      mediaItems: (json['mediaItems'] as List?)?.map((item) => MediaItem(
        id: item['id'] as String,
        uri: item['uri'] as String,
        type: MediaType.values.firstWhere(
          (e) => e.toString() == item['type'],
          orElse: () => MediaType.image,
        ),
        duration: item['duration'] != null
          ? Duration(milliseconds: item['duration'] as int)
          : null,
        sizeBytes: item['sizeBytes'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(item['createdAt'] as int),
        transcript: item['transcript'] as String?,
        ocrText: item['ocrText'] as String?,
      )).toList().cast<MediaItem>() ?? [],
      initialEmotion: json['initialEmotion'] as String?,
      initialReason: json['initialReason'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      lastModified: DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      linkedEntryId: json['linkedEntryId'] as String?,
      lumaraBlocks: (json['lumaraBlocks'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  JournalDraft copyWith({
    String? content,
    List<MediaItem>? mediaItems,
    String? initialEmotion,
    String? initialReason,
    DateTime? lastModified,
    Map<String, dynamic>? metadata,
    String? linkedEntryId,
    List<Map<String, dynamic>>? lumaraBlocks,
  }) {
    return JournalDraft(
      id: id,
      content: content ?? this.content,
      mediaItems: mediaItems ?? this.mediaItems,
      initialEmotion: initialEmotion ?? this.initialEmotion,
      initialReason: initialReason ?? this.initialReason,
      createdAt: createdAt,
      lastModified: lastModified ?? DateTime.now(),
      metadata: metadata ?? this.metadata,
      linkedEntryId: linkedEntryId ?? this.linkedEntryId,
      lumaraBlocks: lumaraBlocks ?? this.lumaraBlocks,
    );
  }

  // Consider draft empty only if there's no text, no media, and no LUMARA blocks
  // This allows entries that start with LUMARA reflections to be saved
  bool get isEmpty => content.trim().isEmpty && mediaItems.isEmpty && lumaraBlocks.isEmpty;
  bool get hasContent => !isEmpty;

  /// Get a summary of the draft for display purposes
  String get summary {
    if (content.isEmpty) return 'Empty draft';

    final truncated = content.length > 100
        ? '${content.substring(0, 100)}...'
        : content;

    return truncated.replaceAll('\n', ' ').trim();
  }

  /// Get age of draft
  Duration get age => DateTime.now().difference(lastModified);

  /// Check if draft is recent (less than 24 hours old)
  bool get isRecent => age.inHours < 24;
}

/// Service for managing journal draft persistence and recovery
class DraftCacheService {
  static const String _boxName = 'journal_drafts';
  static const String _currentDraftKey = 'current_draft';
  static const String _draftHistoryKey = 'draft_history';
  static const Duration _maxDraftAge = Duration(days: 7);
  static const int _maxDraftHistory = 10;

  static DraftCacheService? _instance;
  static DraftCacheService get instance => _instance ??= DraftCacheService._();
  DraftCacheService._();

  Box? _box;
  Timer? _autoSaveTimer;
  Timer? _debounceTimer;
  JournalDraft? _currentDraft;
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  // Content hash tracking for autosave
  String? _lastContentHash;
  DateTime? _lastWriteTime;
  static const Duration _debounceDelay = Duration(seconds: 2); // Gmail-like: 2 seconds instead of 5
  static const Duration _throttleMinInterval = Duration(seconds: 10); // Gmail-like: 10 seconds instead of 30
  
  // Version service integration
  final JournalVersionService _versionService = JournalVersionService.instance;

  /// Initialize the draft cache service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('DraftCacheService: Already initialized, skipping');
      return;
    }

    if (_isInitializing) {
      debugPrint('DraftCacheService: Initialization already in progress, skipping');
      return;
    }

    try {
      _isInitializing = true;
      debugPrint('DraftCacheService: Starting initialization...');
      
      // Add timeout to prevent hanging
      await Future.any([
        _performInitialization(),
        Future.delayed(const Duration(seconds: 10), () {
          throw TimeoutException('DraftCacheService initialization timed out', const Duration(seconds: 10));
        }),
      ]);
      
      _isInitialized = true;
      debugPrint('DraftCacheService: Initialized successfully');
    } catch (e) {
      debugPrint('DraftCacheService: Failed to initialize - $e');
      _isInitialized = false; // Reset flag on failure
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _performInitialization() async {
    _box = await Hive.openBox(_boxName);
    await _cleanupOldDrafts();
  }

  /// Remove duplicate drafts (same content + linkedEntryId or same content without linkedEntryId)
  Future<int> removeDuplicateDrafts() async {
    await _ensureInitialized();
    
    print('🔍 DraftCacheService: Starting duplicate draft removal...');
    
    // Helper function to normalize content for comparison
    String normalizeContent(String content) {
      return content
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
          .replaceAll(RegExp(r'\s+'), '') // Remove all whitespace
          .trim();
    }
    
    final allDrafts = await getAllDrafts();
    final originalCount = allDrafts.length;
    
    // Group drafts by normalized content + linkedEntryId
    final draftMap = <String, List<JournalDraft>>{};
    for (final draft in allDrafts) {
      final normalizedContent = normalizeContent(draft.content);
      final key = '${draft.linkedEntryId ?? 'unlinked'}|$normalizedContent';
      
      if (!draftMap.containsKey(key)) {
        draftMap[key] = [];
      }
      draftMap[key]!.add(draft);
    }
    
    final draftsToDelete = <String>[];
    
    // For each group with duplicates, keep the most recent
    for (final draftList in draftMap.values) {
      if (draftList.length > 1) {
        print('⚠️ DraftCacheService: Found ${draftList.length} duplicate drafts');
        // Sort by lastModified descending, keep the first (most recent)
        draftList.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        final keepDraft = draftList.first;
        
        // Mark others for deletion
        for (int i = 1; i < draftList.length; i++) {
          final duplicateDraft = draftList[i];
          if (!draftsToDelete.contains(duplicateDraft.id)) {
            draftsToDelete.add(duplicateDraft.id);
            print('   ✅ Marking duplicate draft for deletion: ${duplicateDraft.id} (keeping ${keepDraft.id})');
          }
        }
      }
    }
    
    // Delete duplicate drafts
    int deletedCount = 0;
    if (draftsToDelete.isNotEmpty) {
      await deleteDrafts(draftsToDelete);
      deletedCount = draftsToDelete.length;
    }
    
    print('🔍 DraftCacheService: Duplicate draft removal complete');
    print('   Original drafts: $originalCount');
    print('   Duplicates removed: $deletedCount');
    
    return deletedCount;
  }

  /// Create a new draft session or reuse existing one (single-draft-per-entry invariant)
  Future<String> createDraft({
    String? initialEmotion,
    String? initialReason,
    String initialContent = '',
    List<MediaItem> initialMedia = const [],
    String? linkedEntryId, // ID of the original entry this draft is linked to
    String? baseVersionId, // If editing an old version, reference the base version
  }) async {
    await _ensureInitialized();
    
    // Run deduplication before creating new draft (silently in background)
    try {
      await removeDuplicateDrafts();
    } catch (e) {
      debugPrint('DraftCacheService: Error running deduplication: $e');
      // Continue even if deduplication fails
    }

    // SINGLE-DRAFT INVARIANT: If editing an existing entry, check for existing draft
    if (linkedEntryId != null) {
      // First check MCP version service
      final mcpDraft = await _versionService.getDraft(linkedEntryId);
      if (mcpDraft != null) {
        // Reuse existing MCP draft
        debugPrint('DraftCacheService: Found existing MCP draft for entry $linkedEntryId');
        
        // Also check Hive for legacy compatibility
        final hiveDraft = await getDraftByLinkedEntryId(linkedEntryId);
        if (hiveDraft != null && mcpDraft.content == hiveDraft.content) {
          // Use Hive draft (has LUMARA blocks)
          _currentDraft = hiveDraft;
        } else {
          // Create new Hive draft from MCP draft
          final now = DateTime.now();
          final mediaItems = await _convertDraftMediaToMediaItems(mcpDraft.media, linkedEntryId);
          _currentDraft = JournalDraft(
            id: 'draft_${now.millisecondsSinceEpoch}',
            content: mcpDraft.content,
            mediaItems: mediaItems,
            createdAt: mcpDraft.createdAt,
            lastModified: mcpDraft.updatedAt,
            linkedEntryId: linkedEntryId,
            metadata: mcpDraft.metadata,
          );
        }
        
        _lastContentHash = mcpDraft.contentHash;
        await _saveDraft(_currentDraft!);
        return _currentDraft!.id;
      }

      // Check Hive for legacy drafts
      final existingDraft = await getDraftByLinkedEntryId(linkedEntryId);
      if (existingDraft != null) {
        debugPrint('DraftCacheService: Found existing Hive draft ${existingDraft.id} for entry $linkedEntryId');
        _currentDraft = existingDraft.copyWith(
          lastModified: DateTime.now(),
          content: initialContent.isNotEmpty ? initialContent : existingDraft.content,
          mediaItems: initialMedia.isNotEmpty ? List.from(initialMedia) : existingDraft.mediaItems,
        );
        _lastContentHash = _computeContentHash(_currentDraft!.content);
        await _saveDraft(_currentDraft!);
        return _currentDraft!.id;
      }

      // Note: baseVersionId handling is done by caller when editing old versions
      // If baseVersionId is null, we're editing the latest (or creating new)
    }

    // If we already have a current draft with the same linkedEntryId, reuse it (single-draft invariant)
    if (_currentDraft != null && _currentDraft!.linkedEntryId == linkedEntryId) {
      debugPrint('DraftCacheService: Reusing existing draft ${_currentDraft!.id}');
      return _currentDraft!.id;
    }

    // Create new draft
    final now = DateTime.now();
    final draftId = 'draft_${now.millisecondsSinceEpoch}';

    _currentDraft = JournalDraft(
      id: draftId,
      content: initialContent,
      mediaItems: List.from(initialMedia),
      initialEmotion: initialEmotion,
      initialReason: initialReason,
      createdAt: now,
      lastModified: now,
      linkedEntryId: linkedEntryId,
      lumaraBlocks: const [],
      metadata: baseVersionId != null ? {'baseVersionId': baseVersionId} : {},
    );

    _lastContentHash = _computeContentHash(initialContent);
    await _saveDraft(_currentDraft!);

    // Also create MCP draft if linked
    if (linkedEntryId != null) {
      try {
        await _versionService.saveDraft(
          entryId: linkedEntryId,
          content: initialContent,
          media: initialMedia,
          ai: [], // No AI content initially
          metadata: _currentDraft!.metadata,
          baseVersionId: baseVersionId,
        );
      } catch (e) {
        debugPrint('DraftCacheService: Error creating MCP draft: $e');
      }
    }

    // Start Gmail-like periodic saves for long writing sessions
    startPeriodicSave();

    debugPrint('DraftCacheService: Created new draft $draftId${linkedEntryId != null ? ' (linked to entry $linkedEntryId)' : ''} with periodic saves');
    return draftId;
  }

  /// Compute content hash
  String _computeContentHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Update the current draft content with debounce and hash checking
  /// Gmail-like behavior: supports multiple trigger types for seamless saving
  Future<void> updateDraftContent(String content, {List<Map<String, dynamic>>? lumaraBlocks, bool immediate = false}) async {
    if (_currentDraft == null) return;

    final newHash = _computeContentHash(content);

    // Skip if content hasn't changed
    if (newHash == _lastContentHash && !immediate) {
      return;
    }

    // Cancel existing debounce timer
    _debounceTimer?.cancel();

    if (immediate) {
      // Save immediately (e.g., on blur, on exit, on pause)
      await _performDraftWrite(content, lumaraBlocks, newHash);
    } else {
      // Debounce: schedule save after delay
      _debounceTimer = Timer(_debounceDelay, () async {
        await _performDraftWrite(content, lumaraBlocks, newHash);
      });
    }
  }

  /// Gmail-like auto-save triggered by user actions (blur, selection change, etc.)
  Future<void> updateDraftOnUserAction(String content, {List<Map<String, dynamic>>? lumaraBlocks}) async {
    // Save immediately on user actions that indicate intent to pause
    await updateDraftContent(content, lumaraBlocks: lumaraBlocks, immediate: true);
  }

  /// Gmail-like periodic save for long writing sessions (every 60 seconds)
  void startPeriodicSave() {
    // Cancel any existing periodic timer
    _autoSaveTimer?.cancel();

    // Start periodic save every minute during active writing
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_currentDraft != null) {
        await updateDraftContent(_currentDraft!.content, immediate: true);
        debugPrint('DraftCacheService: Periodic save completed');
      }
    });
  }

  /// Stop periodic saves
  void stopPeriodicSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// Perform the actual draft write with throttle check
  Future<void> _performDraftWrite(String content, List<Map<String, dynamic>>? lumaraBlocks, String contentHash) async {
    // Throttle: ensure minimum interval between writes
    final now = DateTime.now();
    if (_lastWriteTime != null && now.difference(_lastWriteTime!) < _throttleMinInterval) {
      debugPrint('DraftCacheService: Throttled write (min interval not met)');
      return;
    }

    // Skip if hash unchanged (double-check after debounce)
    if (contentHash == _lastContentHash) {
      debugPrint('DraftCacheService: Content hash unchanged, skipping write');
      return;
    }

    _currentDraft = _currentDraft!.copyWith(
      content: content,
      lastModified: DateTime.now(),
      lumaraBlocks: lumaraBlocks ?? _currentDraft!.lumaraBlocks,
    );

    // Save to Hive (legacy)
    await _saveDraft(_currentDraft!);

    // Also save to MCP version service if linked to an entry
    if (_currentDraft!.linkedEntryId != null) {
      try {
        final mediaItems = _currentDraft!.mediaItems;
        final aiContent = _convertLumaraBlocksToAIContent(lumaraBlocks);
        await _versionService.saveDraft(
          entryId: _currentDraft!.linkedEntryId!,
          content: content,
          media: mediaItems,
          ai: aiContent,
          metadata: _currentDraft!.metadata,
        );
      } catch (e) {
        debugPrint('DraftCacheService: Error saving to version service: $e');
      }
    }

    _lastContentHash = contentHash;
    _lastWriteTime = now;
    debugPrint('DraftCacheService: Draft written (hash: ${contentHash.substring(0, 8)}...)');
  }

  /// Update the current draft content and media items with hash checking
  Future<void> updateDraftContentAndMedia(String content, List<MediaItem> mediaItems, {List<Map<String, dynamic>>? lumaraBlocks, bool immediate = false}) async {
    if (_currentDraft == null) return;

    final newHash = _computeContentHash(content);
    
    // Skip if content hasn't changed
    if (newHash == _lastContentHash && !immediate) {
      return;
    }

    // Cancel existing debounce timer
    _debounceTimer?.cancel();

    if (immediate) {
      await _performDraftWriteWithMedia(content, mediaItems, lumaraBlocks, newHash);
    } else {
      _debounceTimer = Timer(_debounceDelay, () async {
        await _performDraftWriteWithMedia(content, mediaItems, lumaraBlocks, newHash);
      });
    }
  }

  /// Perform draft write with media
  Future<void> _performDraftWriteWithMedia(
    String content,
    List<MediaItem> mediaItems,
    List<Map<String, dynamic>>? lumaraBlocks,
    String contentHash,
  ) async {
    // Throttle check
    final now = DateTime.now();
    if (_lastWriteTime != null && now.difference(_lastWriteTime!) < _throttleMinInterval) {
      debugPrint('DraftCacheService: Throttled write (min interval not met)');
      return;
    }

    // Hash check
    if (contentHash == _lastContentHash) {
      debugPrint('DraftCacheService: Content hash unchanged, skipping write');
      return;
    }

    _currentDraft = _currentDraft!.copyWith(
      content: content,
      mediaItems: mediaItems,
      lastModified: DateTime.now(),
      lumaraBlocks: lumaraBlocks ?? _currentDraft!.lumaraBlocks,
    );

    await _saveDraft(_currentDraft!);

    // Also save to MCP version service if linked
    if (_currentDraft!.linkedEntryId != null) {
      try {
        final aiContent = _convertLumaraBlocksToAIContent(lumaraBlocks);
        await _versionService.saveDraft(
          entryId: _currentDraft!.linkedEntryId!,
          content: content,
          media: mediaItems,
          ai: aiContent,
          metadata: _currentDraft!.metadata,
        );
      } catch (e) {
        debugPrint('DraftCacheService: Error saving to version service: $e');
      }
    }

    _lastContentHash = contentHash;
    _lastWriteTime = now;
    debugPrint('DraftCacheService: Draft with media written (hash: ${contentHash.substring(0, 8)}...)');
  }

  /// Add media item to the current draft
  Future<void> addMediaToDraft(MediaItem mediaItem) async {
    if (_currentDraft == null) return;

    final updatedMedia = List<MediaItem>.from(_currentDraft!.mediaItems);
    updatedMedia.add(mediaItem);

    _currentDraft = _currentDraft!.copyWith(
      mediaItems: updatedMedia,
      lastModified: DateTime.now(),
    );

    await _saveDraft(_currentDraft!);
  }

  /// Remove media item from the current draft
  Future<void> removeMediaFromDraft(MediaItem mediaItem) async {
    if (_currentDraft == null) return;

    final updatedMedia = List<MediaItem>.from(_currentDraft!.mediaItems);
    updatedMedia.removeWhere((item) => item.uri == mediaItem.uri);

    _currentDraft = _currentDraft!.copyWith(
      mediaItems: updatedMedia,
      lastModified: DateTime.now(),
    );

    await _saveDraft(_currentDraft!);
  }

  /// Get the current active draft
  JournalDraft? getCurrentDraft() {
    return _currentDraft;
  }

  /// Check if there's a recoverable draft
  Future<JournalDraft?> getRecoverableDraft() async {
    await _ensureInitialized();

    try {
      final draftData = _box?.get(_currentDraftKey);
      if (draftData == null) return null;

      final draft = JournalDraft.fromJson(Map<String, dynamic>.from(draftData));

      // Only return if the draft has meaningful content and isn't too old
      if (draft.hasContent && draft.age < _maxDraftAge) {
        return draft;
      }

      // Clean up old/empty draft
      await _clearCurrentDraft();
      return null;
    } catch (e) {
      debugPrint('DraftCacheService: Error getting recoverable draft - $e');
      return null;
    }
  }

  /// Restore a draft as the current working draft
  Future<void> restoreDraft(JournalDraft draft) async {
    _currentDraft = draft.copyWith(lastModified: DateTime.now());
    _lastContentHash = _computeContentHash(_currentDraft!.content);
    await _saveDraft(_currentDraft!);

    // Start Gmail-like periodic saves for restored draft
    startPeriodicSave();

    debugPrint('DraftCacheService: Restored draft ${draft.id} with periodic saves');
  }

  /// Complete the current draft (when successfully saved as journal entry)
  /// Gmail-like behavior: immediately delete completed draft instead of moving to history
  Future<void> completeDraft() async {
    if (_currentDraft == null) return;

    final draftId = _currentDraft!.id;
    final linkedEntryId = _currentDraft!.linkedEntryId;

    // Clear current draft immediately (Gmail-like)
    await _clearCurrentDraft();

    // Also clear from MCP version service if linked
    if (linkedEntryId != null) {
      try {
        await _versionService.discardDraft(linkedEntryId);
      } catch (e) {
        debugPrint('DraftCacheService: Error clearing MCP draft: $e');
      }
    }

    _stopAutoSave();
    _currentDraft = null;
    _lastContentHash = null;
    _lastWriteTime = null;

    debugPrint('DraftCacheService: Completed and immediately deleted draft $draftId (Gmail-like)');
  }

  /// Save current draft immediately (for app close/reset/crash scenarios)
  Future<void> saveCurrentDraftImmediately() async {
    if (_currentDraft == null) return;
    
    try {
      // Update lastModified timestamp before saving
      _currentDraft = _currentDraft!.copyWith(lastModified: DateTime.now());
      await _saveDraft(_currentDraft!);
      debugPrint('DraftCacheService: Saved current draft immediately (ID: ${_currentDraft!.id})');
    } catch (e) {
      debugPrint('DraftCacheService: Error saving draft immediately - $e');
    }
  }

  /// Get all saved drafts (including current and history)
  Future<List<JournalDraft>> getAllDrafts() async {
    await _ensureInitialized();
    
    final List<JournalDraft> allDrafts = [];
    
    // Add current draft if it exists and has content
    if (_currentDraft != null && _currentDraft!.hasContent) {
      allDrafts.add(_currentDraft!);
    }
    
    // Add history drafts
    final historyDrafts = await getDraftHistory();
    allDrafts.addAll(historyDrafts);
    
    // Sort by last modified (most recent first)
    allDrafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    
    return allDrafts;
  }

  /// Find a draft by linked entry ID
  Future<JournalDraft?> getDraftByLinkedEntryId(String entryId) async {
    await _ensureInitialized();
    
    // Check current draft
    if (_currentDraft != null && _currentDraft!.linkedEntryId == entryId) {
      return _currentDraft;
    }
    
    // Check history drafts
    final historyDrafts = await getDraftHistory();
    try {
      final linkedDraft = historyDrafts.firstWhere(
        (draft) => draft.linkedEntryId == entryId,
      );
      
      if (linkedDraft.hasContent && linkedDraft.age < _maxDraftAge) {
        return linkedDraft;
      }
    } catch (e) {
      // No draft found for this entry ID
      return null;
    }
    
    return null;
  }

  /// Check if there's a draft linked to a specific entry ID
  Future<bool> hasDraftForEntry(String entryId) async {
    try {
      final draft = await getDraftByLinkedEntryId(entryId);
      return draft != null;
    } catch (e) {
      return false;
    }
  }

  /// Delete specific drafts by IDs
  Future<void> deleteDrafts(List<String> draftIds) async {
    await _ensureInitialized();
    
    try {
      // Remove from current draft if it's in the list
      if (_currentDraft != null && draftIds.contains(_currentDraft!.id)) {
        await _clearCurrentDraft();
        _currentDraft = null;
      }
      
      // Remove from history
      final historyDrafts = await getDraftHistory();
      final remainingDrafts = historyDrafts
          .where((draft) => !draftIds.contains(draft.id))
          .toList();
      
      await _box?.put(_draftHistoryKey,
          remainingDrafts.map((d) => d.toJson()).toList());
      
      debugPrint('DraftCacheService: Deleted ${draftIds.length} drafts');
    } catch (e) {
      debugPrint('DraftCacheService: Error deleting drafts - $e');
    }
  }

  /// Delete a single draft by ID
  Future<void> deleteDraft(String draftId) async {
    await deleteDrafts([draftId]);
  }

  /// Discard the current draft (legacy method - kept for compatibility, use discardDraft() below)
  @Deprecated('Use discardDraft() which handles both Hive and MCP drafts')
  Future<void> discardCurrentDraft() async {
    await discardDraft();
  }

  /// Get draft history for recovery purposes
  Future<List<JournalDraft>> getDraftHistory() async {
    await _ensureInitialized();

    try {
      final historyData = _box?.get(_draftHistoryKey) as List?;
      if (historyData == null) return [];

      return historyData
          .map((item) => JournalDraft.fromJson(Map<String, dynamic>.from(item)))
          .where((draft) => draft.hasContent && draft.age < _maxDraftAge)
          .toList();
    } catch (e) {
      debugPrint('DraftCacheService: Error getting draft history - $e');
      return [];
    }
  }

  /// Clear all drafts (useful for cleanup)
  Future<void> clearAllDrafts() async {
    await _ensureInitialized();
    await _box?.clear();
    _currentDraft = null;
    _stopAutoSave();
    debugPrint('DraftCacheService: Cleared all drafts');
  }

  /// Private methods

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  Future<void> _saveDraft(JournalDraft draft) async {
    try {
      // Check for duplicate drafts before saving
      await _checkAndRemoveDuplicateDrafts(draft);
      await _box?.put(_currentDraftKey, draft.toJson());
    } catch (e) {
      debugPrint('DraftCacheService: Error saving draft - $e');
    }
  }
  
  /// Check for and remove duplicate drafts matching the current draft
  Future<void> _checkAndRemoveDuplicateDrafts(JournalDraft currentDraft) async {
    try {
      // Helper function to normalize content
      String normalizeContent(String content) {
        return content
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .replaceAll(RegExp(r'\s+'), '')
            .trim();
      }
      
      final allDrafts = await getAllDrafts();
      final normalizedCurrent = normalizeContent(currentDraft.content);
      final currentKey = '${currentDraft.linkedEntryId ?? 'unlinked'}|$normalizedCurrent';
      
      final duplicatesToDelete = <String>[];
      
      for (final draft in allDrafts) {
        // Skip the current draft itself
        if (draft.id == currentDraft.id) continue;
        
        final normalizedDraft = normalizeContent(draft.content);
        final draftKey = '${draft.linkedEntryId ?? 'unlinked'}|$normalizedDraft';
        
        // If same normalized content and same linkedEntryId (or both unlinked), mark for deletion
        if (draftKey == currentKey) {
          // Keep the one with later lastModified, delete the older one
          if (draft.lastModified.isBefore(currentDraft.lastModified)) {
            duplicatesToDelete.add(draft.id);
            debugPrint('DraftCacheService: Found duplicate draft ${draft.id}, will delete (keeping ${currentDraft.id})');
          }
        }
      }
      
      if (duplicatesToDelete.isNotEmpty) {
        await deleteDrafts(duplicatesToDelete);
        debugPrint('DraftCacheService: Removed ${duplicatesToDelete.length} duplicate drafts');
      }
    } catch (e) {
      debugPrint('DraftCacheService: Error checking for duplicate drafts: $e');
      // Don't fail draft save if deduplication check fails
    }
  }

  Future<void> _clearCurrentDraft() async {
    try {
      await _box?.delete(_currentDraftKey);
    } catch (e) {
      debugPrint('DraftCacheService: Error clearing current draft - $e');
    }
  }

  // Removed _moveDraftToHistory - drafts are now immediately deleted when completed (Gmail-like)

  void _stopAutoSave() {
    // Cancel both periodic timer and debounce timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    debugPrint('DraftCacheService: Stopped all auto-save timers');
  }

  /// Publish current draft (save as version, update latest, clear draft)
  Future<void> publishDraft({
    String? phase,
    Map<String, dynamic>? sentiment,
  }) async {
    if (_currentDraft == null || _currentDraft!.linkedEntryId == null) {
      throw StateError('Cannot publish: no draft linked to an entry');
    }

    try {
      final aiContent = _convertLumaraBlocksToAIContent(_currentDraft!.lumaraBlocks);
      await _versionService.publish(
        entryId: _currentDraft!.linkedEntryId!,
        content: _currentDraft!.content,
        media: _currentDraft!.mediaItems,
        ai: aiContent,
        metadata: _currentDraft!.metadata,
        phase: phase,
        sentiment: sentiment,
      );

      // Clear Hive draft
      await completeDraft();
      _lastContentHash = null;
      _lastWriteTime = null;

      debugPrint('DraftCacheService: Published draft for entry ${_currentDraft!.linkedEntryId}');
    } catch (e) {
      debugPrint('DraftCacheService: Error publishing draft: $e');
      rethrow;
    }
  }

  /// Save version (creates new version, keeps draft open)
  Future<void> saveVersion({
    String? phase,
    Map<String, dynamic>? sentiment,
  }) async {
    if (_currentDraft == null || _currentDraft!.linkedEntryId == null) {
      throw StateError('Cannot save version: no draft linked to an entry');
    }

    try {
      final baseVersionId = _currentDraft!.metadata['baseVersionId'] as String?;
      final aiContent = _convertLumaraBlocksToAIContent(_currentDraft!.lumaraBlocks);
      
      await _versionService.saveVersion(
        entryId: _currentDraft!.linkedEntryId!,
        content: _currentDraft!.content,
        media: _currentDraft!.mediaItems,
        ai: aiContent,
        metadata: _currentDraft!.metadata,
        baseVersionId: baseVersionId,
        phase: phase,
        sentiment: sentiment,
      );

      debugPrint('DraftCacheService: Saved version for entry ${_currentDraft!.linkedEntryId} (draft remains open)');
    } catch (e) {
      debugPrint('DraftCacheService: Error saving version: $e');
      rethrow;
    }
  }

  /// Discard draft (delete draft.json, keep versions)
  Future<void> discardDraft() async {
    if (_currentDraft?.linkedEntryId != null) {
      try {
        await _versionService.discardDraft(_currentDraft!.linkedEntryId!);
      } catch (e) {
        debugPrint('DraftCacheService: Error discarding MCP draft: $e');
      }
    }

    await _clearCurrentDraft();
    _stopAutoSave();
    _currentDraft = null;
    _lastContentHash = null;
    _lastWriteTime = null;
    debugPrint('DraftCacheService: Discarded draft');
  }

  /// Check for conflicts with remote changes
  Future<ConflictInfo?> checkConflict() async {
    if (_currentDraft?.linkedEntryId == null) return null;
    
    try {
      return await _versionService.checkConflict(_currentDraft!.linkedEntryId!);
    } catch (e) {
      debugPrint('DraftCacheService: Error checking conflict: $e');
      return null;
    }
  }

  /// Convert LUMARA blocks (from journal_entry_state.dart) to DraftAIContent
  List<DraftAIContent> _convertLumaraBlocksToAIContent(
    List<Map<String, dynamic>>? lumaraBlocks,
  ) {
    if (lumaraBlocks == null || lumaraBlocks.isEmpty) return [];

    return lumaraBlocks.map((blockJson) {
      return DraftAIContent(
        id: JournalVersionService.generateUlid(),
        role: 'assistant',
        scope: 'inline',
        purpose: blockJson['intent'] as String? ?? 'reflection',
        text: blockJson['content'] as String? ?? '',
        createdAt: blockJson['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(blockJson['timestamp'] as int)
            : DateTime.now(),
        models: {
          'name': 'LUMARA',
          'params': {},
        },
        provenance: {
          'source': 'in-journal',
          'trace_id': blockJson['type'] as String? ?? 'inline_reflection',
        },
      );
    }).toList();
  }

  /// Convert DraftMediaItem list to MediaItem list (for Hive compatibility)
  Future<List<MediaItem>> _convertDraftMediaToMediaItems(
    List<DraftMediaItem> draftMedia,
    String entryId,
  ) async {
    final mediaItems = <MediaItem>[];
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final entryDir = Directory(path.join(appDir.path, 'mcp', 'entries', entryId));
      
      for (final draftMediaItem in draftMedia) {
        // Resolve relative path to absolute path
        final mediaPath = draftMediaItem.path.startsWith('draft_media/')
            ? path.join(entryDir.path, draftMediaItem.path)
            : draftMediaItem.path;
        
        final mediaFile = File(mediaPath);
        if (!await mediaFile.exists()) {
          debugPrint('DraftCacheService: Media file not found: $mediaPath');
          continue;
        }

        // Determine MediaType from kind
        final mediaType = draftMediaItem.kind == 'video'
            ? MediaType.video
            : draftMediaItem.kind == 'audio'
                ? MediaType.audio
                : MediaType.image;

        final duration = draftMediaItem.durationMs != null
            ? Duration(milliseconds: draftMediaItem.durationMs!)
            : null;

        mediaItems.add(MediaItem(
          id: draftMediaItem.id,
          uri: mediaPath,
          type: mediaType,
          duration: duration,
          sizeBytes: await mediaFile.length(),
          createdAt: draftMediaItem.createdAt,
          sha256: draftMediaItem.sha256,
          thumbUri: draftMediaItem.thumb != null
              ? path.join(path.dirname(mediaPath), draftMediaItem.thumb!)
              : null,
        ));
      }
    } catch (e) {
      debugPrint('DraftCacheService: Error converting draft media: $e');
    }

    return mediaItems;
  }

  Future<void> _cleanupOldDrafts() async {
    try {
      // Clean up current draft if too old (direct access to avoid recursion)
      final draftData = _box?.get(_currentDraftKey);
      if (draftData != null) {
        final current = JournalDraft.fromJson(Map<String, dynamic>.from(draftData));
        if (current.hasContent && current.age > _maxDraftAge) {
          await _clearCurrentDraft();
        }
      }

      // Clean up history (direct access to avoid recursion)
      final historyData = _box?.get(_draftHistoryKey) as List?;
      if (historyData != null) {
        final history = historyData
            .map((item) => JournalDraft.fromJson(Map<String, dynamic>.from(item)))
            .where((draft) => draft.hasContent && draft.age < _maxDraftAge)
            .take(_maxDraftHistory)
            .toList();

        await _box?.put(_draftHistoryKey,
            history.map((d) => d.toJson()).toList());
      }
    } catch (e) {
      debugPrint('DraftCacheService: Error during cleanup - $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _stopAutoSave();
    _currentDraft = null;
    _isInitialized = false;
  }
}