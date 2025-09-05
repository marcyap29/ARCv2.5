import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/journal_capture_state.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/features/journal/widgets/emotion_selection_view.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_app/core/perf/frame_budget.dart';
import 'package:my_app/core/a11y/a11y_flags.dart';

class JournalCaptureView extends StatefulWidget {
  final String? initialEmotion;
  final String? initialReason;
  
  const JournalCaptureView({
    super.key,
    this.initialEmotion,
    this.initialReason,
  });

  @override
  State<JournalCaptureView> createState() => _JournalCaptureViewState();
}

class _JournalCaptureViewState extends State<JournalCaptureView> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _showVoiceRecorder = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    // Add listener for auto-save
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    context.read<JournalCaptureCubit>().updateDraft(_textController.text);
  }

  void _onNextPressed() async {
    // Validate that we have content to proceed
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before proceeding'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    // Navigate to emotion selection screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => JournalCaptureCubit(context.read<JournalRepository>()),
            ),
            BlocProvider(
              create: (context) => KeywordExtractionCubit()..initialize(),
            ),
          ],
          child: EmotionSelectionView(
            content: _textController.text,
            initialEmotion: widget.initialEmotion,
            initialReason: widget.initialReason,
          ),
        ),
      ),
    ).then((result) {
      // If entry was saved successfully, clear the text and navigate back
      if (result != null && result['save'] == true) {
        _textController.clear();
        // The emotion selection view should have already handled navigation to home
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // COMMENTED OUT FOR DEBUGGING - Step 5.2
    /*
    return Stack(
      children: [
        BlocListener<JournalCaptureCubit, JournalCaptureState>(
        listener: (context, state) {
          if (state is JournalCaptureSaved) {
            _textController.clear();
            setState(() {
              _showVoiceRecorder = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entry saved successfully'),
                backgroundColor: kcSuccessColor,
              ),
            );
            Navigator.pop(context);
          } else if (state is JournalCaptureTranscribed) {
            _textController.text = state.transcription;
          }
        },
        child: Scaffold(
          backgroundColor: kcBackgroundColor,
          appBar: AppBar(
            backgroundColor: kcBackgroundColor,
            title: Text('New Entry', style: heading1Style(context)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: Semantics(
                    label: 'Continue to next step',
                    button: true,
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kcPrimaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text('Next', style: buttonStyle(context)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Context from start entry flow
                if (widget.initialEmotion != null || widget.initialReason != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: kcPrimaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your reflection context:',
                          style: captionStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (widget.initialEmotion != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  widget.initialEmotion!,
                                  style: captionStyle(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (widget.initialReason != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  widget.initialReason!,
                                  style: captionStyle(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Voice recording section
                Card(
                  color: kcSurfaceAltColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Voice Journal',
                              style:
                                  heading1Style(context).copyWith(fontSize: 18),
                            ),
                            IconButton(
                              icon: Icon(
                                _showVoiceRecorder
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: kcPrimaryColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showVoiceRecorder = !_showVoiceRecorder;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_showVoiceRecorder) ...[
                          const SizedBox(height: 16),
                          BlocBuilder<JournalCaptureCubit, JournalCaptureState>(
                            builder: (context, state) {
                              return Column(
                                children: [
                                  if (state is JournalCaptureInitial ||
                                      state is JournalCapturePermissionDenied)
                                    _buildPermissionSection(state),
                                  if (state
                                          is JournalCapturePermissionGranted ||
                                      state is JournalCaptureRecording ||
                                      state is JournalCaptureRecordingPaused ||
                                      state is JournalCaptureRecordingStopped)
                                    _buildRecordingSection(state),
                                  if (state is JournalCaptureTranscribing ||
                                      state is JournalCaptureTranscribed)
                                    _buildTranscriptionSection(state),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Text editor
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: bodyStyle(context),
                    decoration: InputDecoration(
                      hintText: widget.initialEmotion != null 
                          ? 'Write what is true about feeling ${widget.initialEmotion!.toLowerCase()}...'
                          : 'Write what is true right now.',
                      hintStyle: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    maxLines: null,
                    expands: true,
                    textInputAction: TextInputAction.newline,
                    cursorColor: kcPrimaryColor,
                    cursorWidth: 2,
                    cursorRadius: const Radius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
        // FPS Performance Overlay (debug only)
        const FrameBudgetOverlay(targetFps: 45),
      ],
    );
    */
    
    // SIMPLE RETURN WITH FPS OVERLAY - Step 5.2
    return Stack(
      children: [
        BlocListener<JournalCaptureCubit, JournalCaptureState>(
          listener: (context, state) {
            if (state is JournalCaptureSaved) {
              _textController.clear();
              setState(() {
                _showVoiceRecorder = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entry saved successfully'),
                  backgroundColor: kcSuccessColor,
                ),
              );
              Navigator.pop(context);
            } else if (state is JournalCaptureTranscribed) {
              _textController.text = state.transcription;
            }
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: kcBackgroundColor,
              title: Text('New Entry', style: heading1Style(context)),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Semantics(
                      label: 'Continue to next step',
                      button: true,
                      child: ElevatedButton(
                        onPressed: _onNextPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kcPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text('Next', style: buttonStyle(context)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: BlocBuilder<A11yCubit, A11yState>(
              builder: (context, a11yState) {
                return Theme(
                  data: a11yState.highContrast 
                    ? highContrastTheme(Theme.of(context))
                    : Theme.of(context),
                  child: withTextScale(
                    context,
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Debugging FPS overlay integration'),
                          const SizedBox(height: 20),
                          Text('Larger Text: ${a11yState.largerText}'),
                          Text('High Contrast: ${a11yState.highContrast}'),
                          Text('Reduced Motion: ${a11yState.reducedMotion}'),
                        ],
                      ),
                    ),
                    enabled: a11yState.largerText,
                  ),
                );
              },
            ),
          ),
        ),
        // FPS Performance Overlay (debug only)
        const FrameBudgetOverlay(targetFps: 45),
      ],
    );
  }


  Widget _buildPermissionSection(JournalCaptureState state) {
    return Column(
      children: [
        Text(
          'Record your thoughts with your voice',
          style: bodyStyle(context),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Semantics(
            label: 'Enable voice journaling and request microphone permission',
            button: true,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<JournalCaptureCubit>().requestMicrophonePermission();
              },
              icon: const Icon(Icons.mic, color: Colors.white),
              label: Text('Enable Voice Journaling', style: buttonStyle(context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ),
        if (state is JournalCapturePermissionDenied) ...[
          const SizedBox(height: 16),
          Text(
            state.message,
            style: bodyStyle(context).copyWith(color: kcDangerColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              openAppSettings();
            },
            child: Text(
              'Open Settings to Grant Permission',
              style: linkStyle(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordingSection(JournalCaptureState state) {
    Duration recordingDuration = Duration.zero;
    bool isRecording = false;
    bool isPaused = false;

    if (state is JournalCaptureRecording) {
      recordingDuration = state.recordingDuration;
      isRecording = true;
    } else if (state is JournalCaptureRecordingPaused) {
      recordingDuration = state.recordingDuration;
      isPaused = true;
    } else if (state is JournalCaptureRecordingStopped) {
      recordingDuration = state.recordingDuration;
    }

    return Column(
      children: [
        // Visualizer
        Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: kcPrimaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: isRecording
                ? _buildVisualizer()
                : const Icon(
                    Icons.mic,
                    size: 40,
                    color: Colors.white,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Timer
        Text(
          _formatDuration(recordingDuration),
          style: bodyStyle(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (isRecording) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Pause recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.pause, color: kcSecondaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().pauseRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Stop recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.stop, color: kcDangerColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().stopRecording();
                    },
                  ),
                ),
              ),
            ] else if (isPaused) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Resume recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, color: kcPrimaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().startRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Stop recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.stop, color: kcDangerColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().stopRecording();
                    },
                  ),
                ),
              ),
            ] else if (state is JournalCaptureRecordingStopped) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Play recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, color: kcPrimaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().playRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Start new recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.restart_alt, color: kcSecondaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().startRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Transcribe audio to text',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<JournalCaptureCubit>().transcribeAudio();
                    },
                    icon: const Icon(Icons.translate, color: Colors.white),
                    label: Text('Transcribe', style: buttonStyle(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                    ),
                  ),
                ),
              ),
            ] else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Start recording voice',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.fiber_manual_record,
                        color: kcPrimaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().startRecording();
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTranscriptionSection(JournalCaptureState state) {
    if (state is JournalCaptureTranscribing) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Transcribing your voice...', style: bodyStyle(context)),
        ],
      );
    }

    if (state is JournalCaptureTranscribed) {
      return Column(
        children: [
          Text('Transcription:', style: heading1Style(context)),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            style: bodyStyle(context),
            decoration: InputDecoration(
              hintText: 'Edit your transcription...',
              hintStyle: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kcSecondaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kcPrimaryColor),
              ),
            ),
            controller: TextEditingController(text: state.transcription),
            onChanged: (text) {
              context.read<JournalCaptureCubit>().updateTranscription(text);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'You can edit the transcription above before saving.',
            style: captionStyle(context),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (index) {
        final height = 20 + (index % 5) * 10.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}