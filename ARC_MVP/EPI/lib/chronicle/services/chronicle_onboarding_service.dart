import 'dart:io';
import 'dart:convert';
import '../../models/journal_entry_model.dart';
import '../../arc/internal/mira/journal_repository.dart';
import '../storage/layer0_repository.dart';
import '../storage/layer0_populator.dart';
import '../storage/aggregation_repository.dart';
import '../synthesis/synthesis_engine.dart';
import '../models/chronicle_layer.dart';
import '../scheduling/synthesis_scheduler.dart';

/// CHRONICLE Onboarding Service
/// 
/// Handles onboarding of existing users into CHRONICLE:
/// - Backfill Layer 0 from existing journal entries
/// - Batch synthesize historical periods
/// - Import from external formats
class ChronicleOnboardingService {
  final JournalRepository _journalRepo;
  final Layer0Repository _layer0Repo;
  final AggregationRepository _aggregationRepo;
  final SynthesisEngine _synthesisEngine;

  ChronicleOnboardingService({
    required JournalRepository journalRepo,
    required Layer0Repository layer0Repo,
    required AggregationRepository aggregationRepo,
    required SynthesisEngine synthesisEngine,
  })  : _journalRepo = journalRepo,
        _layer0Repo = layer0Repo,
        _aggregationRepo = aggregationRepo,
        _synthesisEngine = synthesisEngine;

  /// Backfill Layer 0 from all existing journal entries
  /// 
  /// Processes entries in batches to avoid blocking the UI.
  /// Returns progress updates via callback.
  Future<OnboardingResult> backfillLayer0({
    required String userId,
    Function(int processed, int total)? onProgress,
  }) async {
    print('📥 ChronicleOnboardingService: Starting Layer 0 backfill (userId: $userId)');
    
    final result = OnboardingResult();
    
    try {
      // Get all journal entries (same store Chronicle reads from)
      final entries = await _journalRepo.getAllJournalEntries();
      result.totalEntries = entries.length;
      print('📥 ChronicleOnboardingService: Journal has ${entries.length} entries to consider');
      
      if (entries.isEmpty) {
        onProgress?.call(0, 1); // Signal UI so progress view is not static
        result.success = true;
        result.message = 'No entries to backfill';
        return result;
      }

      // Initialize Layer 0 repository
      await _layer0Repo.initialize();
      
      // Check which entries are already in Layer 0
      // We'll check during processing to avoid loading all entries at once
      final existingEntryIds = <String>{};
      
      // Process in batches, checking if entry already exists in Layer 0
      const batchSize = 50;
      final populator = Layer0Populator(_layer0Repo);
      
      for (int i = 0; i < entries.length; i += batchSize) {
        final batch = entries.skip(i).take(batchSize).toList();
        
        // Check which entries need to be in Layer 0 (missing or wrong userId)
        // Re-populate when existing entry has different userId (e.g. 'default_user')
        final batchToProcess = <JournalEntry>[];
        for (final entry in batch) {
          try {
            final existing = await _layer0Repo.getEntry(entry.id);
            if (existing == null || existing.userId != userId) {
              batchToProcess.add(entry);
            } else {
              existingEntryIds.add(entry.id);
            }
          } catch (e) {
            // If check fails, assume entry doesn't exist and process it
            batchToProcess.add(entry);
          }
        }
        
        if (batchToProcess.isNotEmpty) {
          final counts = await populator.populateFromJournalEntries(
            entries: batchToProcess,
            userId: userId,
          );
          result.newEntries += counts.succeeded;
          result.errors += counts.failed;
        }
        
        result.processedEntries += batch.length;
        onProgress?.call(result.processedEntries, entries.length);
        
        // Yield to UI thread every batch
        await Future.microtask(() {});
      }
      
      if (result.newEntries == 0 && result.errors == 0) {
        result.success = true;
        result.message = 'All entries already in Layer 0';
        return result;
      }
      
      result.success = true;
      if (result.errors > 0) {
        result.message = 'Backfilled ${result.newEntries} entries to Layer 0, ${result.errors} failed (see log)';
        print('✅ ChronicleOnboardingService: Layer 0 backfill complete: ${result.newEntries} new, ${result.errors} failed');
      } else if (result.totalEntries > result.newEntries && result.newEntries > 0) {
        result.message = 'Backfilled ${result.newEntries} of ${result.totalEntries} entries (rest already in Layer 0)';
        print('✅ ChronicleOnboardingService: Layer 0 backfill complete: ${result.newEntries} new of ${result.totalEntries} total');
      } else {
        result.message = 'Backfilled ${result.newEntries} entries to Layer 0';
        print('✅ ChronicleOnboardingService: Layer 0 backfill complete: ${result.newEntries} new entries');
      }
      
      return result;
    } catch (e) {
      print('❌ ChronicleOnboardingService: Layer 0 backfill failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Batch synthesize historical periods
  /// 
  /// Synthesizes all months/years that have entries but no aggregations.
  /// Processes in chronological order (oldest first).
  Future<OnboardingResult> batchSynthesizeHistorical({
    required String userId,
    required SynthesisTier tier,
    Function(int processed, int total, String currentPeriod)? onProgress,
  }) async {
    print('📥 ChronicleOnboardingService: Starting batch synthesis (userId: $userId)');
    
    final result = OnboardingResult();
    
    try {
      await _layer0Repo.initialize();

      // Build list of months from Layer 0 for this userId (not journal)
      // So we only synthesize months that actually have Layer 0 data for this user
      final monthlyPeriods = await _layer0Repo.getMonthsWithEntries(userId);
      if (monthlyPeriods.isEmpty) {
        result.success = true;
        result.message = 'No Layer 0 entries for this user. Run Backfill Layer 0 first.';
        print('⚠️ ChronicleOnboardingService: No Layer 0 entries for userId $userId');
        return result;
      }
      print('📥 ChronicleOnboardingService: Found ${monthlyPeriods.length} months with Layer 0 data: $monthlyPeriods');

      // Filter to months that don't already have an aggregation
      final monthlyToSynthesize = <String>[];
      for (final period in monthlyPeriods) {
        final existing = await _aggregationRepo.loadLayer(
          userId: userId,
          layer: ChronicleLayer.monthly,
          period: period,
        );
        if (existing == null) {
          monthlyToSynthesize.add(period);
        }
      }

      // Yearly: only if tier supports and we have enough months in Layer 0 for that year
      final cadence = SynthesisCadence.forTier(tier);
      final yearlyPeriods = monthlyPeriods.map((p) => p.split('-').first).toSet();
      final yearlyPeriodsToSynthesize = <String>[];
      if (cadence.enableYearly) {
        for (final year in yearlyPeriods) {
          final existing = await _aggregationRepo.loadLayer(
            userId: userId,
            layer: ChronicleLayer.yearly,
            period: year,
          );
          if (existing == null) {
            final yearMonths = monthlyPeriods.where((p) => p.startsWith(year)).toList();
            if (yearMonths.length >= 3) {
              yearlyPeriodsToSynthesize.add(year);
            }
          }
        }
      }

      final totalPeriods = monthlyToSynthesize.length + yearlyPeriodsToSynthesize.length;
      result.totalPeriods = totalPeriods;

      if (totalPeriods == 0) {
        result.success = true;
        result.message = 'All periods already synthesized';
        return result;
      }

      // Synthesize monthly periods (only months that have Layer 0 data and no aggregation yet)
      for (int i = 0; i < monthlyToSynthesize.length; i++) {
        final period = monthlyToSynthesize[i];
        onProgress?.call(i + 1, totalPeriods, period);
        
        try {
          await _synthesisEngine.synthesizeLayer(
            userId: userId,
            layer: ChronicleLayer.monthly,
            period: period,
          );
          result.processedPeriods++;
        } catch (e) {
          result.errors++;
          print('⚠️ ChronicleOnboardingService: Failed to synthesize month $period: $e');
        }
        
        if (i % 5 == 0) {
          await Future.microtask(() {});
        }
      }

      // Synthesize yearly periods
      for (int i = 0; i < yearlyPeriodsToSynthesize.length; i++) {
        final period = yearlyPeriodsToSynthesize[i];
        final index = monthlyToSynthesize.length + i + 1;
        onProgress?.call(index, totalPeriods, period);
        
        try {
          await _synthesisEngine.synthesizeLayer(
            userId: userId,
            layer: ChronicleLayer.yearly,
            period: period,
          );
          result.processedPeriods++;
        } catch (e) {
          result.errors++;
          print('⚠️ ChronicleOnboardingService: Failed to synthesize year $period: $e');
        }
        
        // Yield to UI thread every period
        await Future.microtask(() {});
      }
      
      result.success = true;
      result.message = 'Synthesized ${result.processedPeriods} periods (${monthlyToSynthesize.length} monthly, ${yearlyPeriodsToSynthesize.length} yearly)';
      print('✅ ChronicleOnboardingService: Batch synthesis complete: ${result.processedPeriods} periods');
      
      return result;
    } catch (e) {
      print('❌ ChronicleOnboardingService: Batch synthesis failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Backfill Layer 0 then synthesize current month only.
  /// Reports progress as (current, total) with total >= 2: 0/2 = backfill, 1/2 = synthesizing.
  Future<OnboardingResult> backfillAndSynthesizeCurrentMonth({
    required String userId,
    Function(int processed, int total)? onProgress,
  }) async {
    final result = OnboardingResult();
    try {
      onProgress?.call(0, 2);
      final layer0Result = await backfillLayer0(userId: userId, onProgress: (p, t) {
        if (t > 0) onProgress?.call(0, 2); // Keep at "phase 1" with sub-progress from backfill
      });
      if (!layer0Result.success) {
        result.success = false;
        result.error = layer0Result.error;
        return result;
      }
      onProgress?.call(1, 2);
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
        period: period,
      );
      onProgress?.call(2, 2);
      result.success = true;
      result.message = 'Backfill complete; current month ($period) synthesized';
      return result;
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Backfill Layer 0 then synthesize current year only.
  Future<OnboardingResult> backfillAndSynthesizeCurrentYear({
    required String userId,
    Function(int processed, int total)? onProgress,
  }) async {
    final result = OnboardingResult();
    try {
      onProgress?.call(0, 2);
      final layer0Result = await backfillLayer0(userId: userId, onProgress: (p, t) => onProgress?.call(0, 2));
      if (!layer0Result.success) {
        result.success = false;
        result.error = layer0Result.error;
        return result;
      }
      onProgress?.call(1, 2);
      final period = DateTime.now().year.toString();
      await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.yearly,
        period: period,
      );
      onProgress?.call(2, 2);
      result.success = true;
      result.message = 'Backfill complete; current year ($period) synthesized';
      return result;
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Backfill Layer 0 then synthesize current multi-year block (5-year period containing current year).
  Future<OnboardingResult> backfillAndSynthesizeMultiYear({
    required String userId,
    Function(int processed, int total)? onProgress,
  }) async {
    final result = OnboardingResult();
    try {
      onProgress?.call(0, 2);
      final layer0Result = await backfillLayer0(userId: userId, onProgress: (p, t) => onProgress?.call(0, 2));
      if (!layer0Result.success) {
        result.success = false;
        result.error = layer0Result.error;
        return result;
      }
      onProgress?.call(1, 2);
      final now = DateTime.now().year;
      final startYear = (now ~/ 5) * 5;
      final endYear = startYear + 4;
      final period = '$startYear-$endYear';
      await _synthesisEngine.synthesizeLayer(
        userId: userId,
        layer: ChronicleLayer.multiyear,
        period: period,
      );
      onProgress?.call(2, 2);
      result.success = true;
      result.message = 'Backfill complete; multi-year ($period) synthesized';
      return result;
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Full onboarding: backfill Layer 0 + batch synthesize.
  /// Reports progress on a 0-100 scale: 0-50 = backfill, 50-100 = synthesis (so the bar moves continuously).
  Future<OnboardingResult> fullOnboarding({
    required String userId,
    required SynthesisTier tier,
    Function(String stage, int progress, int total)? onProgress,
  }) async {
    print('📥 ChronicleOnboardingService: Starting full onboarding...');
    
    final result = OnboardingResult();
    const int totalScale = 100;
    
    try {
      // Stage 1: Backfill Layer 0 (reports 0–50)
      onProgress?.call('Backfilling Layer 0...', 0, totalScale);
      final layer0Result = await backfillLayer0(
        userId: userId,
        onProgress: (processed, total) {
          if (total > 0) {
            final p = (processed / total * 50).round().clamp(0, 50);
            onProgress?.call('Backfilling Layer 0... ($processed / $total entries)', p, totalScale);
          } else {
            onProgress?.call('Backfilling Layer 0...', 0, totalScale);
          }
        },
      );
      
      if (!layer0Result.success) {
        result.success = false;
        result.error = 'Layer 0 backfill failed: ${layer0Result.error}';
        return result;
      }
      
      result.processedEntries = layer0Result.processedEntries;
      result.newEntries = layer0Result.newEntries;
      
      onProgress?.call('Synthesizing historical periods...', 50, totalScale);
      
      // Stage 2: Batch synthesize (reports 50–100)
      final synthesisResult = await batchSynthesizeHistorical(
        userId: userId,
        tier: tier,
        onProgress: (processed, total, period) {
          if (total > 0) {
            final p = 50 + (processed / total * 50).round().clamp(0, 50);
            onProgress?.call('Synthesizing $period ($processed / $total)', p, totalScale);
          } else {
            onProgress?.call('Synthesizing historical periods...', 50, totalScale);
          }
        },
      );
      
      if (!synthesisResult.success) {
        result.success = false;
        result.error = 'Batch synthesis failed: ${synthesisResult.error}';
        return result;
      }
      
      result.processedPeriods = synthesisResult.processedPeriods;
      result.totalPeriods = synthesisResult.totalPeriods;
      result.errors = synthesisResult.errors;
      
      onProgress?.call('Done', totalScale, totalScale);
      
      result.success = true;
      result.message = 'Onboarding complete: ${result.newEntries} entries backfilled, ${result.processedPeriods} periods synthesized';
      
      return result;
    } catch (e) {
      print('❌ ChronicleOnboardingService: Full onboarding failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }

  /// Import from JSON file (external format)
  /// 
  /// Supports importing journal entries from JSON format.
  /// Expected format: List of entries with {id, content, createdAt, ...}
  Future<OnboardingResult> importFromJson({
    required String userId,
    required File jsonFile,
    Function(int processed, int total)? onProgress,
  }) async {
    print('📥 ChronicleOnboardingService: Importing from JSON: ${jsonFile.path}');
    
    final result = OnboardingResult();
    
    try {
      final content = await jsonFile.readAsString();
      final json = jsonDecode(content) as List<dynamic>;
      
      result.totalEntries = json.length;
      
      // Parse entries
      final entries = <JournalEntry>[];
      for (final entryJson in json) {
        try {
          final entry = JournalEntry.fromJson(entryJson as Map<String, dynamic>);
          entries.add(entry);
        } catch (e) {
          result.errors++;
          print('⚠️ ChronicleOnboardingService: Failed to parse entry: $e');
        }
      }
      
      // Save entries to journal repository (pass userId so Layer 0 is keyed correctly)
      for (int i = 0; i < entries.length; i++) {
        try {
          await _journalRepo.createJournalEntry(entries[i], userId: userId);
          result.processedEntries++;
          onProgress?.call(result.processedEntries, entries.length);
        } catch (e) {
          result.errors++;
          print('⚠️ ChronicleOnboardingService: Failed to save entry ${entries[i].id}: $e');
        }
      }
      
      // Backfill Layer 0 for imported entries
      await backfillLayer0(userId: userId);
      
      result.success = true;
      result.message = 'Imported ${result.processedEntries} entries from JSON';
      
      return result;
    } catch (e) {
      print('❌ ChronicleOnboardingService: JSON import failed: $e');
      result.success = false;
      result.error = e.toString();
      return result;
    }
  }
}

/// Result of onboarding operation
class OnboardingResult {
  int processedEntries = 0;
  int newEntries = 0;
  int totalEntries = 0;
  int processedPeriods = 0;
  int totalPeriods = 0;
  int errors = 0;
  bool success = false;
  String? message;
  String? error;
  
  @override
  String toString() {
    if (!success) {
      return 'Onboarding failed: $error';
    }
    return message ?? 'Onboarding complete';
  }
}
