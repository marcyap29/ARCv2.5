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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_session_service.dart';
import '../services/voice_usage_service.dart';
import '../models/voice_session.dart';
import '../storage/voice_timeline_storage.dart';
import '../../../../models/engagement_discipline.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../arc/internal/mira/journal_repository.dart';
import '../../../../models/journal_entry_model.dart';
import '../../../../arc/voice_notes/models/voice_note.dart' hide VoiceProcessingChoice;
import '../../../../arc/voice_notes/repositories/voice_note_repository.dart';
import 'voice_sigil.dart';
import '../endpoint/smart_endpoint_detector.dart';

// Re-export VoiceProcessingChoice for use in callbacks
export '../services/voice_session_service.dart' show VoiceProcessingChoice;

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

  /// User-selected engagement mode override (null = auto from transcript)
  EngagementMode? _voiceEngagementOverride;
  
  /// Whether user has committed to a voice conversation with LUMARA
  /// The Finish button only appears after this is true
  bool _hasChosenVoiceConversation = false;

  // Transition: delay showing "Recording" by 1s after tap
  bool _showRecordingUI = false;

  /// Sentinel for "Default" (auto from transcript) in engagement menu
  static const Object _voiceEngagementAuto = Object();

  // Voice usage tracking
  final VoiceUsageService _usageService = VoiceUsageService.instance;
  DateTime? _sessionStartTime;
  VoiceUsageStats? _usageStats;

  /// Chat bubbles built from completed turns (user + LUMARA per turn)
  final List<_VoiceChatMessage> _chatMessages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    _initialize();
  }
  
  void _setupCallbacks() {
    widget.sessionService.onBackendStatusMessage = (message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    };

    widget.sessionService.onStateChanged = (state) {
      if (!mounted) return;
      _previousState = _state;
      setState(() {
        _state = state;
        if (state != VoiceSessionState.listening) {
          _showRecordingUI = false;
        }
      });
      _handleStateChangeHaptics(state);
      // 1s transition: show "Recording" UI after 1 second in listening state
      if (state == VoiceSessionState.listening) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _state == VoiceSessionState.listening) {
            setState(() => _showRecordingUI = true);
          }
        });
      }
    };
    
    widget.sessionService.onTranscriptUpdate = (transcript) {
      if (!mounted) return;
      setState(() => _currentTranscript = transcript);
      _scrollToBottom();
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
      setState(() {
        _turnCount++;
        _chatMessages.add(_VoiceChatMessage(isUser: true, text: turn.userText));
        _chatMessages.add(_VoiceChatMessage(isUser: false, text: turn.lumaraResponse));
      });
      _scrollToBottom();
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
    
    // Progressive Voice Capture: Request processing choice from UI
    widget.sessionService.onRequestProcessingChoice = (transcription) async {
      if (!mounted) return VoiceProcessingChoice.talkWithLumara;
      
      // Show modal and get user's choice
      final choice = await _showProcessingChoiceModal(transcription);
      
      // If user chose to talk with LUMARA, enable the Finish button
      if (choice == VoiceProcessingChoice.talkWithLumara) {
        setState(() {
          _hasChosenVoiceConversation = true;
        });
      }
      
      return choice ?? VoiceProcessingChoice.cancel; // Dismiss (tap outside / slide down) = cancel
    };
    
    // Handle saving as voice note
    widget.sessionService.onSaveAsVoiceNote = (transcription) async {
      await _saveAsVoiceNote(transcription);
    };
    
    // Handle add to timeline (create journal entry from transcription)
    widget.sessionService.onAddToTimeline = (transcription) async {
      await _addTranscriptionToTimeline(transcription);
    };
  }
  
  /// Show modal to let user choose between voice note and LUMARA conversation.
  /// User can cancel by tapping outside or sliding the sheet down.
  Future<VoiceProcessingChoice?> _showProcessingChoiceModal(String transcription) async {
    final choice = await showModalBottomSheet<VoiceProcessingChoice>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoiceProcessingModalWidget(
        transcription: transcription,
        autoSelectDelay: const Duration(seconds: 2),
      ),
    );
    return choice;
  }
  
  /// Save transcription as a voice note (persisted to Hive so it shows in Voice Notes tab)
  Future<void> _saveAsVoiceNote(String transcription) async {
    if (transcription.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech to save. Try speaking, then tap the orb to finish.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onComplete?.call();
      }
      return;
    }
    try {
      final note = VoiceNote.create(transcription: transcription.trim());
      final box = Hive.isBoxOpen(VoiceNoteRepository.boxName)
          ? Hive.box<VoiceNote>(VoiceNoteRepository.boxName)
          : await Hive.openBox<VoiceNote>(VoiceNoteRepository.boxName);
      final repository = VoiceNoteRepository(box);
      await repository.save(note);
      debugPrint('VoiceModeScreen: Saved voice note to Hive: ${note.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice note saved to Voice Notes'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        widget.onComplete?.call();
      }
    } catch (e) {
      debugPrint('VoiceModeScreen: Error saving voice note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save voice note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Add transcription as a journal entry on the normal timeline (Conversations)
  Future<void> _addTranscriptionToTimeline(String transcription) async {
    if (transcription.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No speech to add. Try speaking, then tap the orb to finish.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onComplete?.call();
      }
      return;
    }
    try {
      final journalRepository = JournalRepository();
      final entryId = const Uuid().v4();
      final now = DateTime.now();
      final title = transcription.length > 50
          ? '${transcription.substring(0, 47).trim()}...'
          : transcription.trim();
      final entry = JournalEntry(
        id: entryId,
        title: title.isEmpty ? 'Voice note' : title,
        content: transcription.trim(),
        createdAt: now,
        updatedAt: now,
        tags: ['voice', 'timeline'],
        mood: '',
        metadata: {'fromVoiceNote': true},
      );
      await journalRepository.createJournalEntry(entry);
      debugPrint('VoiceModeScreen: Added to timeline (entry ID: $entryId)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to Conversations timeline'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        widget.onComplete?.call();
      }
    } catch (e) {
      debugPrint('VoiceModeScreen: Error adding to timeline: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to timeline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      _sessionStartTime = DateTime.now();
      _syncEngagementOverrideToService();
    }
  }

  void _syncEngagementOverrideToService() {
    widget.sessionService.setEngagementModeOverride(_voiceEngagementOverride);
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
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
        child: Stack(
          children: [
            // Background: voice sigil + state label (semi-transparent so chat is readable)
            Positioned.fill(
              child: Center(
                child: _buildVoiceSigilBackground(),
              ),
            ),
            // Foreground: scrolling chat + controls
            Column(
              children: [
                _buildEngagementModeDropdown(),
                const SizedBox(height: 4),
                _buildUsageIndicator(),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildChatList(),
                ),
                const SizedBox(height: 12),
                _buildControls(),
                const SizedBox(height: 12),
              ],
            ),
            // Tap-to-talk: transparent overlay over sigil area
            Positioned.fill(
              child: Center(
                child: IgnorePointer(
                  ignoring: _state != VoiceSessionState.idle && _state != VoiceSessionState.listening,
                  child: GestureDetector(
                    onTap: _handleSigilTap,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(width: 220, height: 220),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatList() {
    const lumaraPurple = Color(0xFF7C3AED);
    final hasPendingUser = _currentTranscript.trim().isNotEmpty;
    final showPendingLumara = (_state == VoiceSessionState.waitingForLumara ||
            _state == VoiceSessionState.speaking) &&
        _lastLumaraResponse.trim().isNotEmpty;
    var itemCount = _chatMessages.length;
    if (hasPendingUser) itemCount += 1;
    if (showPendingLumara) itemCount += 1;

    if (itemCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _isFirstTurn && _state == VoiceSessionState.idle
                ? 'Tap the orb to start speaking.\nYour conversation will appear here.'
                : 'Say something and tap the orb when done.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < _chatMessages.length) {
          final msg = _chatMessages[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildChatBubble(
              isUser: msg.isUser,
              text: msg.text,
              lumaraPurple: lumaraPurple,
            ),
          );
        }
        if (hasPendingUser && index == _chatMessages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildChatBubble(
              isUser: true,
              text: _currentTranscript,
              lumaraPurple: lumaraPurple,
              isPending: true,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildChatBubble(
            isUser: false,
            text: _lastLumaraResponse,
            lumaraPurple: lumaraPurple,
            isPending: true,
          ),
        );
      },
    );
  }

  Widget _buildChatBubble({
    required bool isUser,
    required String text,
    required Color lumaraPurple,
    bool isPending = false,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? Colors.white.withOpacity(isPending ? 0.12 : 0.1)
                : lumaraPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUser
                  ? Colors.white.withOpacity(0.2)
                  : lumaraPurple.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUser ? 'YOU' : 'LUMARA',
                style: TextStyle(
                  color: isUser
                      ? Colors.white.withOpacity(0.6)
                      : lumaraPurple.withOpacity(0.95),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white.withOpacity(0.95)
                      : lumaraPurple.withOpacity(1.0),
                  fontSize: 15,
                  height: 1.45,
                ),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEngagementModeDropdown() {
    final effectiveMode = _voiceEngagementOverride ?? EngagementMode.reflect;
    final label = _voiceEngagementOverride == null
        ? 'Default'
        : effectiveMode.displayName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showVoiceEngagementMenu(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.expand_more,
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVoiceEngagementMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final selection = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(0, 80, MediaQuery.of(context).size.width, 200),
      items: [
        const PopupMenuItem<Object>(
          value: _voiceEngagementAuto,
          child: ListTile(
            leading: Icon(Icons.auto_awesome, size: 20, color: Colors.white70),
            title: Text('Default', style: TextStyle(color: Colors.white)),
            subtitle: Text('Auto from what you say', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        ),
        ...[EngagementMode.reflect, EngagementMode.deeper].map((mode) {
          final isSelected = _voiceEngagementOverride == mode;
          return PopupMenuItem<Object>(
            value: mode,
            child: ListTile(
              leading: Icon(
                mode == EngagementMode.reflect ? Icons.auto_awesome : Icons.integration_instructions,
                size: 20,
                color: isSelected ? Colors.blue : Colors.white70,
              ),
              title: Text(
                mode.displayName,
                style: TextStyle(color: isSelected ? Colors.blue : Colors.white),
              ),
              trailing: isSelected ? const Icon(Icons.check, size: 18, color: Colors.blue) : null,
            ),
          );
        }),
      ],
    );

    if (!mounted) return;
    if (selection == _voiceEngagementAuto) {
      setState(() => _voiceEngagementOverride = null);
      _syncEngagementOverrideToService();
    } else if (selection is EngagementMode) {
      setState(() => _voiceEngagementOverride = selection);
      _syncEngagementOverrideToService();
    }
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
  
  /// Background layer: sigil + label with reduced opacity (tap handled by overlay).
  Widget _buildVoiceSigilBackground() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceSigil(
            state: _mapToSigilState(_state),
            currentPhase: widget.sessionService.currentPhase,
            audioLevel: _audioLevel,
            commitmentLevel: _commitmentLevel,
            onTap: () {}, // Tap-to-talk is handled by overlay
            size: 200,
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1000),
            child: KeyedSubtree(
              key: ValueKey<String>('label_${_state.name}_$_showRecordingUI'),
              child: VoiceSigilStateLabel(
                state: _mapToSigilState(_state),
                hasConversationStarted: _turnCount > 0,
              ),
            ),
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
    // Finish button only appears after user has chosen "Talk with LUMARA"
    // This is the key UX change: no Finish button on initial voice capture
    if (!_hasChosenVoiceConversation) {
      return const SizedBox(height: 48); // Placeholder space
    }
    
    // Finish button should be enabled when:
    // 1. User has chosen voice conversation
    // 2. At least one turn has completed (_turnCount > 0)
    // 3. We're in a state where finishing makes sense (idle after turn, or error)
    // 4. NOT during active processing (listening, scrubbing, waitingForLumara, speaking)
    final canFinish = _hasChosenVoiceConversation && _turnCount > 0 && 
        (_state == VoiceSessionState.idle || _state == VoiceSessionState.error);
    
    // Fade in the Finish button when it first appears
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: _hasChosenVoiceConversation ? 1.0 : 0.0,
      child: Row(
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
      ),
    );
  }
}

/// Single message in the voice chat list (user or LUMARA).
class _VoiceChatMessage {
  final bool isUser;
  final String text;

  const _VoiceChatMessage({required this.isUser, required this.text});
}

/// Inline modal widget for voice processing choice
/// Shows after transcription to let user choose:
/// - Save as Voice Note
/// - Talk with LUMARA (continue to conversation)
/// 
/// NOTE: No auto-select timer - user must explicitly choose
class _VoiceProcessingModalWidget extends StatelessWidget {
  final String transcription;
  final Duration autoSelectDelay; // Kept for API compatibility but not used

  const _VoiceProcessingModalWidget({
    required this.transcription,
    this.autoSelectDelay = const Duration(seconds: 2), // Not used
  });

  void _selectOption(BuildContext context, VoiceProcessingChoice choice) {
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            // Title
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Transcription preview (show "No speech detected." when empty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  transcription.trim().isEmpty
                      ? 'No speech detected. You may have stopped too quickly—try speaking longer, then tap the orb to finish.'
                      : transcription,
                  style: TextStyle(
                    fontSize: 16,
                    color: transcription.trim().isEmpty
                        ? (isDark ? Colors.grey[500] : Colors.grey[600])
                        : (isDark ? Colors.white : Colors.black87),
                    height: 1.4,
                    fontStyle: transcription.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Option 1 - Save as Voice Note
            _buildOption(
              context: context,
              icon: Icons.mic,
              label: 'Save as Voice Note',
              subtitle: 'Save to Voice Notes',
              primaryColor: primaryColor,
              isDark: isDark,
              isPrimary: true,
              onTap: () => _selectOption(context, VoiceProcessingChoice.saveAsVoiceNote),
            ),

            const SizedBox(height: 12),

            // Option 2 - Talk with LUMARA
            _buildOption(
              context: context,
              icon: Icons.record_voice_over,
              label: 'Talk with LUMARA',
              subtitle: 'Start voice conversation',
              primaryColor: primaryColor,
              isDark: isDark,
              isPrimary: false,
              onTap: () => _selectOption(context, VoiceProcessingChoice.talkWithLumara),
            ),

            const SizedBox(height: 12),

            // Option 3 - Add to Timeline
            _buildOption(
              context: context,
              icon: Icons.timeline,
              label: 'Add to Timeline',
              subtitle: 'Add to Conversations timeline',
              primaryColor: primaryColor,
              isDark: isDark,
              isPrimary: false,
              onTap: () => _selectOption(context, VoiceProcessingChoice.addToTimeline),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color primaryColor,
    required bool isDark,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isPrimary ? primaryColor : Colors.grey.withOpacity(isDark ? 0.3 : 0.2),
            width: isPrimary ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isPrimary ? primaryColor.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isPrimary ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[700]),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                      color: isPrimary ? primaryColor : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right, 
              color: isPrimary ? primaryColor.withOpacity(0.7) : Colors.grey.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
