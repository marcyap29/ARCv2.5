// lib/arc/chat/services/arc_subsystem.dart
// ARC subsystem: recent journal entries for LUMARA reflection (wraps LumaraContextSelector).

import 'package:my_app/lumara/models/command_intent.dart';
import 'package:my_app/lumara/models/subsystem_result.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/subsystems/subsystem.dart';
import 'lumara_context_selector.dart';
import 'lumara_reflection_settings_service.dart';

/// LUMARA subsystem that provides recent journal entries for reflection.
///
/// Delegates to [LumaraContextSelector]; returns [recentEntries] and [entryContents]
/// for prompt building in [EnhancedLumaraApi].
class ArcSubsystem implements Subsystem {
  final LumaraContextSelector _contextSelector;
  final LumaraReflectionSettingsService _settingsService;

  ArcSubsystem({
    LumaraContextSelector? contextSelector,
    LumaraReflectionSettingsService? settingsService,
  })  : _contextSelector = contextSelector ?? LumaraContextSelector(),
        _settingsService = settingsService ?? LumaraReflectionSettingsService.instance;

  @override
  String get name => 'ARC';

  @override
  bool canHandle(CommandIntent intent) {
    switch (intent.type) {
      case IntentType.temporalQuery:
      case IntentType.patternAnalysis:
      case IntentType.developmentalArc:
      case IntentType.historicalParallel:
      case IntentType.comparison:
      case IntentType.recentContext:
      case IntentType.decisionSupport:
      case IntentType.specificRecall:
        return true;
      default:
        return false;
    }
  }

  @override
  Future<SubsystemResult> query(CommandIntent intent) async {
    if (intent.userId == null || intent.userId!.isEmpty) {
      return SubsystemResult.error(
        source: name,
        message: 'ARC requires userId',
      );
    }

    try {
      final memoryFocus = await _settingsService.getMemoryFocusPreset();
      final engagementSettings = await _settingsService.getEngagementSettings();
      final engagementMode = engagementSettings.activeMode;
      final now = DateTime.now();

      final entries = await _contextSelector.selectContextEntries(
        memoryFocus: memoryFocus,
        engagementMode: engagementMode,
        currentEntryText: intent.rawQuery,
        currentDate: now,
        entryId: intent.entryId,
        customMaxEntries: intent.maxResults,
      );

      final recentEntries = entries.map((entry) {
        final daysAgo = now.difference(entry.createdAt).inDays;
        final relativeDate = daysAgo == 0
            ? 'today'
            : daysAgo == 1
                ? 'yesterday'
                : '$daysAgo days ago';
        final title = entry.content.split('\n').first.trim().isEmpty
            ? 'Untitled entry'
            : entry.content.split('\n').first.trim();
        return {
          'date': entry.createdAt,
          'relativeDate': relativeDate,
          'daysAgo': daysAgo,
          'title': title,
          'id': entry.id,
        };
      }).toList();

      final entryContents = entries.map((e) => e.content).toList();

      return SubsystemResult(
        source: name,
        data: {
          'recentEntries': recentEntries,
          'entryContents': entryContents,
        },
        metadata: {'count': entries.length},
      );
    } catch (e) {
      return SubsystemResult.error(
        source: name,
        message: 'ARC query failed: $e',
      );
    }
  }
}
