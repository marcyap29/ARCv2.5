// Crossroads: Hive storage for DecisionCapture and DecisionOutcomePrompt.

import 'package:hive/hive.dart';
import '../models/decision_capture.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';

const String decisionCapturesBoxName = 'decision_captures';
const String decisionOutcomePromptsBoxName = 'decision_outcome_prompts';

/// Manual Hive TypeAdapter for DecisionCapture (typeId 118).
class DecisionCaptureAdapter extends TypeAdapter<DecisionCapture> {
  @override
  final int typeId = 118;

  @override
  DecisionCapture read(BinaryReader reader) {
    final id = reader.read() as String;
    final capturedAt = reader.read() as DateTime;
    final phaseAtCapture = PhaseLabel.values[reader.read() as int];
    final sentinelScoreAtCapture = reader.read() as double;
    final decisionStatement = reader.read() as String;
    final lifeContext = reader.read() as String;
    final optionsConsidered = reader.read() as String;
    final successMarker = reader.read() as String;
    final outcomeLog = reader.read() as String?;
    final outcomeLoggedAt = reader.read() as DateTime?;
    final phaseAtOutcomeIdx = reader.read() as int;
    final phaseAtOutcome = phaseAtOutcomeIdx < 0 ? null : PhaseLabel.values[phaseAtOutcomeIdx];
    final linkedJournalEntryId = reader.read() as String?;
    final includedInAggregation = reader.read() as bool;
    final triggerConfidence = reader.read() as double;
    final triggerPhrase = DecisionPhraseCategory.values[reader.read() as int];
    final userInitiated = reader.read() as bool;
    return DecisionCapture(
      id: id,
      capturedAt: capturedAt,
      phaseAtCapture: phaseAtCapture,
      sentinelScoreAtCapture: sentinelScoreAtCapture,
      decisionStatement: decisionStatement,
      lifeContext: lifeContext,
      optionsConsidered: optionsConsidered,
      successMarker: successMarker,
      outcomeLog: outcomeLog,
      outcomeLoggedAt: outcomeLoggedAt,
      phaseAtOutcome: phaseAtOutcome,
      linkedJournalEntryId: linkedJournalEntryId,
      includedInAggregation: includedInAggregation,
      triggerConfidence: triggerConfidence,
      triggerPhrase: triggerPhrase,
      userInitiated: userInitiated,
    );
  }

  @override
  void write(BinaryWriter writer, DecisionCapture obj) {
    writer
      ..write(obj.id)
      ..write(obj.capturedAt)
      ..write(obj.phaseAtCapture.index)
      ..write(obj.sentinelScoreAtCapture)
      ..write(obj.decisionStatement)
      ..write(obj.lifeContext)
      ..write(obj.optionsConsidered)
      ..write(obj.successMarker)
      ..write(obj.outcomeLog)
      ..write(obj.outcomeLoggedAt)
      ..write(obj.phaseAtOutcome == null ? -1 : obj.phaseAtOutcome!.index)
      ..write(obj.linkedJournalEntryId)
      ..write(obj.includedInAggregation)
      ..write(obj.triggerConfidence)
      ..write(obj.triggerPhrase.index)
      ..write(obj.userInitiated);
  }
}

/// Manual Hive TypeAdapter for DecisionOutcomePrompt (typeId 119).
class DecisionOutcomePromptAdapter extends TypeAdapter<DecisionOutcomePrompt> {
  @override
  final int typeId = 119;

  @override
  DecisionOutcomePrompt read(BinaryReader reader) {
    return DecisionOutcomePrompt(
      decisionCaptureId: reader.read() as String,
      scheduledFor: reader.read() as DateTime,
      hasBeenSurfaced: reader.read() as bool,
      surfacedAt: reader.read() as DateTime?,
      completed: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DecisionOutcomePrompt obj) {
    writer
      ..write(obj.decisionCaptureId)
      ..write(obj.scheduledFor)
      ..write(obj.hasBeenSurfaced)
      ..write(obj.surfacedAt)
      ..write(obj.completed);
  }
}

/// Repository for DecisionCapture (Hive box: decision_captures).
class DecisionCaptureRepository {
  Box<DecisionCapture>? _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized && _box != null && _box!.isOpen) return;
    if (!Hive.isAdapterRegistered(118)) return;
    _box = await Hive.openBox<DecisionCapture>(decisionCapturesBoxName);
    _initialized = true;
  }

  Future<void> _ensureBox() async {
    if (!_initialized || _box == null || !_box!.isOpen) await initialize();
  }

  Future<void> save(DecisionCapture capture) async {
    await _ensureBox();
    if (_box == null) return;
    await _box!.put(capture.id, capture);
  }

  Future<DecisionCapture?> getById(String id) async {
    await _ensureBox();
    return _box?.get(id);
  }

  Future<List<DecisionCapture>> getAll() async {
    await _ensureBox();
    if (_box == null) return [];
    return _box!.values.toList()..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }

  Future<List<DecisionCapture>> getCapturesAfter(DateTime after) async {
    await _ensureBox();
    if (_box == null) return [];
    return _box!.values.where((c) => c.capturedAt.isAfter(after)).toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  }

  Future<void> update(DecisionCapture capture) async {
    await _ensureBox();
    if (_box == null) return;
    await _box!.put(capture.id, capture);
  }

  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _initialized = false;
    }
  }
}

/// Repository for DecisionOutcomePrompt (Hive box: decision_outcome_prompts).
/// Key: decisionCaptureId (one prompt per capture).
class DecisionOutcomePromptRepository {
  Box<DecisionOutcomePrompt>? _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized && _box != null && _box!.isOpen) return;
    if (!Hive.isAdapterRegistered(119)) return;
    _box = await Hive.openBox<DecisionOutcomePrompt>(decisionOutcomePromptsBoxName);
    _initialized = true;
  }

  Future<void> _ensureBox() async {
    if (!_initialized || _box == null || !_box!.isOpen) await initialize();
  }

  Future<void> save(DecisionOutcomePrompt prompt) async {
    await _ensureBox();
    if (_box == null) return;
    await _box!.put(prompt.decisionCaptureId, prompt);
  }

  Future<DecisionOutcomePrompt?> getByCaptureId(String decisionCaptureId) async {
    await _ensureBox();
    return _box?.get(decisionCaptureId);
  }

  Future<List<DecisionOutcomePrompt>> getDuePrompts(DateTime now) async {
    await _ensureBox();
    if (_box == null) return [];
    return _box!.values
        .where((p) => !p.completed && (p.scheduledFor.isBefore(now) || !p.scheduledFor.isAfter(now)))
        .toList();
  }

  Future<List<DecisionOutcomePrompt>> getAll() async {
    await _ensureBox();
    if (_box == null) return [];
    return _box!.values.toList();
  }

  Future<void> update(DecisionOutcomePrompt prompt) async {
    await _ensureBox();
    if (_box == null) return;
    await _box!.put(prompt.decisionCaptureId, prompt);
  }

  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _initialized = false;
    }
  }
}

/// Pending outcome prompt to surface at next conversation start (one per user).
const String crossroadsPendingOutcomeBoxName = 'crossroads_pending_outcome';

/// Store/retrieve the decision capture ID that should be surfaced as outcome prompt at next conversation start.
class PendingOutcomeStore {
  static Box<String>? _box;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized && _box != null && _box!.isOpen) return;
    _box = await Hive.openBox<String>(crossroadsPendingOutcomeBoxName);
    _initialized = true;
  }

  static Future<String?> getPendingCaptureId(String userId) async {
    await initialize();
    return _box?.get(userId);
  }

  static Future<void> setPending(String userId, String decisionCaptureId) async {
    await initialize();
    await _box?.put(userId, decisionCaptureId);
  }

  static Future<void> clearPending(String userId) async {
    await initialize();
    await _box?.delete(userId);
  }
}
