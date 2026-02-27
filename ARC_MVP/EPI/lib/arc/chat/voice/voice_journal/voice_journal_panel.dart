/// Voice Journal Panel UI
/// 
/// A beautiful, minimal UI for voice journaling with LUMARA.
/// 
/// Features:
/// - Single mic button for start/stop recording
/// - Live transcript display
/// - Processing state indicators
/// - LUMARA response display
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'voice_journal_state.dart';
import 'voice_journal_pipeline.dart';

/// Voice Journal Panel - Main UI Widget
class VoiceJournalPanel extends StatefulWidget {
  final VoiceJournalPipeline pipeline;
  final VoidCallback? onSessionSaved;
  final VoidCallback? onSessionEnded;

  const VoiceJournalPanel({
    super.key,
    required this.pipeline,
    this.onSessionSaved,
    this.onSessionEnded,
  });

  @override
  State<VoiceJournalPanel> createState() => _VoiceJournalPanelState();
}

class _VoiceJournalPanelState extends State<VoiceJournalPanel>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  
  StreamSubscription<double>? _audioLevelSubscription;
  double _currentAudioLevel = 0.0;
  
  // Conversation history for display
  final List<_ConversationTurn> _conversationHistory = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // Set up animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Listen to audio levels
    _audioLevelSubscription = widget.pipeline.audioLevelStream.listen((level) {
      if (mounted) {
        setState(() {
          _currentAudioLevel = level;
        });
      }
    });
    
    // Listen to state changes
    widget.pipeline.stateNotifier.addListener(_onStateChange);
    
    // Set up callbacks
    widget.pipeline.onTranscriptUpdate = _onTranscriptUpdate;
    widget.pipeline.onLumaraResponse = _onLumaraResponse;
    widget.pipeline.onSessionSaved = (_) {
      widget.onSessionSaved?.call();
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _audioLevelSubscription?.cancel();
    widget.pipeline.stateNotifier.removeListener(_onStateChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTranscriptUpdate(String transcript) {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _onLumaraResponse(String response) {
    if (mounted) {
      // Add LUMARA response to history when complete
      if (widget.pipeline.stateNotifier.finalTranscript.isNotEmpty) {
        _conversationHistory.add(_ConversationTurn(
          userText: widget.pipeline.stateNotifier.finalTranscript,
          lumaraText: response,
        ));
      }
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.pipeline.state;
    final stateNotifier = widget.pipeline.stateNotifier;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            _buildDragHandle(theme),
            
            // Title
            _buildTitle(theme),
            
            const SizedBox(height: 16),
            
            // Conversation history
            if (_conversationHistory.isNotEmpty)
              _buildConversationHistory(theme),
            
            // Current transcript
            _buildCurrentTranscript(theme, stateNotifier),
            
            // Processing indicator
            _buildProcessingIndicator(theme, state),
            
            const SizedBox(height: 24),
            
            // Mic button
            _buildMicButton(theme, state),
            
            const SizedBox(height: 8),
            
            // Status text
            Text(
              stateNotifier.stateDisplayText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            _buildActionButtons(theme, state),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.auto_awesome,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          'Voice Journal',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildConversationHistory(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: _conversationHistory.length,
        itemBuilder: (context, index) {
          final turn = _conversationHistory[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User message
              _buildMessageBubble(
                theme: theme,
                text: turn.userText,
                isUser: true,
              ),
              const SizedBox(height: 8),
              // LUMARA message
              _buildMessageBubble(
                theme: theme,
                text: turn.lumaraText,
                isUser: false,
              ),
              if (index < _conversationHistory.length - 1)
                const Divider(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble({
    required ThemeData theme,
    required String text,
    required bool isUser,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? 'You' : 'LUMARA',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isUser
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTranscript(
    ThemeData theme,
    VoiceJournalStateNotifier stateNotifier,
  ) {
    final transcript = stateNotifier.partialTranscript.isNotEmpty
        ? stateNotifier.partialTranscript
        : stateNotifier.finalTranscript;
    
    if (transcript.isEmpty && stateNotifier.lumaraReply.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transcript.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.mic,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'You',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                transcript,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: stateNotifier.partialTranscript.isNotEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            ],
            if (stateNotifier.lumaraReply.isNotEmpty) ...[
              if (transcript.isNotEmpty) const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFF7C3AED), // Purple icon for LUMARA (same as journal mode)
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LUMARA',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF7C3AED), // Purple label for LUMARA (same as journal mode)
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stateNotifier.lumaraReply,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7C3AED), // Purple text for LUMARA (same as journal mode)
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator(ThemeData theme, VoiceJournalState state) {
    if (!widget.pipeline.stateNotifier.isProcessing) {
      return const SizedBox.shrink();
    }

    String message;
    IconData icon;
    Color color;

    switch (state) {
      case VoiceJournalState.transcribing:
        message = 'Processing speech...';
        icon = Icons.hearing;
        color = Colors.blue;
        break;
      case VoiceJournalState.scrubbing:
        message = 'Securing your privacy...';
        icon = Icons.security;
        color = Colors.green;
        break;
      case VoiceJournalState.thinking:
        message = 'LUMARA is thinking...';
        icon = Icons.psychology;
        color = Colors.purple;
        break;
      case VoiceJournalState.speaking:
        message = 'LUMARA is speaking...';
        icon = Icons.volume_up;
        color = Colors.orange;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(ThemeData theme, VoiceJournalState state) {
    final isListening = state == VoiceJournalState.listening;
    final isProcessing = widget.pipeline.stateNotifier.isProcessing;
    final canTap = !isProcessing;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _glowController]),
      builder: (context, child) {
        final pulseScale = isListening
            ? 1.0 + (_pulseController.value * 0.1) + (_currentAudioLevel * 0.2)
            : 1.0;
        
        final glowOpacity = isListening
            ? 0.3 + (_glowController.value * 0.3)
            : 0.0;

        return GestureDetector(
          onTap: canTap ? _onMicTap : null,
          child: Transform.scale(
            scale: pulseScale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getMicButtonColor(state),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(glowOpacity),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : canTap
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
              ),
              child: Icon(
                _getMicButtonIcon(state),
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getMicButtonColor(VoiceJournalState state) {
    switch (state) {
      case VoiceJournalState.idle:
        return const Color(0xFF2196F3);  // Blue
      case VoiceJournalState.listening:
        return Colors.red;
      case VoiceJournalState.transcribing:
      case VoiceJournalState.scrubbing:
      case VoiceJournalState.thinking:
        return Colors.amber;
      case VoiceJournalState.speaking:
        return Colors.grey;
      case VoiceJournalState.saved:
        return Colors.green;
      case VoiceJournalState.error:
        return Colors.redAccent;
    }
  }

  IconData _getMicButtonIcon(VoiceJournalState state) {
    switch (state) {
      case VoiceJournalState.idle:
        return Icons.mic;
      case VoiceJournalState.listening:
        return Icons.stop;
      case VoiceJournalState.transcribing:
      case VoiceJournalState.scrubbing:
      case VoiceJournalState.thinking:
        return Icons.hourglass_top;
      case VoiceJournalState.speaking:
        return Icons.volume_up;
      case VoiceJournalState.saved:
        return Icons.check;
      case VoiceJournalState.error:
        return Icons.error;
    }
  }

  Future<void> _onMicTap() async {
    final state = widget.pipeline.state;
    
    if (state == VoiceJournalState.idle) {
      // Start new session and begin listening
      await widget.pipeline.startSession();
      await widget.pipeline.startListening();
    } else if (state == VoiceJournalState.listening) {
      // Stop and process
      await widget.pipeline.endTurnAndProcess();
    }
  }

  Widget _buildActionButtons(ThemeData theme, VoiceJournalState state) {
    if (state == VoiceJournalState.idle && _conversationHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state != VoiceJournalState.idle)
          OutlinedButton.icon(
            onPressed: () async {
              await widget.pipeline.saveAndEndSession();
              _conversationHistory.clear();
              setState(() {});
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Save & End'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        if (state != VoiceJournalState.idle)
          const SizedBox(width: 12),
        if (state != VoiceJournalState.idle)
          TextButton.icon(
            onPressed: () async {
              await widget.pipeline.endSession();
              _conversationHistory.clear();
              setState(() {});
              widget.onSessionEnded?.call();
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
          ),
      ],
    );
  }
}

/// Represents a single conversation turn
class _ConversationTurn {
  final String userText;
  final String lumaraText;

  const _ConversationTurn({
    required this.userText,
    required this.lumaraText,
  });
}

