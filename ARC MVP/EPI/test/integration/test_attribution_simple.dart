// Simple test to verify attribution system works
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/attribution_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';

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
