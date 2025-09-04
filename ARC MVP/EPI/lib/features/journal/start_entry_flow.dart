import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/widgets/emotion_picker.dart';
import 'package:my_app/features/journal/widgets/reason_picker.dart';
import 'package:my_app/features/journal/widgets/keyword_analysis_view.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/core/i18n/copy.dart';

class StartEntryFlow extends StatefulWidget {
  const StartEntryFlow({super.key});

  @override
  State<StartEntryFlow> createState() => _StartEntryFlowState();
}

class _StartEntryFlowState extends State<StartEntryFlow> {
  final PageController _pageController = PageController();
  String? _selectedEmotion;
  String? _selectedReason;
  String _textContent = '';

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
    
    // Animate to text editor
    Future.delayed(const Duration(milliseconds: 300), () {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onTextChanged(String text) {
    setState(() {
      _textContent = text;
    });
  }

  void _onSaveEntry() {
    if (_textContent.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before proceeding'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    // Navigate to keyword analysis with all the data
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
            content: _textContent,
            mood: _selectedEmotion ?? '',
            initialEmotion: _selectedEmotion,
            initialReason: _selectedReason,
          ),
        ),
      ),
    ).then((result) {
      // Handle save result - if saved successfully, go back to home
      if (result != null && result['save'] == true) {
        // Navigate back to the root (home screen)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Step 1: Emotion Picker
          EmotionPicker(
            onEmotionSelected: _onEmotionSelected,
            selectedEmotion: _selectedEmotion,
          ),
          
          // Step 2: Reason Picker
          if (_selectedEmotion != null)
            ReasonPicker(
              onReasonSelected: _onReasonSelected,
              selectedEmotion: _selectedEmotion!,
              selectedReason: _selectedReason,
            ),
          
          // Step 3: Text Editor
          if (_selectedReason != null)
            _buildTextEditor(),
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: kcPrimaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Context hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$_selectedEmotion • $_selectedReason",
                    style: captionStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  "Write what is true right now",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 28,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  Copy.editorSubtext,
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Text editor
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      onChanged: _onTextChanged,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: bodyStyle(context).copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: Copy.editorPlaceholder,
                        hintStyle: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: kcPrimaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: _onSaveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: buttonStyle(context).copyWith(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}