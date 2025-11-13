// lib/lumara/services/semantic_similarity_service.dart
// TF-IDF based similarity calculation with boosting

import '../models/reflective_node.dart';

class SemanticSimilarityService {
  // Extract text for comparison
  String gatherText(ReflectiveNode node) {
    return node.contentText ?? 
           node.transcription ?? 
           node.captionText ?? 
           (node.keywords?.join(' ') ?? '');
  }
  
  // Calculate similarity (0.0-1.0) using Jaccard similarity
  double calculateSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return 0.0;
    
    final keywords1 = _extractKeywords(text1);
    final keywords2 = _extractKeywords(text2);
    
    if (keywords1.isEmpty || keywords2.isEmpty) return 0.0;
    
    return _jaccardSimilarity(keywords1, keywords2);
  }
  
  // Boost recent entries slightly
  // [horizonYears] - Can be overridden by settings, default is 5
  double recencyBoost(DateTime? date, {int horizonYears = 5}) {
    if (date == null) return 1.0;
    
    final ageYears = DateTime.now().difference(date).inDays / 365.0;
    if (ageYears > horizonYears) return 0.8;       // outside window, slight penalty
    if (ageYears < 0.25) return 1.10;              // last ~3 months
    if (ageYears < 1.0) return 1.05;               // last year
    return 1.0;
  }
  
  // Boost same/adjacent phases
  double phaseBoost(PhaseHint? phase1, PhaseHint? phase2) {
    if (phase1 == null || phase2 == null) return 1.0;
    if (phase1 == phase2) return 1.10;
    
    // Adjacent phase logic
    final adjacencies = {
      PhaseHint.discovery: [PhaseHint.expansion, PhaseHint.transition],
      PhaseHint.expansion: [PhaseHint.discovery, PhaseHint.transition, PhaseHint.consolidation],
      PhaseHint.transition: [PhaseHint.discovery, PhaseHint.expansion, PhaseHint.consolidation, PhaseHint.recovery],
      PhaseHint.consolidation: [PhaseHint.expansion, PhaseHint.recovery],
      PhaseHint.recovery: [PhaseHint.consolidation, PhaseHint.transition],
      PhaseHint.breakthrough: [PhaseHint.expansion, PhaseHint.transition],
    };
    
    return adjacencies[phase1]?.contains(phase2) == true ? 1.05 : 0.98;
  }
  
  // Boost for keyword overlap
  double keywordOverlapBoost(String currentText, List<String>? nodeKeywords) {
    if (nodeKeywords == null || nodeKeywords.isEmpty) return 1.0;
    
    final currentKeywords = _extractKeywords(currentText);
    if (currentKeywords.isEmpty) return 1.0;
    
    final overlap = currentKeywords.where((k) => nodeKeywords.contains(k)).length;
    final total = currentKeywords.length;
    
    if (total == 0) return 1.0;
    
    final overlapRatio = overlap / total;
    return 1.0 + (overlapRatio * 0.1); // Up to 10% boost
  }
  
  // Combined scoring
  double scoreNode(
    String currentText,
    ReflectiveNode node,
    PhaseHint? currentPhase,
  ) {
    final nodeText = gatherText(node);
    final baseSimilarity = calculateSimilarity(currentText, nodeText);
    final rBoost = recencyBoost(node.createdAt);
    final pBoost = phaseBoost(currentPhase, node.phaseHint);
    final kBoost = keywordOverlapBoost(currentText, node.keywords);
    
    return baseSimilarity * rBoost * pBoost * kBoost;
  }
  
  // Extract keywords from text
  List<String> _extractKeywords(String text) {
    if (text.isEmpty) return [];
    
    // Simple keyword extraction
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3)
        .toList();
    
    // Count word frequency
    final wordCount = <String, int>{};
    for (final word in words) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }
    
    // Return top 10 most frequent words
    final sortedWords = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedWords.take(10).map((e) => e.key).toList();
  }
  
  // Calculate Jaccard similarity between two sets
  double _jaccardSimilarity(List<String> set1, List<String> set2) {
    if (set1.isEmpty && set2.isEmpty) return 1.0;
    if (set1.isEmpty || set2.isEmpty) return 0.0;
    
    final intersection = set1.where((item) => set2.contains(item)).length;
    final union = set1.toSet().union(set2.toSet()).length;
    
    return intersection / union;
  }
}