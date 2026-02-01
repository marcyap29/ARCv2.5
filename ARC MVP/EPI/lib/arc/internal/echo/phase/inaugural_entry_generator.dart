// lib/arc/internal/echo/phase/inaugural_entry_generator.dart
// Generates comprehensive inaugural journal entry from quiz profile

import 'quiz_models.dart';
import 'quiz_expansion_templates.dart';

class InauguralEntryGenerator {
  final QuizExpansionTemplates _templates = QuizExpansionTemplates();
  
  /// Generate comprehensive 350-800 word journal entry from profile (dynamic structure by emphasis)
  String generateInauguralEntry(UserProfile profile) {
    final buffer = StringBuffer();
    final emotionalState = profile.emotionalState ?? 'uncertain';
    final inflectionTiming = profile.inflectionTiming ?? 'few_months';

    // Title
    buffer.writeln('# Starting My Journey with LUMARA');
    buffer.writeln();
    buffer.writeln('*Generated from onboarding on ${DateTime.now().toString().split(' ')[0]}*');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Always: where I am (phase)
    buffer.writeln('## Where I Am Right Now');
    buffer.writeln();
    buffer.writeln(_templates.expandPhase(profile.currentPhase ?? 'questioning'));
    buffer.writeln();

    // Conditional: lead with emotional landscape for users in difficult states
    if (emotionalState == 'struggling' || emotionalState == 'mixed') {
      buffer.writeln('## My Emotional Reality');
      buffer.writeln();
      buffer.writeln(_templates.expandEmotional(emotionalState));
      buffer.writeln();
    }

    // Always: primary focus
    buffer.writeln('## What\'s Occupying My Mind');
    buffer.writeln();
    final themeList = _formatThemeList(profile.dominantThemes);
    final themeContext = _templates.expandThemeContext(profile.dominantThemes);
    buffer.writeln('Lately, most of my mental energy has been going toward $themeList. $themeContext');
    buffer.writeln();

    // Conditional: temporal context only when significant
    if (_isInflectionSignificant(inflectionTiming)) {
      buffer.writeln('## When This Began');
      buffer.writeln();
      buffer.writeln(_templates.expandInflection(inflectionTiming));
      buffer.writeln();
    }

    // Emotional section if not already shown
    if (emotionalState != 'struggling' && emotionalState != 'mixed') {
      buffer.writeln('## My Emotional Landscape');
      buffer.writeln();
      buffer.writeln(_templates.expandEmotional(emotionalState));
      buffer.writeln();
    }

    // Momentum (with emotional state for nuance)
    buffer.writeln('## The Pattern Over Time');
    buffer.writeln();
    buffer.writeln(_templates.expandMomentum(
      profile.momentum ?? 'stable',
      inflectionTiming,
      emotionalState,
    ));
    buffer.writeln();

    // Stakes
    buffer.writeln('## What Matters Most');
    buffer.writeln();
    buffer.writeln(_templates.expandStakes(
      profile.stakes ?? 'identity',
      profile.dominantThemes,
    ));
    buffer.writeln();

    // Approach & Support
    buffer.writeln('## How I Navigate This');
    buffer.writeln();
    buffer.writeln(_templates.expandApproach(
      profile.approachStyle ?? 'reflective',
      profile.support ?? 'few_key',
    ));
    buffer.writeln();

    // Closing
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('This is where I\'m starting. LUMARA will track how this unfolds from here.');

    return buffer.toString();
  }

  /// Only include temporal context when it's narratively significant
  bool _isInflectionSignificant(String? timing) {
    if (timing == null) return false;
    return timing == 'longer' || timing == 'recent';
  }
  
  String _formatThemeList(List<String> themes) {
    if (themes.isEmpty) return 'various life questions';
    if (themes.length == 1) return _themeDisplayName(themes[0]);
    if (themes.length == 2) return '${_themeDisplayName(themes[0])} and ${_themeDisplayName(themes[1])}';
    
    final allButLast = themes.sublist(0, themes.length - 1).map(_themeDisplayName).join(', ');
    final last = _themeDisplayName(themes.last);
    return '$allButLast, and $last';
  }
  
  String _themeDisplayName(String theme) {
    final names = {
      'career': 'career decisions',
      'relationships': 'relationships',
      'health': 'health and wellbeing',
      'creativity': 'creative expression',
      'learning': 'learning and growth',
      'identity': 'identity questions',
      'purpose': 'life purpose',
      'transition': 'life transitions',
      'financial': 'financial concerns',
      'family': 'family matters',
    };
    return names[theme] ?? theme;
  }
}
