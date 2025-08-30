import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/journal_capture_state.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_state.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:permission_handler/permission_handler.dart';

class JournalCaptureView extends StatefulWidget {
  const JournalCaptureView({super.key});

  @override
  State<JournalCaptureView> createState() => _JournalCaptureViewState();
}

class _JournalCaptureViewState extends State<JournalCaptureView> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  final List<String> _moods = [
    'calm',
    'hopeful',
    'stressed',
    'tired',
    'grateful'
  ];
  String _selectedMood = '';
  bool _showVoiceRecorder = false;
  bool _showKeywordExtraction = false;
  bool _isSaving = false;
  List<String> _selectedKeywords = [];

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

  void _onSavePressed() {
    final content = _textController.text.trim();
    
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before saving'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    if (_selectedMood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a mood before saving'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    context.read<JournalCaptureCubit>().saveEntry(
          content: content,
          mood: _selectedMood,
          selectedKeywords: _selectedKeywords.isNotEmpty ? _selectedKeywords : null,
        );
  }

  void _onMoodSelected(String mood) {
    setState(() {
      _selectedMood = mood == _selectedMood ? '' : mood;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
        listeners: [
          BlocListener<JournalCaptureCubit, JournalCaptureState>(
            listener: (context, state) {
              if (state is JournalCaptureSaved) {
                _textController.clear();
                setState(() {
                  _selectedMood = '';
                  _showVoiceRecorder = false;
                  _isSaving = false;
                  _selectedKeywords = []; // Clear selected keywords
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Entry saved successfully'),
                    backgroundColor: kcSuccessColor,
                  ),
                );
                Navigator.pop(context);
              } else if (state is JournalCaptureError) {
                setState(() {
                  _isSaving = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save entry: ${state.message}'),
                    backgroundColor: kcDangerColor,
                  ),
                );
              } else if (state is JournalCaptureTranscribed) {
                _textController.text = state.transcription;
              }
            },
          ),
          BlocListener<KeywordExtractionCubit, KeywordExtractionState>(
            listener: (context, state) {
              if (state is KeywordExtractionLoaded) {
                setState(() {
                  _selectedKeywords = state.selectedKeywords;
                });
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: kcBackgroundColor,
          appBar: AppBar(
            backgroundColor: kcBackgroundColor,
            title: Text('New Entry', style: heading1Style(context)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSavePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: _isSaving 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('Save', style: buttonStyle(context)),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mood chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _moods.map((mood) {
                      final isSelected = mood == _selectedMood;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            mood,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : kcSecondaryColor,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: kcSecondaryColor,
                          backgroundColor: kcSurfaceColor,
                          onSelected: (_) => _onMoodSelected(mood),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

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

                // Keyword extraction section - only show when there's meaningful text
                if (_textController.text.trim().split(' ').length >= 10)
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
                                'Keywords',
                                style:
                                    heading1Style(context).copyWith(fontSize: 18),
                              ),
                              IconButton(
                                icon: Icon(
                                  _showKeywordExtraction
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: kcPrimaryColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showKeywordExtraction =
                                        !_showKeywordExtraction;
                                  });
                                  if (_showKeywordExtraction) {
                                    context
                                        .read<KeywordExtractionCubit>()
                                        .extractKeywords(_textController.text);
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_showKeywordExtraction) ...[
                            const SizedBox(height: 16),
                            BlocBuilder<KeywordExtractionCubit,
                                KeywordExtractionState>(
                              builder: (context, state) {
                                if (state is KeywordExtractionLoading) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (state is KeywordExtractionLoaded) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Choose the words that matter most',
                                        style: heading2Style(context),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Select 5-10 keywords that best represent your entry',
                                        style: captionStyle(context),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: state.suggestedKeywords
                                            .map((keyword) => _buildKeywordChip(
                                                keyword, state.selectedKeywords))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      if (state.selectedKeywords.length < 5)
                                        Text(
                                          'Please select at least 5 keywords',
                                          style: errorStyle(context),
                                        )
                                      else if (state.selectedKeywords.length > 10)
                                        Text(
                                          'Please select no more than 10 keywords',
                                          style: errorStyle(context),
                                        ),
                                    ],
                                  );
                                }

                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (_textController.text.trim().split(' ').length >= 10)
                  const SizedBox(height: 24),

                // Text editor
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: bodyStyle(context),
                    decoration: InputDecoration(
                      hintText: 'Write what is true right now.',
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
    );
  }

  Widget _buildKeywordChip(String keyword, List<String> selectedKeywords) {
    final isSelected = selectedKeywords.contains(keyword);
    return GestureDetector(
      onTap: () {
        context.read<KeywordExtractionCubit>().toggleKeyword(keyword);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kcPrimaryColor : kcSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kcPrimaryColor : kcSecondaryColor,
          ),
        ),
        child: Text(
          keyword,
          style: bodyStyle(context).copyWith(
            color: isSelected ? Colors.white : kcSecondaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
        ElevatedButton.icon(
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
                : Icon(
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
              IconButton(
                icon: const Icon(Icons.pause, color: kcSecondaryColor),
                onPressed: () {
                  context.read<JournalCaptureCubit>().pauseRecording();
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop, color: kcDangerColor),
                onPressed: () {
                  context.read<JournalCaptureCubit>().stopRecording();
                },
              ),
            ] else if (isPaused) ...[
              IconButton(
                icon: const Icon(Icons.play_arrow, color: kcPrimaryColor),
                onPressed: () {
                  context.read<JournalCaptureCubit>().startRecording();
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop, color: kcDangerColor),
                onPressed: () {
                  context.read<JournalCaptureCubit>().stopRecording();
                },
              ),
            ] else if (state is JournalCaptureRecordingStopped) ...[
              IconButton(
                icon: const Icon(Icons.play_arrow, color: kcPrimaryColor),
                onPressed: () {
                  context.read<JournalCaptureCubit>().playRecording();
                },
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt, color: kcSecondaryColor),
                onPressed: () {
                  context.read<JournalCaptureCubit>().startRecording();
                },
              ),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<JournalCaptureCubit>().transcribeAudio();
                },
                icon: const Icon(Icons.translate, color: Colors.white),
                label: Text('Transcribe', style: buttonStyle(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcPrimaryColor,
                ),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.fiber_manual_record,
                    color: kcPrimaryColor),
                onPressed: () {
                  context.read<JournalCaptureCubit>().startRecording();
                },
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
                borderSide: BorderSide(color: kcSecondaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kcPrimaryColor),
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
