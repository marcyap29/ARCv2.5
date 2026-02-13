// Crossroads: decision capture flow and RIVET trigger handling.

import 'package:my_app/chronicle/storage/layer0_populator.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/crossroads/models/decision_capture.dart';
import 'package:my_app/crossroads/storage/decision_capture_repository.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:uuid/uuid.dart';

/// Step in the four-prompt capture flow
enum CrossroadsCaptureStep {
  none,
  prompt1, // What are you deciding?
  prompt2, // What's going on in your life...
  prompt3, // What are your real options...
  prompt4, // What would make this feel right...
  complete,
}

/// In-memory state for a single capture session (partial or complete)
class CrossroadsCaptureState {
  final String id;
  final DateTime startedAt;
  final PhaseLabel phaseAtCapture;
  final double sentinelScoreAtCapture;
  final double triggerConfidence;
  final DecisionPhraseCategory triggerPhrase;
  final bool userInitiated;
  final String? linkedJournalEntryId;

  String decisionStatement;
  String lifeContext;
  String optionsConsidered;
  String successMarker;
  CrossroadsCaptureStep step;

  CrossroadsCaptureState({
    String? id,
    required this.startedAt,
    required this.phaseAtCapture,
    required this.sentinelScoreAtCapture,
    required this.triggerConfidence,
    required this.triggerPhrase,
    required this.userInitiated,
    this.linkedJournalEntryId,
  })  : id = id ?? const Uuid().v4(),
        decisionStatement = '',
        lifeContext = '',
        optionsConsidered = '',
        successMarker = '',
        step = CrossroadsCaptureStep.prompt1;
}

/// Four-prompt texts (for LUMARA to send)
const String crossroadsPrompt1 = "What are you deciding?";
const String crossroadsPrompt2 =
    "What's going on in your life right now that's making this feel important or difficult?";
const String crossroadsPrompt3 =
    "What are your real options - including the one you're leaning away from?";
const String crossroadsPrompt4 =
    "What would make you feel like this was the right call, looking back?";
const String crossroadsConfirmDone =
    "Got it. I'll remember this moment. I'll check back in with you about it down the road.";

class CrossroadsService {
  final DecisionCaptureRepository _captureRepo = DecisionCaptureRepository();
  final DecisionOutcomePromptRepository _outcomeRepo = DecisionOutcomePromptRepository();
  Layer0Populator? _layer0Populator;
  bool _layer0Initialized = false;

  bool _captureInProgress = false;
  bool _surfacedThisSessionTurn = false;
  CrossroadsCaptureState? _currentState;

  /// Whether the user is currently in the four-prompt flow (guard for not surfacing again).
  bool get isCaptureInProgress => _captureInProgress;

  /// Call when starting the capture flow (user said Yes).
  void setCaptureInProgress(bool value) {
    _captureInProgress = value;
    if (!value) _currentState = null;
  }

  /// Call when a new conversation turn starts (new user message) so we can surface once per turn.
  void clearSurfacedThisTurn() {
    _surfacedThisSessionTurn = false;
  }

  /// Guard: don't surface if user already in active Crossroads capture; don't surface if a decision
  /// was captured in the last 2 hours; don't surface more than once per conversation turn.
  Future<bool> shouldSurfaceCrossroadsPrompt({
    required DecisionTriggerSignal signal,
    required String userId,
  }) async {
    if (_captureInProgress) return false;
    if (_surfacedThisSessionTurn) return false;

    await _captureRepo.initialize();
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    final recent = await _captureRepo.getCapturesAfter(twoHoursAgo);
    if (recent.isNotEmpty) return false;

    _surfacedThisSessionTurn = true;
    return true;
  }

  /// LUMARA's one-sentence confirmation before entering the full capture flow.
  String buildConfirmationPrompt(DecisionTriggerSignal signal) {
    switch (signal.phraseCategory) {
      case DecisionPhraseCategory.activeChoice:
        return "It sounds like you're working through a real decision here. Want to capture it properly so you can look back on this moment clearly?";
      case DecisionPhraseCategory.seekingOpinion:
        return "Before I weigh in - this sounds like a significant choice. Want to capture your thinking first?";
      case DecisionPhraseCategory.actionFraming:
        return "It sounds like you've made a decision. Worth capturing your reasoning while it's fresh?";
      default:
        return "It sounds like you're working through something important. Want to capture this decision properly?";
    }
  }

  /// Start a new capture (after user confirmed, or user-initiated). Returns state to drive the flow.
  CrossroadsCaptureState startCapture({
    required PhaseLabel phaseAtCapture,
    required double sentinelScoreAtCapture,
    required double triggerConfidence,
    required DecisionPhraseCategory triggerPhrase,
    required bool userInitiated,
    String? linkedJournalEntryId,
  }) {
    _captureInProgress = true;
    _currentState = CrossroadsCaptureState(
      startedAt: DateTime.now(),
      phaseAtCapture: phaseAtCapture,
      sentinelScoreAtCapture: sentinelScoreAtCapture,
      triggerConfidence: triggerConfidence,
      triggerPhrase: triggerPhrase,
      userInitiated: userInitiated,
      linkedJournalEntryId: linkedJournalEntryId,
    );
    return _currentState!;
  }

  /// Get current in-progress state (if any).
  CrossroadsCaptureState? get currentState => _currentState;

  /// Advance step and submit answer for the current step. Returns next step (or complete).
  CrossroadsCaptureStep submitStepAnswer(String answer) {
    final state = _currentState;
    if (state == null) return CrossroadsCaptureStep.none;

    switch (state.step) {
      case CrossroadsCaptureStep.prompt1:
        state.decisionStatement = answer.trim();
        state.step = CrossroadsCaptureStep.prompt2;
        return CrossroadsCaptureStep.prompt2;
      case CrossroadsCaptureStep.prompt2:
        state.lifeContext = answer.trim();
        state.step = CrossroadsCaptureStep.prompt3;
        return CrossroadsCaptureStep.prompt3;
      case CrossroadsCaptureStep.prompt3:
        state.optionsConsidered = answer.trim();
        state.step = CrossroadsCaptureStep.prompt4;
        return CrossroadsCaptureStep.prompt4;
      case CrossroadsCaptureStep.prompt4:
        state.successMarker = answer.trim();
        state.step = CrossroadsCaptureStep.complete;
        return CrossroadsCaptureStep.complete;
      default:
        return state.step;
    }
  }

  /// Persist partial capture (e.g. after prompt 2 if user abandons). Saves what we have so far.
  Future<void> savePartialCapture() async {
    final state = _currentState;
    if (state == null) return;
    await _captureRepo.initialize();
    final capture = DecisionCapture(
      id: state.id,
      capturedAt: state.startedAt,
      phaseAtCapture: state.phaseAtCapture,
      sentinelScoreAtCapture: state.sentinelScoreAtCapture,
      decisionStatement: state.decisionStatement,
      lifeContext: state.lifeContext,
      optionsConsidered: state.optionsConsidered,
      successMarker: state.successMarker,
      linkedJournalEntryId: state.linkedJournalEntryId,
      includedInAggregation: false,
      triggerConfidence: state.triggerConfidence,
      triggerPhrase: state.triggerPhrase,
      userInitiated: state.userInitiated,
    );
    await _captureRepo.save(capture);
    setCaptureInProgress(false);
  }

  /// Save full capture after all four prompts, schedule outcome prompt, trigger Layer 0, and return the saved capture.
  Future<DecisionCapture> saveCompleteCaptureAndScheduleOutcome({String? userId}) async {
    final state = _currentState;
    if (state == null || state.step != CrossroadsCaptureStep.complete) {
      throw StateError('Crossroads: no complete capture state');
    }
    await _captureRepo.initialize();
    await _outcomeRepo.initialize();

    final capture = DecisionCapture(
      id: state.id,
      capturedAt: state.startedAt,
      phaseAtCapture: state.phaseAtCapture,
      sentinelScoreAtCapture: state.sentinelScoreAtCapture,
      decisionStatement: state.decisionStatement,
      lifeContext: state.lifeContext,
      optionsConsidered: state.optionsConsidered,
      successMarker: state.successMarker,
      linkedJournalEntryId: state.linkedJournalEntryId,
      includedInAggregation: true,
      triggerConfidence: state.triggerConfidence,
      triggerPhrase: state.triggerPhrase,
      userInitiated: state.userInitiated,
    );
    await _captureRepo.save(capture);

    final scheduledFor = _defaultOutcomeSchedule(capture);
    final outcomePrompt = DecisionOutcomePrompt(
      decisionCaptureId: capture.id,
      scheduledFor: scheduledFor,
    );
    await _outcomeRepo.save(outcomePrompt);

    await _populateLayer0IfEnabled(capture, userId ?? 'default_user');

    setCaptureInProgress(false);
    return capture;
  }

  Future<void> _populateLayer0IfEnabled(DecisionCapture capture, String userId) async {
    try {
      if (!_layer0Initialized) {
        final repo = Layer0Repository();
        await repo.initialize();
        _layer0Populator = Layer0Populator(repo);
        _layer0Initialized = true;
      }
      if (_layer0Populator != null) {
        await _layer0Populator!.populateFromDecisionCapture(
          capture: capture,
          userId: userId,
        );
      }
    } catch (e) {
      print('⚠️ CrossroadsService: Layer 0 population failed (non-fatal): $e');
    }
  }

  /// Default: 4 months from capture. Can be refined by content later.
  DateTime _defaultOutcomeSchedule(DecisionCapture capture) {
    return DateTime(
      capture.capturedAt.year,
      capture.capturedAt.month + 4,
      capture.capturedAt.day,
      capture.capturedAt.hour,
      capture.capturedAt.minute,
    );
  }

  /// Get the next prompt text for the current step (for LUMARA to send).
  String? getPromptTextForCurrentStep() {
    final state = _currentState;
    if (state == null) return null;
    switch (state.step) {
      case CrossroadsCaptureStep.prompt1:
        return crossroadsPrompt1;
      case CrossroadsCaptureStep.prompt2:
        return crossroadsPrompt2;
      case CrossroadsCaptureStep.prompt3:
        return crossroadsPrompt3;
      case CrossroadsCaptureStep.prompt4:
        return crossroadsPrompt4;
      default:
        return null;
    }
  }

  Future<DecisionCaptureRepository> get captureRepo async {
    await _captureRepo.initialize();
    return _captureRepo;
  }

  Future<DecisionOutcomePromptRepository> get outcomeRepo async {
    await _outcomeRepo.initialize();
    return _outcomeRepo;
  }

  /// Called from nightly VeilChronicleScheduler: set pending outcome prompt for due decisions.
  Future<void> checkDueOutcomePrompts(String userId) async {
    await _outcomeRepo.initialize();
    final due = await _outcomeRepo.getDuePrompts(DateTime.now());
    if (due.isEmpty) return;
    await PendingOutcomeStore.setPending(userId, due.first.decisionCaptureId);
  }

  /// Build revisitation prompt for a capture (for next conversation start).
  String buildRevisitationPrompt(DecisionCapture capture) {
    final statement = capture.decisionStatement.length > 80
        ? '${capture.decisionStatement.substring(0, 80)}...'
        : capture.decisionStatement;
    return "A while back you were deciding $statement. You said you'd feel good about it if ${capture.successMarker}. How did that turn out?";
  }

  /// Log outcome for a capture and mark prompt completed. Updates Layer 0 decision entry with outcome.
  Future<void> logOutcome({
    required String decisionCaptureId,
    required String outcomeLog,
    PhaseLabel? phaseAtOutcome,
    String userId = 'default_user',
  }) async {
    await _captureRepo.initialize();
    await _outcomeRepo.initialize();
    final capture = await _captureRepo.getById(decisionCaptureId);
    if (capture == null) return;
    final updated = capture.copyWith(
      outcomeLog: outcomeLog,
      outcomeLoggedAt: DateTime.now(),
      phaseAtOutcome: phaseAtOutcome,
    );
    await _captureRepo.update(updated);
    final prompt = await _outcomeRepo.getByCaptureId(decisionCaptureId);
    if (prompt != null) {
      await _outcomeRepo.update(prompt.copyWith(completed: true));
    }
    await PendingOutcomeStore.clearPending(userId);
    await _updateLayer0WithOutcome(updated, userId);
  }

  Future<void> _updateLayer0WithOutcome(DecisionCapture capture, String userId) async {
    try {
      if (!_layer0Initialized) {
        final repo = Layer0Repository();
        await repo.initialize();
        _layer0Populator = Layer0Populator(repo);
        _layer0Initialized = true;
      }
      if (_layer0Populator != null) {
        await _layer0Populator!.populateFromDecisionCapture(
          capture: capture,
          userId: userId,
        );
      }
    } catch (e) {
      print('⚠️ CrossroadsService: Layer 0 outcome update failed (non-fatal): $e');
    }
  }
}
