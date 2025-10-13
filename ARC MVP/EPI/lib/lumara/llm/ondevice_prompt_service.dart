// lib/lumara/llm/ondevice_prompt_service.dart
// Dedicated prompt service for on-device LLMs with strict word limits

import 'package:flutter/foundation.dart';

class OnDevicePromptService {
  /// Create a concise prompt for on-device LLMs (5-10 words, 1-2 sentences)
  static String createJournalPrompt(String text, String phase) {
    // Get phase-specific style hint
    final phaseStyle = _getPhaseStyle(phase);
    
    // Extract key themes from the text to make responses more relevant
    final themes = _extractThemes(text);
    final themeContext = themes.isNotEmpty ? 'Themes: ${themes.join(', ')}' : '';
    
    // Add variety to the prompt structure with more diverse approaches
    final prompts = [
      '''Read this journal entry: "$text"

${phaseStyle.isNotEmpty ? 'PHASE: $phase\nPHASE STYLE: $phaseStyle\n' : ''}${themeContext.isNotEmpty ? '$themeContext\n' : ''}Write a micro-reflection (1-2 sentences, 5-10 words) that directly responds to what they wrote.''',
      
      '''JOURNAL ENTRY: "$text"

${phaseStyle.isNotEmpty ? 'PHASE: $phase\nPHASE STYLE: $phaseStyle\n' : ''}${themeContext.isNotEmpty ? '$themeContext\n' : ''}TASK: Write a micro-reflection (5-10 words, max 2 sentences) that relates to their specific content.''',
      
      '''User wrote: "$text"

${phaseStyle.isNotEmpty ? 'Phase: $phase\nTone: $phaseStyle\n' : ''}${themeContext.isNotEmpty ? '$themeContext\n' : ''}Respond with empathy and clarity in no more than two short sentences (5-10 words total) about their writing.''',
      
      '''Entry content: "$text"

${phaseStyle.isNotEmpty ? 'Phase: $phase\nStyle: $phaseStyle\n' : ''}${themeContext.isNotEmpty ? '$themeContext\n' : ''}Offer a brief, supportive insight (5-10 words, 1-2 sentences) that connects to their specific words.''',
      
      '''They shared: "$text"

${phaseStyle.isNotEmpty ? 'Phase: $phase\nApproach: $phaseStyle\n' : ''}${themeContext.isNotEmpty ? '$themeContext\n' : ''}Provide a gentle, thoughtful response (5-10 words) that acknowledges their specific experience.''',
      
      '''Journal text: "$text"

${phaseStyle.isNotEmpty ? 'Phase: $phase\nGuidance: $phaseStyle\n' : ''}${themeContext.isNotEmpty ? '$themeContext\n' : ''}Share a brief, encouraging reflection (5-10 words, 1-2 sentences) that builds on their specific thoughts.''',
    ];
    
    // Use current time to select a random prompt for variety
    final index = DateTime.now().millisecondsSinceEpoch % prompts.length;
    return prompts[index];
  }

  /// Create phase-specific guidance for on-device LLMs
  static String getPhaseSpecificGuidance(String phase) {
    // Add variety to phase-specific guidance
    final discoveryPrompts = [
      'Ask 1 question (5-10 words) that encourages deeper exploration.',
      'Ask 1 question (5-10 words) that opens new possibilities.',
      'Ask 1 question (5-10 words) that sparks curiosity.',
      'Ask 1 question (5-10 words) that invites fresh perspective.',
      'Ask 1 question (5-10 words) that encourages gentle exploration.',
      'Ask 1 question (5-10 words) that sparks wonder and inquiry.',
    ];
    
    final breakthroughPrompts = [
      'Ask 1 question (5-10 words) that celebrates and builds on insights.',
      'Ask 1 question (5-10 words) that honors this breakthrough moment.',
      'Ask 1 question (5-10 words) that channels this energy forward.',
    ];
    
    final expansionPrompts = [
      'Ask 1 question (5-10 words) that supports continued growth.',
      'Ask 1 question (5-10 words) that expands this momentum.',
      'Ask 1 question (5-10 words) that builds on this progress.',
    ];
    
    final transitionPrompts = [
      'Ask 1 question (5-10 words) that helps navigate change smoothly.',
      'Ask 1 question (5-10 words) that supports this transition.',
      'Ask 1 question (5-10 words) that eases this shift.',
    ];
    
    final consolidationPrompts = [
      'Ask 1 question (5-10 words) that helps organize and connect ideas.',
      'Ask 1 question (5-10 words) that solidifies these learnings.',
      'Ask 1 question (5-10 words) that integrates these insights.',
    ];
    
    final recoveryPrompts = [
      'Ask 1 question (5-10 words) that emphasizes self-care and healing.',
      'Ask 1 question (5-10 words) that supports gentle restoration.',
      'Ask 1 question (5-10 words) that honors this healing process.',
    ];
    
    final defaultPrompts = [
      'Ask 1 question (5-10 words) that helps them reflect deeper.',
      'Ask 1 question (5-10 words) that offers gentle guidance.',
      'Ask 1 question (5-10 words) that encourages thoughtful consideration.',
    ];
    
    List<String> prompts;
    switch (phase.toLowerCase()) {
      case 'discovery':
        prompts = discoveryPrompts;
        break;
      case 'breakthrough':
        prompts = breakthroughPrompts;
        break;
      case 'expansion':
        prompts = expansionPrompts;
        break;
      case 'transition':
        prompts = transitionPrompts;
        break;
      case 'consolidation':
        prompts = consolidationPrompts;
        break;
      case 'recovery':
        prompts = recoveryPrompts;
        break;
      default:
        prompts = defaultPrompts;
    }
    
    // Use current time to select a random prompt for variety
    final index = DateTime.now().millisecondsSinceEpoch % prompts.length;
    return prompts[index];
  }

  /// Format prompt specifically for on-device models (Llama, Qwen)
  static String formatOnDevicePrompt(String systemPrompt, String userPrompt) {
    // Optimized system prompt for on-device LLMs
    const optimizedSystemPrompt = '''You are LUMARA, a reflective journaling assistant.
Read the journal entry carefully and respond specifically to what the person wrote.
Respond with empathy and clarity in no more than two short sentences.
Keep responses concise (5-10 meaningful words total).
Make your response directly relevant to their specific content and themes.
Avoid generic questions - respond to their actual words and experiences.
Use calm, emotionally balanced tone that acknowledges their specific situation.''';

    return '''$optimizedSystemPrompt

$userPrompt''';
  }

  /// Clean and truncate response from on-device models
  static String cleanOnDeviceResponse(String response) {
    // Remove common artifacts
    String cleaned = response
        .replaceAll(RegExp(r'\[INST\].*?\[/INST\]', dotAll: true), '')
        .replaceAll(RegExp(r'<s>|</s>'), '')
        .replaceAll(RegExp(r'<<SYS>>.*?<</SYS>>', dotAll: true), '')
        .replaceAll(RegExp(r'^\s*[:\-•]\s*'), '') // Remove bullet points
        .trim();

    // Enforce 5-10 word limit
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.length > 10) {
      cleaned = words.take(10).join(' ');
    }
    
    // Ensure it's 1-2 sentences max
    final sentences = cleaned.split(RegExp(r'[.!?]+'));
    if (sentences.length > 2) {
      cleaned = sentences.take(2).join('. ').trim();
      if (!cleaned.endsWith('.') && !cleaned.endsWith('!') && !cleaned.endsWith('?')) {
        cleaned += '.';
      }
    } else if (sentences.isNotEmpty) {
      cleaned = sentences.first.trim();
      if (!cleaned.endsWith('.') && !cleaned.endsWith('!') && !cleaned.endsWith('?')) {
        cleaned += '.';
      }
    }

    return cleaned;
  }

  /// Find similar entries for context (simplified for on-device)
  static List<String> _findSimilarEntries(String currentText) {
    try {
      // Extract key themes from current text
      final themes = _extractThemes(currentText);
      if (themes.isEmpty) return [];
      
      // Return example similar themes based on keywords
      final similarThemes = <String>[];
      
      for (final theme in themes) {
        if (theme.toLowerCase().contains('happiness') || theme.toLowerCase().contains('joy')) {
          similarThemes.add('previous joy moments');
        } else if (theme.toLowerCase().contains('sadness') || theme.toLowerCase().contains('difficult')) {
          similarThemes.add('past challenges');
        } else if (theme.toLowerCase().contains('work') || theme.toLowerCase().contains('career')) {
          similarThemes.add('work reflections');
        } else if (theme.toLowerCase().contains('relationship') || theme.toLowerCase().contains('family')) {
          similarThemes.add('relationship insights');
        } else if (theme.toLowerCase().contains('goal') || theme.toLowerCase().contains('future')) {
          similarThemes.add('future planning');
        }
      }
      
      return similarThemes.take(3).toList();
    } catch (e) {
      debugPrint('OnDevicePromptService: Error finding similar entries: $e');
      return [];
    }
  }

  /// Extract themes from text (simplified for on-device)
  static List<String> _extractThemes(String text) {
    final themes = <String>[];
    final lowerText = text.toLowerCase();
    
    // Enhanced keyword-based theme extraction
    if (lowerText.contains('happy') || lowerText.contains('joy') || lowerText.contains('excited') || 
        lowerText.contains('celebrate') || lowerText.contains('grateful') || lowerText.contains('blessed')) {
      themes.add('happiness');
    }
    if (lowerText.contains('sad') || lowerText.contains('difficult') || lowerText.contains('struggle') ||
        lowerText.contains('hard') || lowerText.contains('tough') || lowerText.contains('challenge') ||
        lowerText.contains('stress') || lowerText.contains('overwhelmed') || lowerText.contains('anxious')) {
      themes.add('challenges');
    }
    if (lowerText.contains('work') || lowerText.contains('job') || lowerText.contains('career') ||
        lowerText.contains('office') || lowerText.contains('meeting') || lowerText.contains('project')) {
      themes.add('work');
    }
    if (lowerText.contains('relationship') || lowerText.contains('family') || lowerText.contains('friend') ||
        lowerText.contains('partner') || lowerText.contains('love') || lowerText.contains('marriage') ||
        lowerText.contains('parent') || lowerText.contains('child') || lowerText.contains('sibling')) {
      themes.add('relationships');
    }
    if (lowerText.contains('goal') || lowerText.contains('future') || lowerText.contains('plan') ||
        lowerText.contains('dream') || lowerText.contains('aspire') || lowerText.contains('want') ||
        lowerText.contains('hope') || lowerText.contains('wish') || lowerText.contains('ambition')) {
      themes.add('goals');
    }
    if (lowerText.contains('learn') || lowerText.contains('grow') || lowerText.contains('improve') ||
        lowerText.contains('develop') || lowerText.contains('progress') || lowerText.contains('better') ||
        lowerText.contains('change') || lowerText.contains('evolve') || lowerText.contains('transform')) {
      themes.add('growth');
    }
    if (lowerText.contains('health') || lowerText.contains('exercise') || lowerText.contains('fitness') ||
        lowerText.contains('wellness') || lowerText.contains('medical') || lowerText.contains('doctor') ||
        lowerText.contains('pain') || lowerText.contains('sick') || lowerText.contains('healing')) {
      themes.add('health');
    }
    if (lowerText.contains('money') || lowerText.contains('financial') || lowerText.contains('budget') ||
        lowerText.contains('debt') || lowerText.contains('save') || lowerText.contains('invest') ||
        lowerText.contains('expensive') || lowerText.contains('cheap') || lowerText.contains('cost')) {
      themes.add('finance');
    }
    if (lowerText.contains('travel') || lowerText.contains('trip') || lowerText.contains('vacation') ||
        lowerText.contains('journey') || lowerText.contains('adventure') || lowerText.contains('explore') ||
        lowerText.contains('visit') || lowerText.contains('place') || lowerText.contains('country')) {
      themes.add('travel');
    }
    if (lowerText.contains('creative') || lowerText.contains('art') || lowerText.contains('music') ||
        lowerText.contains('write') || lowerText.contains('paint') || lowerText.contains('draw') ||
        lowerText.contains('design') || lowerText.contains('craft') || lowerText.contains('make')) {
      themes.add('creativity');
    }
    
    return themes;
  }

  /// Get phase-specific style hint for on-device LLMs
  static String _getPhaseStyle(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return 'Curious, observational. Invite noticing and one tiny step.';
      case 'expansion':
        return 'Energized, outward. Reinforce momentum and focused growth.';
      case 'transition':
        return 'Steady amid change. Normalize uncertainty; suggest small experiments.';
      case 'consolidation':
        return 'Grounding, ordered. Emphasize integration, routines, commitments.';
      case 'recovery':
        return 'Gentle, protective. Honor limits; celebrate small restorations.';
      case 'breakthrough':
        return 'Clear, catalytic. Name the shift; suggest direction.';
      default:
        return 'Calm, empathetic. Offer gentle insight and support.';
    }
  }
}
