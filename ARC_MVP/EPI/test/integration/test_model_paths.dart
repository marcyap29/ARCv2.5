// Quick test to check model paths and registry
import 'package:flutter/material.dart';
// import 'lib/lumara/llm/bridge.pigeon.dart' as pigeon;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: bridge.pigeon.dart not available - commenting out test
  // final api = pigeon.LumaraNative();

  print('=== Testing Model Paths ===');
  print('⚠️  bridge.pigeon.dart not available - test disabled');
  
  // All test code commented out until bridge.pigeon.dart is available
  /*
  // 1. Self-test
  try {
    final result = await api.selfTest();
    print('✅ Self-test: ${result.message}');
  } catch (e) {
    print('❌ Self-test failed: $e');
    return;
  }

  // 2. Get model root path
  try {
    final rootPath = await api.getModelRootPath();
    print('✅ Model root path: $rootPath');
  } catch (e) {
    print('❌ Get root path failed: $e');
  }

  // 3. List models
  try {
    final registry = await api.availableModels();
    print('✅ Found ${registry.installed.length} models:');
    for (final model in registry.installed) {
      print('   - ${model.id} (${model.format})');

      // Get model status
      try {
        final status = await api.getModelStatus(model.id!);
        print('     Path: ${status.folder}');
        print('     Loaded: ${status.loaded}');
        if (status.missing.isNotEmpty) {
          print('     Missing files: ${status.missing.join(", ")}');
        }
      } catch (e) {
        print('     ❌ Status check failed: $e');
      }
    }
  } catch (e) {
    print('❌ List models failed: $e');
  }
  */
}
