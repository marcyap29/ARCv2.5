// lib/arc/internal/echo/phase/inaugural_entry_generator.dart
// Generates comprehensive inaugural journal entry from quiz profile

import 'quiz_models.dart';
import 'quiz_expansion_templates.dart';

class InauguralEntryGenerator {
  final QuizExpansionTemplates _templates = QuizExpansionTemplates();
  
  /// Generate comprehensive 350-800 word journal entry from profile
  String generateInauguralEntry(UserProfile profile) {
    final buffer = StringBuffer();
    
    // Title
    buffer.writeln('# Starting My Journey with LUMARA');
    buffer.writeln();
    buffer.writeln('*Generated from onboarding on ${DateTime.now().toString().split(' ')[0]}*');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    
    // Section 1: Current State (from phase)
    buffer.writeln('## Where I Am Right Now');
    buffer.writeln();
    buffer.writeln(_templates.expandPhase(profile.currentPhase ?? 'questioning'));
    buffer.writeln();
    
    // Section 2: Primary Focus (from themes)
    buffer.writeln('## What\'s Occupying My Mind');
    buffer.writeln();
    final themeList = _formatThemeList(profile.dominantThemes);
    final themeContext = _templates.expandThemeContext(profile.dominantThemes);
    buffer.writeln('Lately, most of my mental energy has been going toward $themeList. $themeContext');
    buffer.writeln();
    
    // Section 3: Temporal Context (from inflection timing)
    buffer.writeln('## How This Began');
    buffer.writeln();
    buffer.writeln(_templates.expandInflection(profile.inflectionTiming ?? 'few_months'));
    buffer.writeln();
    
    // Section 4: Emotional State
    buffer.writeln('## My Emotional Landscape');
    buffer.writeln();
    buffer.writeln(_templates.expandEmotional(profile.emotionalState ?? 'uncertain'));
    buffer.writeln();
    
    // Section 5: Momentum
    buffer.writeln('## The Pattern Over Time');
    buffer.writeln();
    buffer.writeln(_templates.expandMomentum(
      profile.momentum ?? 'stable',
      profile.inflectionTiming ?? 'few_months',
    ));
    buffer.writeln();
    
    // Section 6: Stakes
    buffer.writeln('## What Matters Most');
    buffer.writeln();
    buffer.writeln(_templates.expandStakes(
      profile.stakes ?? 'identity',
      profile.dominantThemes,
    ));
    buffer.writeln();
    
    // Section 7: Approach & Support
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
