// lib/shared/ui/onboarding/widgets/phase_quiz_screen.dart
// Phase Detection Quiz Interface (Screens 5-9)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';

class PhaseQuizScreen extends StatefulWidget {
  const PhaseQuizScreen({super.key});

  @override
  State<PhaseQuizScreen> createState() => _PhaseQuizScreenState();
}

class _PhaseQuizScreenState extends State<PhaseQuizScreen> {
  final TextEditingController _textController = TextEditingController();
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
    _textController.addListener(_onTextChanged);
    _loadCurrentResponse();
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

  @override
  void dispose() {
    _textController.dispose();
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
        backgroundColor: const Color(0xFFD4AF37).withOpacity(0.8),
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFD4AF37).withOpacity(0.1),
                Colors.black,
              ],
            ),
          ),
          child: Column(
            children: [
              // LUMARA symbol in top corner (static, 20% opacity)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Opacity(
                    opacity: 0.2,
                    child: const LumaraIcon(size: 32),
                  ),
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
                            ? const Color(0xFFD4AF37)
                            : Colors.white.withOpacity(0.3),
                      ),
                    );
                  }),
                ),
              ),

              // Question text
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                              borderSide: const BorderSide(
                                color: Color(0xFFD4AF37),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: 5,
                          minLines: 3,
                          autofocus: true,
                        ),
                        const SizedBox(height: 32),
                        // Continue button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canContinue ? _submitResponse : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canContinue
                                  ? const Color(0xFFD4AF37)
                                  : Colors.white.withOpacity(0.2),
                              foregroundColor: canContinue
                                  ? Colors.black
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
                                    ? Colors.black
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
            ],
          ),
        ),
      ),
    );
  }
}
