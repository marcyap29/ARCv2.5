import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/journal_capture_state.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_state.dart';
import 'package:my_app/features/home/home_cubit.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/in_app_notification.dart';
import 'package:my_app/shared/arcform_intro_animation.dart';
import 'package:my_app/features/arcforms/phase_recommender.dart';
import 'package:my_app/features/arcforms/widgets/phase_choice_sheet.dart';
import 'package:my_app/core/i18n/copy.dart';
import 'package:permission_handler/permission_handler.dart';

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
      InAppNotification.show(
        context: context,
        message: 'Please write something before saving',
        type: NotificationType.info,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    if (_selectedMood.isEmpty) {
      InAppNotification.show(
        context: context,
        message: 'Please select a mood before saving',
        type: NotificationType.info,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Get phase recommendation
    final emotion = widget.initialEmotion ?? _selectedMood;
    final reason = widget.initialReason ?? '';
    
    final recommendedPhase = PhaseRecommender.recommend(
      emotion: emotion,
      reason: reason,
      text: content,
    );
    
    final rationale = PhaseRecommender.rationale(recommendedPhase);
    
    // Show recommendation modal
    _showPhaseRecommendationModal(
      phase: recommendedPhase,
      rationale: rationale,
      content: content,
    );
  }

  void _showPhaseRecommendationModal({
    required String phase,
    required String rationale,
    required String content,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          Copy.recModalTitle,
          style: heading2Style(context).copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Copy.recModalBody(phase),
              style: bodyStyle(context).copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kcPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kcPrimaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phase,
                    style: heading3Style(context).copyWith(
                      color: kcPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rationale,
                    style: captionStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showPhaseChoiceSheet(content);
            },
            child: Text(
              Copy.seeOtherPhases,
              style: buttonStyle(context).copyWith(
                color: kcSecondaryColor,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: kcPrimaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveWithPhase(content, phase, true); // userConsented = true
              },
              child: Text(
                Copy.keepPhase(phase),
                style: buttonStyle(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhaseChoiceSheet(String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PhaseChoiceSheet(
        currentPhase: PhaseRecommender.recommend(
          emotion: widget.initialEmotion ?? _selectedMood,
          reason: widget.initialReason ?? '',
          text: content,
        ),
        onPhaseSelected: (selectedPhase) {
          _saveWithPhase(content, selectedPhase, true); // userConsented = true
        },
      ),
    );
  }

  void _saveWithPhase(String content, String phase, bool userConsented) {
    setState(() {
      _isSaving = true;
    });

    context.read<JournalCaptureCubit>().saveEntryWithPhase(
      content: content,
      mood: _selectedMood,
      emotion: widget.initialEmotion,
      emotionReason: widget.initialReason,
      phase: phase,
      userConsentedPhase: userConsented,
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
                final entryContent = _textController.text;
                _textController.clear();
                setState(() {
                  _selectedMood = '';
                  _showVoiceRecorder = false;
                  _isSaving = false;
                  _selectedKeywords = []; // Clear selected keywords
                });

                // Show elegant in-app notification
                InAppNotification.show(
                  context: context,
                  message: 'Entry saved successfully',
                  type: NotificationType.success,
                  duration: const Duration(seconds: 2),
                );

                // Navigate to Timeline tab
                final homeCubit = context.read<HomeCubit>();
                homeCubit.changeTab(2); // Timeline is tab index 2

                // Show Arcform introduction animation after a brief delay
                Future.delayed(const Duration(milliseconds: 1000), () {
                  // Check if widget is still mounted before accessing context
                  if (!mounted) return;
                  
                  final arcforms = SimpleArcformStorage.loadAllArcforms();
                  if (arcforms.isNotEmpty) {
                    final latestArcform = arcforms.last;
                    
                    ArcformIntroAnimation.show(
                      context: context,
                      arcform: latestArcform,
                      entryTitle: _generateTitle(entryContent),
                      onComplete: () {
                        // Check if widget is still mounted before showing follow-up notification
                        if (!mounted) return;
                        
                        // Show follow-up notification with action
                        InAppNotification.showArcformGenerated(
                          context: context,
                          entryTitle: _generateTitle(entryContent),
                          arcformType: _getGeometryDisplayName(latestArcform.geometry),
                          onViewPressed: () {
                            // Check if still mounted before navigation
                            if (mounted) {
                              // Switch to Arcforms tab to view the generated form
                              homeCubit.changeTab(1); // Arcforms tab is index 1
                            }
                          },
                        );
                      },
                    );
                  }
                });
              } else if (state is JournalCaptureError) {
                setState(() {
                  _isSaving = false;
                });
                InAppNotification.show(
                  context: context,
                  message: 'Failed to save entry: ${state.message}',
                  type: NotificationType.error,
                  duration: const Duration(seconds: 4),
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

  String _generateTitle(String content) {
    // Simple title generation from first few words
    final words = content.split(' ');
    if (words.isEmpty) return 'Untitled';

    final titleWords = words.take(3);
    return '${titleWords.join(' ')}${words.length > 3 ? '...' : ''}';
  }

  String _getGeometryDisplayName(ArcformGeometry geometry) {
    switch (geometry) {
      case ArcformGeometry.spiral:
        return 'Spiral';
      case ArcformGeometry.flower:
        return 'Flower';
      case ArcformGeometry.branch:
        return 'Branch';
      case ArcformGeometry.weave:
        return 'Weave';
      case ArcformGeometry.glowCore:
        return 'Glow Core';
      case ArcformGeometry.fractal:
        return 'Fractal';
    }
  }
}
