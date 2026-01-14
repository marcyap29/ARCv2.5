// lib/shared/ui/onboarding/widgets/phase_quiz_screen.dart
// Phase Detection Quiz Interface - Conversation Style

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';

class PhaseQuizScreen extends StatefulWidget {
  const PhaseQuizScreen({super.key});

  @override
  State<PhaseQuizScreen> createState() => _PhaseQuizScreenState();
}

class _PhaseQuizScreenState extends State<PhaseQuizScreen> {
  final List<TextEditingController> _responseControllers = [];
  final List<FocusNode> _focusNodes = [];
  final ScrollController _scrollController = ScrollController();
  int _currentQuestionIndex = 0;

  final List<String> _questions = [
    "Let's start simple—where are you right now? One sentence.",
    "What's been occupying your thoughts lately?",
    "When did this start mattering to you?",
    "Is this feeling getting stronger, quieter, or shifting into something else?",
    "What changes if this resolves? Or if it doesn't?",
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers and focus nodes for each question
    for (int i = 0; i < _questions.length; i++) {
      _responseControllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    _loadSavedResponses();
    // Restore current question index from saved state
    _restoreQuestionIndex();
  }
  
  void _restoreQuestionIndex() {
    final cubit = context.read<ArcOnboardingCubit>();
    // Find the first unanswered question
    for (int i = 0; i < _questions.length; i++) {
      if (cubit.state.quizResponses[i] == null || cubit.state.quizResponses[i]!.isEmpty) {
        setState(() {
          _currentQuestionIndex = i;
        });
        return;
      }
    }
    // All questions answered, stay on last question
    setState(() {
      _currentQuestionIndex = _questions.length - 1;
    });
  }

  void _loadSavedResponses() {
    final cubit = context.read<ArcOnboardingCubit>();
    for (int i = 0; i < _questions.length; i++) {
      final response = cubit.state.quizResponses[i];
      if (response != null) {
        _responseControllers[i].text = response;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _responseControllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    for (final focusNode in _focusNodes) {
      focusNode.unfocus();
    }
  }

  bool _canContinue() {
    // Check if current response has at least 10 characters
    final currentController = _responseControllers[_currentQuestionIndex];
    return currentController.text.trim().length >= 10;
  }

  void _continueToNext() {
    if (!_canContinue()) return;

    final cubit = context.read<ArcOnboardingCubit>();
    
    // Save current response
    final response = _responseControllers[_currentQuestionIndex].text.trim();
    cubit.submitQuizResponse(_currentQuestionIndex, response);

    // Move to next question or complete quiz
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        // Focus on next question's text field
        Future.delayed(const Duration(milliseconds: 100), () {
          _focusNodes[_currentQuestionIndex].requestFocus();
        });
      });
    } else {
      // Last question - complete quiz
      cubit.completeQuiz();
    }
  }
  
  void _goToPrevious() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        // Focus on previous question's text field
        Future.delayed(const Duration(milliseconds: 100), () {
          _focusNodes[_currentQuestionIndex].requestFocus();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _canContinue();
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;
    final isFirstQuestion = _currentQuestionIndex == 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _dismissKeyboard,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kcPrimaryColor.withOpacity(0.1),
                  Colors.black,
                ],
              ),
            ),
            child: Column(
              children: [
                // Close button (X) in upper left corner
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          _dismissKeyboard();
                          context.read<ArcOnboardingCubit>().skipToMainPage();
                        },
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Close quiz',
                      ),
                      // Progress indicator (5 dots)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_questions.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _currentQuestionIndex
                                  ? kcPrimaryColor
                                  : index < _currentQuestionIndex
                                      ? kcPrimaryColor.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.2),
                            ),
                          );
                        }),
                      ),
                      // LUMARA symbol (full image scaled down)
                      Opacity(
                        opacity: 0.2,
                        child: Image.asset(
                          'assets/images/LUMARA_Symbol-Final.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.psychology,
                              size: 32,
                              color: kcPrimaryColor.withOpacity(0.2),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Single question display
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question number indicator
                        Text(
                          'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                          style: bodyStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Current question and response
                        _buildConversationItem(
                          question: _questions[_currentQuestionIndex],
                          controller: _responseControllers[_currentQuestionIndex],
                          focusNode: _focusNodes[_currentQuestionIndex],
                          questionNumber: _currentQuestionIndex + 1,
                        ),

                        const SizedBox(height: 32),

                        // Navigation buttons
                        Row(
                          children: [
                            // Previous button
                            if (!isFirstQuestion)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _goToPrevious,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Previous',
                                    style: buttonStyle(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            if (!isFirstQuestion) const SizedBox(width: 16),
                            // Continue/Submit button
                            Expanded(
                              flex: isFirstQuestion ? 1 : 1,
                              child: ElevatedButton(
                                onPressed: canContinue ? _continueToNext : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canContinue
                                      ? kcPrimaryColor
                                      : Colors.white.withOpacity(0.2),
                                  foregroundColor: canContinue
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isLastQuestion ? 'Submit' : 'Continue',
                                  style: buttonStyle(context).copyWith(
                                    color: canContinue
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildConversationItem({
    required String question,
    required TextEditingController controller,
    required FocusNode focusNode,
    required int questionNumber,
  }) {
    final responseLength = controller.text.trim().length;
    final isValid = responseLength >= 10;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LUMARA question (purple, like comments)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LUMARA label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LUMARA',
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Question text in purple
          Text(
            question,
            style: bodyStyle(context).copyWith(
              color: const Color(0xFF7C3AED), // Purple for LUMARA questions
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // User response field
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'You',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text input for user response
          TextField(
            controller: controller,
            focusNode: focusNode,
            style: bodyStyle(context).copyWith(
              color: Colors.white, // Normal text color for user responses
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Type your response...',
              hintStyle: bodyStyle(context).copyWith(
                color: Colors.white.withOpacity(0.4),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isValid
                      ? kcPrimaryColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isValid
                      ? kcPrimaryColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: kcPrimaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
            minLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          // Character count indicator
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${responseLength}/10 characters ${isValid ? "✓" : ""}',
              style: bodyStyle(context).copyWith(
                color: isValid
                    ? kcPrimaryColor.withOpacity(0.7)
                    : Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
