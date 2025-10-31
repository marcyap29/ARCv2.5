import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/core/journal_capture_state.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/arc/ui/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/atlas/rivet/rivet_provider.dart';
import 'package:my_app/atlas/rivet/rivet_models.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/atlas/phase_detection/phase_tracker.dart';
import 'package:my_app/atlas/phase_detection/phase_history_repository.dart';
import 'package:my_app/atlas/phase_detection/phase_change_notifier.dart';
import 'package:my_app/shared/ui/onboarding/phase_celebration_view.dart';
import 'package:my_app/core/sync/sync_service.dart';
import 'package:my_app/core/sync/sync_models.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:my_app/mode/first_responder/fr_mode_suggestion_service.dart';
import 'package:my_app/mode/first_responder/fr_settings_cubit.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/core/services/journal_version_service.dart';
import 'package:my_app/platform/photo_bridge.dart';

class JournalCaptureCubit extends Cubit<JournalCaptureState> {
  final JournalRepository _journalRepository;
  final SyncService _syncService = SyncService();
  final DraftCacheService _draftCache = DraftCacheService.instance;
  final JournalVersionService _versionService = JournalVersionService.instance;
  String _draftContent = '';
  String? _currentDraftId;
  List<MediaItem> _draftMediaItems = [];
  static const _autoSaveDelay = Duration(seconds: 3);
  DateTime? _lastSaveTime;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  String? _audioPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  String? _transcription;
  final FRModeSuggestionService _frSuggestionService = FRModeSuggestionService();
  bool _hasTriggeredFRSuggestion = false;

  JournalCaptureCubit(this._journalRepository) : super(JournalCaptureInitial()) {
    _initializeDraftCache();
  }

  void updateDraft(String content) {
    _draftContent = content;
    _autoSaveDraft();
    
    // Check for first responder mode suggestion (but only once per session)
    if (!_hasTriggeredFRSuggestion && content.length > 50) {
      _checkForFRModeSuggestion(content);
    }
  }

  /// Check if we should suggest first responder mode based on content
  Future<void> _checkForFRModeSuggestion(String content) async {
    _hasTriggeredFRSuggestion = true;
    
    try {
      // Get current FR settings using static method
      final box = await Hive.openBox(FRSettingsCubit.hiveBox);
      final currentSettings = FRSettingsCubit.load(box);
      final frCubit = FRSettingsCubit();
      
      // Check if we should suggest FR mode
      final shouldSuggest = await _frSuggestionService.shouldSuggestFRMode(
        content, 
        currentSettings
      );
      
      if (shouldSuggest) {
        // Emit state to trigger UI suggestion
        emit(JournalCaptureFRSuggestionTriggered(
          draftContent: _draftContent,
          frCubit: frCubit,
        ));
      }
    } catch (e) {
      // Silently fail to not disrupt journaling experience
    }
  }

  /// Initialize draft cache and check for recoverable drafts
  Future<void> _initializeDraftCache() async {
    try {
      await _draftCache.initialize();
      await _checkForRecoverableDraft();
    } catch (e) {
      print('Failed to initialize draft cache: $e');
    }
  }

  /// Check for recoverable draft on startup
  Future<void> _checkForRecoverableDraft() async {
    try {
      final recoverableDraft = await _draftCache.getRecoverableDraft();
      if (recoverableDraft != null && recoverableDraft.hasContent) {
        emit(JournalCaptureDraftRecoverable(recoverableDraft: recoverableDraft));
      }
    } catch (e) {
      print('Error checking for recoverable draft: $e');
    }
  }

  /// Start a new draft session
  Future<void> startNewDraft({
    String? initialEmotion,
    String? initialReason,
  }) async {
    try {
      _currentDraftId = await _draftCache.createDraft(
        initialEmotion: initialEmotion,
        initialReason: initialReason,
      );
      _draftContent = '';
      _draftMediaItems = [];
      emit(JournalCaptureDraftStarted(draftId: _currentDraftId!));
    } catch (e) {
      print('Error starting new draft: $e');
    }
  }

  /// Restore a draft from cache
  Future<void> restoreDraft(JournalDraft draft) async {
    try {
      await _draftCache.restoreDraft(draft);
      _currentDraftId = draft.id;
      _draftContent = draft.content;
      _draftMediaItems = List.from(draft.mediaItems);

      emit(JournalCaptureDraftRestored(
        draft: draft,
        content: _draftContent,
        mediaItems: _draftMediaItems,
      ));
    } catch (e) {
      print('Error restoring draft: $e');
    }
  }

  /// Add media item to current draft
  Future<void> addMediaToDraft(MediaItem mediaItem) async {
    try {
      _draftMediaItems.add(mediaItem);
      await _draftCache.addMediaToDraft(mediaItem);
      emit(JournalCaptureMediaAdded(mediaItem: mediaItem));
    } catch (e) {
      print('Error adding media to draft: $e');
    }
  }

  /// Remove media item from current draft
  Future<void> removeMediaFromDraft(MediaItem mediaItem) async {
    try {
      _draftMediaItems.removeWhere((item) => item.uri == mediaItem.uri);
      await _draftCache.removeMediaFromDraft(mediaItem);
      emit(JournalCaptureMediaRemoved(mediaItem: mediaItem));
    } catch (e) {
      print('Error removing media from draft: $e');
    }
  }

  /// Discard current draft
  Future<void> discardDraft() async {
    try {
      await _draftCache.discardDraft();
      _currentDraftId = null;
      _draftContent = '';
      _draftMediaItems = [];
      emit(JournalCaptureDraftDiscarded());
    } catch (e) {
      print('Error discarding draft: $e');
    }
  }

  /// Get recoverable draft
  Future<JournalDraft?> getRecoverableDraft() async {
    try {
      return await _draftCache.getRecoverableDraft();
    } catch (e) {
      print('Error getting recoverable draft: $e');
      return null;
    }
  }

  /// Get draft history
  Future<List<JournalDraft>> getDraftHistory() async {
    try {
      return await _draftCache.getDraftHistory();
    } catch (e) {
      print('Error getting draft history: $e');
      return [];
    }
  }

  void _autoSaveDraft() {
    // Auto-save after delay if content has changed
    if (_lastSaveTime == null ||
        DateTime.now().difference(_lastSaveTime!) > _autoSaveDelay) {
      _lastSaveTime = DateTime.now();

      // Save to draft cache
      if (_currentDraftId != null) {
        _draftCache.updateDraftContent(_draftContent);
      }

      emit(JournalCaptureDraftSaved());
    }
  }

  void saveEntry({
    required String content, 
    required String mood, 
    List<String>? selectedKeywords,
    List<MediaItem>? media,
  }) async {
    try {
      // Use selected keywords if provided, otherwise extract from content
      final keywords = selectedKeywords?.isNotEmpty == true 
          ? selectedKeywords! 
          : SimpleKeywordExtractor.extractKeywords(content);
      
      final now = DateTime.now();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        title: _generateTitle(content),
        content: content,
        createdAt: now,
        updatedAt: now,
        tags: const [], // Tags could be extracted from content in a more advanced implementation
        mood: mood,
        audioUri: _audioPath,
        keywords: keywords, // Now populated with extracted keywords
        media: media ?? [], // Include media items
      );

      // Save the entry first
      await _journalRepository.createJournalEntry(entry);

      // Enqueue for sync
      await _syncService.enqueue(
        kind: SyncKind.journalEntry,
        refId: entry.id,
        payload: {
          'title': entry.title,
          'mood': entry.mood,
          'keywords': entry.keywords,
          'createdAt': entry.createdAt.toIso8601String(),
        },
      );

      // Complete the draft since entry was saved successfully
      await _draftCache.completeDraft();
      _currentDraftId = null;
      _draftContent = '';
      _draftMediaItems = [];

      // Emit saved state immediately - don't wait for background processing
      emit(JournalCaptureSaved());

      // Process SAGE annotation in background (don't await)
      _processSAGEAnnotation(entry);

      // Create Arcform using ARC MVP service (don't await)
      _createArcformSnapshot(entry);
    } catch (e) {
      emit(JournalCaptureError('Failed to save entry: ${e.toString()}'));
    }
  }

  void saveEntryWithPhase({
    required String content,
    required String mood,
    required String phase,
    required bool userConsentedPhase,
    String? emotion,
    String? emotionReason,
    List<String>? selectedKeywords,
    List<MediaItem>? media,
  }) async {
    try {
      // Use selected keywords if provided, otherwise extract from content
      final keywords = selectedKeywords?.isNotEmpty == true 
          ? selectedKeywords! 
          : SimpleKeywordExtractor.extractKeywords(content);
      
      final now = DateTime.now();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        title: _generateTitle(content),
        content: content,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        mood: mood,
        audioUri: _audioPath,
        keywords: keywords,
        emotion: emotion,
        emotionReason: emotionReason,
        media: media ?? [], // Include media items
      );

      // Check for conflicts before saving
      final conflict = await _versionService.checkConflict(entry.id);
      if (conflict != null) {
        emit(JournalCaptureConflictDetected(conflict: conflict));
        return; // Stop save, let user resolve conflict
      }

      // Save the entry first
      await _journalRepository.createJournalEntry(entry);

      // Publish draft if one exists (promotes to latest version)
      final draft = _draftCache.getCurrentDraft();
      if (draft != null && draft.linkedEntryId == entry.id) {
        await _draftCache.publishDraft(
          phase: phase,
        );
        await _draftCache.completeDraft();
      } else {
        // New entry - create first version
        await _versionService.publish(
          entryId: entry.id,
          content: content,
          media: media ?? [],
          metadata: {
            'mood': mood,
            'emotion': emotion,
            'emotionReason': emotionReason,
            'keywords': selectedKeywords?.join(',') ?? '',
          },
          phase: phase,
        );
      }

      // Emit saved state immediately - don't wait for background processing
      emit(JournalCaptureSaved());

      // Process SAGE annotation in background (don't await)
      _processSAGEAnnotation(entry);

      // Create Arcform using ARC MVP service with phase (don't await)
      _createArcformSnapshotWithPhase(entry, phase, userConsentedPhase);
    } catch (e) {
      emit(JournalCaptureError('Failed to save entry: ${e.toString()}'));
    }
  }

  void saveEntryWithKeywords({
    required String content,
    required String mood,
    required List<String> selectedKeywords,
    String? emotion,
    String? emotionReason,
    BuildContext? context,
    List<MediaItem>? media,
    List<Map<String, dynamic>>? blocks,
  }) async {
    try {
      print('DEBUG: JournalCaptureCubit.saveEntryWithKeywords - Media count: ${media?.length ?? 0}');
      if (media != null && media.isNotEmpty) {
        for (int i = 0; i < media.length; i++) {
          final mediaItem = media[i];
          print('DEBUG: Media $i - Type: ${mediaItem.type}, URI: ${mediaItem.uri}, AnalysisData: ${mediaItem.analysisData?.keys}');
        }
      }
      
      // Process photos to permanent storage before saving entry
      List<MediaItem> processedMedia = [];
      if (media != null && media.isNotEmpty) {
        for (final mediaItem in media) {
          if (mediaItem.type == MediaType.image && !mediaItem.uri.contains('/photos/')) {
            // Get photo bytes from ph:// URI or file path
            Uint8List? bytes;
            
            if (mediaItem.uri.startsWith('ph://')) {
              // Get bytes from photo library
              final localId = PhotoBridge.extractLocalIdentifier(mediaItem.uri);
              if (localId != null) {
                final photoData = await PhotoBridge.getPhotoBytes(localId);
                if (photoData != null) {
                  bytes = photoData['bytes'] as Uint8List;
                  print('DEBUG: Got photo bytes from photo library for: ${mediaItem.id}');
                }
              }
            } else {
              // Get bytes from file path
              try {
                bytes = await File(mediaItem.uri).readAsBytes();
              } catch (e) {
                print('ERROR: Failed to read photo from file: ${mediaItem.uri}: $e');
              }
            }
            
            if (bytes != null) {
              try {
                // Compute hash and save to permanent storage
                final digest = sha256.convert(bytes);
                final hash = digest.toString();
                
                final appDir = await getApplicationDocumentsDirectory();
                final fileName = '$hash.jpg';
                final permanentDir = '${appDir.path}/photos';
                await Directory(permanentDir).create(recursive: true);
                final permanentPath = '$permanentDir/$fileName';
                
                await File(permanentPath).writeAsBytes(bytes);
                
                // Create new MediaItem with permanent path
                final processedItem = mediaItem.copyWith(
                  uri: permanentPath,
                  sha256: hash,
                );
                
                processedMedia.add(processedItem);
                print('DEBUG: Saved photo to permanent storage: $permanentPath');
              } catch (e) {
                print('ERROR: Failed to save photo to permanent storage: $e');
                // Keep original media item if saving fails
                processedMedia.add(mediaItem);
              }
            } else {
              print('ERROR: Could not get bytes for photo ${mediaItem.id}, keeping original URI');
              processedMedia.add(mediaItem);
            }
          } else {
            // Already in permanent storage or not a photo
            processedMedia.add(mediaItem);
          }
        }
      }
      
      final now = DateTime.now();
      // Save LUMARA blocks to metadata
      final metadata = blocks != null && blocks.isNotEmpty
          ? {'inlineBlocks': blocks}
          : null;
      
      final entry = JournalEntry(
        id: const Uuid().v4(),
        title: _generateTitle(content),
        content: content,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        mood: mood,
        audioUri: _audioPath,
        keywords: selectedKeywords,
        emotion: emotion,
        emotionReason: emotionReason,
        media: processedMedia, // Use processed media with permanent paths
        metadata: metadata, // Include LUMARA blocks
      );
      
      print('DEBUG: JournalEntry created with ${entry.media.length} media items');

      // Save the entry first
      await _journalRepository.createJournalEntry(entry);

      // Emit saved state immediately - don't wait for background processing
      emit(JournalCaptureSaved());

      // Process SAGE annotation in background (don't await)
      _processSAGEAnnotation(entry);

      // Create Arcform using current user phase (respecting quiz selection)
      _createArcformWithCurrentUserPhase(entry, emotion, emotionReason);

      // Phase stability analysis - analyze entry for potential phase changes
      _performPhaseStabilityAnalysis(entry, emotion, emotionReason, context);
      
      // Also perform RIVET analysis for gate status
      _performRivetAnalysis(entry, emotion, emotionReason);
    } catch (e) {
      emit(JournalCaptureError('Failed to save entry: ${e.toString()}'));
    }
  }

  void saveEntryWithPhaseAndGeometry({
    required String content,
    required String mood,
    required List<String> selectedKeywords,
    required String phase,
    required ArcformGeometry overrideGeometry,
    String? emotion,
    String? emotionReason,
    List<MediaItem>? media,
  }) async {
    try {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        title: _generateTitle(content),
        content: content,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        mood: mood,
        audioUri: _audioPath,
        keywords: selectedKeywords,
        emotion: emotion,
        emotionReason: emotionReason,
        media: media ?? [], // Include media items
      );

      // Save the entry first
      await _journalRepository.createJournalEntry(entry);

      // Emit saved state immediately - don't wait for background processing
      emit(JournalCaptureSaved());

      // Process SAGE annotation in background (don't await)
      _processSAGEAnnotation(entry);

      // Create Arcform with manual geometry override
      _createArcformWithManualGeometry(entry, emotion, emotionReason, phase, overrideGeometry);
    } catch (e) {
      emit(JournalCaptureError('Failed to save entry: ${e.toString()}'));
    }
  }

  /// Save entry with proposed phase when RIVET gate is closed
  void saveEntryWithProposedPhase({
    required String content,
    required String mood,
    required List<String> selectedKeywords,
    required String proposedPhase,
    required ArcformGeometry overrideGeometry,
    String? emotion,
    String? emotionReason,
    String? gateReason,
    List<MediaItem>? media,
  }) async {
    try {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        title: _generateTitle(content),
        content: content,
        createdAt: now,
        updatedAt: now,
        tags: const [],
        mood: mood,
        audioUri: _audioPath,
        keywords: selectedKeywords,
        emotion: emotion,
        emotionReason: emotionReason,
        media: media ?? [], // Include media items
      );

      // Save the entry first
      await _journalRepository.createJournalEntry(entry);

      // Emit saved state immediately - don't wait for background processing
      emit(JournalCaptureSaved());

      // Process SAGE annotation in background (don't await)
      _processSAGEAnnotation(entry);

      // Create Arcform with proposed phase (not yet active)
      // The displayed phase will remain unchanged until RIVET gate opens
      _createArcformWithProposedPhase(entry, emotion, emotionReason, proposedPhase, overrideGeometry, gateReason);
    } catch (e) {
      emit(JournalCaptureError('Failed to save entry: ${e.toString()}'));
    }
  }

  /// Update existing entry with new data
  void updateEntryWithKeywords({
    required JournalEntry existingEntry,
    required String content,
    required String mood,
    required List<String> selectedKeywords,
    String? emotion,
    String? emotionReason,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    String? selectedLocation,
    BuildContext? context,
    List<MediaItem>? media,
    List<Map<String, dynamic>>? blocks,
  }) async {
    try {
      print('DEBUG: JournalCaptureCubit.updateEntryWithKeywords - Existing media count: ${existingEntry.media.length}');
      print('DEBUG: JournalCaptureCubit.updateEntryWithKeywords - New media count: ${media?.length ?? 0}');
      if (media != null && media.isNotEmpty) {
        for (int i = 0; i < media.length; i++) {
          final mediaItem = media[i];
          print('DEBUG: New Media $i - Type: ${mediaItem.type}, URI: ${mediaItem.uri}, AnalysisData: ${mediaItem.analysisData?.keys}');
        }
      }
      
      // Combine date and time if provided
      DateTime? newCreatedAt = existingEntry.createdAt;
      print('DEBUG: Original createdAt: ${existingEntry.createdAt}');
      print('DEBUG: Selected date: $selectedDate');
      print('DEBUG: Selected time: $selectedTime');
      
      if (selectedDate != null && selectedTime != null) {
        newCreatedAt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
        print('DEBUG: New createdAt (date + time): $newCreatedAt');
      } else if (selectedDate != null) {
        newCreatedAt = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          existingEntry.createdAt.hour,
          existingEntry.createdAt.minute,
        );
        print('DEBUG: New createdAt (date only): $newCreatedAt');
      } else {
        print('DEBUG: No date change, keeping original: $newCreatedAt');
      }

      // Save LUMARA blocks to metadata
      final metadata = blocks != null && blocks.isNotEmpty
          ? {'inlineBlocks': blocks}
          : existingEntry.metadata;
      
      // Prevent keyword duplication - merge with existing keywords, remove duplicates
      final existingKeywords = List<String>.from(existingEntry.keywords);
      final newKeywords = List<String>.from(selectedKeywords);
      final mergedKeywords = <String>{};
      
      // Add existing keywords first
      for (final keyword in existingKeywords) {
        mergedKeywords.add(keyword.trim().toLowerCase());
      }
      
      // Add new keywords, converting to lowercase for comparison
      for (final keyword in newKeywords) {
        final normalized = keyword.trim().toLowerCase();
        if (!mergedKeywords.contains(normalized)) {
          mergedKeywords.add(normalized);
        }
      }
      
      // Convert back to original case from new keywords where possible, otherwise use existing
      final finalKeywords = <String>[];
      for (final normalized in mergedKeywords) {
        // Try to preserve original case from new keywords
        final originalKeyword = newKeywords.firstWhere(
          (k) => k.trim().toLowerCase() == normalized,
          orElse: () => existingKeywords.firstWhere(
            (k) => k.trim().toLowerCase() == normalized,
            orElse: () => normalized,
          ),
        );
        finalKeywords.add(originalKeyword);
      }
      
      // Create updated entry
      final updatedEntry = existingEntry.copyWith(
        content: content,
        mood: mood,
        keywords: finalKeywords, // Use deduplicated keywords
        emotion: emotion,
        emotionReason: emotionReason,
        createdAt: newCreatedAt,
        updatedAt: DateTime.now(),
        location: selectedLocation,
        // Phase is determined automatically by phase regime system, not manually set
        isEdited: true,
        metadata: metadata,
        media: media ?? existingEntry.media, // Update media items or keep existing
      );
      
      print('DEBUG: Updated JournalEntry created with ${updatedEntry.media.length} media items');

      // Update the entry
      await _journalRepository.updateJournalEntry(updatedEntry);

      // Emit saved state
      emit(JournalCaptureSaved());

      // Process SAGE annotation in background
      _processSAGEAnnotation(updatedEntry);

      // Create Arcform with current user phase
      _createArcformWithCurrentUserPhase(updatedEntry, emotion, emotionReason);

      // Phase stability analysis
      _performPhaseStabilityAnalysis(updatedEntry, emotion, emotionReason, context);
      
      // RIVET analysis
      _performRivetAnalysis(updatedEntry, emotion, emotionReason);
    } catch (e) {
      emit(JournalCaptureError('Failed to update entry: ${e.toString()}'));
    }
  }

  void _processSAGEAnnotation(JournalEntry entry) async {
    try {
      // In a real implementation, this would call an AI service
      // For now, we'll simulate the processing with a delay
      await Future.delayed(const Duration(seconds: 2));

      // Check if cubit is still active before proceeding
      if (!isClosed) {
        // Generate simulated SAGE annotation
        const annotation = SAGEAnnotation(
          situation:
              "User described a situation involving work challenges and personal reflection",
          action:
              "User took time to write in their journal and reflect on their experiences",
          growth:
              "User is developing self-awareness and emotional processing skills",
          essence:
              "The core of this entry is about personal growth through self-reflection",
          confidence: 0.85,
        );

        // Update the entry with the annotation
        final updatedEntry = entry.copyWith(sageAnnotation: annotation);
        await _journalRepository.updateJournalEntry(updatedEntry);
      }
    } catch (e) {
      // Silently fail if SAGE processing fails - it's not critical
      print('SAGE annotation failed: $e');
    }
  }

  void _createArcformSnapshot(JournalEntry entry) async {
    try {
      // Create Arcform using the ARC MVP service
      final arcformService = ArcformMVPService();
      final arcform = arcformService.createArcformFromEntry(
        entryId: entry.id,
        title: entry.title,
        content: entry.content,
        mood: entry.mood,
        keywords: entry.keywords,
      );

      // Save to SimpleArcformStorage (in-memory for now)
      SimpleArcformStorage.saveArcform(arcform);

      // Also save as ArcformSnapshot for backward compatibility
      final snapshot = ArcformSnapshot(
        id: const Uuid().v4(),
        arcformId: entry.id,
        data: {
          'keywords': arcform.keywords,
          'geometry': arcform.geometry.name,
          'colorMap': arcform.colorMap,
          'edges': arcform.edges,
          'phaseHint': arcform.phaseHint,
        },
        timestamp: arcform.createdAt,
        notes: 'Generated from journal entry using ARC MVP',
      );

      // Save the snapshot to Hive
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      final snapshotBox = Hive.box<ArcformSnapshot>('arcform_snapshots');
      await snapshotBox.put(snapshot.id, snapshot);
      
      // Enqueue arcform for sync
      await _syncService.enqueue(
        kind: SyncKind.arcformSnapshot,
        refId: snapshot.id,
        payload: {
          'arcformId': snapshot.arcformId,
          'geometry': arcform.geometry.name,
          'keywords': arcform.keywords,
          'createdAt': snapshot.timestamp.toIso8601String(),
        },
      );
      
      print('Arcform created: ${arcform.geometry.name} with ${arcform.keywords.length} keywords');
    } catch (e) {
      print('Arcform snapshot creation failed: $e');
    }
  }

  void _createArcformSnapshotWithPhase(JournalEntry entry, String phase, bool userConsentedPhase) async {
    try {
      // Create Arcform using the ARC MVP service with explicit phase
      final arcformService = ArcformMVPService();
      final arcform = arcformService.createArcformFromEntryWithPhase(
        entryId: entry.id,
        title: entry.title,
        content: entry.content,
        mood: entry.mood,
        keywords: entry.keywords,
        phase: phase,
        userConsentedPhase: userConsentedPhase,
      );

      // Save to SimpleArcformStorage (in-memory for now)
      SimpleArcformStorage.saveArcform(arcform);

      // Also save as ArcformSnapshot with phase information
      final snapshot = ArcformSnapshot(
        id: const Uuid().v4(),
        arcformId: entry.id,
        data: {
          'keywords': arcform.keywords,
          'geometry': arcform.geometry.name,
          'colorMap': arcform.colorMap,
          'edges': arcform.edges,
          'phaseHint': arcform.phaseHint,
          'phase': phase,
          'userConsentedPhase': userConsentedPhase,
        },
        timestamp: arcform.createdAt,
        notes: 'Generated from journal entry with phase: $phase',
      );

      // Save the snapshot to Hive
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      final snapshotBox = Hive.box<ArcformSnapshot>('arcform_snapshots');
      await snapshotBox.put(snapshot.id, snapshot);
      
      print('Phase-aware Arcform created: $phase (${arcform.geometry.name}) with ${arcform.keywords.length} keywords');
    } catch (e) {
      print('Phase-aware Arcform snapshot creation failed: $e');
    }
  }

  void _performRivetAnalysis(JournalEntry entry, String? emotion, String? emotionReason) async {
    try {
      // Get current user phase and recommended phase for comparison
      final currentPhase = await UserPhaseService.getCurrentPhase();
      final recommendedPhase = PhaseRecommender.recommend(
        emotion: emotion ?? '',
        reason: emotionReason ?? '',
        text: entry.content,
        selectedKeywords: entry.keywords,
      );
      
      print('DEBUG: RIVET Analysis - Current: $currentPhase, Recommended: $recommendedPhase');
      
      // Initialize RIVET provider
      final rivetProvider = RivetProvider();
      const userId = 'default_user'; // TODO: Use actual user ID
      
      print('DEBUG: RIVET provider available: ${rivetProvider.isAvailable}');
      if (!rivetProvider.isAvailable) {
        print('DEBUG: Initializing RIVET provider...');
        await rivetProvider.initialize(userId);
        print('DEBUG: RIVET provider initialized: ${rivetProvider.isAvailable}');
      }
      
      // Create RIVET event
      final rivetEvent = RivetEvent(
        eventId: const Uuid().v4(),
        date: DateTime.now(),
        source: EvidenceSource.text,
        keywords: entry.keywords.toSet(),
        predPhase: recommendedPhase, // What PhaseRecommender thinks
        refPhase: currentPhase, // What user currently has
        tolerance: const {}, // Stub for categorical phases
      );
      
      // Submit to RIVET for analysis
      print('DEBUG: Submitting to RIVET - predPhase: $recommendedPhase, refPhase: $currentPhase');
      final decision = await rivetProvider.safeIngest(rivetEvent, userId);
      print('DEBUG: RIVET decision - open: ${decision?.open}, whyNot: ${decision?.whyNot}');
      
      if (decision != null) {
        if (decision.open && recommendedPhase != currentPhase) {
          // RIVET gate is open and recommends a phase change
          print('INFO: RIVET gate OPEN - Approved phase change: $currentPhase → $recommendedPhase');
          print('DEBUG: RIVET criteria met - ALIGN/TRACE sustained with independence');
          
          // Update user phase in storage
          await _updateUserPhase(recommendedPhase, 'RIVET algorithm approved change');
          
          print('SUCCESS: Phase updated by RIVET: $currentPhase → $recommendedPhase');
        } else if (!decision.open) {
          // RIVET gate is closed - maintain current phase (this is the stability protection)
          print('DEBUG: RIVET gate CLOSED - Phase change blocked: ${decision.whyNot}');
          print('INFO: Maintaining current phase: $currentPhase (RIVET stability protection)');
        } else {
          // Gate is open but no change needed
          print('DEBUG: RIVET gate OPEN but no phase change needed (already $currentPhase)');
        }
      } else {
        // RIVET unavailable - maintain current phase
        print('DEBUG: RIVET unavailable - Maintaining current phase: $currentPhase');
      }
      
    } catch (e) {
      print('ERROR: RIVET analysis failed: $e');
    }
  }

  /// Perform phase stability analysis using PhaseTracker
  void _performPhaseStabilityAnalysis(JournalEntry entry, String? emotion, String? emotionReason, BuildContext? context) async {
    try {
      // Initialize PhaseHistoryRepository
      await PhaseHistoryRepository.initialize();
      
      // Get current user profile
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');
      
      if (userProfile == null) {
        print('ERROR: No user profile found for phase stability analysis');
        return;
      }
      
      // Create PhaseTracker instance
      final phaseTracker = PhaseTracker(userProfile: userProfile);
      
      // Get phase scores for this entry
      final phaseScores = PhaseRecommender.score(
        emotion: emotion ?? '',
        reason: emotionReason ?? '',
        text: entry.content,
        selectedKeywords: entry.keywords,
      );
      
      print('DEBUG: Phase Stability Analysis - Entry: ${entry.id}');
      print('DEBUG: Phase scores: ${PhaseRecommender.getScoringSummary(phaseScores)}');
      
      // Update phase tracking with new scores
      final result = await phaseTracker.updatePhaseScores(
        phaseScores: phaseScores,
        journalEntryId: entry.id,
        emotion: emotion ?? '',
        reason: emotionReason ?? '',
        text: entry.content,
      );
      
      print('DEBUG: Phase tracking result: ${result.reason}');
      print('DEBUG: Phase changed: ${result.phaseChanged}');
      
      if (result.phaseChanged && result.newPhase != null) {
        // Phase change approved by PhaseTracker
        print('INFO: PhaseTracker approved phase change: ${result.previousPhase} → ${result.newPhase}');
        await _updateUserPhaseWithStability(result.newPhase!, result.reason);
        
        // Show phase celebration if context is available
        if (context != null) {
          _showPhaseCelebration(context, result.newPhase!);
        }
      } else {
        // No phase change - maintain current phase
        print('DEBUG: PhaseTracker - No phase change needed: ${result.reason}');
        
        // Show phase stability notification if context is available and it's a meaningful reason
        if (context != null && _shouldShowStabilityNotification(result.reason)) {
          PhaseChangeNotifier.showPhaseStabilityNotification(
            context,
            currentPhase: result.previousPhase ?? 'Unknown',
            reason: result.reason,
          );
        }
      }
      
    } catch (e) {
      print('ERROR: Phase stability analysis failed: $e');
    }
  }

  /// Determine if we should show a phase stability notification
  bool _shouldShowStabilityNotification(String reason) {
    // Only show notifications for meaningful stability reasons
    return reason.contains('cooldown') || 
           reason.contains('hysteresis') || 
           reason.contains('threshold') ||
           reason.contains('optimal');
  }

  /// Show phase celebration when Atlas/Rivet/Sentinel changes phase
  void _showPhaseCelebration(BuildContext context, String phase) {
    final phaseDescription = UserPhaseService.getPhaseDescription(phase);
    String phaseEmoji;
    
    switch (phase.toLowerCase()) {
      case 'discovery':
        phaseEmoji = '🌱';
        break;
      case 'expansion':
        phaseEmoji = '🌸';
        break;
      case 'transition':
        phaseEmoji = '🌿';
        break;
      case 'consolidation':
        phaseEmoji = '🧵';
        break;
      case 'recovery':
        phaseEmoji = '✨';
        break;
      case 'breakthrough':
        phaseEmoji = '💥';
        break;
      default:
        phaseEmoji = '🌱';
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhaseCelebrationView(
          discoveredPhase: phase,
          phaseDescription: phaseDescription,
          phaseEmoji: phaseEmoji,
        ),
      ),
    );
  }

  /// Update user phase with phase stability tracking
  Future<void> _updateUserPhaseWithStability(String newPhase, String reason) async {
    try {
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');
      
      if (userProfile != null) {
        final updatedProfile = userProfile.copyWith(
          onboardingCurrentSeason: newPhase,
          currentPhase: newPhase,
          lastPhaseChangeAt: DateTime.now(),
        );
        await userBox.put('profile', updatedProfile);
        print('DEBUG: Updated user profile phase to: $newPhase (reason: $reason)');
      }
    } catch (e) {
      print('ERROR: Failed to update user phase: $e');
    }
  }

  Future<void> _updateUserPhase(String newPhase, String reason) async {
    try {
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');
      
      if (userProfile != null) {
        final updatedProfile = userProfile.copyWith(
          onboardingCurrentSeason: newPhase,
        );
        await userBox.put('profile', updatedProfile);
        print('DEBUG: Updated user profile phase to: $newPhase (reason: $reason)');
      }
    } catch (e) {
      print('ERROR: Failed to update user phase: $e');
    }
  }

  void _createArcformWithCurrentUserPhase(JournalEntry entry, String? emotion, String? emotionReason) async {
    try {
      // Get the user's current phase from their profile/quiz selection
      final currentPhase = await UserPhaseService.getCurrentPhase();
      
      print('DEBUG: Using current user phase: $currentPhase (respecting quiz selection)');

      // Create Arcform using the ARC MVP service with user's current phase
      final arcformService = ArcformMVPService();
      final arcform = arcformService.createArcformFromEntryWithPhase(
        entryId: entry.id,
        title: entry.title,
        content: entry.content,
        mood: entry.mood,
        keywords: entry.keywords,
        phase: currentPhase,
        userConsentedPhase: true, // User explicitly chose this via quiz
      );

      // Save to SimpleArcformStorage (in-memory for now)
      SimpleArcformStorage.saveArcform(arcform);

      // Also save as ArcformSnapshot with phase information
      final snapshot = ArcformSnapshot(
        id: const Uuid().v4(),
        arcformId: entry.id,
        data: {
          'keywords': arcform.keywords,
          'geometry': arcform.geometry.name,
          'colorMap': arcform.colorMap,
          'edges': arcform.edges,
          'phaseHint': arcform.phaseHint,
          'phase': currentPhase,
          'userConsentedPhase': true,
          'source': 'user_quiz_selection',
        },
        timestamp: arcform.createdAt,
        notes: 'Generated from journal entry with user-selected phase: $currentPhase',
      );

      // Save the snapshot to Hive
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      final snapshotBox = Hive.box<ArcformSnapshot>('arcform_snapshots');
      await snapshotBox.put(snapshot.id, snapshot);
      
      // Track analytics for user-selected phase
      AnalyticsService.trackGeometryAccepted(
        phase: currentPhase,
        geometry: arcform.geometry.name,
        keywords: arcform.keywords,
      );
      
      print('Arcform created with user phase: $currentPhase with ${arcform.keywords.length} keywords');
    } catch (e) {
      print('User-phase Arcform creation failed: $e');
    }
  }
  
  void _createArcformWithPhaseRecommendation(JournalEntry entry, String? emotion, String? emotionReason) async {
    try {
      // Use phase recommender to get the appropriate phase
      final recommendedPhase = PhaseRecommender.recommend(
        emotion: emotion ?? '',
        reason: emotionReason ?? '',
        text: entry.content,
        selectedKeywords: entry.keywords,
      );
      
      final rationale = PhaseRecommender.rationale(recommendedPhase);

      // Create Arcform using the ARC MVP service with recommended phase
      final arcformService = ArcformMVPService();
      final arcform = arcformService.createArcformFromEntryWithPhase(
        entryId: entry.id,
        title: entry.title,
        content: entry.content,
        mood: entry.mood,
        keywords: entry.keywords,
        phase: recommendedPhase,
        userConsentedPhase: false, // User hasn't been asked yet
      );

      // Save to SimpleArcformStorage (in-memory for now)
      SimpleArcformStorage.saveArcform(arcform);

      // Also save as ArcformSnapshot with phase information
      final snapshot = ArcformSnapshot(
        id: const Uuid().v4(),
        arcformId: entry.id,
        data: {
          'keywords': arcform.keywords,
          'geometry': arcform.geometry.name,
          'colorMap': arcform.colorMap,
          'edges': arcform.edges,
          'phaseHint': arcform.phaseHint,
          'phase': recommendedPhase,
          'userConsentedPhase': false,
          'recommendationRationale': rationale,
        },
        timestamp: arcform.createdAt,
        notes: 'Generated from journal entry with recommended phase: $recommendedPhase',
      );

      // Save the snapshot to Hive
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      final snapshotBox = Hive.box<ArcformSnapshot>('arcform_snapshots');
      await snapshotBox.put(snapshot.id, snapshot);
      
      // Track analytics for auto-accepted geometry
      AnalyticsService.trackGeometryAccepted(
        phase: recommendedPhase,
        geometry: arcform.geometry.name,
        keywords: arcform.keywords,
      );
      
      print('Arcform created: $recommendedPhase with ${arcform.keywords.length} keywords');
    } catch (e) {
      print('Phase-recommendation Arcform creation failed: $e');
    }
  }

  void _createArcformWithManualGeometry(
    JournalEntry entry, 
    String? emotion, 
    String? emotionReason, 
    String phase, 
    ArcformGeometry overrideGeometry
  ) async {
    try {
      final rationale = PhaseRecommender.rationale(phase);

      // Create Arcform using the ARC MVP service with manual geometry
      final arcformService = ArcformMVPService();
      final arcform = arcformService.createArcformFromEntryWithPhaseAndGeometry(
        entryId: entry.id,
        title: entry.title,
        content: entry.content,
        mood: entry.mood,
        keywords: entry.keywords,
        phase: phase,
        overrideGeometry: overrideGeometry,
        userConsentedPhase: true, // User explicitly chose/confirmed this
      );

      // Save to SimpleArcformStorage (in-memory for now)
      SimpleArcformStorage.saveArcform(arcform);

      // Also save as ArcformSnapshot with manual geometry override
      final snapshot = ArcformSnapshot(
        id: const Uuid().v4(),
        arcformId: entry.id,
        data: {
          'keywords': arcform.keywords,
          'geometry': overrideGeometry.name, // Use the manually selected geometry
          'colorMap': arcform.colorMap,
          'edges': arcform.edges,
          'phaseHint': arcform.phaseHint,
          'phase': phase,
          'userConsentedPhase': true, // User confirmed this phase
          'recommendationRationale': rationale,
          'isGeometryAuto': false, // Mark as manually overridden
          'overrideGeometry': overrideGeometry.name,
        },
        timestamp: arcform.createdAt,
        notes: 'Generated from journal entry with manual geometry override: ${overrideGeometry.name}',
      );

      // Save the snapshot to Hive
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      final snapshotBox = Hive.box<ArcformSnapshot>('arcform_snapshots');
      await snapshotBox.put(snapshot.id, snapshot);
      
      // Track analytics for manual geometry override
      final originalGeometry = UserPhaseService.getGeometryForPhase(phase);
      AnalyticsService.trackGeometryOverride(
        originalPhase: phase,
        originalGeometry: originalGeometry.name,
        selectedGeometry: overrideGeometry.name,
        keywords: arcform.keywords,
      );
      
      print('Arcform created with manual geometry: $phase (${overrideGeometry.name}) with ${arcform.keywords.length} keywords');
    } catch (e) {
      print('Manual-geometry Arcform creation failed: $e');
    }
  }

  void _createArcformWithProposedPhase(
    JournalEntry entry,
    String? emotion,
    String? emotionReason,
    String proposedPhase,
    ArcformGeometry overrideGeometry,
    String? gateReason,
  ) async {
    try {
      // For now, just log the proposed phase creation
      // The actual arcform creation logic can be added later when the arcform system is clarified
      print('Arcform would be created with proposed phase: $proposedPhase (${overrideGeometry.name}) - Gate: ${gateReason ?? "Unknown"}');
      print('Entry metadata includes RIVET gate closure reason: $gateReason');
      
      // TODO: Implement actual arcform creation with proposed phase metadata
      // This should create an arcform marked with:
      // - rivet_proposed_phase: proposedPhase
      // - rivet_gate_closed: 'true'
      // - rivet_gate_reason: gateReason
      
    } catch (e) {
      print('Proposed-phase Arcform creation failed: $e');
    }
  }

  String _generateTitle(String content) {
    // Simple title generation from first few words
    final words = content.split(' ');
    if (words.isEmpty) return 'Untitled';

    final titleWords = words.take(3);
    return '${titleWords.join(' ')}${words.length > 3 ? '...' : ''}';
  }

  // Audio recording methods
  Future<void> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      emit(JournalCapturePermissionGranted());
    } else {
      emit(const JournalCapturePermissionDenied(
          'Microphone permission is required to record audio.'));
    }
  }

  Future<void> startRecording() async {
    try {
      if (!_isRecording) {
        final status = await Permission.microphone.status;
        if (!status.isGranted) {
          emit(const JournalCapturePermissionDenied(
              'Microphone permission is required to record audio.'));
          return;
        }

        final tempDir = await getTemporaryDirectory();
        _audioPath = '${tempDir.path}/${const Uuid().v4()}.m4a';

        // In a real implementation, you would use a proper audio recording package
        // For now, we'll simulate the recording process
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordingDuration += const Duration(seconds: 1);
          emit(JournalCaptureRecording(recordingDuration: _recordingDuration));
        });

        emit(JournalCaptureRecording(recordingDuration: _recordingDuration));
      }
    } catch (e) {
      emit(JournalCaptureError('Failed to start recording: ${e.toString()}'));
    }
  }

  Future<void> pauseRecording() async {
    try {
      if (_isRecording && !_isPaused) {
        // In a real implementation, you would pause the actual recording
        _isPaused = true;
        _recordingTimer?.cancel();
        emit(JournalCaptureRecordingPaused(
            recordingDuration: _recordingDuration));
      }
    } catch (e) {
      emit(JournalCaptureError('Failed to pause recording: ${e.toString()}'));
    }
  }

  Future<void> stopRecording() async {
    try {
      if (_isRecording) {
        // In a real implementation, you would stop the actual recording
        _isRecording = false;
        _isPaused = false;
        _recordingTimer?.cancel();
        emit(JournalCaptureRecordingStopped(
            recordingDuration: _recordingDuration, audioPath: _audioPath!));
      }
    } catch (e) {
      emit(JournalCaptureError('Failed to stop recording: ${e.toString()}'));
    }
  }

  Future<void> playRecording() async {
    try {
      if (_audioPath != null) {
        _isPlaying = true;
        if (!isClosed) {
          emit(JournalCapturePlaying());
        }
        // In a real implementation, you would play the actual audio file
        // For now, we'll simulate playback
        await Future.delayed(const Duration(seconds: 3));
        _isPlaying = false;
        if (!isClosed) {
          emit(JournalCapturePlaybackStopped());
        }
      }
    } catch (e) {
      _isPlaying = false;
      if (!isClosed) {
        emit(JournalCaptureError('Failed to play recording: ${e.toString()}'));
      }
    }
  }

  Future<void> stopPlayback() async {
    try {
      // In a real implementation, you would stop the actual playback
      _isPlaying = false;
      emit(JournalCapturePlaybackStopped());
    } catch (e) {
      emit(JournalCaptureError('Failed to stop playback: ${e.toString()}'));
    }
  }

  Future<void> transcribeAudio() async {
    try {
      if (_audioPath == null) {
        if (!isClosed) {
          emit(const JournalCaptureError('No audio recording found'));
        }
        return;
      }

      if (!isClosed) {
        emit(JournalCaptureTranscribing());
      }

      // In a real implementation, you would call an actual transcription service
      // For this example, we'll simulate transcription with a delay
      await Future.delayed(const Duration(seconds: 2));

      // Check if cubit is still active before proceeding
      if (!isClosed) {
        // Simulated transcription result
        _transcription =
            "This is a simulated transcription of your voice journal entry. In a real implementation, this would be the actual transcription from a service like OpenAI's Whisper API.";

        emit(JournalCaptureTranscribed(transcription: _transcription!));
      }
    } catch (e) {
      if (!isClosed) {
        emit(JournalCaptureError('Failed to transcribe audio: ${e.toString()}'));
      }
    }
  }

  void updateTranscription(String transcription) {
    _transcription = transcription;
  }

  String? get transcription => _transcription;

  @override
  Future<void> close() {
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}
