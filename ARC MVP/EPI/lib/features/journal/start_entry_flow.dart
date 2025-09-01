import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/widgets/emotion_picker.dart';
import 'package:my_app/features/journal/widgets/reason_picker.dart';
import 'package:my_app/features/journal/journal_capture_view.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/repositories/journal_repository.dart';

class StartEntryFlow extends StatefulWidget {
  const StartEntryFlow({super.key});

  @override
  State<StartEntryFlow> createState() => _StartEntryFlowState();
}

class _StartEntryFlowState extends State<StartEntryFlow> {
  final PageController _pageController = PageController();
  String? _selectedEmotion;
  String? _selectedReason;

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
    
    // Navigate directly to journal interface with context
    Future.delayed(const Duration(milliseconds: 300), () {
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
            child: JournalCaptureView(
              initialEmotion: _selectedEmotion,
              initialReason: _selectedReason,
            ),
          ),
        ),
      );
    });
  }



  @override
  Widget build(BuildContext context) {
    return PageView(
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
    );
  }
}