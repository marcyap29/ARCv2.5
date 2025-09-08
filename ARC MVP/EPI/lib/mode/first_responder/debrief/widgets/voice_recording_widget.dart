import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../voice_debrief_service.dart';

/// Voice recording widget for debrief steps
class VoiceRecordingWidget extends StatefulWidget {
  final String? debriefStepId;
  final Function(VoiceRecording?)? onRecordingComplete;
  final Function(VoiceRecording?)? onRecordingSaved;
  final bool showTranscription;
  final bool autoStart;
  final Duration? maxDuration;

  const VoiceRecordingWidget({
    super.key,
    this.debriefStepId,
    this.onRecordingComplete,
    this.onRecordingSaved,
    this.showTranscription = true,
    this.autoStart = false,
    this.maxDuration,
  });

  @override
  State<VoiceRecordingWidget> createState() => _VoiceRecordingWidgetState();
}

class _VoiceRecordingWidgetState extends State<VoiceRecordingWidget> {
  final VoiceDebriefService _voiceService = VoiceDebriefService();
  RecordingState _currentState = RecordingState.idle;
  Duration _recordingDuration = Duration.zero;
  VoiceRecording? _currentRecording;
  String? _transcription;
  bool _isTranscribing = false;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _voiceService.recordingStateStream.listen(_onRecordingStateChanged);
    
    if (widget.autoStart) {
      _startRecording();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _onRecordingStateChanged(RecordingState state) {
    if (mounted) {
      setState(() {
        _currentState = state;
      });
    }
  }

  void _startRecording() async {
    final success = await _voiceService.startRecording();
    if (success && mounted) {
      _startDurationTimer();
    }
  }

  void _stopRecording() async {
    _stopDurationTimer();
    final recording = await _voiceService.stopRecording();
    if (recording != null) {
      setState(() {
        _currentRecording = recording;
      });
      widget.onRecordingComplete?.call(recording);
      
      if (widget.showTranscription) {
        _transcribeRecording(recording);
      }
    }
  }

  void _pauseRecording() async {
    await _voiceService.pauseRecording();
    _stopDurationTimer();
  }

  void _resumeRecording() async {
    await _voiceService.resumeRecording();
    _startDurationTimer();
  }

  void _cancelRecording() async {
    _stopDurationTimer();
    await _voiceService.cancelRecording();
    setState(() {
      _currentRecording = null;
      _transcription = null;
    });
  }

  void _transcribeRecording(VoiceRecording recording) async {
    setState(() {
      _isTranscribing = true;
    });

    final transcription = await _voiceService.transcribeAudio(recording.filePath);
    
    if (mounted) {
      setState(() {
        _transcription = transcription;
        _isTranscribing = false;
      });
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration = _voiceService.currentDuration;
        });
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
  }

  void _saveRecording() {
    if (_currentRecording != null) {
      widget.onRecordingSaved?.call(_currentRecording);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.mic,
                color: _currentState == RecordingState.recording 
                    ? kcAccentColor 
                    : kcSecondaryTextColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Voice Recording',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                ),
              ),
              const Spacer(),
              if (_currentState == RecordingState.recording)
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Recording controls
          _buildRecordingControls(),
          
          // Recording duration
          if (_currentState == RecordingState.recording || _currentState == RecordingState.paused)
            _buildDurationDisplay(),
          
          // Current recording info
          if (_currentRecording != null)
            _buildRecordingInfo(),
          
          // Transcription
          if (widget.showTranscription && _transcription != null)
            _buildTranscription(),
          
          // Transcription loading
          if (widget.showTranscription && _isTranscribing)
            _buildTranscriptionLoading(),
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Start/Stop button
        if (_currentState == RecordingState.idle || _currentState == RecordingState.stopped)
          _buildControlButton(
            icon: Icons.mic,
            label: 'Start Recording',
            onPressed: _startRecording,
            color: kcAccentColor,
          ),
        
        // Pause/Resume button
        if (_currentState == RecordingState.recording)
          _buildControlButton(
            icon: Icons.pause,
            label: 'Pause',
            onPressed: _pauseRecording,
            color: Colors.orange,
          ),
        
        if (_currentState == RecordingState.paused)
          _buildControlButton(
            icon: Icons.play_arrow,
            label: 'Resume',
            onPressed: _resumeRecording,
            color: kcAccentColor,
          ),
        
        // Stop button
        if (_currentState == RecordingState.recording || _currentState == RecordingState.paused)
          _buildControlButton(
            icon: Icons.stop,
            label: 'Stop',
            onPressed: _stopRecording,
            color: Colors.red,
          ),
        
        // Cancel button
        if (_currentState == RecordingState.recording || _currentState == RecordingState.paused)
          _buildControlButton(
            icon: Icons.cancel,
            label: 'Cancel',
            onPressed: _cancelRecording,
            color: Colors.grey,
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 28),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDisplay() {
    final minutes = _recordingDuration.inMinutes;
    final seconds = _recordingDuration.inSeconds % 60;
    final durationText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: kcAccentColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            durationText,
            style: heading3Style(context).copyWith(
              color: kcAccentColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingInfo() {
    if (_currentRecording == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcAccentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: kcAccentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: kcAccentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Recording Complete',
                style: bodyStyle(context).copyWith(
                  color: kcAccentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Duration: ${_currentRecording!.formattedDuration}',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
          ),
          Text(
            'Size: ${_currentRecording!.formattedFileSize}',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveRecording,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Recording'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kcAccentColor,
                    side: const BorderSide(color: kcAccentColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelRecording,
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscription() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.text_fields,
                color: kcAccentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Transcription',
                style: bodyStyle(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _transcription ?? 'No transcription available',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionLoading() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(kcAccentColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Transcribing audio...',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
