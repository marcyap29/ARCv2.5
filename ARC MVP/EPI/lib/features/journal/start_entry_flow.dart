import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/widgets/emotion_picker.dart';
import 'package:my_app/features/journal/widgets/reason_picker.dart';
import 'package:my_app/features/journal/journal_capture_view.dart';
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
  int _currentPage = 0;

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
      setState(() {
        _currentPage = 1;
      });
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
      setState(() {
        _currentPage = 2;
      });
    });
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
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                    );
                    setState(() {
                      _currentPage = 1;
                    });
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Context hints
                Row(
                  children: [
                    if (_selectedEmotion != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _selectedEmotion!,
                          style: captionStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_selectedReason != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _selectedReason!,
                          style: captionStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Title
                Text(
                  "Now, what's true?",
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
                
                const SizedBox(height: 32),
                
                // Navigate to full journal editor with context
                Expanded(
                  child: GestureDetector(
                    onTap: () {
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
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Copy.editorPlaceholder,
                            style: heading3Style(context).copyWith(
                              color: Colors.white.withOpacity(0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: kcPrimaryColor.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Begin writing",
                                  style: buttonStyle(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        if (_selectedEmotion != null && _selectedReason != null)
          _buildTextEditor(),
      ],
    );
  }
}