// lib/shared/ui/onboarding/widgets/phase_quiz_screen.dart
// Phase Detection Quiz Interface (Screens 5-9)

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
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _currentQuestionIndex = 0;
  bool _isKeyboardVisible = false;

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
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _loadCurrentResponse();
  }

  void _onFocusChanged() {
    setState(() {
      _isKeyboardVisible = _focusNode.hasFocus;
    });
  }

  void _loadCurrentResponse() {
    final cubit = context.read<ArcOnboardingCubit>();
    final response = cubit.state.quizResponses[_currentQuestionIndex];
    if (response != null) {
      _textController.text = response;
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _dismissKeyboard() {
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitResponse() {
    final response = _textController.text.trim();
    if (response.length >= 10) {
      context.read<ArcOnboardingCubit>().submitQuizResponse(
            _currentQuestionIndex,
            response,
          );

      // Brief acknowledgment
      _showAcknowledgment();

      // Move to next question after delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          if (_currentQuestionIndex < _questions.length - 1) {
            setState(() {
              _currentQuestionIndex++;
              _textController.clear();
              _loadCurrentResponse();
            });
          } else {
            // All questions answered, complete quiz
            context.read<ArcOnboardingCubit>().completeQuiz();
          }
        }
      });
    }
  }

  void _showAcknowledgment() {
    final acknowledgments = ['I see.', 'Got it.', 'Understood.'];
    final random = acknowledgments[_currentQuestionIndex % acknowledgments.length];
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(random),
        duration: const Duration(milliseconds: 600),
        backgroundColor: kcPrimaryColor.withOpacity(0.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _textController.text.trim().length >= 10;
    final currentQuestion = _questions[_currentQuestionIndex];

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
                // Top row: Close button (X) left, LUMARA symbol right
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close button (X)
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

                // Progress indicator (5 dots)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentQuestionIndex
                              ? kcPrimaryColor
                              : Colors.white.withOpacity(0.3),
                        ),
                      );
                    }),
                  ),
                ),

                // Question and input - CENTERED vertically
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Question with fade-in effect
                            AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                currentQuestion,
                                style: heading1Style(context).copyWith(
                                  color: Colors.white,
                                  fontSize: 22,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Text input field
                            TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              style: bodyStyle(context).copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type your response...',
                                hintStyle: bodyStyle(context).copyWith(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
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
                                suffixIcon: _isKeyboardVisible
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.keyboard_hide,
                                          color: kcPrimaryColor,
                                        ),
                                        onPressed: _dismissKeyboard,
                                        tooltip: 'Hide keyboard',
                                      )
                                    : null,
                              ),
                              maxLines: 5,
                              minLines: 3,
                              textInputAction: TextInputAction.done,
                              autofocus: true,
                              onSubmitted: (_) {
                                if (canContinue) {
                                  _submitResponse();
                                }
                              },
                            ),
                            const SizedBox(height: 32),
                            // Continue button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: canContinue ? _submitResponse : null,
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
                                  'Continue',
                                  style: buttonStyle(context).copyWith(
                                    color: canContinue
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
}
