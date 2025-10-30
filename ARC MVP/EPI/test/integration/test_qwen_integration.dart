// test_qwen_integration.dart
// Simple test to verify QwenAdapter integration

import 'package:flutter/material.dart';
import 'package:my_app/lumara/llm/qwen_adapter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 Testing QwenAdapter Integration...');
  
  // Test 1: Initialize QwenAdapter
  print('\n1. Testing QwenAdapter initialization...');
  final success = await QwenAdapter.initialize();
  print('   QwenAdapter.initialize() returned: $success');
  
  // Test 2: Check if ready
  print('\n2. Testing QwenAdapter readiness...');
  final isReady = QwenAdapter.isReady;
  print('   QwenAdapter.isReady: $isReady');
  
  // Test 3: Check loaded model
  print('\n3. Testing loaded model...');
  final loadedModel = QwenAdapter.loadedModel;
  print('   QwenAdapter.loadedModel: $loadedModel');
  
  // Test 4: Check device capabilities
  print('\n4. Testing device capabilities...');
  final deviceCaps = QwenAdapter.deviceCapabilities;
  print('   QwenAdapter.deviceCapabilities: $deviceCaps');
  
  // Test 5: Test response generation
  if (isReady) {
    print('\n5. Testing response generation...');
    final adapter = QwenAdapter();
    final responseStream = adapter.realize(
      task: 'chat',
      facts: {'total_entries': 8, 'current_phase': 'Discovery'},
      snippets: ['Sample journal entry about growth and discovery'],
      chat: [{'role': 'user', 'content': 'Hello, how are you?'}],
    );
    
    await for (final response in responseStream) {
      print('   Response: $response');
    }
  } else {
    print('\n5. Skipping response generation test (adapter not ready)');
  }
  
  print('\n✅ QwenAdapter integration test completed!');
}
