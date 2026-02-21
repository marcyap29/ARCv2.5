// lib/services/phase_history_readiness_backfill_service.dart
// One-time backfill of phase history entries with operationalReadinessScore and healthData
// so Health & Readiness (Rating History, Phase Transitions, Health Correlation) show data
// after app upgrade or data restore.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/prism/atlas/phase/phase_history_repository.dart';
import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/services/phase_aware_analysis_service.dart';

const String _kBackfillDoneKey = 'phase_history_readiness_backfill_v1';

/// Backfills phase history entries that lack [operationalReadinessScore] / [healthData]
/// using current effective health (e.g. after upgrade or data restore).
/// Only updates entries that need it; sets a done flag when there is nothing left to backfill.
/// Safe to call repeatedly; runs in background and does not block.
Future<void> runPhaseHistoryReadinessBackfillIfNeeded() async {
  try {
    await PhaseHistoryRepository.initialize();
    final allEntries = await PhaseHistoryRepository.getAllEntries();
    final toBackfill = allEntries
        .where((e) => e.operationalReadinessScore == null)
        .toList();

    if (toBackfill.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBackfillDoneKey, true);
      if (kDebugMode) {
        // ignore: avoid_print
        print('Phase history readiness backfill: no entries to backfill');
      }
      return;
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('Phase history readiness backfill: backfilling ${toBackfill.length} entries');
    }

    final healthData = await HealthDataService.instance.getEffectiveHealthData();
    final phaseService = PhaseAwareAnalysisService();
    int updated = 0;

    for (final entry in toBackfill) {
      try {
        final text = entry.text;
        if (text.isEmpty) continue;
        final context = await phaseService.analyzePhase(
          text,
          healthData: healthData,
        );
        await PhaseHistoryRepository.updateEntryReadinessAndHealth(
          entry.id,
          context.operationalReadinessScore,
          context.healthData?.toJson(),
        );
        updated++;
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Phase history readiness backfill: skip entry ${entry.id}: $e');
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBackfillDoneKey, true);
    if (kDebugMode) {
      // ignore: avoid_print
      print('Phase history readiness backfill: done, updated $updated entries');
    }
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Phase history readiness backfill failed: $e');
      // ignore: avoid_print
      print(st);
    }
    // Do not set flag so we can retry on next launch
  }
}
