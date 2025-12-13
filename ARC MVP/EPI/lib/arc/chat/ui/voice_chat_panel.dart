import 'package:flutter/material.dart';
import '../voice/push_to_talk_controller.dart';
import '../voice/voice_diagnostics.dart';
import 'package:my_app/shared/widgets/glowing_voice_indicator.dart';

class VoiceChatPanel extends StatefulWidget {
  final PushToTalkController controller;
  final VoiceDiagnostics? diagnostics;
  final String? partialTranscript;

  const VoiceChatPanel({
    super.key,
    required this.controller,
    this.diagnostics,
    this.partialTranscript,
  });

  @override
  State<VoiceChatPanel> createState() => _VoiceChatPanelState();
}

class _VoiceChatPanelState extends State<VoiceChatPanel> {
  @override
  void initState() {
    super.initState();
    // Listen to controller state changes
    widget.controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerStateChanged);
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (mounted) {
      setState(() {
        // State will be read from controller in build()
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Read current state from controller
    final currentState = widget.controller.state;
    final isListening = currentState == VCState.listening;
    final isSpeaking = currentState == VCState.speaking;
    final isThinking = currentState == VCState.thinking;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Title
            Text(
              'Voice Chat',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Glowing voice indicator with state-based styling
            Center(
              child: _buildMicrophoneButton(currentState, isListening, isSpeaking, isThinking),
            ),
            
            const SizedBox(height: 16),
            
            // State text
            Text(
              _getStateText(currentState),
              style: theme.textTheme.titleMedium?.copyWith(
                color: _getStateColor(currentState),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Partial transcript display
            if (widget.partialTranscript != null && widget.partialTranscript!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.text_fields,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.partialTranscript!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Thinking indicator
            if (isThinking)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Processing...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Control buttons
            if (isListening || isSpeaking || isThinking)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.controller.endSession,
                    icon: const Icon(Icons.stop, size: 20),
                    label: const Text('End Session'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      side: BorderSide(
                        color: theme.colorScheme.outline,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                currentState == VCState.idle && widget.partialTranscript != null && widget.partialTranscript!.isNotEmpty
                    ? 'Session ended - transcript saved'
                    : 'Tap the glowing mic to start',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              // Show final transcript when session is idle
              if (currentState == VCState.idle && widget.partialTranscript != null && widget.partialTranscript!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Final Transcript',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.partialTranscript!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
            
            const SizedBox(height: 12),
            
            // Diagnostics overlay (debug mode)
            if (widget.diagnostics != null && currentState != VCState.idle)
              _buildDiagnosticsOverlay(),
          ],
          ),
        ),
      ),
    );
  }

  /// Build microphone button with state-based styling
  Widget _buildMicrophoneButton(VCState state, bool isListening, bool isSpeaking, bool isThinking) {
    final isEnabled = state == VCState.idle || state == VCState.listening;
    final isProcessing = isThinking || isSpeaking;
    
    // Determine colors and icon based on state
    Color primaryColor;
    Color glowColor;
    IconData icon;
    bool isActive;
    
    if (state == VCState.idle) {
      // Green when ready to transcribe
      primaryColor = Colors.green;
      glowColor = Colors.greenAccent;
      icon = Icons.mic;
      isActive = false; // No animation when idle/ready
    } else if (state == VCState.thinking) {
      // Yellow when processing
      primaryColor = Colors.amber;
      glowColor = Colors.orangeAccent;
      icon = Icons.hourglass_empty;
      isActive = true; // Animate when processing
    } else if (state == VCState.speaking) {
      // Grayed out when speaking (TTS active)
      primaryColor = Colors.grey;
      glowColor = Colors.grey;
      icon = Icons.mic;
      isActive = false; // No animation when speaking
    } else if (state == VCState.listening) {
      // Red when listening
      primaryColor = Colors.red;
      glowColor = Colors.redAccent;
      icon = Icons.mic;
      isActive = true; // Animate when listening
    } else {
      // Error or other states
      primaryColor = Colors.grey;
      glowColor = Colors.grey;
      icon = Icons.mic;
      isActive = false;
    }
    
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5, // Grayed out when disabled
      child: GlowingVoiceIndicator(
        icon: icon,
        primaryColor: primaryColor,
        glowColor: glowColor,
        size: 80,
        isActive: isActive,
        onTap: isEnabled ? widget.controller.onMicTap : null, // Disable tap when processing/speaking
      ),
    );
  }

  Color _getStateColor(VCState state) {
    switch (state) {
      case VCState.listening:
        return Colors.red;
      case VCState.thinking:
        return Colors.amber; // Yellow/amber for processing
      case VCState.speaking:
        return Colors.grey; // Grayed out when speaking
      case VCState.error:
        return Colors.redAccent;
      case VCState.idle:
        return Colors.green; // Green when ready
      default:
        return Colors.grey;
    }
  }

  Color _getGlowColor(VCState state) {
    switch (state) {
      case VCState.listening:
        return Colors.redAccent;
      case VCState.thinking:
        return Colors.orangeAccent; // Yellow glow for processing
      case VCState.speaking:
        return Colors.grey; // No glow when speaking
      case VCState.error:
        return Colors.red;
      case VCState.idle:
        return Colors.greenAccent; // Green glow when ready
      default:
        return Colors.grey;
    }
  }

  String _getStateText(VCState state) {
    switch (state) {
      case VCState.listening:
        return 'Listening...';
      case VCState.thinking:
        return 'Processing...';
      case VCState.speaking:
        return 'LUMARA is speaking - Please wait';
      case VCState.error:
        return 'Error - Try again';
      case VCState.idle:
        return 'Ready to transcribe';
      default:
        return 'Ready to transcribe';
    }
  }

  Widget _buildDiagnosticsOverlay() {
    final events = widget.diagnostics!.getRecentEvents();
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Diagnostics:',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 4),
          ...events.take(5).map((e) => Text(
                e,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              )),
        ],
      ),
    );
  }
}

