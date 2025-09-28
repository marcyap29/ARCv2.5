/// Draft Cache Service
///
/// Provides automatic persistence of journal drafts to prevent data loss
/// when users switch away, shut down, or experience app crashes.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:my_app/data/models/media_item.dart';

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

  JournalDraft({
    required this.id,
    required this.content,
    required this.mediaItems,
    this.initialEmotion,
    this.initialReason,
    required this.createdAt,
    required this.lastModified,
    this.metadata = const {},
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
    );
  }

  JournalDraft copyWith({
    String? content,
    List<MediaItem>? mediaItems,
    String? initialEmotion,
    String? initialReason,
    DateTime? lastModified,
    Map<String, dynamic>? metadata,
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
    );
  }

  bool get isEmpty => content.trim().isEmpty && mediaItems.isEmpty;
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
  static const Duration _autoSaveInterval = Duration(seconds: 2);
  static const Duration _maxDraftAge = Duration(days: 7);
  static const int _maxDraftHistory = 10;

  static DraftCacheService? _instance;
  static DraftCacheService get instance => _instance ??= DraftCacheService._();
  DraftCacheService._();

  Box? _box;
  Timer? _autoSaveTimer;
  JournalDraft? _currentDraft;
  bool _isInitialized = false;

  /// Initialize the draft cache service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('DraftCacheService: Already initialized, skipping');
      return;
    }

    try {
      debugPrint('DraftCacheService: Starting initialization...');
      _box = await Hive.openBox(_boxName);
      await _cleanupOldDrafts();
      _isInitialized = true;
      debugPrint('DraftCacheService: Initialized successfully');
    } catch (e) {
      debugPrint('DraftCacheService: Failed to initialize - $e');
      _isInitialized = false; // Reset flag on failure
      rethrow;
    }
  }

  /// Create a new draft session
  Future<String> createDraft({
    String? initialEmotion,
    String? initialReason,
    String initialContent = '',
    List<MediaItem> initialMedia = const [],
  }) async {
    await _ensureInitialized();

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
    );

    await _saveDraft(_currentDraft!);
    _startAutoSave();

    debugPrint('DraftCacheService: Created new draft $draftId');
    return draftId;
  }

  /// Update the current draft content
  Future<void> updateDraftContent(String content) async {
    if (_currentDraft == null) return;

    _currentDraft = _currentDraft!.copyWith(
      content: content,
      lastModified: DateTime.now(),
    );

    // Auto-save will handle persistence
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
    await _saveDraft(_currentDraft!);
    _startAutoSave();
    debugPrint('DraftCacheService: Restored draft ${draft.id}');
  }

  /// Complete the current draft (when successfully saved as journal entry)
  Future<void> completeDraft() async {
    if (_currentDraft == null) return;

    // Move to history before clearing
    await _moveDraftToHistory(_currentDraft!);
    await _clearCurrentDraft();

    _stopAutoSave();
    _currentDraft = null;

    debugPrint('DraftCacheService: Completed and cleared current draft');
  }

  /// Discard the current draft
  Future<void> discardDraft() async {
    await _clearCurrentDraft();
    _stopAutoSave();
    _currentDraft = null;
    debugPrint('DraftCacheService: Discarded current draft');
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
      await _box?.put(_currentDraftKey, draft.toJson());
    } catch (e) {
      debugPrint('DraftCacheService: Error saving draft - $e');
    }
  }

  Future<void> _clearCurrentDraft() async {
    try {
      await _box?.delete(_currentDraftKey);
    } catch (e) {
      debugPrint('DraftCacheService: Error clearing current draft - $e');
    }
  }

  Future<void> _moveDraftToHistory(JournalDraft draft) async {
    try {
      final currentHistory = await getDraftHistory();
      currentHistory.insert(0, draft);

      // Keep only the most recent drafts
      final trimmedHistory = currentHistory.take(_maxDraftHistory).toList();

      await _box?.put(_draftHistoryKey,
          trimmedHistory.map((d) => d.toJson()).toList());
    } catch (e) {
      debugPrint('DraftCacheService: Error moving draft to history - $e');
    }
  }

  void _startAutoSave() {
    _stopAutoSave();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) {
      if (_currentDraft != null) {
        _saveDraft(_currentDraft!);
      }
    });
  }

  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  Future<void> _cleanupOldDrafts() async {
    try {
      // Clean up current draft if too old
      final current = await getRecoverableDraft();
      if (current != null && current.age > _maxDraftAge) {
        await _clearCurrentDraft();
      }

      // Clean up history
      final history = await getDraftHistory();
      final validHistory = history
          .where((draft) => draft.age < _maxDraftAge)
          .take(_maxDraftHistory)
          .toList();

      if (validHistory.length != history.length) {
        await _box?.put(_draftHistoryKey,
            validHistory.map((d) => d.toJson()).toList());
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