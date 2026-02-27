// Simple test to verify attribution system works
import 'package:my_app/mira/memory/attribution_service.dart';

void main() async {
  print('Testing attribution system...');
  
  // Create a simple attribution service
  final attributionService = AttributionService();
  
  // Create a test attribution trace
  final trace = attributionService.createTrace(
    nodeRef: 'test_node_123',
    relation: 'supports',
    confidence: 0.85,
    reasoning: 'This memory supports the user query about personal growth',
  );
  
  print('Created attribution trace:');
  print('- Node Ref: ${trace.nodeRef}');
  print('- Relation: ${trace.relation}');
  print('- Confidence: ${trace.confidence}');
  print('- Reasoning: ${trace.reasoning}');
  print('- Timestamp: ${trace.timestamp}');
  
  print('Attribution system test completed successfully!');
}
