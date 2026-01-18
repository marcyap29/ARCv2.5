/// Smart Endpoint Detector
/// 
/// Multi-signal endpoint detection for natural voice interaction
/// - Phase-adaptive silence thresholds
/// - Linguistic completeness detection
/// - Filler word handling
/// - Visual commitment window
/// - User override support (tap to force end, speak to cancel)

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../models/phase_models.dart';
import 'linguistic_analyzer.dart';
import 'filler_word_handler.dart';

/// Endpoint detection state
enum EndpointState {
  listening,           // Normal listening (0-0.5s silence)
  showingCommitment,   // Inner ring contracting (0.5-1.5s)
  accelerating,        // Shimmer intensifying (1.5s+)
  committingWindow,    // Final 0.5s window before commit
  committed,           // Endpoint detected, finalizing
}

/// Commitment level for visualization
class CommitmentLevel {
  final double level; // 0.0 (no commitment) to 1.0 (about to commit)
  final EndpointState state;
  final Duration silenceDuration;
  
  const CommitmentLevel({
    required this.level,
    required this.state,
    required this.silenceDuration,
  });
}

/// Callback types
typedef OnEndpointDetected = void Function();
typedef OnCommitmentChanged = void Function(CommitmentLevel commitment);
typedef OnStateChanged = void Function(EndpointState state);

/// Smart Endpoint Detector
/// 
/// Implements sophisticated endpoint detection with multiple signals:
/// 1. Phase-adaptive silence thresholds
/// 2. Linguistic completeness analysis
/// 3. Filler word grace periods
/// 4. Visual commitment countdown
/// 5. User override (tap/resume)
class SmartEndpointDetector {
  final LinguisticAnalyzer _linguisticAnalyzer = LinguisticAnalyzer();
  final FillerWordHandler _fillerHandler = FillerWordHandler();
  
  PhaseLabel _currentPhase = PhaseLabel.discovery;
  EndpointState _state = EndpointState.listening;
  
  DateTime? _lastAudioTime;
  Duration _silenceDuration = Duration.zero;
  Timer? _silenceTimer;
  Timer? _commitTimer;
  
  String _currentTranscript = '';
  bool _userRequestedEnd = false;
  
  // Callbacks
  OnEndpointDetected? onEndpointDetected;
  OnCommitmentChanged? onCommitmentChanged;
  OnStateChanged? onStateChanged;
  
  EndpointState get state => _state;
  Duration get silenceDuration => _silenceDuration;
  PhaseLabel get currentPhase => _currentPhase;
  
  /// Update current phase (affects silence threshold)
  void updatePhase(PhaseLabel phase) {
    _currentPhase = phase;
    debugPrint('EndpointDetector: Phase updated to ${phase.name}');
  }
  
  /// Get phase-adaptive silence threshold
  Duration getSilenceThreshold(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.recovery:
        return const Duration(seconds: 3, milliseconds: 500);
      case PhaseLabel.transition:
        return const Duration(seconds: 2, milliseconds: 500);
      case PhaseLabel.discovery:
        return const Duration(seconds: 2);
      case PhaseLabel.expansion:
        return const Duration(seconds: 1, milliseconds: 500);
      case PhaseLabel.consolidation:
        return const Duration(seconds: 2);
      case PhaseLabel.breakthrough:
        return const Duration(seconds: 1, milliseconds: 500);
    }
  }
  
  /// Process audio signal (call when audio is detected)
  void onAudioDetected() {
    _lastAudioTime = DateTime.now();
    _silenceDuration = Duration.zero;
    
    // Cancel any pending commit
    _cancelCommitment();
    
    // Reset to listening state
    if (_state != EndpointState.listening) {
      _updateState(EndpointState.listening);
    }
  }
  
  /// Process transcript update
  void onTranscriptUpdate(String transcript) {
    _currentTranscript = transcript;
    
    // Check for filler words at the end
    final words = transcript.trim().split(' ');
    if (words.isNotEmpty) {
      final lastWord = words.last.toLowerCase();
      
      if (_fillerHandler.isFillerWord(lastWord)) {
        // Add grace period for filler word
        _addFillerGracePeriod();
      }
    }
  }
  
  /// Process silence (call periodically when no audio)
  void onSilenceDetected() {
    if (_lastAudioTime == null) {
      _lastAudioTime = DateTime.now();
      return;
    }
    
    _silenceDuration = DateTime.now().difference(_lastAudioTime!);
    final threshold = getSilenceThreshold(_currentPhase);
    
    // Calculate commitment level
    final commitmentLevel = (_silenceDuration.inMilliseconds / threshold.inMilliseconds).clamp(0.0, 1.0);
    
    // Determine state based on silence duration
    if (_silenceDuration < const Duration(milliseconds: 500)) {
      // 0-0.5s: Normal listening
      if (_state != EndpointState.listening) {
        _updateState(EndpointState.listening);
      }
    } else if (_silenceDuration < const Duration(milliseconds: 1500)) {
      // 0.5-1.5s: Show commitment ring
      if (_state != EndpointState.showingCommitment) {
        _updateState(EndpointState.showingCommitment);
      }
    } else if (_silenceDuration < threshold) {
      // 1.5s-threshold: Accelerate shimmer
      if (_state != EndpointState.accelerating) {
        _updateState(EndpointState.accelerating);
      }
    } else {
      // Threshold met: Check linguistic completeness
      _checkEndpoint();
    }
    
    // Emit commitment level for visualization
    final commitment = CommitmentLevel(
      level: commitmentLevel,
      state: _state,
      silenceDuration: _silenceDuration,
    );
    onCommitmentChanged?.call(commitment);
  }
  
  /// Check if we should commit the endpoint
  void _checkEndpoint() {
    if (_state == EndpointState.committingWindow || _state == EndpointState.committed) {
      return; // Already committing
    }
    
    // Analyze linguistic completeness
    final completeness = _linguisticAnalyzer.analyzeCompleteness(_currentTranscript);
    
    if (completeness == CompletionConfidence.definitelyComplete) {
      // High confidence - shorter commit window
      _startCommitWindow(const Duration(milliseconds: 300));
    } else if (completeness == CompletionConfidence.definitelyIncomplete) {
      // They're not done - extend threshold
      _extendThreshold(const Duration(seconds: 1));
    } else {
      // Uncertain - use default commit window
      _startCommitWindow(const Duration(milliseconds: 500));
    }
  }
  
  /// Start commitment window with countdown
  void _startCommitWindow(Duration windowDuration) {
    if (_state == EndpointState.committingWindow) return;
    
    _updateState(EndpointState.committingWindow);
    debugPrint('EndpointDetector: Starting commit window (${windowDuration.inMilliseconds}ms)');
    
    // Start commit timer
    _commitTimer?.cancel();
    _commitTimer = Timer(windowDuration, () {
      if (_state == EndpointState.committingWindow) {
        _commitEndpoint();
      }
    });
  }
  
  /// Commit the endpoint
  void _commitEndpoint() {
    debugPrint('EndpointDetector: Endpoint committed');
    _updateState(EndpointState.committed);
    _silenceTimer?.cancel();
    _commitTimer?.cancel();
    
    onEndpointDetected?.call();
  }
  
  /// Cancel commitment (user started speaking again)
  void _cancelCommitment() {
    if (_state == EndpointState.committingWindow || _state == EndpointState.accelerating || _state == EndpointState.showingCommitment) {
      debugPrint('EndpointDetector: Commitment cancelled');
      _commitTimer?.cancel();
      _commitTimer = null;
      _updateState(EndpointState.listening);
    }
  }
  
  /// Extend silence threshold (when we detect incomplete speech)
  void _extendThreshold(Duration extension) {
    _lastAudioTime = _lastAudioTime?.add(extension);
    debugPrint('EndpointDetector: Threshold extended by ${extension.inMilliseconds}ms');
  }
  
  /// Add grace period for filler word
  void _addFillerGracePeriod() {
    final gracePeriod = _fillerHandler.getGracePeriod();
    _lastAudioTime = _lastAudioTime?.add(gracePeriod);
    debugPrint('EndpointDetector: Grace period added (${gracePeriod.inMilliseconds}ms)');
  }
  
  /// User tapped to force end
  void onUserTap() {
    debugPrint('EndpointDetector: User forced end');
    _userRequestedEnd = true;
    _commitEndpoint();
  }
  
  /// User started speaking again during commit window
  void onUserResume() {
    debugPrint('EndpointDetector: User resumed speaking');
    _cancelCommitment();
    onAudioDetected();
  }
  
  /// Update state and notify
  void _updateState(EndpointState newState) {
    if (_state == newState) return;
    
    _state = newState;
    onStateChanged?.call(newState);
    debugPrint('EndpointDetector: State changed to ${newState.name}');
  }
  
  /// Reset detector for new turn
  void reset() {
    _lastAudioTime = null;
    _silenceDuration = Duration.zero;
    _currentTranscript = '';
    _userRequestedEnd = false;
    _silenceTimer?.cancel();
    _commitTimer?.cancel();
    _silenceTimer = null;
    _commitTimer = null;
    _state = EndpointState.listening;
    
    debugPrint('EndpointDetector: Reset');
  }
  
  /// Start monitoring
  void start() {
    reset();
    
    // Start periodic silence check
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_lastAudioTime != null) {
        onSilenceDetected();
      }
    });
    
    debugPrint('EndpointDetector: Started monitoring');
  }
  
  /// Stop monitoring
  void stop() {
    _silenceTimer?.cancel();
    _commitTimer?.cancel();
    _silenceTimer = null;
    _commitTimer = null;
    
    debugPrint('EndpointDetector: Stopped monitoring');
  }
  
  /// Dispose resources
  void dispose() {
    stop();
  }
}
