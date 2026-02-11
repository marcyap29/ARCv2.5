import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/mira/mira_service.dart';
import 'package:my_app/mira/core/schema.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/data/hive/duration_adapter.dart';
import 'package:my_app/state/journal_entry_state.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/storage/layer0_populator.dart';
import 'package:my_app/chronicle/query/chronicle_context_cache.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Self-initializing repository with consistent box name.
/// No external init() needed.
class JournalRepository {
  static const String _boxName = 'journal_entries';
  Box<JournalEntry>? _box;
  bool _lumaraMigrationDone = false;
  
  // CHRONICLE Layer 0 population (lazy initialization)
  Layer0Repository? _layer0Repo;
  Layer0Populator? _layer0Populator;
  bool _layer0Initialized = false;

  Future<Box<JournalEntry>> _openBoxSafely({int retries = 5}) async {
    for (var i = 0; i < retries; i++) {
      if (Hive.isBoxOpen(_boxName)) return Hive.box<JournalEntry>(_boxName);
      try {
        return await Hive.openBox<JournalEntry>(_boxName);
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 80 * (i + 1)));
      }
    }
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<JournalEntry>(_boxName);
    }
    return Hive.box<JournalEntry>(_boxName);
  }

  Future<Box<JournalEntry>> _ensureBox() async {
    // Register adapters before opening the box so Hive can deserialize nested types (InlineBlock, MediaItem)
    _ensureAdapters();
    if (_box != null && _box!.isOpen) return _box!;
    _box = await _openBoxSafely();

    // Run one-time migration to persist LUMARA blocks into the dedicated field
    if (!_lumaraMigrationDone) {
      await _migrateLumaraBlocks();
      _lumaraMigrationDone = true;
    }

    return _box!;
  }

  /// Public migration entrypoint so startup code can force persistence of legacy inline blocks.
  Future<void> migrateLumaraBlocks() async {
    await _ensureBox();
    if (_lumaraMigrationDone) return;
    await _migrateLumaraBlocks();
    _lumaraMigrationDone = true;
  }

  /// Ensure the journal entries box is open. Call before sync reads (e.g. timeline refresh)
  /// so that getEntriesPaginatedSync/getAllJournalEntriesSync do not return [] when box was closed.
  Future<void> ensureBoxOpen() async {
    await _ensureBox();
  }

  /// Convert legacy metadata.inlineBlocks into the lumaraBlocks field and persist.
  Future<void> _migrateLumaraBlocks() async {
    final box = _box;
    if (box == null) return;

    try {
      for (final key in box.keys) {
        final entry = box.get(key);
        if (entry == null) continue;

        // Skip if already has lumaraBlocks
        if (entry.lumaraBlocks.isNotEmpty) continue;

        final inlineBlocksData = entry.metadata?['inlineBlocks'];
        if (inlineBlocksData == null) continue;

        final convertedBlocks = _convertInlineBlocks(inlineBlocksData);
        if (convertedBlocks.isEmpty) continue;

        // Remove inlineBlocks from metadata when migrating
        final cleanedMetadata = entry.metadata != null 
            ? Map<String, dynamic>.from(entry.metadata!) 
            : <String, dynamic>{};
        cleanedMetadata.remove('inlineBlocks');
        
        final updated = entry.copyWith(
          lumaraBlocks: convertedBlocks,
          metadata: cleanedMetadata,
        );
        await box.put(entry.id, updated);
        print('🔄 Migrated ${convertedBlocks.length} LUMARA blocks for entry ${entry.id}');
      }
    } catch (e) {
      print('⚠️ LUMARA migration error: $e');
    }
  }

  /// Helper to convert legacy inlineBlocks data (List or JSON string) to InlineBlock list.
  List<InlineBlock> _convertInlineBlocks(dynamic inlineBlocksData) {
    try {
      if (inlineBlocksData is List) {
        return inlineBlocksData
            .whereType<Map>()
            .map((block) => InlineBlock.fromJson(Map<String, dynamic>.from(block)))
            .toList();
      }

      if (inlineBlocksData is String) {
        final decoded = jsonDecode(inlineBlocksData);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((block) => InlineBlock.fromJson(Map<String, dynamic>.from(block)))
              .toList();
        }
      }
    } catch (e) {
      print('⚠️ LUMARA inlineBlocks conversion error: $e');
    }
    return const [];
  }

  /// Ensure required adapters are registered before saving entries
  void _ensureAdapters() {
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(MediaTypeAdapter());
      print('🔍 JournalRepository: Registered MediaTypeAdapter (ID: 10)');
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(MediaItemAdapter());
      print('🔍 JournalRepository: Registered MediaItemAdapter (ID: 11)');
    }
    if (!Hive.isAdapterRegistered(105)) {
      Hive.registerAdapter(DurationAdapter());
      print('🔍 JournalRepository: Registered DurationAdapter (ID: 105)');
    }
    if (!Hive.isAdapterRegistered(103)) {
      Hive.registerAdapter(InlineBlockAdapter());
      print('🔍 JournalRepository: Registered InlineBlockAdapter (ID: 103)');
    }
  }

  // Create
  /// [userId] Optional. Used for CHRONICLE Layer 0 population. If omitted, uses
  /// current Firebase user uid when available, otherwise 'default_user'.
  Future<void> createJournalEntry(JournalEntry entry, {String? userId}) async {
    print('🔍 JournalRepository: Creating journal entry with ID: ${entry.id}');
    print('🔍 JournalRepository: Entry content: ${entry.content}');
    print('🔍 JournalRepository: Entry media count: ${entry.media.length}');

    // Debug metadata before saving
    if (entry.metadata != null) {
      print('🔍 JournalRepository: Entry metadata keys: ${entry.metadata!.keys}');
      print('🔍 JournalRepository: Full metadata: ${entry.metadata}');
      if (entry.metadata!.containsKey('inlineBlocks')) {
        final blocks = entry.metadata!['inlineBlocks'];
        print('🔍 JournalRepository: inlineBlocks type: ${blocks.runtimeType}');
        if (blocks is String) {
          print('🔍 JournalRepository: inlineBlocks is JSON string (length: ${blocks.length})');
          print('🔍 JournalRepository: JSON content preview: ${blocks.substring(0, blocks.length > 200 ? 200 : blocks.length)}...');
        } else if (blocks is List) {
          print('🔍 JournalRepository: inlineBlocks is List with ${blocks.length} items');
          for (int i = 0; i < blocks.length; i++) {
            final block = blocks[i];
            print('🔍 JournalRepository: Block $i type: ${block.runtimeType}, keys: ${block is Map ? block.keys : "not a map"}');
          }
        } else {
          print('🔍 JournalRepository: ❌ UNEXPECTED inlineBlocks type: ${blocks.runtimeType}, value: $blocks');
        }
      } else {
        print('🔍 JournalRepository: ❌ No inlineBlocks key in metadata');
      }
    } else {
      print('🔍 JournalRepository: Entry has NO metadata');
    }
    
    // Ensure required adapters are registered
    if (entry.media.isNotEmpty || entry.lumaraBlocks.isNotEmpty) {
      _ensureAdapters();
      if (!Hive.isAdapterRegistered(11)) {
        print('❌ JournalRepository: CRITICAL - MediaItemAdapter (ID: 11) is NOT registered!');
      } else {
        print('✅ JournalRepository: Verified MediaItemAdapter (ID: 11) is registered');
      }
    }
    
    try {
      final box = await _ensureBox();
      await box.put(entry.id, entry);
      print('🔍 JournalRepository: Successfully saved entry ${entry.id} to database');
      
      // Populate Layer 0 for CHRONICLE (if enabled)
      _populateLayer0IfEnabled(entry, userId);

      // Invalidate CHRONICLE context cache for this user/period so next reflection sees new content
      final effectiveUserId = userId ?? FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final monthPeriod = '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}';
      final yearPeriod = '${entry.createdAt.year}';
      ChronicleContextCache.instance.invalidate(userId: effectiveUserId, layer: ChronicleLayer.monthly, period: monthPeriod);
      ChronicleContextCache.instance.invalidate(userId: effectiveUserId, layer: ChronicleLayer.yearly, period: yearPeriod);
      
      // Verify the entry was saved
      final savedEntry = box.get(entry.id);
      if (savedEntry != null) {
        print('🔍 JournalRepository: Verification - Entry ${entry.id} found in database');
        print('🔍 JournalRepository: Verification - Saved entry media count: ${savedEntry.media.length}');
        print('🔍 JournalRepository: Verification - Saved entry LUMARA blocks count: ${savedEntry.lumaraBlocks.length}');

        // Verify lumaraBlocks were saved correctly
        if (savedEntry.lumaraBlocks.length != entry.lumaraBlocks.length) {
          print('❌ JournalRepository: CRITICAL - LUMARA blocks count mismatch! Saved: ${entry.lumaraBlocks.length}, Retrieved: ${savedEntry.lumaraBlocks.length}');
        } else if (entry.lumaraBlocks.isNotEmpty) {
          print('✅ JournalRepository: Verification - LUMARA blocks count matches: ${savedEntry.lumaraBlocks.length}');
          // Verify each block
          for (int i = 0; i < entry.lumaraBlocks.length; i++) {
            final originalBlock = entry.lumaraBlocks[i];
            final savedBlock = savedEntry.lumaraBlocks[i];
            if (originalBlock.userComment != savedBlock.userComment) {
              print('❌ JournalRepository: Block $i userComment mismatch!');
            }
          }
        }

        // Verify metadata was saved correctly (should NOT have inlineBlocks - we use lumaraBlocks field now)
        if (savedEntry.metadata != null) {
          print('🔍 JournalRepository: Verification - Saved entry metadata keys: ${savedEntry.metadata!.keys}');
          if (savedEntry.metadata!.containsKey('inlineBlocks')) {
            print('⚠️ JournalRepository: WARNING - Saved entry still has inlineBlocks in metadata (legacy format)');
            print('   This should be removed - blocks should only be in lumaraBlocks field');
          } else {
            print('✅ JournalRepository: Verification - No inlineBlocks in metadata (correct - using lumaraBlocks field)');
          }
        } else {
          print('✅ JournalRepository: Verification - Entry has no metadata (acceptable)');
        }

        if (savedEntry.media.length != entry.media.length) {
          print('❌ JournalRepository: CRITICAL - Media count mismatch! Saved: ${entry.media.length}, Retrieved: ${savedEntry.media.length}');
          if (savedEntry.media.isEmpty && entry.media.isNotEmpty) {
            print('❌ JournalRepository: Media list was lost during save/retrieve!');
            print('   Original media IDs: ${entry.media.map((m) => m.id).toList()}');
          }
        }
        if (savedEntry.media.isNotEmpty) {
          print('🔍 JournalRepository: First saved media item: id=${savedEntry.media.first.id}, type=${savedEntry.media.first.type}, uri=${savedEntry.media.first.uri}');
        }
      } else {
        print('🔍 JournalRepository: ERROR - Entry ${entry.id} not found in database after save');
      }
    } catch (e) {
      print('🔍 JournalRepository: ERROR saving entry ${entry.id}: $e');
      rethrow;
    }
  }

  // Read - Async version that ensures box is properly opened
  Future<List<JournalEntry>> getAllJournalEntries() async {
    try {
      // Ensure MediaItem adapter is registered before loading entries
      _ensureAdapters();
      
      // Ensure box is open before trying to read
      final box = await _ensureBox();
      
      // Normalize all entries and track which ones need migration persistence
      final rawEntries = box.values.toList();
      final entries = <JournalEntry>[];
      final entriesToPersist = <JournalEntry>[];
      
      // Process entries in batches to avoid blocking UI thread.
      // Per-entry try/catch so one bad or legacy entry doesn't cause entire list to be dropped.
      for (int i = 0; i < rawEntries.length; i++) {
        final rawEntry = rawEntries[i];
        try {
          final normalized = _normalize(rawEntry);
          // If migration occurred (entry had blocks in metadata but not in lumaraBlocks, and now it does),
          // persist immediately to ensure blocks are saved
          if (rawEntry.lumaraBlocks.isEmpty &&
              normalized.lumaraBlocks.isNotEmpty &&
              rawEntry.metadata?.containsKey('inlineBlocks') == true) {
            try {
              await box.put(normalized.id, normalized);
            } catch (e) {
              print('❌ JournalRepository: Error persisting migration for entry ${normalized.id}: $e');
            }
          }
          entries.add(normalized);
        } catch (e) {
          try {
            print('⚠️ JournalRepository: Skipping entry ${rawEntry.id} (normalize failed): $e');
          } catch (_) {
            print('⚠️ JournalRepository: Skipping entry at index $i (normalize failed): $e');
          }
        }
        if (i % 20 == 0 && i > 0) {
          await Future.microtask(() {});
        }
      }
      return entries;
    } catch (e) {
      print('🔍 JournalRepository: ERROR in getAllJournalEntries: $e');
      return const [];
    }
  }

  // Synchronous version for backward compatibility
  List<JournalEntry> getAllJournalEntriesSync() {
    // Ensure required adapters are registered before loading entries
    _ensureAdapters();
    if (!Hive.isAdapterRegistered(11)) {
      print('❌ JournalRepository: CRITICAL - MediaItemAdapter (ID: 11) is NOT registered when loading entries synchronously!');
    } else {
      print('✅ JournalRepository: Verified MediaItemAdapter (ID: 11) is registered when loading synchronously');
    }
    
    if (!Hive.isBoxOpen(_boxName)) {
      return const [];
    }
    final box = Hive.box<JournalEntry>(_boxName);
    final entries = <JournalEntry>[];
    final entriesToPersist = <JournalEntry>[]; // Track entries that need migration persistence
    
    // Per-entry try/catch so one bad or legacy entry (e.g. from older ARCX backup) doesn't
    // crash the timeline or drop the entire list. Matches async getAllJournalEntries behavior.
    int skippedCount = 0;
    for (final key in box.keys) {
      final e = box.get(key);
      if (e == null) continue;
      try {
        final normalized = _normalize(e);
        // If migration occurred (entry had blocks in metadata but not in lumaraBlocks, and now it does),
        // mark it for persistence
        if (e.lumaraBlocks.isEmpty &&
            normalized.lumaraBlocks.isNotEmpty &&
            e.metadata?.containsKey('inlineBlocks') == true) {
          print('🔄 JournalRepository: Entry ${e.id} was migrated in memory - will persist migration');
          entriesToPersist.add(normalized);
        }
        // Debug: Check media after normalization (only log errors)
        if (normalized.media.length != e.media.length) {
          print('❌ JournalRepository: CRITICAL - Media count changed during normalization! Before: ${e.media.length}, After: ${normalized.media.length}');
        }
        entries.add(normalized);
      } catch (err) {
        skippedCount++;
        try {
          final dateStr = e.createdAt.toIso8601String();
          print('⚠️ JournalRepository: Skipping entry ${e.id} (createdAt: $dateStr, normalize failed in sync load): $err');
        } catch (_) {
          print('⚠️ JournalRepository: Skipping entry at key $key (normalize failed in sync load): $err');
        }
      }
    }
    if (skippedCount > 0 || entries.isNotEmpty) {
      final range = entries.isEmpty
          ? 'none loaded'
          : '${(entries.map((e) => e.createdAt)).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String().split('T').first} .. ${(entries.map((e) => e.createdAt)).reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String().split('T').first}';
      print('📋 JournalRepository: getAllJournalEntriesSync: ${entries.length} loaded, $skippedCount skipped; date range: $range');
    }
    
    // Persist migrations asynchronously (don't block the sync call)
    if (entriesToPersist.isNotEmpty) {
      print('🔄 JournalRepository: Persisting ${entriesToPersist.length} migrated entries');
      Future.microtask(() async {
        try {
          final box = await _ensureBox();
          for (final entry in entriesToPersist) {
            // Remove inlineBlocks from metadata when persisting migration
            final cleanedMetadata = entry.metadata != null 
                ? Map<String, dynamic>.from(entry.metadata!) 
                : <String, dynamic>{};
            cleanedMetadata.remove('inlineBlocks');
            
            final cleanedEntry = entry.copyWith(metadata: cleanedMetadata);
            await box.put(cleanedEntry.id, cleanedEntry);
            print('✅ JournalRepository: Persisted migration for entry ${cleanedEntry.id} with ${cleanedEntry.lumaraBlocks.length} blocks (removed inlineBlocks from metadata)');
          }
        } catch (e) {
          print('❌ JournalRepository: Error persisting migrations: $e');
        }
      });
    }
    
    return entries;
  }

    JournalEntry _normalize(JournalEntry e) {
      // Check if we need to migrate legacy metadata to SAGE annotation
      SAGEAnnotation? sageAnnotation = e.sageAnnotation;
      if (sageAnnotation == null && e.metadata?['narrative'] != null) {
        final raw = e.metadata!['narrative'];
        // Legacy entries may have narrative as Map or other type; only migrate when it's a Map
        if (raw is Map) {
          final n = raw;
          sageAnnotation = SAGEAnnotation(
            situation: (n['situation'] ?? '').toString(),
            action: (n['action'] ?? '').toString(),
            growth: (n['growth'] ?? '').toString(),
            essence: (n['essence'] ?? '').toString(),
            confidence: 0.8, // Default confidence for migrated annotations
          );
        }
      }

      // Ensure media list is properly preserved (create new list to avoid reference issues)
      final mediaList = List<MediaItem>.from(e.media);
      
      // Debug: Log media preservation
      if (e.media.isNotEmpty && mediaList.isEmpty) {
        print('❌ JournalRepository: CRITICAL - Media list was lost during normalization! Original count: ${e.media.length}');
      }

      // Deep copy metadata to ensure inline blocks are preserved
      Map<String, dynamic>? normalizedMetadata;
      List<InlineBlock> migratedLumaraBlocks = List.from(e.lumaraBlocks);

      if (e.metadata != null) {
        normalizedMetadata = Map<String, dynamic>.from(e.metadata!);
        
        // MIGRATION: Convert old metadata-based LUMARA blocks to new lumaraBlocks field
        if (e.metadata!.containsKey('inlineBlocks') && migratedLumaraBlocks.isEmpty) {
          final inlineBlocksData = e.metadata!['inlineBlocks'];
          
          if (inlineBlocksData != null) {
            try {
              List<InlineBlock> convertedBlocks = [];

              if (inlineBlocksData is String) {
                // JSON string format; per-block try so one bad block doesn't drop the rest (legacy)
                final decoded = jsonDecode(inlineBlocksData);
                if (decoded is List) {
                  convertedBlocks = decoded
                      .map((blockJson) {
                        if (blockJson is Map) {
                          try {
                            return InlineBlock.fromJson(Map<String, dynamic>.from(blockJson));
                          } catch (_) {
                            return null;
                          }
                        }
                        return null;
                      })
                      .whereType<InlineBlock>()
                      .toList();
                }
              } else if (inlineBlocksData is List) {
                // Direct List format
                convertedBlocks = inlineBlocksData
                    .map((blockJson) {
                      if (blockJson is Map) {
                        try {
                          return InlineBlock.fromJson(Map<String, dynamic>.from(blockJson));
                        } catch (err) {
                          return null;
                        }
                      }
                      return null;
                    })
                    .whereType<InlineBlock>()
                    .toList();
              }

              if (convertedBlocks.isNotEmpty) {
                migratedLumaraBlocks = convertedBlocks;
              }
            } catch (err) {
              // Silently handle migration errors - entry will work without migrated blocks
            }
          }

          // Remove inlineBlocks from metadata after migration (we use lumaraBlocks field now)
          normalizedMetadata.remove('inlineBlocks');
        } else if (e.metadata!.containsKey('inlineBlocks') && migratedLumaraBlocks.isNotEmpty) {
          // Remove inlineBlocks from metadata since blocks are already in lumaraBlocks field
          normalizedMetadata.remove('inlineBlocks');
        }
        
        // Remove inlineBlocks from metadata if it still exists (cleanup)
        normalizedMetadata.remove('inlineBlocks');
      }

      // Create a new entry with normalized data
      return JournalEntry(
        id: e.id,
        title: e.title,
        content: e.content,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        tags: e.tags,
        mood: e.mood,
        audioUri: e.audioUri,
        media: mediaList, // Use preserved media list
        keywords: e.keywords,
        sageAnnotation: sageAnnotation,
        emotion: e.emotion,
        emotionReason: e.emotionReason,
        metadata: normalizedMetadata, // Use deep-copied metadata
        location: e.location,
        phase: e.phase,
        phaseAtTime: e.phaseAtTime,
        isEdited: e.isEdited,
        autoPhase: e.autoPhase,
        autoPhaseConfidence: e.autoPhaseConfidence,
        userPhaseOverride: e.userPhaseOverride,
        isPhaseLocked: e.isPhaseLocked,
        legacyPhaseTag: e.legacyPhaseTag,
        importSource: e.importSource,
        phaseInferenceVersion: e.phaseInferenceVersion,
        phaseMigrationStatus: e.phaseMigrationStatus,
        lumaraBlocks: migratedLumaraBlocks, // Use migrated LUMARA blocks
      );
    }

  Future<JournalEntry?> getJournalEntryById(String id) async {
    final box = await _ensureBox();
    final entry = box.get(id);
    if (entry != null) {
      // Normalize to ensure lumaraBlocks are migrated if needed
      final normalized = _normalize(entry);
      
      // If migration occurred, persist immediately
      if (entry.lumaraBlocks.isEmpty && 
          normalized.lumaraBlocks.isNotEmpty && 
          entry.metadata?.containsKey('inlineBlocks') == true) {
        await box.put(normalized.id, normalized);
      }
      
      return normalized;
    }
    return null;
  }
  
  // Synchronous version for backward compatibility
  JournalEntry? getJournalEntryByIdSync(String id) {
    if (Hive.isBoxOpen(_boxName)) {
      final entry = Hive.box<JournalEntry>(_boxName).get(id);
      if (entry != null) {
        return _normalize(entry);
      }
    }
    return null;
  }

  // Update
  Future<void> updateJournalEntry(JournalEntry entry) async {
    // Remove inlineBlocks from metadata if present (blocks are now in lumaraBlocks field)
    final cleanedMetadata = entry.metadata != null 
        ? Map<String, dynamic>.from(entry.metadata!) 
        : <String, dynamic>{};
    cleanedMetadata.remove('inlineBlocks');
    
    final cleanedEntry = cleanedMetadata != entry.metadata 
        ? entry.copyWith(metadata: cleanedMetadata.isEmpty ? null : cleanedMetadata)
        : entry;

    final box = await _ensureBox();
    await box.put(cleanedEntry.id, cleanedEntry);

    // Verify the update was successful - check lumaraBlocks field directly
    final updatedEntry = box.get(entry.id);
    if (updatedEntry != null) {
      print('🔍 JournalRepository: Update verification - Retrieved entry has ${updatedEntry.lumaraBlocks.length} LUMARA blocks');
      if (updatedEntry.lumaraBlocks.length != entry.lumaraBlocks.length) {
        print('❌ JournalRepository: Update verification - Block count mismatch! Saved: ${entry.lumaraBlocks.length}, Retrieved: ${updatedEntry.lumaraBlocks.length}');
      } else if (entry.lumaraBlocks.isNotEmpty) {
        // Verify user comments were saved
        for (int i = 0; i < entry.lumaraBlocks.length; i++) {
          final originalComment = entry.lumaraBlocks[i].userComment;
          final savedComment = updatedEntry.lumaraBlocks[i].userComment;
          if (originalComment != savedComment) {
            print('❌ JournalRepository: Update verification - Block $i userComment mismatch!');
            print('   Original: ${originalComment ?? "null"}');
            print('   Saved: ${savedComment ?? "null"}');
          } else if (originalComment != null && originalComment.isNotEmpty) {
            print('✅ JournalRepository: Update verification - Block $i userComment saved correctly (length: ${originalComment.length})');
          }
        }
      }
    } else {
      print('❌ JournalRepository: Update verification - Updated entry missing!');
    }
  }

  // Delete
  Future<void> deleteJournalEntry(String id) async {
    // Get the entry before deleting to clean up MIRA data
    final entry = await getJournalEntryById(id);
    
    // Delete from journal repository
    final box = await _ensureBox();
    await box.delete(id);
    
    // Clean up MIRA nodes and edges if entry existed
    if (entry != null) {
      try {
        final miraService = MiraService.instance;
        
        // Find MIRA node by original_entry_id in metadata (more reliable than deterministic ID)
        // This ensures we delete the correct node even if there are duplicate entries
        String? miraNodeId;
        List<String> candidateNodeIds = [];
        
        try {
          final entryNodes = await miraService.repo.findNodesByType(NodeType.entry);
          print('🔍 Journal: Searching through ${entryNodes.length} MIRA entry nodes for entry $id');
          
          for (final node in entryNodes) {
            final metadata = node.data;
            
            // Check for original_entry_id match
            if (metadata.containsKey('original_entry_id') && 
                metadata['original_entry_id'] == id) {
              miraNodeId = node.id;
              print('🔍 Journal: Found MIRA node by original_entry_id: $miraNodeId');
              break;
            }
            
            // Also check if node ID contains the entry ID (for nodes created with unique ID)
            if (node.id.contains(id) || node.id.endsWith(id.substring(0, 8))) {
              candidateNodeIds.add(node.id);
              print('🔍 Journal: Found candidate MIRA node by ID pattern: ${node.id}');
            }
          }
          
          // If no exact match but we have candidates, use the first one
          if (miraNodeId == null && candidateNodeIds.isNotEmpty) {
            miraNodeId = candidateNodeIds.first;
            print('🔍 Journal: Using candidate MIRA node ID: $miraNodeId');
          }
        } catch (e) {
          print('⚠️ Journal: Error searching for MIRA node by original_entry_id: $e');
        }
        
        // Fallback: Try generating unique ID that includes entry ID
        if (miraNodeId == null) {
          // Generate unique ID that includes entry ID to ensure we get the right node
          final normalized = entry.content.trim();
          final combined = '$id|$normalized|${entry.createdAt.toUtc().toIso8601String()}';
          final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 12);
          miraNodeId = 'entry_$hash';
          print('🔍 Journal: Generated unique MIRA node ID with entry ID: $miraNodeId');
        }
        
        print('🔍 Journal: Cleaning up MIRA data for entry $id (MIRA node: $miraNodeId)');
        
        // Delete the entry node and its edges
        await miraService.deleteNode(miraNodeId);
        
        // Clean up orphaned keyword nodes
        if (entry.keywords.isNotEmpty) {
          await miraService.cleanupOrphanedKeywords(entry.keywords);
        }
        
        print('✅ Journal: Successfully cleaned up MIRA data for entry $id');
      } catch (e) {
        print('❌ Journal: Error cleaning up MIRA data for entry $id: $e');
        // Don't rethrow - journal entry is already deleted
      }
    }
  }

  Future<void> deleteAllEntries() async {
    final box = await _ensureBox();
    await box.clear();
  }

  Future<int> getEntryCount() async {
    final box = await _ensureBox();
    return box.length;
  }

  /// Remove duplicate entries, keeping the most recent version of each
  /// Duplicates are identified by:
  /// 1. Same ID (shouldn't happen with Hive, but check anyway)
  /// 2. Same content + createdAt (within 1 second tolerance)
  Future<int> removeDuplicateEntries() async {
    print('🔍 JournalRepository: Starting duplicate removal...');
    final box = await _ensureBox();
    final allEntries = box.values.toList();
    final originalCount = allEntries.length;
    
    // Track entries to keep and delete
    final entriesToKeep = <String, JournalEntry>{};
    final entriesToDelete = <String>[];
    
    // First pass: Check for duplicate IDs (shouldn't happen, but check)
    final idMap = <String, List<JournalEntry>>{};
    for (final entry in allEntries) {
      if (!idMap.containsKey(entry.id)) {
        idMap[entry.id] = [];
      }
      idMap[entry.id]!.add(entry);
    }
    
    // If we find duplicate IDs, keep the one with the latest updatedAt
    for (final entryList in idMap.values) {
      if (entryList.length > 1) {
        print('⚠️ JournalRepository: Found ${entryList.length} entries with same ID: ${entryList.first.id}');
        // Sort by updatedAt descending, keep the first (most recent)
        entryList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        entriesToKeep[entryList.first.id] = entryList.first;
        // Mark others for deletion
        for (int i = 1; i < entryList.length; i++) {
          entriesToDelete.add(entryList[i].id);
          print('   Marking duplicate ID entry for deletion: ${entryList[i].id}');
        }
      } else {
        entriesToKeep[entryList.first.id] = entryList.first;
      }
    }
    
    // Helper functions to normalize content for comparison/key generation
    String normalizeContentForKey(String content) {
      // Remove punctuation and collapse whitespace entirely so identical content maps to same key
      return content
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
    }

    String normalizeContentForWords(String content) {
      // Remove punctuation but keep single spaces so we can compare word tokens
      return content
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    
    // Helper function to get date-only key (ignore time)
    String getDateKey(DateTime date) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    
    // Second pass: Check for duplicate content + date (by day only, normalized content)
    final contentDateMap = <String, List<JournalEntry>>{};
    for (final entry in entriesToKeep.values) {
      // Create a key from normalized content + date (day only)
      final dateKey = getDateKey(entry.createdAt);
      final normalizedContent = normalizeContentForKey(entry.content);
      final key = '$dateKey|$normalizedContent';
      
      if (!contentDateMap.containsKey(key)) {
        contentDateMap[key] = [];
      }
      contentDateMap[key]!.add(entry);
    }
    
    // For entries with same normalized content + date, keep the one with latest updatedAt
    for (final entryList in contentDateMap.values) {
      if (entryList.length > 1) {
        print('⚠️ JournalRepository: Found ${entryList.length} entries with same content and date');
        for (final e in entryList) {
          print('   Entry ID: ${e.id}, Date: ${e.createdAt}, Updated: ${e.updatedAt}');
          print('   Content preview: ${e.content.substring(0, e.content.length > 100 ? 100 : e.content.length)}...');
        }
        
        // Sort by updatedAt descending, keep the first (most recent)
        entryList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final keepEntry = entryList.first;
        
        // Mark others for deletion
        for (int i = 1; i < entryList.length; i++) {
          final duplicateEntry = entryList[i];
          // Only delete if not already marked for deletion
          if (!entriesToDelete.contains(duplicateEntry.id)) {
            entriesToDelete.add(duplicateEntry.id);
            print('   ✅ Marking duplicate content entry for deletion: ${duplicateEntry.id} (keeping ${keepEntry.id})');
          }
        }
      }
    }
    
    // Third pass: Also check for entries with very similar content (fuzzy match)
    // This catches cases where content might have minor differences
    // Always run this check, not just when no exact duplicates are found
    print('🔍 JournalRepository: Checking for similar content entries...');
    final remainingEntries = entriesToKeep.values.where((e) => !entriesToDelete.contains(e.id)).toList();
    
    // Helper function to calculate Jaccard similarity
    double calculateJaccardSimilarity(String s1, String s2) {
      final set1 = s1.split(' ').where((w) => w.isNotEmpty).toSet();
      final set2 = s2.split(' ').where((w) => w.isNotEmpty).toSet();
      
      if (set1.isEmpty && set2.isEmpty) return 1.0;
      if (set1.isEmpty || set2.isEmpty) return 0.0;
      
      final intersection = set1.intersection(set2).length;
      final union = set1.length + set2.length - intersection;
      return intersection / union;
    }
    
    for (int i = 0; i < remainingEntries.length; i++) {
      final entry1 = remainingEntries[i];
      if (entriesToDelete.contains(entry1.id)) continue;
      
      final content1 = normalizeContentForWords(entry1.content);
      
      // Skip if content is too short (likely not a real duplicate)
      if (content1.length < 20) continue;
      
      for (int j = i + 1; j < remainingEntries.length; j++) {
        final entry2 = remainingEntries[j];
        if (entriesToDelete.contains(entry2.id)) continue;
        
        final content2 = normalizeContentForWords(entry2.content);
        
        // Skip if content is too short
        if (content2.length < 20) continue;
        
        if (content1.isEmpty || content2.isEmpty) continue;

        // Consider entries saved within a short window (12 hours) as potential duplicates
        final timeDifference =
            entry1.createdAt.difference(entry2.createdAt).abs();
        if (timeDifference <= const Duration(hours: 12)) {
          final similarity = calculateJaccardSimilarity(content1, content2);
          
          if (similarity > 0.95) {
            // Very similar content on same date - likely duplicates
            print('⚠️ JournalRepository: Found similar entries (similarity: ${similarity.toStringAsFixed(2)})');
            print('   Entry 1 ID: ${entry1.id}, Date: ${entry1.createdAt}, Updated: ${entry1.updatedAt}');
            print('   Entry 2 ID: ${entry2.id}, Date: ${entry2.createdAt}, Updated: ${entry2.updatedAt}');
            print('   Content 1 preview: ${entry1.content.substring(0, entry1.content.length > 100 ? 100 : entry1.content.length)}...');
            print('   Content 2 preview: ${entry2.content.substring(0, entry2.content.length > 100 ? 100 : entry2.content.length)}...');
            
            // Keep the one with latest updatedAt
            final toKeep = entry1.updatedAt.isAfter(entry2.updatedAt) ? entry1 : entry2;
            final toDelete = entry1.updatedAt.isAfter(entry2.updatedAt) ? entry2 : entry1;
            
            if (!entriesToDelete.contains(toDelete.id)) {
              entriesToDelete.add(toDelete.id);
              print('   ✅ Marking similar entry for deletion: ${toDelete.id} (keeping ${toKeep.id})');
            }
          }
        }
      }
    }
    
    // Delete duplicate entries
    int deletedCount = 0;
    for (final entryId in entriesToDelete) {
      try {
        await box.delete(entryId);
        deletedCount++;
        print('✅ JournalRepository: Deleted duplicate entry: $entryId');
      } catch (e) {
        print('❌ JournalRepository: Error deleting duplicate entry $entryId: $e');
      }
    }
    
    final finalCount = box.length;
    print('🔍 JournalRepository: Duplicate removal complete');
    print('   Original entries: $originalCount');
    print('   Duplicates removed: $deletedCount');
    print('   Remaining entries: $finalCount');
    
    return deletedCount;
  }

  // Pagination methods for timeline
  Future<List<JournalEntry>> getEntriesPaginated({
    required int page,
    required int pageSize,
    TimelineFilter? filter,
  }) async {
    final allEntries = await getAllJournalEntries();
    allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

    // Apply filter if provided
    List<JournalEntry> filtered = allEntries;
    if (filter != null) {
      switch (filter) {
        case TimelineFilter.textOnly:
          filtered = allEntries.where((e) => e.content.isNotEmpty).toList();
          break;
        case TimelineFilter.withArcform:
          filtered = allEntries.where((e) => e.sageAnnotation != null).toList();
          break;
        case TimelineFilter.all:
          filtered = allEntries;
          break;
      }
    }

    final startIndex = page * pageSize;
    if (startIndex >= filtered.length) return [];

    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  // Synchronous version for backward compatibility
  List<JournalEntry> getEntriesPaginatedSync({
    required int page,
    required int pageSize,
    TimelineFilter? filter,
  }) {
    final allEntries = getAllJournalEntriesSync();
    allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first (fixed)

    // Apply filter if provided
    List<JournalEntry> filtered = allEntries;
    if (filter != null) {
      switch (filter) {
        case TimelineFilter.textOnly:
          filtered = allEntries.where((e) => e.content.isNotEmpty).toList();
          break;
        case TimelineFilter.withArcform:
          filtered = allEntries.where((e) => e.sageAnnotation != null).toList();
          break;
        case TimelineFilter.all:
          filtered = allEntries;
          break;
      }
    }

    final startIndex = page * pageSize;
    if (startIndex >= filtered.length) return [];

    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  /// Populate Layer 0 for CHRONICLE (if enabled)
  /// 
  /// This is called after journal entry save to populate Layer 0.
  /// [userId] When provided (e.g. by PhaseQuizV2), used for Layer 0. Otherwise
  /// uses current Firebase user uid or 'default_user' so synthesis finds entries.
  Future<void> _populateLayer0IfEnabled(JournalEntry entry, String? userIdParam) async {
    try {
      // Lazy initialization
      if (!_layer0Initialized) {
        try {
          _layer0Repo = Layer0Repository();
          await _layer0Repo!.initialize();
          _layer0Populator = Layer0Populator(_layer0Repo!);
          _layer0Initialized = true;
          print('✅ JournalRepository: CHRONICLE Layer 0 initialized');
        } catch (e) {
          print('⚠️ JournalRepository: CHRONICLE Layer 0 initialization failed (non-fatal): $e');
          // Don't set _layer0Initialized = true, so we don't keep trying
          return;
        }
      }

      if (_layer0Populator != null) {
        final userId = userIdParam ??
            FirebaseAuthService.instance.currentUser?.uid ??
            'default_user';
        await _layer0Populator!.populateFromJournalEntry(
          journalEntry: entry,
          userId: userId,
        );
      }
    } catch (e) {
      // Don't let Layer 0 population failure break journal save
      print('⚠️ JournalRepository: Layer 0 population failed (non-fatal): $e');
    }
  }

  // Close the box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    if (_layer0Repo != null) {
      await _layer0Repo!.close();
    }
  }
}
