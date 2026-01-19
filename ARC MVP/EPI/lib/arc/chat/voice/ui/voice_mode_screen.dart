/// Voice Mode Screen
/// 
/// Main UI for voice conversations with LUMARA
/// - Voice sigil at center
/// - Transcript display above
/// - LUMARA response below
/// - Session controls
/// - Turn counter
/// - Phase indicator
/// - Haptic feedback on interactions
/// - Real-time transcript display

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_session_service.dart';
import '../models/voice_session.dart';
import '../../../../models/phase_models.dart';
import 'voice_sigil.dart';
import '../endpoint/smart_endpoint_detector.dart';

/// Voice Mode Screen
class VoiceModeScreen extends StatefulWidget {
  final VoiceSessionService sessionService;
  final VoidCallback? onComplete;
  
  const VoiceModeScreen({
    super.key,
    required this.sessionService,
    this.onComplete,
  });
  
  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen> {
  VoiceSessionState _state = VoiceSessionState.idle;
  VoiceSessionState _previousState = VoiceSessionState.idle;
  String _currentTranscript = '';
  String _lastLumaraResponse = '';
  int _turnCount = 0;
  double _audioLevel = 0.0;
  CommitmentLevel? _commitmentLevel;
  bool _isFirstTurn = true;
  
  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    _initialize();
  }
  
  void _setupCallbacks() {
    widget.sessionService.onStateChanged = (state) {
      _previousState = _state;
      setState(() => _state = state);
      _handleStateChangeHaptics(state);
    };
    
    widget.sessionService.onTranscriptUpdate = (transcript) {
      setState(() => _currentTranscript = transcript);
    };
    
    widget.sessionService.onLumaraResponse = (response) {
      // Haptic feedback when LUMARA starts responding
      HapticFeedback.lightImpact();
      setState(() {
        _lastLumaraResponse = response;
        _currentTranscript = ''; // Clear transcript after LUMARA responds
        _isFirstTurn = false;
      });
    };
    
    widget.sessionService.onTurnComplete = (turn) {
      setState(() => _turnCount++);
    };
    
    widget.sessionService.onError = (error) {
      HapticFeedback.heavyImpact(); // Error feedback
      _showError(error);
    };
    
    widget.sessionService.onSessionComplete = (session) {
      _onSessionComplete(session);
    };
  }
  
  /// Handle haptic feedback based on state transitions
  void _handleStateChangeHaptics(VoiceSessionState newState) {
    // Haptic when starting to listen
    if (newState == VoiceSessionState.listening && 
        _previousState != VoiceSessionState.listening) {
      HapticFeedback.mediumImpact();
    }
    
    // Haptic when processing starts (user released)
    if (newState == VoiceSessionState.processingTranscript && 
        _previousState == VoiceSessionState.listening) {
      HapticFeedback.lightImpact();
    }
    
    // Haptic when LUMARA starts thinking
    if (newState == VoiceSessionState.waitingForLumara) {
      HapticFeedback.selectionClick();
    }
  }
  
  Future<void> _initialize() async {
    final success = await widget.sessionService.initialize();
    if (success && mounted) {
      await widget.sessionService.startSession();
    }
  }
  
  VoiceSigilState _mapToSigilState(VoiceSessionState sessionState) {
    switch (sessionState) {
      case VoiceSessionState.idle:
      case VoiceSessionState.initializing:
        return VoiceSigilState.idle;
      case VoiceSessionState.listening:
        return VoiceSigilState.listening;
      case VoiceSessionState.processingTranscript:
      case VoiceSessionState.scrubbing:
        return VoiceSigilState.commitment;
      case VoiceSessionState.waitingForLumara:
        return VoiceSigilState.thinking;
      case VoiceSessionState.speaking:
        return VoiceSigilState.speaking;
      case VoiceSessionState.error:
        return VoiceSigilState.idle;
    }
  }
  
  Color _getPhaseColor(PhaseLabel phase) {
    switch (phase) {
      case PhaseLabel.recovery:
        return const Color(0xFF7E57C2);
      case PhaseLabel.transition:
        return const Color(0xFFFF9800);
      case PhaseLabel.discovery:
        return const Color(0xFF4CAF50);
      case PhaseLabel.expansion:
        return const Color(0xFF2196F3);
      case PhaseLabel.consolidation:
        return const Color(0xFF9C27B0);
      case PhaseLabel.breakthrough:
        return const Color(0xFFFFD700);
    }
  }
  
  void _showError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  Future<void> _onSessionComplete(VoiceSession session) async {
    if (!mounted) return;
    
    // Show completion message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice session saved (${session.turnCount} turns)'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Call completion callback
    widget.onComplete?.call();
  }
  
  Future<void> _endSession() async {
    await widget.sessionService.endSession();
  }
  
  @override
  void dispose() {
    widget.sessionService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Voice Mode'),
        actions: [
          // Turn counter
          if (_turnCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_turnCount} turn${_turnCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator
            _buildPhaseIndicator(),
            
            const SizedBox(height: 20),
            
            // Transcript display (above sigil)
            Expanded(
              flex: 2,
              child: _buildTranscriptDisplay(),
            ),
            
            const SizedBox(height: 20),
            
            // Voice sigil (center)
            _buildVoiceSigil(),
            
            const SizedBox(height: 20),
            
            // LUMARA response display (below sigil)
            Expanded(
              flex: 2,
              child: _buildLumaraResponseDisplay(),
            ),
            
            const SizedBox(height: 20),
            
            // Controls
            _buildControls(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhaseIndicator() {
    final phase = widget.sessionService.currentPhase;
    final phaseColor = _getPhaseColor(phase);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: phaseColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 12,
            color: phaseColor,
          ),
          const SizedBox(width: 8),
          Text(
            phase.name.toUpperCase(),
            style: TextStyle(
              color: phaseColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTranscriptDisplay() {
    // Show instructions on first turn
    if (_isFirstTurn && _state == VoiceSessionState.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic,
              size: 32,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Hold the sigil to speak',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Release when finished',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // Show listening state with real-time transcript
    if (_state == VoiceSessionState.listening) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // Recording indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Real-time transcript
            if (_currentTranscript.isNotEmpty) ...[
              Text(
                'You:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentTranscript,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                'Listening...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    // Show processing state
    if (_state == VoiceSessionState.processingTranscript || 
        _state == VoiceSessionState.scrubbing ||
        _state == VoiceSessionState.waitingForLumara) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentTranscript.isNotEmpty) ...[
              Text(
                'You said:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _currentTranscript,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    // Default empty state
    if (_currentTranscript.isEmpty) {
      return const SizedBox();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'You:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentTranscript,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLumaraResponseDisplay() {
    if (_lastLumaraResponse.isEmpty) {
      return const SizedBox();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'LUMARA:',
            style: TextStyle(
              color: _getPhaseColor(widget.sessionService.currentPhase).withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lastLumaraResponse,
            style: TextStyle(
              color: _getPhaseColor(widget.sessionService.currentPhase),
              fontSize: 18,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildVoiceSigil() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceSigil(
            state: _mapToSigilState(_state),
            currentPhase: widget.sessionService.currentPhase,
            audioLevel: _audioLevel,
            commitmentLevel: _commitmentLevel,
            onTap: _state == VoiceSessionState.listening 
                ? () => widget.sessionService.endpointDetector.onUserTap()
                : null,
            size: 200,
          ),
          
          const SizedBox(height: 16),
          
          // State label
          VoiceSigilStateLabel(
            state: _mapToSigilState(_state),
            additionalInfo: _state == VoiceSessionState.listening && _commitmentLevel != null
                ? 'Tap to end'
                : null,
          ),
        ],
      ),
    );
  }
  
  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Finish button
        OutlinedButton.icon(
          onPressed: _state != VoiceSessionState.idle ? _endSession : null,
          icon: const Icon(Icons.check),
          label: const Text('Finish'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
