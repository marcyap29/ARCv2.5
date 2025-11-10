import 'package:flutter/material.dart';
import '../voice/push_to_talk_controller.dart';
import '../voice/voice_diagnostics.dart';
import 'widgets/mic_button.dart';

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
    final isError = currentState == VCState.error;

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
            const SizedBox(height: 16),
            
            // State indicator
            _buildStateIndicator(theme, isListening, isSpeaking, isThinking, isError),
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
            
            // Mic button
            MicButton(
              listening: isListening,
              speaking: isSpeaking,
              onTap: () => widget.controller.onMicTap(),
              onEnd: () => widget.controller.endSession(),
            ),
            const SizedBox(height: 12),
            
            // Help text
            Text(
              isListening
                  ? 'Tap the mic again to stop and process'
                  : isSpeaking
                      ? 'Listening will resume automatically'
                      : 'Tap the mic to start voice chat',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            
            // Diagnostics overlay (debug mode)
            if (widget.diagnostics != null && currentState != VCState.idle)
              _buildDiagnosticsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateIndicator(
    ThemeData theme,
    bool isListening,
    bool isSpeaking,
    bool isThinking,
    bool isError,
  ) {
    IconData icon;
    String label;
    Color color;

    if (isError) {
      icon = Icons.error_outline;
      label = 'Error';
      color = theme.colorScheme.error;
    } else if (isSpeaking) {
      icon = Icons.volume_up;
      label = 'Speaking';
      color = theme.colorScheme.primary;
    } else if (isThinking) {
      icon = Icons.psychology;
      label = 'Thinking';
      color = theme.colorScheme.secondary;
    } else if (isListening) {
      icon = Icons.mic;
      label = 'Listening';
      color = Colors.red;
    } else {
      icon = Icons.mic_none;
      label = 'Ready';
      color = theme.colorScheme.onSurface.withOpacity(0.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

