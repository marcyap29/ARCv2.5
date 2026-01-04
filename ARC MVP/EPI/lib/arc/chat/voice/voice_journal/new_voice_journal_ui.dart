/// New Voice Journal UI
/// 
/// A clean, minimal UI for push-to-talk voice journaling with LUMARA.
/// Features:
/// - Push-to-talk button (hold to record, release to process)
/// - Live transcript display
/// - LUMARA response display
/// - Session management (start/stop)
/// - Equalizer animation during recording

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'new_voice_journal_service.dart';

/// Voice Journal UI Widget
class NewVoiceJournalUI extends StatefulWidget {
  final NewVoiceJournalService service;
  final VoidCallback? onSessionComplete;

  const NewVoiceJournalUI({
    super.key,
    required this.service,
    this.onSessionComplete,
  });

  @override
  State<NewVoiceJournalUI> createState() => _NewVoiceJournalUIState();
}

class _NewVoiceJournalUIState extends State<NewVoiceJournalUI>
    with TickerProviderStateMixin {
  String _currentTranscript = '';
  String _lastLumaraResponse = '';
  VoiceJournalState _currentState = VoiceJournalState.idle;
  
  // Animation controllers
  late AnimationController _equalizerController;
  late AnimationController _pulseController;
  
  // Equalizer bars (for animation)
  final List<double> _barHeights = List.generate(5, (_) => 0.2);
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Setup service callbacks
    widget.service.onStateChange = (state) {
      setState(() {
        _currentState = state;
      });
      
      // Update equalizer animation
      if (state == VoiceJournalState.listening) {
        _equalizerController.repeat();
      } else {
        _equalizerController.stop();
        _equalizerController.reset();
      }
    };
    
    widget.service.onTranscriptUpdate = (transcript) {
      setState(() {
        _currentTranscript = transcript;
      });
    };
    
    widget.service.onLumaraResponse = (response) {
      setState(() {
        _lastLumaraResponse = response;
        // Force rebuild to update Finish button when turn is complete
      });
    };
    
    widget.service.onSessionComplete = (session) {
      widget.onSessionComplete?.call();
    };
    
    widget.service.onError = (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    };
    
    // Initialize service
    widget.service.initialize().then((success) {
      if (success) {
        widget.service.startSession();
      }
    });
  }

  @override
  void dispose() {
    _equalizerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Journal'),
      ),
      body: Column(
        children: [
          // Status and transcript area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status indicator
                  _buildStatusIndicator(theme),
                  const SizedBox(height: 24),
                  
                  // Current transcript
                  if (_currentTranscript.isNotEmpty) ...[
                    Text(
                      'Your words:',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currentTranscript,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // LUMARA response
                  if (_lastLumaraResponse.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LUMARA:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _lastLumaraResponse,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Push-to-talk button area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Push-to-talk button and Finish button side by side
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Push-to-talk button
                    _buildPushToTalkButton(theme),
                    const SizedBox(width: 24),
                    // Finish button
                    _buildFinishButton(theme),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Instruction text
                Text(
                  _getInstructionText(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ThemeData theme) {
    final statusText = _getStatusText();
    final statusColor = _getStatusColor(theme);
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishButton(ThemeData theme) {
    final hasTurns = widget.service.currentSession?.turns.isNotEmpty ?? false;
    final isProcessing = _currentState == VoiceJournalState.processing;
    final canFinish = hasTurns && !isProcessing;
    
    return GestureDetector(
      onTap: canFinish ? _endSession : null,
      child: Opacity(
        opacity: canFinish ? 1.0 : 0.6,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasTurns
                ? theme.colorScheme.secondary
                : theme.colorScheme.surfaceContainerHighest,
            boxShadow: hasTurns
                ? [
                    BoxShadow(
                      color: theme.colorScheme.secondary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isProcessing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onSecondary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.check_circle,
                    color: hasTurns
                        ? theme.colorScheme.onSecondary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                    size: 32,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPushToTalkButton(ThemeData theme) {
    final isRecording = _currentState == VoiceJournalState.listening;
    final isProcessing = _currentState != VoiceJournalState.idle &&
        _currentState != VoiceJournalState.listening;
    
    return GestureDetector(
      onTapDown: (_) {
        if (_currentState == VoiceJournalState.idle ||
            _currentState == VoiceJournalState.speaking) {
          widget.service.startListening();
        }
      },
      onTapUp: (_) {
        if (isRecording) {
          widget.service.stopListeningAndProcess();
        }
      },
      onTapCancel: () {
        if (isRecording) {
          widget.service.stopListeningAndProcess();
        }
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = isRecording
              ? 1.0 + (_pulseController.value * 0.1)
              : 1.0;
          
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? theme.colorScheme.error
                    : isProcessing
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary)
                        .withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: isRecording
                    ? _buildEqualizerAnimation(theme)
                    : Icon(
                        isProcessing ? Icons.hourglass_empty : Icons.mic,
                        color: theme.colorScheme.onPrimary,
                        size: 32,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEqualizerAnimation(ThemeData theme) {
    return AnimatedBuilder(
      animation: _equalizerController,
      builder: (context, child) {
        // Update bar heights with animation
        for (int i = 0; i < _barHeights.length; i++) {
          final phase = (_equalizerController.value * 2 * math.pi) + (i * 0.5);
          _barHeights[i] = 0.2 + (math.sin(phase).abs() * 0.8);
        }
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _barHeights.map((height) {
            return Container(
              width: 4,
              height: 30 * height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _getStatusText() {
    switch (_currentState) {
      case VoiceJournalState.idle:
        return 'Ready';
      case VoiceJournalState.listening:
        return 'Listening...';
      case VoiceJournalState.transcribing:
        return 'Transcribing...';
      case VoiceJournalState.scrubbing:
        return 'Processing...';
      case VoiceJournalState.thinking:
        return 'LUMARA is thinking...';
      case VoiceJournalState.speaking:
        return 'Speaking...';
      case VoiceJournalState.processing:
        return 'Processing...';
      case VoiceJournalState.error:
        return 'Error';
    }
  }

  Color _getStatusColor(ThemeData theme) {
    switch (_currentState) {
      case VoiceJournalState.idle:
        return theme.colorScheme.primary;
      case VoiceJournalState.listening:
        return theme.colorScheme.error;
      case VoiceJournalState.transcribing:
      case VoiceJournalState.scrubbing:
      case VoiceJournalState.thinking:
      case VoiceJournalState.processing:
        return theme.colorScheme.secondary;
      case VoiceJournalState.speaking:
        return theme.colorScheme.tertiary;
      case VoiceJournalState.error:
        return theme.colorScheme.error;
    }
  }

  String _getInstructionText() {
    switch (_currentState) {
      case VoiceJournalState.idle:
        return 'Hold the button to start recording';
      case VoiceJournalState.listening:
        return 'Release to process';
      case VoiceJournalState.transcribing:
      case VoiceJournalState.scrubbing:
      case VoiceJournalState.thinking:
        return 'Processing your words...';
      case VoiceJournalState.speaking:
        return 'LUMARA is responding...';
      case VoiceJournalState.processing:
        return 'Processing session...';
      case VoiceJournalState.error:
        return 'An error occurred';
    }
  }

  Future<void> _endSession() async {
    try {
      // End session and generate summary
      await widget.service.endSessionAndSummarize();
      
      // Save as journal entry
      await widget.service.saveSessionAsEntry();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice journal entry saved!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Call completion callback
      widget.onSessionComplete?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending session: $e')),
        );
      }
    }
  }
}

