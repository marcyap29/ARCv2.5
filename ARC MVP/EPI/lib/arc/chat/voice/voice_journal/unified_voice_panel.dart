/// Unified Voice Panel
/// 
/// A single UI component for both Voice Journal and Voice Chat modes.
/// The UI adapts based on the current mode.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'voice_journal_state.dart';
import 'voice_mode.dart';
import 'unified_voice_service.dart';

/// Unified Voice Panel
class UnifiedVoicePanel extends StatefulWidget {
  final UnifiedVoiceService service;
  final VoidCallback? onSessionSaved;
  final VoidCallback? onSessionEnded;
  final Function(String)? onTranscriptsCollected;
  final bool showModeSwitch;

  const UnifiedVoicePanel({
    super.key,
    required this.service,
    this.onSessionSaved,
    this.onSessionEnded,
    this.onTranscriptsCollected,
    this.showModeSwitch = false,
  });

  @override
  State<UnifiedVoicePanel> createState() => _UnifiedVoicePanelState();
}

class _UnifiedVoicePanelState extends State<UnifiedVoicePanel>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _processingPulseController;
  
  StreamSubscription<double>? _audioLevelSubscription;
  double _currentAudioLevel = 0.0;
  
  // Timeout tracking for processing states
  DateTime? _processingStartTime;
  bool _showTimeoutWarning = false;
  
  // Conversation history
  final List<_ConversationTurn> _conversationHistory = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _processingPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _audioLevelSubscription = widget.service.audioLevelStream.listen((level) {
      if (mounted) setState(() => _currentAudioLevel = level);
    });
    
    widget.service.stateNotifier.addListener(_onStateChange);
    
    // Set up callbacks
    widget.service.onTranscriptUpdate = _onTranscriptUpdate;
    widget.service.onLumaraResponse = _onLumaraResponse;
    widget.service.onSessionComplete = (_) {
      widget.onSessionSaved?.call();
    };
    widget.service.onTranscriptsCollected = (transcriptText) {
      widget.onTranscriptsCollected?.call(transcriptText);
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _processingPulseController.dispose();
    _audioLevelSubscription?.cancel();
    widget.service.stateNotifier.removeListener(_onStateChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      final isProcessing = widget.service.stateNotifier.isProcessing;
      
      // Track processing start time
      if (isProcessing && _processingStartTime == null) {
        _processingStartTime = DateTime.now();
        _showTimeoutWarning = false;
      } else if (!isProcessing) {
        _processingStartTime = null;
        _showTimeoutWarning = false;
      } else if (_processingStartTime != null) {
        // Check for timeout (10 seconds)
        final duration = DateTime.now().difference(_processingStartTime!);
        if (duration.inSeconds >= 10 && !_showTimeoutWarning) {
          _showTimeoutWarning = true;
        }
      }
      
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
      final stateNotifier = widget.service.stateNotifier;
      if (stateNotifier.finalTranscript.isNotEmpty) {
        _conversationHistory.add(_ConversationTurn(
          userText: stateNotifier.finalTranscript,
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
    final state = widget.service.state;
    final stateNotifier = widget.service.stateNotifier;
    final mode = widget.service.mode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            _buildDragHandle(theme),
            _buildHeader(theme, mode),
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
            _buildMicButton(theme, state, mode),
            
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
            _buildActionButtons(theme, state, mode),
            ],
          ),
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

  Widget _buildHeader(ThemeData theme, VoiceMode mode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          mode == VoiceMode.journal ? Icons.auto_awesome : Icons.chat,
          color: _getModeColor(mode),
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          mode.displayName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (widget.showModeSwitch && widget.service.state == VoiceJournalState.idle) ...[
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(
              Icons.swap_horiz,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              final newMode = mode == VoiceMode.journal 
                  ? VoiceMode.chat 
                  : VoiceMode.journal;
              if (widget.service.switchMode(newMode)) {
                setState(() {});
              }
            },
            tooltip: 'Switch to ${mode == VoiceMode.journal ? "Chat" : "Journal"}',
          ),
        ],
      ],
    );
  }

  Color _getModeColor(VoiceMode mode) {
    switch (mode) {
      case VoiceMode.journal:
        return Colors.purple;
      case VoiceMode.chat:
        return Colors.blue;
    }
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
              _buildMessageBubble(theme: theme, text: turn.userText, isUser: true),
              const SizedBox(height: 8),
              _buildMessageBubble(theme: theme, text: turn.lumaraText, isUser: false),
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
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildCurrentTranscript(
    ThemeData theme,
    VoiceJournalStateNotifier stateNotifier,
  ) {
    // Only show current transcript when actively recording/processing
    // Once a turn is complete and in conversation history, hide this to avoid duplicates
    final state = widget.service.state;
    final isActive = state == VoiceJournalState.listening || 
                     state == VoiceJournalState.transcribing ||
                     state == VoiceJournalState.scrubbing ||
                     state == VoiceJournalState.thinking ||
                     state == VoiceJournalState.speaking;
    
    // If we have conversation history, don't show current transcript (it's already in history)
    if (_conversationHistory.isNotEmpty && !isActive) {
      return const SizedBox.shrink();
    }
    
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
                  Icon(Icons.mic, size: 16, color: theme.colorScheme.primary),
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
                  Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'LUMARA',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(stateNotifier.lumaraReply, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator(ThemeData theme, VoiceJournalState state) {
    if (!widget.service.stateNotifier.isProcessing) {
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

    return Center(
      child: AnimatedBuilder(
        animation: _processingPulseController,
        builder: (context, child) {
          final pulseOpacity = 0.2 + (_processingPulseController.value * 0.3);
          return Container(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(pulseOpacity),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(pulseOpacity * 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(icon, size: 24, color: color),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                if (_showTimeoutWarning) ...[
                  const SizedBox(height: 12),
                  Text(
                    'This is taking longer than usual...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMicButton(ThemeData theme, VoiceJournalState state, VoiceMode mode) {
    final isListening = state == VoiceJournalState.listening;
    final isProcessing = widget.service.stateNotifier.isProcessing;
    final canTap = !isProcessing;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController, 
        _glowController,
        if (isProcessing) _processingPulseController,
      ]),
      builder: (context, child) {
        final pulseScale = isListening
            ? 1.0 + (_pulseController.value * 0.1) + (_currentAudioLevel * 0.2)
            : isProcessing
                ? 1.0 + (_processingPulseController.value * 0.08)
                : 1.0;
        
        final glowOpacity = isListening
            ? 0.3 + (_glowController.value * 0.3)
            : isProcessing
                ? 0.4 + (_processingPulseController.value * 0.3)
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
                color: _getMicButtonColor(state, mode),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(glowOpacity),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : isProcessing
                        ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(glowOpacity),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ]
                        : canTap
                            ? [
                                BoxShadow(
                                  color: _getModeColor(mode).withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
              ),
              child: isListening
                  ? _buildAudioVisualization(80, Colors.white)
                  : Icon(
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

  /// Build audio visualization (oscilloscope-like waveform)
  Widget _buildAudioVisualization(double size, Color color) {
    final barCount = 8;
    final barWidth = size / (barCount * 2);
    
    return CustomPaint(
      size: Size(size, size),
      painter: _AudioVisualizationPainter(
        audioLevel: _currentAudioLevel,
        color: color.withOpacity(0.9),
        barCount: barCount,
        barWidth: barWidth,
      ),
    );
  }

  Color _getMicButtonColor(VoiceJournalState state, VoiceMode mode) {
    switch (state) {
      case VoiceJournalState.idle:
        return _getModeColor(mode);
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
    final state = widget.service.state;
    
    if (state == VoiceJournalState.idle || state == VoiceJournalState.saved) {
      await widget.service.startSession();
      await widget.service.startListening();
    } else if (state == VoiceJournalState.listening) {
      await widget.service.endTurnAndProcess();
    }
  }

  Widget _buildActionButtons(ThemeData theme, VoiceJournalState state, VoiceMode mode) {
    if (state == VoiceJournalState.idle && _conversationHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    final saveLabel = mode == VoiceMode.journal ? 'Save Entry' : 'End Chat';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state != VoiceJournalState.idle && state != VoiceJournalState.saved)
          OutlinedButton.icon(
            onPressed: () async {
              await widget.service.saveAndEndSession();
              _conversationHistory.clear();
              setState(() {});
              // Note: onTranscriptsCollected callback is handled by the service
              // and will be called automatically for journal mode
            },
            icon: Icon(
              mode == VoiceMode.journal ? Icons.save : Icons.check,
              size: 18,
            ),
            label: Text(saveLabel),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        if (state != VoiceJournalState.idle && state != VoiceJournalState.saved)
          const SizedBox(width: 12),
        if (state != VoiceJournalState.idle && state != VoiceJournalState.saved)
          TextButton.icon(
            onPressed: () async {
              await widget.service.endSession();
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

class _ConversationTurn {
  final String userText;
  final String lumaraText;
  const _ConversationTurn({required this.userText, required this.lumaraText});
}

/// Custom painter for audio visualization (oscilloscope effect)
class _AudioVisualizationPainter extends CustomPainter {
  final double audioLevel;
  final Color color;
  final int barCount;
  final double barWidth;

  _AudioVisualizationPainter({
    required this.audioLevel,
    required this.color,
    required this.barCount,
    required this.barWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final centerY = size.height / 2;
    final spacing = size.width / (barCount + 1);
    
    // Create bars with varying heights based on audio level
    for (int i = 0; i < barCount; i++) {
      // Simulate oscilloscope effect with sine wave pattern
      final phase = (i / barCount) * 2 * 3.14159; // 2 * pi
      final heightFactor = (math.sin(phase + audioLevel * 10) + 1) / 2;
      final barHeight = (size.height * 0.3) * (0.3 + heightFactor * audioLevel);
      
      final x = spacing * (i + 1) - barWidth / 2;
      final y = centerY - barHeight / 2;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AudioVisualizationPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel;
  }
}

