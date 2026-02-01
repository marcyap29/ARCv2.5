// lib/shared/ui/onboarding/phase_quiz_v2_screen.dart
// Main quiz screen for PhaseQuizV2

import 'package:flutter/material.dart';
import 'package:my_app/arc/internal/echo/phase/phase_quiz_v2.dart';
import 'package:my_app/arc/internal/echo/phase/quiz_models.dart';
import 'package:my_app/arc/internal/echo/phase/inaugural_entry_generator.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/chronicle/synthesis/synthesis_engine.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/ui/onboarding/widgets/quiz_question_card.dart';
import 'package:my_app/shared/ui/onboarding/onboarding_complete_screen.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class PhaseQuizV2Screen extends StatefulWidget {
  const PhaseQuizV2Screen({super.key});

  @override
  State<PhaseQuizV2Screen> createState() => _PhaseQuizV2ScreenState();
}

class _PhaseQuizV2ScreenState extends State<PhaseQuizV2Screen> {
  int _currentQuestionIndex = 0;
  final Map<QuizQuestion, QuizAnswer> _answers = {};
  bool _isProcessing = false;
  
  QuizQuestion get _currentQuestion => PhaseQuizV2.questions[_currentQuestionIndex];
  bool get _isLastQuestion => _currentQuestionIndex == PhaseQuizV2.questions.length - 1;
  bool get _canProceed => _answers.containsKey(_currentQuestion) && _answers[_currentQuestion]!.isNotEmpty;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentQuestionIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _currentQuestionIndex--;
                  });
                },
              )
            : null,
        title: Text(
          'Getting to Know You',
          style: heading2Style(context).copyWith(color: Colors.white),
        ),
      ),
      body: _isProcessing
          ? _buildProcessingView()
          : _buildQuestionView(),
    );
  }
  
  Widget _buildQuestionView() {
    return Column(
      children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / PhaseQuizV2.questions.length,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                minHeight: 4,
              ),
              const SizedBox(height: 8),
              Text(
                'Question ${_currentQuestionIndex + 1} of ${PhaseQuizV2.questions.length}',
                style: bodyStyle(context).copyWith(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        // Question card
        Expanded(
          child: QuizQuestionCard(
            question: _currentQuestion,
            currentAnswer: _answers[_currentQuestion],
            onAnswerChanged: (answer) {
              setState(() {
                _answers[_currentQuestion] = answer;
              });
            },
          ),
        ),
        
        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex--;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: buttonStyle(context).copyWith(color: Colors.white),
                    ),
                  ),
                ),
              if (_currentQuestionIndex > 0)
                const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _canProceed
                      ? (_isLastQuestion ? _completeQuiz : _nextQuestion)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed ? kcPrimaryColor : Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _canProceed ? 4 : 0,
                  ),
                  child: Text(
                    _isLastQuestion ? 'Complete' : 'Next',
                    style: buttonStyle(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Creating your inaugural entry...',
            style: heading2Style(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'LUMARA is synthesizing your baseline understanding',
            style: bodyStyle(context).copyWith(
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  void _nextQuestion() {
    setState(() {
      _currentQuestionIndex++;
    });
  }
  
  Future<void> _completeQuiz() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Get user ID
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      
      // Initialize CHRONICLE components
      final layer0Repo = Layer0Repository();
      await layer0Repo.initialize();
      
      final aggregationRepo = AggregationRepository();
      final changelogRepo = ChangelogRepository();
      
      final synthesisEngine = SynthesisEngine(
        layer0Repo: layer0Repo,
        aggregationRepo: aggregationRepo,
        changelogRepo: changelogRepo,
      );
      
      // Create quiz service
      final quizService = PhaseQuizV2(
        entryGenerator: InauguralEntryGenerator(),
        journalRepo: JournalRepository(),
        synthesisEngine: synthesisEngine,
      );
      
      // Conduct quiz
      final result = await quizService.conductQuiz(
        userId: userId,
        answers: _answers,
      );

      // Persist quiz phase so main app and Phase tab show the same phase
      final phaseFromQuiz = result.profile.currentPhase;
      if (phaseFromQuiz != null && phaseFromQuiz.isNotEmpty) {
        final capitalizedPhase = phaseFromQuiz.substring(0, 1).toUpperCase() + phaseFromQuiz.substring(1).toLowerCase();
        await UserPhaseService.forceUpdatePhase(capitalizedPhase);
      }

      // Load CHRONICLE monthly aggregation preview so completion screen can show "LUMARA's Initial Understanding"
      String? lumaraPreview;
      try {
        final now = DateTime.now();
        final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final agg = await aggregationRepo.loadLayer(
          userId: userId,
          layer: ChronicleLayer.monthly,
          period: currentMonth,
        );
        if (agg != null && agg.content.trim().isNotEmpty) {
          final lines = agg.content.split('\n').where((l) => l.trim().isNotEmpty).take(3).toList();
          lumaraPreview = lines.join('\n').trim();
        }
      } catch (_) {
        // Preview is optional; continue without it
      }

      // Navigate to completion screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingCompleteScreen(
              entry: result.entry,
              profile: result.profile,
              lumaraSynthesisPreview: lumaraPreview,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating entry: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
