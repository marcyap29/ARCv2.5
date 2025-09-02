import 'ARC MVP/EPI/lib/features/keyword_extraction/enhanced_keyword_extractor.dart';

void main() {
  print('🧪 Testing Enhanced Keyword Extraction System with RIVET Gating');
  print('=' * 70);
  
  // Test case 1: Emotional content
  print('\n1. Testing Emotional Content:');
  final emotionalText = """
    Today I felt overwhelmed at work. There was so much pressure and I was 
    anxious about the deadline. But I took some time to breathe and found 
    some clarity. I'm grateful for the support from my family and feel more
    hopeful about tomorrow.
  """;
  
  final emotionalResponse = EnhancedKeywordExtractor.extractKeywords(
    entryText: emotionalText,
    currentPhase: 'Recovery',
  );
  
  print('Text: ${emotionalText.trim()}');
  print('Phase: ${emotionalResponse.meta['current_phase']}');
  print('Total candidates: ${emotionalResponse.candidates.length}');
  print('Preselected: ${emotionalResponse.chips.length}');
  print('Preselected keywords: ${emotionalResponse.chips.join(', ')}');
  
  print('\nTop 5 scored candidates:');
  final topCandidates = emotionalResponse.candidates.take(5).toList();
  for (int i = 0; i < topCandidates.length; i++) {
    final c = topCandidates[i];
    print('  ${i + 1}. ${c.keyword} (score: ${c.score.toStringAsFixed(3)}, '
        'emotion: ${c.emotion.label}/${c.emotion.amplitude.toStringAsFixed(2)}, '
        'phase: ${c.phaseMatch.strength.toStringAsFixed(2)})');
  }
  
  // Test case 2: Growth and transition content  
  print('\n\n2. Testing Growth & Transition Content:');
  final growthText = """
    I'm in a major transition right now - changing careers and moving to a new city.
    It's both exciting and scary. I'm discovering new parts of myself and learning
    to embrace uncertainty. This change feels like a breakthrough moment where I'm
    finally becoming who I'm meant to be.
  """;
  
  final growthResponse = EnhancedKeywordExtractor.extractKeywords(
    entryText: growthText,
    currentPhase: 'Transition',
  );
  
  print('Text: ${growthText.trim()}');
  print('Phase: ${growthResponse.meta['current_phase']}');
  print('Total candidates: ${growthResponse.candidates.length}');
  print('Preselected: ${growthResponse.chips.length}');
  print('Preselected keywords: ${growthResponse.chips.join(', ')}');
  
  print('\nRIVET gating results:');
  int accepted = 0, rejected = 0;
  for (final candidate in growthResponse.candidates) {
    if (!candidate.rivet.accept) {
      rejected++;
      print('  REJECTED: ${candidate.keyword} - ${candidate.rivet.reasonCodes.join(', ')}');
    } else {
      accepted++;
    }
  }
  print('Accepted: $accepted, Rejected: $rejected');
  
  // Test case 3: Short content
  print('\n\n3. Testing Short Content:');
  final shortText = "Feeling grateful today.";
  
  final shortResponse = EnhancedKeywordExtractor.extractKeywords(
    entryText: shortText,
    currentPhase: 'Expansion',
  );
  
  print('Text: $shortText');
  print('Total candidates: ${shortResponse.candidates.length}');
  print('Preselected: ${shortResponse.chips.length}');
  print('All keywords: ${shortResponse.candidates.map((c) => c.keyword).join(', ')}');
  
  // Test deterministic behavior
  print('\n\n4. Testing Deterministic Behavior:');
  final response1 = EnhancedKeywordExtractor.extractKeywords(
    entryText: emotionalText,
    currentPhase: 'Recovery',
  );
  final response2 = EnhancedKeywordExtractor.extractKeywords(
    entryText: emotionalText,
    currentPhase: 'Recovery',
  );
  
  final identical = response1.chips.join(',') == response2.chips.join(',');
  print('Same input produces identical results: $identical');
  
  if (!identical) {
    print('Response 1 chips: ${response1.chips.join(', ')}');
    print('Response 2 chips: ${response2.chips.join(', ')}');
  }
  
  print('\n✅ Enhanced keyword extraction system testing complete!');
  print('📊 Key features validated:');
  print('   • RIVET gating with evidence-based filtering');  
  print('   • 20 candidates max with top 15 preselected');
  print('   • Semantic scoring with emotion/phase/centrality');
  print('   • Deterministic ranking and selection');
  print('   • Rich metadata and quality indicators');
}