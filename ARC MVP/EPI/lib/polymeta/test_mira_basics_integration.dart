// File: lib/mira/test_mira_basics_integration.dart
//
// Simple test to verify MIRA basics integration works

import 'dart:async';
import 'mira_basics.dart';
import 'adapters/mira_basics_adapters.dart';

/// Test the MIRA basics integration
Future<void> testMiraBasicsIntegration() async {
  print('🧪 Testing MIRA Basics Integration...');
  
  try {
    // Create the provider
    final provider = await MiraBasicsFactory.createProvider();
    print('✅ MiraBasicsProvider created successfully');
    
    // Refresh to build MMCO
    await provider.refresh();
    print('✅ MMCO built successfully');
    
    // Test quick answers
    final qa = QuickAnswers(provider.mmco!);
    print('✅ QuickAnswers created successfully');
    
    // Test some basic questions
    final testQuestions = [
      'What phase am I in?',
      'Show my themes',
      'What is my streak?',
      'When was my last entry?',
      'Hello there', // This should not be handled by quick answers
    ];
    
    for (final question in testQuestions) {
      final canAnswer = qa.canAnswer(question);
      if (canAnswer) {
        final answer = qa.answer(question);
        print('✅ Q: "$question" -> A: "$answer"');
      } else {
        print('⏭️  Q: "$question" -> Not handled by quick answers');
      }
    }
    
    print('🎉 MIRA Basics Integration Test Complete!');
    
  } catch (e) {
    print('❌ Error testing MIRA basics integration: $e');
  }
}
