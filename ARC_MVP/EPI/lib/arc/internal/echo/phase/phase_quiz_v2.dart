// lib/arc/internal/echo/phase/phase_quiz_v2.dart
// PhaseQuizV2: 8-question multiple-choice onboarding quiz

import 'package:uuid/uuid.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/chronicle/synthesis/synthesis_engine.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'quiz_models.dart';
import 'inaugural_entry_generator.dart';

class PhaseQuizV2 {
  final InauguralEntryGenerator _entryGenerator;
  final JournalRepository _journalRepo;
  final SynthesisEngine _synthesisEngine;
  final Uuid _uuid = const Uuid();
  
  PhaseQuizV2({
    required InauguralEntryGenerator entryGenerator,
    required JournalRepository journalRepo,
    required SynthesisEngine synthesisEngine,
  })  : _entryGenerator = entryGenerator,
        _journalRepo = journalRepo,
        _synthesisEngine = synthesisEngine;
  
  /// The 8 onboarding questions
  static final List<QuizQuestion> questions = [
    // Q1: Current Phase
    const QuizQuestion(
      id: 'current_phase',
      text: 'Which best describes where you are right now?',
      subtitle: 'Choose the one that resonates most',
      category: QuizCategory.phase,
      options: [
        QuizOption('recovery', 'Recently went through something difficult, still processing'),
        QuizOption('transition', 'Between chapters, figuring out what\'s next'),
        QuizOption('breakthrough', 'Had a major insight or shift recently'),
        QuizOption('discovery', 'Exploring new possibilities or interests'),
        QuizOption('expansion', 'Building momentum, things are clicking'),
        QuizOption('consolidation', 'Deepening focus, refining what matters'),
        QuizOption('questioning', 'Uncertain, reevaluating direction'),
      ],
    ),
    
    // Q2: Primary Focus (multi-select, max 3)
    const QuizQuestion(
      id: 'primary_focus',
      text: 'What occupies most of your mental energy lately?',
      subtitle: 'Select up to 3',
      category: QuizCategory.themes,
      multiSelect: true,
      maxSelections: 3,
      options: [
        QuizOption('career', 'Career decisions or work challenges'),
        QuizOption('relationships', 'Relationships and connections'),
        QuizOption('health', 'Physical or mental health'),
        QuizOption('creativity', 'Creative projects or expression'),
        QuizOption('learning', 'Learning and growth'),
        QuizOption('identity', 'Who I am and who I\'m becoming'),
        QuizOption('purpose', 'Life meaning and direction'),
        QuizOption('transition', 'Major life change or transition'),
        QuizOption('financial', 'Money and financial security'),
        QuizOption('family', 'Family dynamics or responsibilities'),
      ],
    ),
    
    // Q3: Temporal Context
    const QuizQuestion(
      id: 'inflection_timing',
      text: 'When did your current situation begin taking shape?',
      category: QuizCategory.temporal,
      options: [
        QuizOption('recent', 'Very recently (past few weeks)'),
        QuizOption('this_month', 'This month'),
        QuizOption('few_months', 'Past few months'),
        QuizOption('this_year', 'Earlier this year'),
        QuizOption('last_year', 'Last year'),
        QuizOption('longer', 'This has been building for years'),
      ],
    ),
    
    // Q4: Emotional State
    const QuizQuestion(
      id: 'emotional_state',
      text: 'How would you describe your emotional state lately?',
      category: QuizCategory.emotional,
      options: [
        QuizOption('struggling', 'Struggling, low energy'),
        QuizOption('uncertain', 'Uncertain, anxious'),
        QuizOption('stable', 'Stable, managing'),
        QuizOption('hopeful', 'Hopeful, optimistic'),
        QuizOption('energized', 'Energized, excited'),
        QuizOption('mixed', 'Intense mix of highs and lows'),
        QuizOption('numb', 'Numb, disconnected'),
      ],
    ),
    
    // Q5: Momentum Direction
    const QuizQuestion(
      id: 'momentum',
      text: 'How does this feel over time?',
      category: QuizCategory.momentum,
      options: [
        QuizOption('intensifying', 'Getting stronger, more urgent'),
        QuizOption('resolving', 'Starting to resolve or clarify'),
        QuizOption('shifting', 'Shifting into something different'),
        QuizOption('stable', 'Staying about the same'),
        QuizOption('quieting', 'Fading, feeling less important'),
        QuizOption('cyclical', 'Comes and goes in waves'),
      ],
    ),
    
    // Q6: Stakes
    const QuizQuestion(
      id: 'stakes',
      text: 'What feels most at stake right now?',
      subtitle: 'What matters most about this situation?',
      category: QuizCategory.stakes,
      options: [
        QuizOption('identity', 'Who I am, my sense of self'),
        QuizOption('relationships', 'Important relationships'),
        QuizOption('security', 'Stability and security'),
        QuizOption('growth', 'Personal growth and development'),
        QuizOption('meaning', 'Sense of purpose or meaning'),
        QuizOption('autonomy', 'Freedom and independence'),
        QuizOption('health', 'Physical or mental wellbeing'),
        QuizOption('legacy', 'Long-term impact or legacy'),
      ],
    ),
    
    // Q7: Behavioral Pattern
    const QuizQuestion(
      id: 'approach_style',
      text: 'How do you tend to approach challenges?',
      category: QuizCategory.behavioral,
      options: [
        QuizOption('analytical', 'Think it through carefully, plan ahead'),
        QuizOption('intuitive', 'Trust my gut, follow what feels right'),
        QuizOption('social', 'Talk it through with others'),
        QuizOption('action', 'Jump in and figure it out as I go'),
        QuizOption('avoidant', 'Avoid or distract until I have to deal with it'),
        QuizOption('reflective', 'Write and think deeply before acting'),
      ],
    ),
    
    // Q8: Support Context
    const QuizQuestion(
      id: 'support',
      text: 'How would you describe your support system?',
      category: QuizCategory.support,
      options: [
        QuizOption('strong', 'Strong network, many supportive people'),
        QuizOption('few_key', 'A few key people I trust'),
        QuizOption('building', 'Building connections, getting there'),
        QuizOption('limited', 'Relatively isolated right now'),
        QuizOption('complicated', 'Have people but it\'s complicated'),
        QuizOption('transition', 'Support system in transition'),
      ],
    ),
  ];
  
  /// Complete quiz flow
  Future<QuizResult> conductQuiz({
    required String userId,
    required Map<QuizQuestion, QuizAnswer> answers,
  }) async {
    // 1. Compile profile from answers
    final profile = _compileProfile(answers);
    
    // 2. Generate inaugural journal entry (350-800 words)
    final entryContent = _entryGenerator.generateInauguralEntry(profile);
    
    // 3. Create journal entry with analysis populated from profile
    final now = DateTime.now();
    final entry = JournalEntry(
      id: _uuid.v4(),
      title: 'Starting My Journey with LUMARA',
      content: entryContent,
      createdAt: now,
      updatedAt: now,
      tags: const ['onboarding', 'phase_quiz_v2', 'inaugural'],
      mood: _mapEmotionalStateToMood(profile.emotionalState),
      keywords: profile.dominantThemes,
      emotion: _mapEmotionalState(profile.emotionalState),
      autoPhase: profile.currentPhase,
      metadata: {
        'source': 'phase_quiz_v2',
        'quiz_profile': profile.toJson(),
        'onboarding': true,
        'inaugural_entry': true,
      },
    );
    
    // 4. Save entry (triggers Layer 0 population via JournalRepository)
    await _journalRepo.createJournalEntry(entry, userId: userId);
    
    // 5. Trigger immediate CHRONICLE synthesis
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    await _synthesisEngine.synthesizeLayer(
      userId: userId,
      layer: ChronicleLayer.monthly,
      period: currentMonth,
    );
    
    return QuizResult(
      userId: userId,
      profile: profile,
      entry: entry,
      timestamp: now,
    );
  }
  
  /// Compile answers into UserProfile
  UserProfile _compileProfile(Map<QuizQuestion, QuizAnswer> answers) {
    final profile = UserProfile();
    
    for (final entry in answers.entries) {
      final question = entry.key;
      final answer = entry.value;
      
      if (answer.isEmpty) continue;
      
      switch (question.id) {
        case 'current_phase':
          profile.currentPhase = answer.selectedOptions.first;
          break;
        case 'primary_focus':
          profile.dominantThemes = answer.selectedOptions;
          break;
        case 'inflection_timing':
          profile.inflectionTiming = answer.selectedOptions.first;
          break;
        case 'emotional_state':
          profile.emotionalState = answer.selectedOptions.first;
          break;
        case 'momentum':
          profile.momentum = answer.selectedOptions.first;
          break;
        case 'stakes':
          profile.stakes = answer.selectedOptions.first;
          break;
        case 'approach_style':
          profile.approachStyle = answer.selectedOptions.first;
          break;
        case 'support':
          profile.support = answer.selectedOptions.first;
          break;
      }
    }
    
    return profile;
  }
  
  /// Map emotional state to JournalEntry emotion field
  String? _mapEmotionalState(String? state) {
    final mapping = {
      'struggling': 'sad',
      'uncertain': 'anxious',
      'stable': 'neutral',
      'hopeful': 'hopeful',
      'energized': 'excited',
      'mixed': 'mixed',
      'numb': 'numb',
    };
    return state != null ? mapping[state] : null;
  }
  
  /// Map emotional state to JournalEntry mood field
  String _mapEmotionalStateToMood(String? state) {
    final mapping = {
      'struggling': 'Reflective',
      'uncertain': 'Thoughtful',
      'stable': 'Neutral',
      'hopeful': 'Hopeful',
      'energized': 'Excited',
      'mixed': 'Complex',
      'numb': 'Contemplative',
    };
    return state != null ? (mapping[state] ?? 'Reflective') : 'Reflective';
  }
}

/// Result of completing the quiz
class QuizResult {
  final String userId;
  final UserProfile profile;
  final JournalEntry entry;
  final DateTime timestamp;
  
  QuizResult({
    required this.userId,
    required this.profile,
    required this.entry,
    required this.timestamp,
  });
}
