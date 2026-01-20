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
import '../services/voice_usage_service.dart';
import '../models/voice_session.dart';
import '../storage/voice_timeline_storage.dart';
import '../../../../models/phase_models.dart';
import '../../../../arc/internal/mira/journal_repository.dart';
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
  
  // Voice usage tracking
  final VoiceUsageService _usageService = VoiceUsageService.instance;
  DateTime? _sessionStartTime;
  VoiceUsageStats? _usageStats;
  
  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    _initialize();
  }
  
  void _setupCallbacks() {
    widget.sessionService.onStateChanged = (state) {
      if (!mounted) return;
      _previousState = _state;
      setState(() => _state = state);
      _handleStateChangeHaptics(state);
    };
    
    widget.sessionService.onTranscriptUpdate = (transcript) {
      if (!mounted) return;
      setState(() => _currentTranscript = transcript);
    };
    
    widget.sessionService.onLumaraResponse = (response) {
      if (!mounted) return;
      // Haptic feedback when LUMARA starts responding
      HapticFeedback.lightImpact();
      setState(() {
        _lastLumaraResponse = response;
        _currentTranscript = ''; // Clear transcript after LUMARA responds
        _isFirstTurn = false;
      });
    };
    
    widget.sessionService.onTurnComplete = (turn) {
      if (!mounted) return;
      setState(() => _turnCount++);
    };
    
    widget.sessionService.onError = (error) {
      if (!mounted) return;
      HapticFeedback.heavyImpact(); // Error feedback
      _showError(error);
    };
    
    widget.sessionService.onSessionComplete = (session) {
      if (!mounted) return;
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
    // Check voice usage limits first
    await _usageService.initialize();
    final usageCheck = await _usageService.canUseVoice();
    
    if (!mounted) return;
    
    setState(() {
      _usageStats = usageCheck.stats;
    });
    
    if (!usageCheck.canUse) {
      // User has exceeded their monthly limit
      _showUsageLimitExceeded(usageCheck.message ?? 'Monthly voice limit reached');
      return;
    }
    
    final success = await widget.sessionService.initialize();
    if (success && mounted) {
      // Don't auto-start session - wait for user to tap sigil
      // State will be idle, user taps to begin
      _sessionStartTime = DateTime.now();
    }
  }
  
  void _showUsageLimitExceeded(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly Limit Reached'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Close voice mode too
            },
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to subscription screen
              Navigator.of(context).pop();
            },
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
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
    // Colors matching the rest of the app (see calendar_week_timeline.dart)
    switch (phase) {
      case PhaseLabel.discovery:
        return const Color(0xFF7C3AED); // Purple
      case PhaseLabel.expansion:
        return const Color(0xFF059669); // Green
      case PhaseLabel.transition:
        return const Color(0xFFD97706); // Orange
      case PhaseLabel.consolidation:
        return const Color(0xFF2563EB); // Blue
      case PhaseLabel.recovery:
        return const Color(0xFFDC2626); // Red
      case PhaseLabel.breakthrough:
        return const Color(0xFFFBBF24); // Yellow/Amber
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
    
    // Record voice usage (duration in seconds)
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      await _usageService.recordUsage(duration.inSeconds);
      debugPrint('VoiceModeScreen: Recorded ${duration.inSeconds} seconds of voice usage');
    }
    
    // Save session to timeline
    try {
      final journalRepository = JournalRepository();
      final voiceStorage = VoiceTimelineStorage(journalRepository: journalRepository);
      final entryId = await voiceStorage.saveVoiceSession(session);
      
      debugPrint('VoiceModeScreen: Session saved to timeline (entry ID: $entryId)');
      
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice conversation saved (${session.turnCount} turns)'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('VoiceModeScreen: Error saving session: $e');
      
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving conversation: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    // Call completion callback
    widget.onComplete?.call();
  }
  
  Future<void> _endSession() async {
    debugPrint('VoiceModeScreen: Finish button pressed, ending session...');
    await widget.sessionService.endSession();
    debugPrint('VoiceModeScreen: Session ended');
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
            
            const SizedBox(height: 4),
            
            // Usage indicator (for free users)
            _buildUsageIndicator(),
            
            const SizedBox(height: 8),
            
            // Transcript display (above sigil)
            Expanded(
              flex: 1,
              child: _buildTranscriptDisplay(),
            ),
            
            const SizedBox(height: 8),
            
            // Voice sigil (center)
            _buildVoiceSigil(),
            
            const SizedBox(height: 8),
            
            // LUMARA response display (below sigil)
            Expanded(
              flex: 2,
              child: _buildLumaraResponseDisplay(),
            ),
            
            const SizedBox(height: 12),
            
            // Controls
            _buildControls(),
            
            const SizedBox(height: 12),
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
  
  Widget _buildUsageIndicator() {
    // Don't show for unlimited users
    if (_usageStats == null || _usageStats!.isUnlimited) {
      return const SizedBox.shrink();
    }
    
    final stats = _usageStats!;
    final isWarning = stats.isApproachingLimit;
    final isExceeded = stats.isLimitExceeded;
    
    final color = isExceeded 
        ? Colors.red 
        : (isWarning ? Colors.orange : Colors.white.withOpacity(0.5));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExceeded ? Icons.timer_off : Icons.timer,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isExceeded 
                ? 'Limit reached' 
                : '${stats.minutesRemaining} min left',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTranscriptDisplay() {
    // First turn idle state - no transcript to show, instructions are below sigil
    if (_isFirstTurn && _state == VoiceSessionState.idle) {
      return const SizedBox(); // Instructions are now shown below sigil via VoiceSigilStateLabel
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
              color: const Color(0xFF7C3AED).withOpacity(0.7), // Purple label for LUMARA (same as journal mode)
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lastLumaraResponse,
            style: const TextStyle(
              color: Color(0xFF7C3AED), // Purple text for LUMARA (same as journal mode)
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
            onTap: _handleSigilTap,
            size: 200,
          ),
          
          const SizedBox(height: 16),
          
          // State label with instructions
          VoiceSigilStateLabel(
            state: _mapToSigilState(_state),
            hasConversationStarted: _turnCount > 0,
          ),
        ],
      ),
    );
  }
  
  /// Handle tap on sigil for tap-to-toggle interaction
  void _handleSigilTap() {
    switch (_state) {
      case VoiceSessionState.idle:
        // Tap to start talking
        HapticFeedback.mediumImpact();
        widget.sessionService.startListening();
        break;
        
      case VoiceSessionState.listening:
        // Tap to stop and send to LUMARA
        HapticFeedback.lightImpact();
        widget.sessionService.stopListening();
        break;
        
      case VoiceSessionState.processingTranscript:
      case VoiceSessionState.scrubbing:
      case VoiceSessionState.waitingForLumara:
      case VoiceSessionState.speaking:
        // Can't tap during these states - LUMARA is working
        break;
        
      case VoiceSessionState.initializing:
      case VoiceSessionState.error:
        // Can't interact during these states
        break;
    }
  }
  
  Widget _buildControls() {
    // Finish button should be enabled when:
    // 1. At least one turn has completed (_turnCount > 0)
    // 2. We're in a state where finishing makes sense (idle after turn, or error)
    // 3. NOT during active processing (listening, scrubbing, waitingForLumara, speaking)
    final canFinish = _turnCount > 0 && 
        (_state == VoiceSessionState.idle || _state == VoiceSessionState.error);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Finish button
        OutlinedButton.icon(
          onPressed: canFinish ? _endSession : null,
          icon: const Icon(Icons.check),
          label: const Text('Finish'),
          style: OutlinedButton.styleFrom(
            foregroundColor: canFinish ? Colors.white : Colors.white38,
            side: BorderSide(color: canFinish ? Colors.white : Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
