// lib/arc/internal/echo/phase/quiz_expansion_templates.dart
// Natural language expansion templates for quiz answers

class QuizExpansionTemplates {
  /// Expand phase into paragraph
  String expandPhase(String phase) {
    final expansions = {
      'recovery': 'I\'m in a recovery phase right now. Something significant happened recently, and I\'m still processing it. There\'s a heaviness, but also the beginning of something new emerging from the difficulty.',
      
      'transition': 'I\'m between chapters. The old way doesn\'t fit anymore, but the new way isn\'t clear yet. I\'m figuring out what comes next, and it feels both unsettling and full of possibility.',
      
      'breakthrough': 'I recently had a major shift in perspective. Something clicked or changed fundamentally, and I\'m seeing things differently now. There\'s energy in this clarity, even if I\'m still figuring out what to do with it.',
      
      'discovery': 'I\'m in exploration mode - curious, open, trying new things. There\'s excitement in discovering what resonates and what doesn\'t. I don\'t need to have it all figured out yet.',
      
      'expansion': 'Things are building momentum right now. Multiple areas of my life are clicking into place, and I\'m riding that forward energy. It feels good to be making progress.',
      
      'consolidation': 'I\'m in a deepening phase - less about adding new things, more about refining and focusing on what truly matters. There\'s satisfaction in going deeper rather than broader.',
      
      'questioning': 'I\'m in a period of uncertainty and reevaluation. What I thought I wanted or believed is being questioned. It\'s uncomfortable, but feels necessary.',
    };
    
    return expansions[phase] ?? 'I\'m in a phase of change and growth.';
  }
  
  /// Expand theme context based on theme combinations
  String expandThemeContext(List<String> themes) {
    if (themes.length < 2) {
      return 'This is where my attention keeps returning.';
    }
    
    // Check for specific theme pairs
    if (themes.contains('career') && themes.contains('identity')) {
      return 'These aren\'t separate concerns - they\'re deeply intertwined. Who I am at work affects how I see myself, and vice versa.';
    }
    
    if (themes.contains('relationships') && themes.contains('identity')) {
      return 'My relationships are forcing me to confront questions about who I am and what I need.';
    }
    
    if (themes.contains('purpose') && themes.contains('career')) {
      return 'I\'m questioning whether my work aligns with what actually matters to me.';
    }
    
    if (themes.contains('health') && themes.contains('identity')) {
      return 'My physical or mental health is intimately connected to how I see myself and what I\'m capable of.';
    }
    
    if (themes.contains('creativity') && themes.contains('identity')) {
      return 'Creative expression feels essential to who I am - it\'s not just a hobby, it\'s part of my core identity.';
    }
    
    if (themes.length >= 3) {
      return 'These areas feel connected, even if I can\'t fully articulate how yet. They\'re all part of the same larger question.';
    }
    
    return 'These concerns are interconnected in ways I\'m still discovering.';
  }
  
  /// Expand inflection timing
  String expandInflection(String timing) {
    final expansions = {
      'recent': 'This is very new - it\'s only been a few weeks. The situation is still unfolding, and I\'m not sure yet what it will become.',
      
      'this_month': 'This began this month. It\'s recent enough that I remember the before clearly, but it\'s already changing how I think and feel.',
      
      'few_months': 'This has been building for the past few months. It started subtly - a growing sense that something needed to change - and has gradually become more urgent and present.',
      
      'this_year': 'This began earlier this year. Looking back, I can see the moment things shifted, even if I didn\'t recognize it fully at the time.',
      
      'last_year': 'This started last year, and it\'s been a constant companion since then. It\'s evolved and changed, but the core concern has remained.',
      
      'longer': 'This has been building for years. It\'s not new, but it feels like it\'s reaching some kind of culmination or decision point now.',
    };
    
    return expansions[timing] ?? 'The timeline of this is still revealing itself to me.';
  }
  
  /// Expand emotional state
  String expandEmotional(String state) {
    final expansions = {
      'struggling': 'I\'m struggling right now. Energy is low, and simple things feel harder than they should. I\'m aware I\'m not at my best, and that awareness itself is heavy.',
      
      'uncertain': 'I\'m in a state of uncertainty and mild anxiety. There\'s tension in not knowing what\'s next, but also awareness that this discomfort might be necessary for growth. Some days feel heavier than others.',
      
      'stable': 'I\'m emotionally stable - not euphoric, but managing well. There\'s a groundedness that helps me navigate the complexity without getting overwhelmed.',
      
      'hopeful': 'There\'s a sense of hope and optimism in how I\'m feeling. Not naive positivity, but genuine belief that things can move in a good direction. It\'s energizing.',
      
      'energized': 'I feel energized and excited. There\'s momentum and possibility in the air. This energy makes everything feel more doable, even the hard parts.',
      
      'mixed': 'My emotional state is intensely mixed - highs and lows that feel almost overwhelming. One moment I\'m hopeful, the next I\'m anxious. The variability itself is exhausting.',
      
      'numb': 'I feel somewhat numb or disconnected. It\'s not depression exactly, more like emotional distance - observing my life from the outside rather than fully feeling it.',
    };
    
    return expansions[state] ?? 'My emotional landscape is complex and still revealing itself.';
  }
  
  /// Expand momentum direction
  String expandMomentum(String momentum, String timing) {
    final isRecent = timing == 'recent' || timing == 'this_month';
    
    final expansions = {
      'intensifying': isRecent 
          ? 'Even though this is relatively new, it\'s already intensifying. It demands more of my attention with each passing day.'
          : 'What started as a quiet concern has grown louder over time. It\'s harder to ignore now, and the urgency to address it is building.',
      
      'resolving': 'I can feel this starting to shift. Not necessarily resolved, but moving toward clarity or resolution. There\'s a sense that the answer is emerging.',
      
      'shifting': 'This isn\'t staying static - it\'s evolving into something different. What I thought this was about is changing, and I\'m discovering new dimensions to the question.',
      
      'stable': 'It\'s steady. Not getting worse, not resolving. Just... present. There\'s something to be said for the stability, even if resolution would be preferable.',
      
      'quieting': 'The urgency is fading. Either I\'m finding peace with it, or it\'s genuinely mattering less. The intensity that was there before has softened.',
      
      'cyclical': 'This comes in waves. Some days it\'s all-consuming, other days it fades to background noise. The cyclical nature makes it hard to get a handle on.',
    };
    
    return expansions[momentum] ?? 'The pattern over time is still revealing itself.';
  }
  
  /// Expand stakes
  String expandStakes(String stakes, List<String> themes) {
    final baseExpansions = {
      'identity': 'What feels most at stake is my sense of who I am - my identity and self-concept. This situation is forcing me to confront fundamental questions about what I value and where I\'m headed.',
      
      'relationships': 'What matters most are my relationships - the connections that ground me and give life meaning. How this resolves will affect those bonds in ways I can\'t fully predict.',
      
      'security': 'My sense of stability and security feels at stake. There\'s vulnerability in not knowing if the foundation I\'ve built will hold, or if I need to rebuild entirely.',
      
      'growth': 'What matters most is whether I\'m actually growing and evolving, or just spinning in circles. This feels like a test of whether I can move forward.',
      
      'meaning': 'The stakes are about meaning and purpose - whether what I\'m doing actually matters, whether I\'m contributing something worthwhile. It\'s an existential question.',
      
      'autonomy': 'My sense of freedom and independence feels at stake. This is about whether I have control over my own direction, or whether I\'m constrained by circumstances beyond my control.',
      
      'health': 'My wellbeing - physical or mental - is what matters most. Everything else is secondary to being healthy enough to engage with life fully.',
      
      'legacy': 'What\'s at stake is longer-term - the impact I\'ll have, what I\'ll leave behind. This isn\'t just about the present; it\'s about the trajectory of my entire life.',
    };
    
    return baseExpansions[stakes] ?? 'What matters most is still revealing itself through this process.';
  }
  
  /// Expand approach and support together
  String expandApproach(String approach, String support) {
    final approachText = {
      'analytical': 'I tend to think things through carefully and plan ahead before taking action.',
      'intuitive': 'I trust my gut and follow what feels right, even when I can\'t fully articulate why.',
      'social': 'I process best by talking things through with others - thinking out loud helps me clarify.',
      'action': 'I\'m action-oriented - I learn by doing and figure things out as I go rather than overplanning.',
      'avoidant': 'I tend to avoid or distract myself until I absolutely have to deal with something. It\'s not ideal, but it\'s honest.',
      'reflective': 'I process through writing and deep reflection, taking time to understand before acting.',
    }[approach] ?? 'I\'m still figuring out my approach to challenges.';
    
    final supportText = {
      'strong': 'I have a strong support network - many people I can turn to when I need perspective or help.',
      'few_key': 'I have a few key people I trust deeply who I can talk this through with.',
      'building': 'I\'m building my support system - the connections are developing, though not fully established yet.',
      'limited': 'I feel relatively isolated in this. I don\'t have many people to turn to right now.',
      'complicated': 'I have people in my life, but those relationships are complicated in ways that make it hard to lean on them.',
      'transition': 'My support system itself is in transition - people who were there before may not be as present now.',
    }[support] ?? 'My support context is evolving.';
    
    return '$approachText $supportText';
  }
}
