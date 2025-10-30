// File: lib/mira/mira_basics.dart
//
// MIRA BASICS: Instant phase & themes answers without the LLM.
// - Builds a Minimal MIRA Context Object (MMCO) from local stores
// - Provides QuickAnswers for common questions (phase, themes, streak, recency)
// - Safe defaults when journals are empty
//
// Hook points:
//   final mmco = await MiraBasics(journalRepo, memoryRepo, settings).build();
//   final qa = QuickAnswers(mmco);
//   if (qa.canAnswer(userText)) return qa.answer(userText);

import 'dart:async';
import '../lumara/llm/llm_adapter.dart' as llm;
import 'package:my_app/models/journal_entry_model.dart';

// ------------------------------
// DATA SHAPES
// ------------------------------

class RecentEntrySummary {
  final String id;
  final String createdAt; // ISO8601
  final String text;      // trimmed preview
  final String? phase;
  final List<String> tags;

  RecentEntrySummary({
    required this.id,
    required this.createdAt,
    required this.text,
    this.phase,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    "id": id,
    "createdAt": createdAt,
    "text": text,
    "phase": phase,
    "tags": tags,
  };
}

class MMCO {
  final String currentPhase;
  final String phaseGeometry;
  final String? lastPhaseChangeAt; // ISO8601
  final int recentEntryCount;      // last 7 days
  final String? lastEntryAt;       // ISO8601
  final int streakDays;
  final List<String> topKeywords;  // up to 10
  final List<String> recentQuestions; // last 5 prompts
  final String assistantStyle;     // "direct" | "suggestive"
  final String? onboardingIntent;  // nullable free text
  final ModelStatus modelStatus;
  final List<RecentEntrySummary> recentEntries; // NEW

  MMCO({
    required this.currentPhase,
    required this.phaseGeometry,
    required this.lastPhaseChangeAt,
    required this.recentEntryCount,
    required this.lastEntryAt,
    required this.streakDays,
    required this.topKeywords,
    required this.recentQuestions,
    required this.assistantStyle,
    required this.onboardingIntent,
    required this.modelStatus,
    required this.recentEntries, // NEW
  });

  Map<String, dynamic> toJson() => {
        "currentPhase": currentPhase,
        "phaseGeometry": phaseGeometry,
        "lastPhaseChangeAt": lastPhaseChangeAt,
        "recentEntryCount": recentEntryCount,
        "lastEntryAt": lastEntryAt,
        "streakDays": streakDays,
        "topKeywords": topKeywords,
        "recentQuestions": recentQuestions,
        "assistantStyle": assistantStyle,
        "onboardingIntent": onboardingIntent,
        "modelStatus": modelStatus.toJson(),
        "recentEntries": recentEntries.map((e) => e.toJson()).toList(),
      };
}

class ModelStatus {
  final String onDevice; // "available" | "unavailable"
  final String? name;

  ModelStatus({required this.onDevice, this.name});

  Map<String, dynamic> toJson() => {"onDevice": onDevice, "name": name};
}

// ------------------------------
// INTERFACES (plug in your real implementations)
// ------------------------------

abstract class JournalRepository {
  Future<List<JournalEntry>> getAll();
}


abstract class MemoryRepo {
  Future<List<String>> topKeywords({int limit = 10});
  Future<List<String>> lastUserPrompts({int limit = 5});
  Future<String?> currentPhaseFromHistory();
  Future<String?> lastPhaseChangeAt(String phase);
}

abstract class SettingsRepo {
  Future<bool> get memoryModeSuggestive;
  Future<String?> onboardingIntent();
}


// ------------------------------
// MIRA BASICS BUILDER
// ------------------------------

class MiraBasics {
  final JournalRepository journalRepo;
  final MemoryRepo memoryRepo;
  final SettingsRepo settings;

  MiraBasics(this.journalRepo, this.memoryRepo, this.settings);

  String _clip(String s, int n) => s.length <= n ? s : (s.substring(0, n).trimRight() + "...");
  
  String _ascii(String s) => s
    .replaceAll("'", "'")
    .replaceAll(""", '"')
    .replaceAll(""", '"')
    .replaceAll("–", "-")
    .replaceAll("—", "-")
    .replaceAll(RegExp(r"[^\x00-\x7F]"), "");

  List<RecentEntrySummary> _recentEntrySummaries(List<JournalEntry> entries, {int limit = 5}) {
    final sorted = [...entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final take = sorted.take(limit).toList();
    return take.map((e) {
      final preview = _ascii(_clip(e.content, 180)); // ~2 lines
      return RecentEntrySummary(
        id: e.id,
        createdAt: e.createdAt.toIso8601String(),
        text: preview,
        phase: e.metadata?['phase'], // Get phase from metadata
        tags: e.tags.take(5).toList(),
      );
    }).toList();
  }

  Future<MMCO> build() async {
    final now = DateTime.now();
    final entries = await _safeGetAll();
    final last = entries.isEmpty ? null : _maxBy(entries, (e) => e.createdAt);

    final recent7 = entries
        .where((e) => now.difference(e.createdAt).inDays <= 7)
        .length;

    final streak = _computeStreak(entries);

    final phase = await _resolvePhase(entries);
    final phaseGeom = _geometryForPhase(phase);

    final keywords = await _safeTopKeywords(limit: 10);
    final prompts = await _safeLastUserPrompts(limit: 5);
    final intent = await _safeOnboardingIntent();

    final onDeviceAvailable = await _safeIsModelReady();
    final modelName = _safeModelName();

    final chosenKeywords =
        keywords.isNotEmpty ? keywords : await _fallbackKeywords(intent);

    final recentSummaries = _recentEntrySummaries(entries, limit: 5);

    return MMCO(
      currentPhase: phase,
      phaseGeometry: phaseGeom,
      lastPhaseChangeAt: await memoryRepo.lastPhaseChangeAt(phase),
      recentEntryCount: recent7,
      lastEntryAt: last?.createdAt.toIso8601String(),
      streakDays: streak,
      topKeywords: chosenKeywords,
      recentQuestions: prompts,
      assistantStyle: (await settings.memoryModeSuggestive) ? "suggestive" : "direct",
      onboardingIntent: intent,
      modelStatus: ModelStatus(
        onDevice: onDeviceAvailable ? "available" : "unavailable",
        name: modelName,
      ),
      recentEntries: recentSummaries,
    );
  }

  // ---- helpers

  Future<List<JournalEntry>> _safeGetAll() async {
    try {
      return await journalRepo.getAll();
    } catch (_) {
      return <JournalEntry>[];
    }
  }

  Future<List<String>> _safeTopKeywords({int limit = 10}) async {
    try {
      return await memoryRepo.topKeywords(limit: limit);
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<String>> _safeLastUserPrompts({int limit = 5}) async {
    try {
      return await memoryRepo.lastUserPrompts(limit: limit);
    } catch (_) {
      return <String>[];
    }
  }

  Future<String?> _safeOnboardingIntent() async {
    try {
      return await settings.onboardingIntent();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _safeIsModelReady() async {
    try {
      return llm.LLMAdapter.isReady;
    } catch (_) {
      return false;
    }
  }

  String? _safeModelName() {
    try {
      return llm.LLMAdapter.activeModelName;
    } catch (_) {
      return null;
    }
  }

  Future<String> _resolvePhase(List<JournalEntry> entries) async {
    try {
      final fromHistory = await memoryRepo.currentPhaseFromHistory();
      if (fromHistory != null && fromHistory.trim().isNotEmpty) {
        return fromHistory;
      }
    } catch (_) {}
    // default (your ContextProvider already aligns with this)
    return "Discovery";
  }

  String _geometryForPhase(String phase) {
    switch (phase) {
      case "Expansion":
        return "flower";
      case "Consolidation":
        return "weave";
      case "Recovery":
        return "glow_core";
      case "Discovery":
      default:
        return "spiral";
    }
  }

  int _computeStreak(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;
    final sorted = [...entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    int streak = 1;
    DateTime prev = sorted.first.createdAt;
    for (int i = 1; i < sorted.length; i++) {
      final diffDays = prev.difference(sorted[i].createdAt).inDays;
      if (diffDays == 1) {
        streak++;
        prev = sorted[i].createdAt;
      } else if (diffDays == 0) {
        // same day entry: ignore, continue scanning
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<List<String>> _fallbackKeywords(String? intent) async {
    if (intent == null || intent.trim().isEmpty) {
      return const ["curiosity", "setup", "first steps"];
    }
    final words = intent
        .split(RegExp(r"[,\.;:\|\-\_\/\n\r\t\s]+"))
        .where((w) => w.length > 3)
        .map((w) => w.trim())
        .toSet()
        .toList();
    if (words.isEmpty) return const ["curiosity", "setup", "first steps"];
    return words.take(5).toList();
  }
}

// Utility: arg max
T? _maxBy<T>(Iterable<T> items, Comparable Function(T) key) {
  if (items.isEmpty) return null;
  final it = items.iterator;
  it.moveNext();
  var best = it.current;
  var bestKey = key(best);
  while (it.moveNext()) {
    final k = key(it.current);
    if (k.compareTo(bestKey) > 0) {
      best = it.current;
      bestKey = k;
    }
  }
  return best;
}

// ------------------------------
// PHASE GUIDE COPY (short, steady tone)
// ------------------------------

class PhaseGuide {
  final String summary;
  final List<String> signals;
  final List<String> nextSteps;
  const PhaseGuide(this.summary, this.signals, this.nextSteps);
}

PhaseGuide phaseGuideFor(String phase, String geom) {
  switch (phase) {
    case "Discovery":
      return const PhaseGuide(
        "You're exploring and widening inputs. The spiral reflects steady expansion and gentle forward motion.",
        ["new ideas", "notes without outcomes", "energy at the start"],
        ["Capture one idea", "Name one question", "Schedule a short explore block"],
      );
    case "Expansion":
      return const PhaseGuide(
        "You're growing threads into visible work. The flower reflects branching and bloom.",
        ["momentum", "drafts becoming concrete", "collaboration"],
        ["Pick one branch to deepen", "Share a draft", "Protect a focused window"],
      );
    case "Consolidation":
      return const PhaseGuide(
        "You're reducing surface area and stabilizing. The weave reflects coherence and closure.",
        ["cleanup", "refactors", "closing loops"],
        ["List 3 things to finish", "Archive or defer", "Publish a tidy summary"],
      );
    case "Recovery":
      return const PhaseGuide(
        "You're restoring energy and resetting. The glow core reflects containment and care.",
        ["low energy", "simpler tasks", "short reflections"],
        ["One gentle task", "Short walk", "Capture gratitude or relief"],
      );
    default:
      return const PhaseGuide(
        "Phase is unknown; using Discovery defaults.",
        ["curiosity", "inputs"],
        ["Capture one idea", "Name one question"],
      );
  }
}

// ------------------------------
// QUICK ANSWERS (no LLM path)
// ------------------------------

class QuickAnswers {
  final MMCO mmco;
  QuickAnswers(this.mmco);

  bool canAnswer(String q) {
    final s = q.toLowerCase();
    return s.contains("phase") ||
        s.contains("geometry") ||
        s.contains("shape") ||
        s.contains("theme") ||
        s.contains("keyword") ||
        s.contains("streak") ||
        s.contains("recent") ||
        s.contains("last entry") ||
        s.contains("latest entry");
  }

  String answer(String q) {
    final s = q.toLowerCase();
    if (s.contains("phase") || s.contains("shape") || s.contains("geometry")) {
      return _phaseCard();
    }
    if (s.contains("theme") || s.contains("keyword")) {
      return _themes();
    }
    if (s.contains("streak")) {
      return _streak();
    }
    if (s.contains("recent") || s.contains("last entry") || s.contains("latest entry")) {
      return _recent();
    }
    return _help();
  }

  String _phaseCard() {
    final guide = phaseGuideFor(mmco.currentPhase, mmco.phaseGeometry);
    final lines = <String>[
      "Phase: ${mmco.currentPhase}",
      "Shape: ${mmco.phaseGeometry}",
      if (mmco.lastPhaseChangeAt != null) "Since: ${mmco.lastPhaseChangeAt}",
      "",
      guide.summary,
      "Signals: ${guide.signals.join(', ')}",
      "Next: ${guide.nextSteps.join(' • ')}",
    ];
    return lines.join("\n");
  }

  String _themes() {
    final kws = mmco.topKeywords.isEmpty ? ["getting started"] : mmco.topKeywords;
    return "Your current themes: ${kws.join(', ')}.";
  }

  String _streak() {
    return mmco.streakDays > 0
        ? "Streak: ${mmco.streakDays} day(s). Keep going."
        : "No active streak yet. Want a gentle daily nudge?";
  }

  String _recent() {
    if (mmco.recentEntries.isEmpty) {
      return "No journal entries yet. Try a 60-second starter: \"Today I'm curious about...\"";
    }
    // Show up to 3 for compactness; tiny models do better with less text.
    final rows = mmco.recentEntries.take(3).map((e) {
      final date = e.createdAt; // client can humanize later
      final tagLine = e.tags.isEmpty ? "" : "  [${e.tags.take(3).join(', ')}]";
      final phase = e.phase == null ? "" : " (${e.phase})";
      return "- ${date}${phase}${tagLine}\n  ${e.text}";
    }).join("\n");
    return "Recent entries:\n$rows";
  }

  String _help() => "You can ask: \"What phase am I in?\", \"Why spiral?\", \"Show my themes\", \"How many days in my streak?\", \"When was my last entry?\", \"Show recent entries\".";
}

// ------------------------------
// PROVIDER (cache + convenience getters)
// ------------------------------

class MiraBasicsProvider {
  final JournalRepository journalRepo;
  final MemoryRepo memoryRepo;
  final SettingsRepo settings;

  MMCO? _mmco;

  MiraBasicsProvider({
    required this.journalRepo,
    required this.memoryRepo,
    required this.settings,
  });

  MMCO? get mmco => _mmco;

  Future<void> refresh() async {
    final builder = MiraBasics(journalRepo, memoryRepo, settings);
    _mmco = await builder.build();
  }

  // convenience
  String? get phase => _mmco?.currentPhase;
  List<String> get themes => _mmco?.topKeywords ?? const [];
  String? get geometry => _mmco?.phaseGeometry;
  int get streak => _mmco?.streakDays ?? 0;
  bool get hasEntries => (_mmco?.recentEntryCount ?? 0) > 0;
}
