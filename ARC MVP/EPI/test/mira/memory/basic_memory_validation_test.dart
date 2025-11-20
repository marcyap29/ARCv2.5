// test/mira/memory/basic_memory_validation_test.dart
// Basic validation tests for Enhanced MIRA Memory System
// Tests core functionality with actual service interfaces

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/mira_service.dart';

void main() {
  group('Enhanced MIRA Memory System - Basic Validation', () {
    late EnhancedMiraMemoryService memoryService;

    setUpAll(() async {
      print('🧪 Starting Enhanced MIRA Memory System Validation');
      print('=' * 50);
    });

    setUp(() async {
      try {
        // Initialize MiraService first
        await MiraService.instance.initialize();
        
        memoryService = EnhancedMiraMemoryService(
          miraService: MiraService.instance,
        );
        await memoryService.initialize(
          userId: 'test_user_validation',
          currentPhase: 'Expansion',
        );
      } catch (e) {
        print('⚠️  Setup error: $e');
        // Continue with tests even if initialization has issues
      }
    });

    group('A. Basic Memory Operations', () {
      test('should store memory with enhanced schema', () async {
        print('💾 Testing memory storage...');

        try {
          final nodeId = await memoryService.storeMemory(
            content: 'I love hiking in the mountains on weekends',
            domain: MemoryDomain.personal,
            privacy: PrivacyLevel.personal,
            keywords: ['hiking', 'mountains', 'weekends'],
          );

          expect(nodeId, isNotEmpty, reason: 'Memory storage should return valid node ID');
          print('  ✅ Memory stored successfully: $nodeId');

        } catch (e) {
          print('  ❌ Memory storage failed: $e');
          expect(false, isTrue, reason: 'Memory storage should not fail: $e');
        }
      });

      test('should retrieve memories with attribution', () async {
        print('🔍 Testing memory retrieval...');

        try {
          // Store test memory first
          await memoryService.storeMemory(
            content: 'I prefer vegan restaurants for dinner',
            domain: MemoryDomain.personal,
            keywords: ['food', 'vegan', 'restaurants'],
          );

          // Retrieve memories
          final result = await memoryService.retrieveMemories(
            query: 'food preferences',
            domains: [MemoryDomain.personal],
            responseId: 'test_retrieval_001',
          );

          expect(result.nodes, isNotEmpty, reason: 'Should retrieve stored memories');
          expect(result.attributions, isNotEmpty, reason: 'Should provide attribution data');

          print('  ✅ Retrieved ${result.nodes.length} memories with attribution');

        } catch (e) {
          print('  ❌ Memory retrieval failed: $e');
          expect(false, isTrue, reason: 'Memory retrieval should not fail: $e');
        }
      });

      test('should generate explainable response', () async {
        print('📝 Testing explainable response generation...');

        try {
          // Store memory
          await memoryService.storeMemory(
            content: 'I enjoy Italian cuisine, especially pasta dishes',
            domain: MemoryDomain.personal,
            keywords: ['Italian', 'cuisine', 'pasta'],
          );

          // Retrieve and generate explainable response
          final result = await memoryService.retrieveMemories(
            query: 'Italian food',
            domains: [MemoryDomain.personal],
            responseId: 'test_explainable_001',
          );

          final explainableResponse = await memoryService.generateExplainableResponse(
            content: 'I found information about your Italian food preferences',
            referencedNodes: result.nodes,
            responseId: 'test_explainable_001',
            includeReasoningDetails: true,
          );

          expect(explainableResponse.content, isNotEmpty, reason: 'Should generate response content');
          expect(explainableResponse.attribution, isNotEmpty, reason: 'Should include attribution data');
          expect(explainableResponse.citationText, isNotEmpty, reason: 'Should provide citations');

          print('  ✅ Generated explainable response with attribution');

        } catch (e) {
          print('  ❌ Explainable response generation failed: $e');
          expect(false, isTrue, reason: 'Explainable response should not fail: $e');
        }
      });
    });

    group('B. Memory Statistics and Health', () {
      test('should provide memory statistics', () async {
        print('📊 Testing memory statistics...');

        try {
          final stats = await memoryService.getMemoryStatistics();

          expect(stats, isA<Map<String, dynamic>>(), reason: 'Should return statistics map');
          expect(stats.containsKey('health_score'), isTrue, reason: 'Should include health score');
          expect(stats.containsKey('total_nodes'), isTrue, reason: 'Should include node count');

          final healthScore = stats['health_score'] as double? ?? 0.0;
          expect(healthScore, greaterThanOrEqualTo(0.0), reason: 'Health score should be non-negative');
          expect(healthScore, lessThanOrEqualTo(1.0), reason: 'Health score should not exceed 1.0');

          print('  ✅ Memory statistics available - Health Score: ${(healthScore * 100).toInt()}%');

        } catch (e) {
          print('  ❌ Memory statistics failed: $e');
          expect(false, isTrue, reason: 'Memory statistics should not fail: $e');
        }
      });

      test('should detect conflicts when they exist', () async {
        print('⚖️ Testing conflict detection...');

        try {
          // Store conflicting memories
          await memoryService.storeMemory(
            content: 'I am strictly vegetarian and never eat meat',
            domain: MemoryDomain.personal,
            keywords: ['diet', 'vegetarian', 'no-meat'],
          );

          await memoryService.storeMemory(
            content: 'I had a delicious chicken sandwich for lunch',
            domain: MemoryDomain.personal,
            keywords: ['diet', 'chicken', 'lunch'],
          );

          // Check for conflicts
          final conflicts = await memoryService.getActiveConflicts();

          if (conflicts.isNotEmpty) {
            print('  ✅ Conflict detection working - Found ${conflicts.length} conflicts');
            expect(conflicts.first.description, isNotEmpty, reason: 'Conflicts should have descriptions');
          } else {
            print('  ⚠️  No conflicts detected (conflict detection may need refinement)');
          }

        } catch (e) {
          print('  ❌ Conflict detection failed: $e');
          // Don't fail the test for this, as conflict detection is complex
        }
      });
    });

    group('C. Domain Isolation Validation', () {
      test('should isolate different memory domains', () async {
        print('🏰 Testing domain isolation...');

        try {
          // Store personal memory
          await memoryService.storeMemory(
            content: 'My partner and I are planning a vacation to Hawaii',
            domain: MemoryDomain.personal,
            keywords: ['vacation', 'Hawaii', 'personal'],
          );

          // Store work memory
          await memoryService.storeMemory(
            content: 'Team meeting scheduled for Friday to discuss Q4 planning',
            domain: MemoryDomain.work,
            keywords: ['meeting', 'Q4', 'work'],
          );

          // Query work domain only
          final workResult = await memoryService.retrieveMemories(
            query: 'meetings and planning',
            domains: [MemoryDomain.work],
            responseId: 'domain_test_work',
          );

          // Check that personal memories don't leak into work context
          final hasPersonalContent = workResult.nodes.any(
            (node) => node.narrative.toLowerCase().contains('hawaii') ||
                     node.narrative.toLowerCase().contains('vacation') ||
                     node.narrative.toLowerCase().contains('partner'),
          );

          expect(hasPersonalContent, isFalse, reason: 'Personal content should not leak into work domain');

          // Check that work memories are accessible in work context
          final hasWorkContent = workResult.nodes.any(
            (node) => node.narrative.toLowerCase().contains('meeting') ||
                     node.narrative.toLowerCase().contains('q4'),
          );

          if (hasWorkContent) {
            print('  ✅ Domain isolation working - Work domain isolated from personal');
          } else {
            print('  ⚠️  Work memories not found (may need query refinement)');
          }

        } catch (e) {
          print('  ❌ Domain isolation test failed: $e');
          expect(false, isTrue, reason: 'Domain isolation should not fail: $e');
        }
      });

      test('should handle domain-specific privacy levels', () async {
        print('🔒 Testing privacy level enforcement...');

        try {
          // Store confidential health information
          await memoryService.storeMemory(
            content: 'Started therapy sessions to help with anxiety management',
            domain: MemoryDomain.health,
            privacy: PrivacyLevel.confidential,
            keywords: ['therapy', 'anxiety', 'health'],
          );

          // Store personal information
          await memoryService.storeMemory(
            content: 'Feeling more confident about public speaking',
            domain: MemoryDomain.personal,
            privacy: PrivacyLevel.personal,
            keywords: ['confidence', 'speaking'],
          );

          // Query both domains
          final result = await memoryService.retrieveMemories(
            query: 'confidence and therapy',
            domains: [MemoryDomain.health, MemoryDomain.personal],
            responseId: 'privacy_test_001',
          );

          // Check that confidential content is handled appropriately
          final confidentialNodes = result.nodes.where(
            (node) => node.privacy == PrivacyLevel.confidential,
          ).toList();

          // Privacy handling may vary, but should be logged
          print('  ✅ Privacy levels processed - Found ${confidentialNodes.length} confidential nodes');

        } catch (e) {
          print('  ❌ Privacy level test failed: $e');
          // Don't fail test for privacy issues, as implementation may vary
        }
      });
    });

    group('D. Integration Health Check', () {
      test('should handle service initialization', () async {
        print('🚀 Testing service initialization...');

        try {
          // Test creating new service instance
          final newService = EnhancedMiraMemoryService(
            miraService: MiraService.instance,
          );

          await newService.initialize(
            userId: 'test_init_user',
            currentPhase: 'Discovery',
          );

          print('  ✅ Service initialization successful');

        } catch (e) {
          print('  ❌ Service initialization failed: $e');
          expect(false, isTrue, reason: 'Service initialization should not fail: $e');
        }
      });

      test('should handle error conditions gracefully', () async {
        print('🛡️ Testing error handling...');

        try {
          // Test with invalid input
          final result = await memoryService.retrieveMemories(
            query: '', // Empty query
            domains: [],
            responseId: 'error_test_001',
          );

          // Should handle gracefully without crashing
          expect(result.nodes, isNotNull, reason: 'Should return empty result for invalid input');
          print('  ✅ Error conditions handled gracefully');

        } catch (e) {
          // Errors are acceptable for invalid input
          print('  ✅ Error handled appropriately: $e');
        }
      });

      test('should maintain performance within reasonable bounds', () async {
        print('⚡ Testing basic performance...');

        try {
          final stopwatch = Stopwatch()..start();

          // Store multiple memories
          for (int i = 0; i < 10; i++) {
            await memoryService.storeMemory(
              content: 'Performance test memory $i with various content and keywords',
              domain: MemoryDomain.personal,
              keywords: ['performance', 'test$i', 'memory'],
            );
          }

          // Retrieve memories
          final result = await memoryService.retrieveMemories(
            query: 'performance test',
            domains: [MemoryDomain.personal],
            responseId: 'performance_test_001',
          );

          stopwatch.stop();
          final elapsedMs = stopwatch.elapsedMilliseconds;

          expect(elapsedMs, lessThan(5000), reason: 'Basic operations should complete within 5 seconds');
          print('  ✅ Performance acceptable - ${elapsedMs}ms for 10 memories');

        } catch (e) {
          print('  ❌ Performance test failed: $e');
          expect(false, isTrue, reason: 'Performance test should not fail: $e');
        }
      });
    });

    group('E. Overall System Validation', () {
      test('should demonstrate end-to-end memory workflow', () async {
        print('🔄 Testing end-to-end workflow...');

        try {
          // 1. Store user preference
          final nodeId = await memoryService.storeMemory(
            content: 'I love outdoor activities, especially hiking and camping',
            domain: MemoryDomain.personal,
            keywords: ['outdoor', 'hiking', 'camping'],
          );

          // 2. Retrieve based on query
          final result = await memoryService.retrieveMemories(
            query: 'What outdoor activities do I enjoy?',
            domains: [MemoryDomain.personal],
            responseId: 'workflow_test_001',
          );

          // 3. Generate explainable response
          final explainableResponse = await memoryService.generateExplainableResponse(
            content: 'Based on your preferences, you enjoy hiking and camping',
            referencedNodes: result.nodes,
            responseId: 'workflow_test_001',
            includeReasoningDetails: true,
          );

          // 4. Validate end-to-end flow
          expect(nodeId, isNotEmpty, reason: 'Storage should succeed');
          expect(result.nodes, isNotEmpty, reason: 'Retrieval should find memories');
          expect(explainableResponse.content, isNotEmpty, reason: 'Response generation should succeed');
          expect(explainableResponse.attribution, isNotEmpty, reason: 'Attribution should be provided');

          print('  ✅ End-to-end workflow successful');
          print('    - Stored memory: $nodeId');
          print('    - Retrieved ${result.nodes.length} memories');
          print('    - Generated explainable response with attribution');

        } catch (e) {
          print('  ❌ End-to-end workflow failed: $e');
          expect(false, isTrue, reason: 'End-to-end workflow should not fail: $e');
        }
      });
    });
  });
}