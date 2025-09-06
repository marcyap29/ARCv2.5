import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/widgets/emotion_picker.dart';
import 'package:my_app/features/journal/widgets/reason_picker.dart';
import 'package:my_app/features/journal/widgets/keyword_analysis_view.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class EmotionSelectionView extends StatefulWidget {
  final String content;
  final String? initialEmotion;
  final String? initialReason;
  
  const EmotionSelectionView({
    super.key,
    required this.content,
    this.initialEmotion,
    this.initialReason,
  });

  @override
  State<EmotionSelectionView> createState() => _EmotionSelectionViewState();
}

class _EmotionSelectionViewState extends State<EmotionSelectionView> {
  final PageController _pageController = PageController();
  String? _selectedEmotion;
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _selectedEmotion = widget.initialEmotion;
    _selectedReason = widget.initialReason;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onEmotionSelected(String emotion) {
    setState(() {
      _selectedEmotion = emotion;
    });
    
    // Animate to reason picker
    Future.delayed(const Duration(milliseconds: 300), () {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onReasonSelected(String reason) {
    setState(() {
      _selectedReason = reason;
    });
    
    // Navigate to keyword analysis with Analyze button
    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.of(context).push<Map<String, dynamic>>(
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
            child: KeywordAnalysisView(
              content: widget.content,
              mood: _selectedEmotion ?? '',
              initialEmotion: _selectedEmotion,
              initialReason: _selectedReason,
            ),
          ),
        ),
      ).then((result) {
        // Handle save result - if saved successfully, go back to home
        if (result != null && result['save'] == true) {
          // Navigate back to the previous screen
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('Select Emotion', style: heading1Style(context)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          EmotionPicker(
            onEmotionSelected: _onEmotionSelected,
            selectedEmotion: _selectedEmotion,
          ),
          if (_selectedEmotion != null)
            ReasonPicker(
              onReasonSelected: _onReasonSelected,
              selectedEmotion: _selectedEmotion!,
              selectedReason: _selectedReason,
            ),
        ],
      ),
    );
  }
}
