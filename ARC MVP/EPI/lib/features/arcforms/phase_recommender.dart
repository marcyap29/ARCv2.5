class PhaseRecommender {
  static String recommend({
    required String emotion,
    required String reason,
    required String text,
  }) {
    final e = emotion.toLowerCase();
    final r = reason.toLowerCase();
    final t = text.toLowerCase();
    
    // Strong emotion-based recommendations
    if (['depressed', 'tired', 'stressed', 'anxious', 'angry'].any(e.contains)) {
      return 'Recovery';
    }
    if (['excited', 'curious', 'hopeful'].any(e.contains)) {
      return 'Discovery';
    }
    if (['happy', 'blessed', 'grateful', 'energized', 'relaxed'].any(e.contains)) {
      return 'Expansion';
    }
    
    // Content-based analysis
    bool has(String keyword) => t.contains(keyword);
    
    // Transition indicators
    if (['relationship', 'work', 'school', 'family'].any(r.contains) &&
        (has('switch') || has('move') || has('change') || has('leaving') || has('transition'))) {
      return 'Transition';
    }
    
    // Consolidation indicators
    if (has('integrate') || has('organize') || has('weave') || has('routine') || has('habit') ||
        has('ground') || has('settle') || has('stable') || has('consistency')) {
      return 'Consolidation';
    }
    
    // Breakthrough indicators
    if (has('epiphany') || has('breakthrough') || has('suddenly') || has('realized') ||
        has('clarity') || has('insight') || has('understand') || has('aha')) {
      return 'Breakthrough';
    }
    
    // Recovery indicators (beyond emotion)
    if (has('rest') || has('heal') || has('recover') || has('gentle') || has('breathe') ||
        has('peace') || has('calm') || has('restore')) {
      return 'Recovery';
    }
    
    // Expansion indicators
    if (has('grow') || has('expand') || has('reach') || has('possibility') || has('energy') ||
        has('outward') || has('more') || has('bigger') || has('increase')) {
      return 'Expansion';
    }
    
    // Discovery indicators
    if (has('explore') || has('new') || has('curiosity') || has('wonder') || has('question') ||
        has('learn') || has('discover') || has('beginning') || has('start')) {
      return 'Discovery';
    }
    
    // Default to Discovery for gentle beginning
    return 'Discovery';
  }

  static String rationale(String phase) {
    switch (phase) {
      case 'Recovery':
        return 'Your emotion suggests rest and repair.';
      case 'Discovery':
        return 'Your emotion points toward curiosity and exploration.';
      case 'Expansion':
        return 'Your tone suggests growth and outward energy.';
      case 'Transition':
        return 'Your words hint at change and movement between places.';
      case 'Consolidation':
        return 'You mentioned integration and grounding.';
      case 'Breakthrough':
        return 'You referenced sudden clarity or insight.';
      default:
        return 'A gentle starting place for this moment.';
    }
  }
}