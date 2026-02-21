// Test script to debug pattern analysis service
import 'package:my_app/prism/atlas/phase/pattern_analysis_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';

void main() async {
  print('Testing Pattern Analysis Service...');
  
  final repository = JournalRepository();
  final service = PatternAnalysisService(repository);
  
  // Get all journal entries
  final entries = await repository.getAllJournalEntries();
  print('Total journal entries: ${entries.length}');
  
  if (entries.isNotEmpty) {
    print('First entry: ${entries.first.content.substring(0, 100)}...');
    print('First entry keywords: ${entries.first.keywords}');
  }
  
  // Analyze patterns
  final result = await service.analyzePatterns(
    minWeight: 0.3,
    maxNodes: 8,
  );
  
  final nodes = result.$1;
  final edges = result.$2;
  
  print('\nPattern Analysis Results:');
  print('Nodes: ${nodes.length}');
  print('Edges: ${edges.length}');
  
  if (nodes.isNotEmpty) {
    print('\nTop nodes:');
    for (int i = 0; i < nodes.length && i < 5; i++) {
      final node = nodes[i];
      print('  ${node.label}: ${node.frequency} freq, ${node.emotion} emotion, ${node.phase} phase');
    }
  }
  
  if (edges.isNotEmpty) {
    print('\nTop edges:');
    for (int i = 0; i < edges.length && i < 5; i++) {
      final edge = edges[i];
      print('  ${edge.a} -> ${edge.b}: ${edge.weight.toStringAsFixed(2)}');
    }
  }
}
