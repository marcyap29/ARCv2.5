// lib/arc/chat/prompts/lumara_prompt_encouragement_data.dart
// Embedded data for LUMARA Prompt Encouragement System
// Contains prompt library and phase-emotion matrix

class LumaraPromptEncouragementData {
  /// Prompt Library v1.0
  /// Organized by ATLAS phase with prompt types and examples
  static const Map<String, dynamic> promptLibrary = {
    'discovery': [
      {
        'type': 'warmStart',
        'prompt': 'What\'s been catching your attention lately — even in small ways?',
      },
      {
        'type': 'sensoryAnchor',
        'prompt': 'Describe where you are right now using colors, textures, or sounds.',
      },
      {
        'type': 'perspectiveShift',
        'prompt': 'If this week were a landscape, what would it look like?',
      },
      {
        'type': 'memoryBridge',
        'prompt':
            'Last time you were in discovery mode, what surprised you most about yourself?',
      },
      {
        'type': 'creativeDiverter',
        'prompt':
            'Imagine your curiosity as a compass. Where is it pointing today?',
      },
    ],
    'expansion': [
      {
        'type': 'warmStart',
        'prompt':
            'What feels like it\'s beginning to bloom in your life right now?',
      },
      {
        'type': 'memoryBridge',
        'prompt':
            'You\'ve been growing in new directions. What\'s been most energizing about that?',
      },
      {
        'type': 'perspectiveShift',
        'prompt':
            'If your energy had a color or rhythm today, what would it be?',
      },
      {
        'type': 'phaseAlignedDeep',
        'prompt':
            'In this Expansion phase, what new possibilities are taking root?',
      },
      {
        'type': 'creativeDiverter',
        'prompt':
            'Write a short letter to the version of you that started this journey. What would you thank them for?',
      },
    ],
    'transition': [
      {
        'type': 'warmStart',
        'prompt':
            'What\'s one thing that feels uncertain — and one thing that feels clear?',
      },
      {
        'type': 'memoryBridge',
        'prompt':
            'Think back to a past transition. What helped you find your footing then?',
      },
      {
        'type': 'sensoryAnchor',
        'prompt':
            'What does change feel like in your body right now — tension, lightness, motion?',
      },
      {
        'type': 'perspectiveShift',
        'prompt':
            'If you could name this turning point, what would you call it?',
      },
      {
        'type': 'phaseAlignedDeep',
        'prompt':
            'Every transition carries a lesson. What might this one be trying to teach you?',
      },
    ],
    'consolidation': [
      {
        'type': 'warmStart',
        'prompt': 'What has felt steady or consistent for you lately?',
      },
      {
        'type': 'memoryBridge',
        'prompt':
            'You\'ve been learning a lot. Which lessons have stayed with you the most?',
      },
      {
        'type': 'sensoryAnchor',
        'prompt':
            'Notice something ordinary that feels grounding right now. Describe it.',
      },
      {
        'type': 'phaseAlignedDeep',
        'prompt':
            'In this phase of consolidation, what are you choosing to keep — and what are you ready to release?',
      },
      {
        'type': 'perspectiveShift',
        'prompt':
            'If your recent experiences were a book, what would the chapter title be?',
      },
    ],
    'recovery': [
      {
        'type': 'warmStart',
        'prompt':
            'You don\'t have to force clarity today. What\'s one small comfort that helps you feel safe?',
      },
      {
        'type': 'memoryBridge',
        'prompt':
            'Think of a time you made it through something hard. What helped you then?',
      },
      {
        'type': 'sensoryAnchor',
        'prompt':
            'Notice your breathing. What\'s one word that matches its rhythm right now?',
      },
      {
        'type': 'phaseAlignedDeep',
        'prompt':
            'In this Recovery phase, what kind of peace are you hoping to rebuild?',
      },
      {
        'type': 'perspectiveShift',
        'prompt': 'If healing had a voice, what would it say to you today?',
      },
    ],
    'breakthrough': [
      {
        'type': 'warmStart',
        'prompt':
            'What realization has been emerging lately — even if it\'s still forming?',
      },
      {
        'type': 'memoryBridge',
        'prompt':
            'Looking back, what patterns finally make sense to you now?',
      },
      {
        'type': 'perspectiveShift',
        'prompt':
            'If you could speak to your past self, what truth would you share from this new clarity?',
      },
      {
        'type': 'phaseAlignedDeep',
        'prompt':
            'This Breakthrough phase often brings alignment. What feels aligned now that didn\'t before?',
      },
      {
        'type': 'creativeDiverter',
        'prompt':
            'Imagine your growth as a constellation. What stars would you name — and what connects them?',
      },
    ],
  };

  /// Phase + Emotion Matrix v1.0
  /// Cross-references ATLAS phases with emotional states for precise prompt generation
  static const Map<String, dynamic> emotionMatrix = {
    'discovery': {
      'emotions': {
        'curious': {
          'tone': 'Light, exploratory',
          'intent': 'sensoryAnchor',
          'prompt':
              'What has sparked your curiosity lately — even something small?',
        },
        'anxious': {
          'tone': 'Reassuring, stabilizing',
          'intent': 'warmStart',
          'prompt':
              'It\'s okay not to have answers yet. What\'s one thing you\'re noticing right now?',
        },
        'hopeful': {
          'tone': 'Encouraging, forward-focused',
          'intent': 'phaseAlignedDeep',
          'prompt':
              'As you explore new ground, what possibilities excite you most?',
        },
        'lost': {
          'tone': 'Gentle, orienting',
          'intent': 'perspectiveShift',
          'prompt':
              'If this moment were a map, where do you feel you\'re standing?',
        },
      },
    },
    'expansion': {
      'emotions': {
        'inspired': {
          'tone': 'Bright, forward-moving',
          'intent': 'warmStart',
          'prompt':
              'What new idea or feeling has been taking shape for you?',
        },
        'overwhelmed': {
          'tone': 'Grounded, simplifying',
          'intent': 'sensoryAnchor',
          'prompt':
              'Pause and take a breath — what\'s the simplest next step that feels right?',
        },
        'confident': {
          'tone': 'Energizing, affirming',
          'intent': 'perspectiveShift',
          'prompt':
              'What strengths are you noticing in yourself as you grow?',
        },
        'restless': {
          'tone': 'Focused, centering',
          'intent': 'memoryBridge',
          'prompt':
              'You\'ve been expanding quickly. What would help you feel balanced right now?',
        },
      },
    },
    'transition': {
      'emotions': {
        'uncertain': {
          'tone': 'Reassuring, clarifying',
          'intent': 'warmStart',
          'prompt':
              'What\'s changing around you — and what\'s staying the same?',
        },
        'reflective': {
          'tone': 'Thoughtful, steady',
          'intent': 'phaseAlignedDeep',
          'prompt':
              'What lesson might this turning point be trying to reveal?',
        },
        'drained': {
          'tone': 'Grounding, restorative',
          'intent': 'sensoryAnchor',
          'prompt': 'What would rest or stillness look like right now?',
        },
        'determined': {
          'tone': 'Purposeful, forward-focused',
          'intent': 'perspectiveShift',
          'prompt':
              'If this change is leading somewhere better, what might that place look like?',
        },
      },
    },
    'consolidation': {
      'emotions': {
        'calm': {
          'tone': 'Integrative, centered',
          'intent': 'warmStart',
          'prompt': 'What has brought you peace or steadiness this week?',
        },
        'grateful': {
          'tone': 'Appreciative, grounded',
          'intent': 'memoryBridge',
          'prompt':
              'Looking back, what are you most thankful for having learned?',
        },
        'reflective': {
          'tone': 'Deep, balanced',
          'intent': 'phaseAlignedDeep',
          'prompt':
              'What insights are settling in as you integrate recent changes?',
        },
        'stuck': {
          'tone': 'Clarifying, unblocking',
          'intent': 'perspectiveShift',
          'prompt':
              'Sometimes growth means staying still. What might patience be teaching you?',
        },
      },
    },
    'recovery': {
      'emotions': {
        'tired': {
          'tone': 'Gentle, restful',
          'intent': 'warmStart',
          'prompt':
              'You\'ve been carrying a lot. What\'s one small comfort that helps you breathe easier?',
        },
        'sad': {
          'tone': 'Compassionate, validating',
          'intent': 'memoryBridge',
          'prompt':
              'Think of a moment when you found light again after darkness. What helped you then?',
        },
        'healing': {
          'tone': 'Soft, affirming',
          'intent': 'phaseAlignedDeep',
          'prompt':
              'In this Recovery phase, what new forms of peace or self-kindness are emerging?',
        },
        'numb': {
          'tone': 'Slow, sensory grounding',
          'intent': 'sensoryAnchor',
          'prompt':
              'What can you see, hear, or touch right now that feels real?',
        },
      },
    },
    'breakthrough': {
      'emotions': {
        'excited': {
          'tone': 'Bright, expansive',
          'intent': 'warmStart',
          'prompt':
              'What realization or opportunity feels alive in you right now?',
        },
        'empowered': {
          'tone': 'Grounded, forward-focused',
          'intent': 'perspectiveShift',
          'prompt':
              'What truth do you now understand that once felt distant?',
        },
        'relieved': {
          'tone': 'Integrative, calm',
          'intent': 'memoryBridge',
          'prompt':
              'You\'ve made it through a lot. What feels resolved or lighter now?',
        },
        'awed': {
          'tone': 'Reflective, visionary',
          'intent': 'phaseAlignedDeep',
          'prompt':
              'This Breakthrough phase often brings clarity. What connection suddenly makes sense?',
        },
      },
    },
  };
}

