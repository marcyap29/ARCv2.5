// test/mira/memory/memory_system_integration_test.dart
// Integration tests for Enhanced MIRA Memory System
// Real-world testing against the integrated LUMARA system

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/lumara/data/context_provider.dart';
import 'package:my_app/lumara/data/models/lumara_message.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'golden_prompts_harness.dart';

void main() {
  group('Enhanced MIRA Memory System Integration Tests', () {
    late LumaraAssistantCubit lumaraCubit;
    late EnhancedMiraMemoryService memoryService;
    late ContextProvider contextProvider;

    setUp(() async {
      // Initialize test context provider
      contextProvider = MockContextProvider();

      // Initialize LUMARA cubit with enhanced memory
      lumaraCubit = LumaraAssistantCubit(
        contextProvider: contextProvider,
      );

      await lumaraCubit.initialize();

      // Get the enhanced memory service from the cubit
      memoryService = lumaraCubit._memoryService!;
    });

    group('A. Real-World Memory Commands Testing', () {
      test('should handle /memory show command', () async {
        // Store some test memories first
        await memoryService.storeMemory(
          content: 'I love hiking in the mountains',
          domain: MemoryDomain.personal,
          keywords: ['hiking', 'mountains', 'nature'],
        );

        await memoryService.storeMemory(
          content: 'Team standup every Monday at 9am',
          domain: MemoryDomain.work,
          keywords: ['standup', 'Monday', 'team'],
        );

        // Test memory show command
        await lumaraCubit.sendMessage('/memory show');

        final state = lumaraCubit.state as LumaraAssistantLoaded;
        final lastMessage = state.messages.last;

        expect(lastMessage.role, MessageRole.assistant);
        expect(lastMessage.content, contains('Memory System Status'));
        expect(lastMessage.content, contains('Total Nodes'));
        expect(lastMessage.content, contains('Health Score'));
      });

      test('should handle /memory conflicts command', () async {
        // Store conflicting memories
        await memoryService.storeMemory(
          content: 'I am a vegetarian',
          domain: MemoryDomain.personal,
          keywords: ['diet', 'vegetarian'],
        );

        await memoryService.storeMemory(
          content: 'I ate chicken for dinner yesterday',
          domain: MemoryDomain.personal,
          keywords: ['diet', 'chicken', 'meat'],
        );

        // Test conflicts command
        await lumaraCubit.sendMessage('/memory conflicts');

        final state = lumaraCubit.state as LumaraAssistantLoaded;
        final lastMessage = state.messages.last;

        expect(lastMessage.content, anyOf(
          contains('Active Memory Conflicts'),
          contains('No Active Memory Conflicts'),
        ));
      });

      test('should handle /memory domains command', () async {
        await lumaraCubit.sendMessage('/memory domains');

        final state = lumaraCubit.state as LumaraAssistantLoaded;
        final lastMessage = state.messages.last;

        expect(lastMessage.content, contains('Memory Domains Overview'));
        expect(lastMessage.content, contains('Personal'));
        expect(lastMessage.content, contains('Work'));
        expect(lastMessage.content, contains('Creative'));
      });

      test('should handle /memory health command', () async {
        await lumaraCubit.sendMessage('/memory health');

        final state = lumaraCubit.state as LumaraAssistantLoaded;
        final lastMessage = state.messages.last;

        expect(lastMessage.content, contains('Memory System Health'));
        expect(lastMessage.content, contains('Overall Score'));
        expect(lastMessage.content, contains('Key Metrics'));
      });

      test('should handle /memory export command', () async {
        await lumaraCubit.sendMessage('/memory export');

        final state = lumaraCubit.state as LumaraAssistantLoaded;
        final lastMessage = state.messages.last;

        expect(lastMessage.content, contains('Memory Export'));
        expect(lastMessage.content, contains('MCP Bundle'));
        expect(lastMessage.content, contains('User Sovereignty'));
      });
    });

    group('B. Attribution and Explainability Integration', () {
      test('should provide memory attribution in AI responses', () async {
        // Store relevant memory
        await memoryService.storeMemory(
          content: 'I prefer Italian restaurants for dinner',
          domain: MemoryDomain.personal,
          keywords: ['food', 'Italian', 'restaurants'],
        );

        // Ask a food-related question
        await lumaraCubit.sendMessage('Recommend a place for dinner tonight');

        final state = lumaraCubit.state as LumaraAssistantLoaded;
        final lastMessage = state.messages.last;

        // Response should be enhanced with memory attribution
        // Note: This tests the integration, actual AI response would vary
        expect(lastMessage.role, MessageRole.assistant);
        expect(lastMessage.content, isNotEmpty);

        // Verify memory was accessed (internal service call)
        final stats = await memoryService.getMemoryStatistics();
        expect(stats['recent_activity'], greaterThan(0));
      });

      test('should record conversation messages in memory', () async {
        const userMessage = 'I just started learning guitar';
        const expectedKeywords = ['guitar', 'learning', 'music'];

        await lumaraCubit.sendMessage(userMessage);

        // Verify message was stored in memory
        final result = await memoryService.retrieveMemories(
          query: 'guitar learning',
          domains: [MemoryDomain.personal],
          responseId: 'test_verification',
        );

        expect(result.nodes, isNotEmpty);

        final guitarMemory = result.nodes.firstWhere(
          (n) => n.content.contains('guitar'),
          orElse: () => throw Exception('Guitar memory not found'),
        );

        expect(guitarMemory.domain, MemoryDomain.personal);
        expect(guitarMemory.source, 'LUMARA_Chat');
        expect(guitarMemory.metadata['role'], 'user');
      });

      test('should maintain phase awareness in memory storage', () async {
        // Set specific phase context
        final testPhase = 'Expansion';

        await lumaraCubit.sendMessage('I am exploring new creative projects');

        final result = await memoryService.retrieveMemories(
          query: 'creative projects',
          domains: [MemoryDomain.creative],
          responseId: 'phase_test',
        );

        expect(result.nodes, isNotEmpty);

        final creativeMemory = result.nodes.firstWhere(
          (n) => n.content.contains('creative'),
        );

        expect(creativeMemory.phaseContext, contains('Expansion'));
      });
    });

    group('C. Domain Isolation and Privacy', () {
      test('should isolate work and personal domains', () async {
        // Store personal memory
        await memoryService.storeMemory(
          content: 'My partner and I are planning a vacation to Hawaii',
          domain: MemoryDomain.personal,
          privacy: PrivacyLevel.personal,
          keywords: ['vacation', 'Hawaii', 'partner'],
        );

        // Store work memory
        await memoryService.storeMemory(
          content: 'Quarterly review meeting scheduled for next Friday',
          domain: MemoryDomain.work,
          keywords: ['review', 'meeting', 'quarterly'],
        );

        // Test work context query
        final workResult = await memoryService.retrieveMemories(
          query: 'What meetings do I have coming up?',
          domains: [MemoryDomain.work],
          responseId: 'work_context_test',
        );

        // Should only include work memories
        final workMemories = workResult.nodes.where(
          (n) => n.domain == MemoryDomain.work,
        ).toList();

        final personalMemories = workResult.nodes.where(
          (n) => n.domain == MemoryDomain.personal,
        ).toList();

        expect(workMemories, isNotEmpty);
        expect(personalMemories, isEmpty);
        expect(workResult.nodes.any((n) => n.content.contains('Hawaii')), isFalse);
      });

      test('should handle cross-domain queries with consent', () async {
        // Store memories in different domains
        await memoryService.storeMemory(
          content: 'Important client call on Thursday',
          domain: MemoryDomain.work,
          keywords: ['client', 'call', 'Thursday'],
        );

        await memoryService.storeMemory(
          content: 'Doctor appointment on Thursday',
          domain: MemoryDomain.health,
          keywords: ['doctor', 'appointment', 'Thursday'],
        );

        // Cross-domain query with consent
        final crossDomainResult = await memoryService.retrieveMemories(
          query: 'What do I have scheduled for Thursday?',
          domains: [MemoryDomain.work, MemoryDomain.health],
          crossDomainConsent: true,
          responseId: 'cross_domain_test',
        );

        final workMemories = crossDomainResult.nodes.where(
          (n) => n.domain == MemoryDomain.work,
        ).length;

        final healthMemories = crossDomainResult.nodes.where(
          (n) => n.domain == MemoryDomain.health,
        ).length;

        expect(workMemories, greaterThan(0));
        expect(healthMemories, greaterThan(0));
      });
    });

    group('D. Golden Prompts Automated Evaluation', () {
      test('should pass basic memory retrieval golden prompts', () async {
        final harness = GoldenPromptsHarness(
          memoryService: memoryService,
          goldenPrompts: StandardGoldenPrompts.basicMemoryRetrieval,
        );

        final results = await harness.runEvaluation();

        // All basic tests should pass
        final passedCount = results.where((r) => r.passed).length;
        final totalCount = results.length;

        expect(passedCount, equals(totalCount),
          reason: 'All basic memory retrieval tests should pass');

        // Check specific test scores
        for (final result in results) {
          expect(result.score, greaterThan(80.0),
            reason: 'Test ${result.promptId} should score above 80%');
        }
      });

      test('should pass domain isolation golden prompts', () async {
        final harness = GoldenPromptsHarness(
          memoryService: memoryService,
          goldenPrompts: StandardGoldenPrompts.domainIsolation,
        );

        final results = await harness.runEvaluation();

        // Domain isolation is critical - all tests must pass
        for (final result in results) {
          expect(result.passed, isTrue,
            reason: 'Domain isolation test ${result.promptId} failed: ${result.errors}');
        }

        // Check domain isolation score
        final isolationScores = results
            .map((r) => r.metrics['domain_isolation_score'] as double? ?? 0.0)
            .toList();

        expect(isolationScores.every((score) => score == 1.0), isTrue,
          reason: 'All domain isolation scores should be perfect (1.0)');
      });

      test('should pass performance requirements', () async {
        final harness = GoldenPromptsHarness(
          memoryService: memoryService,
          goldenPrompts: StandardGoldenPrompts.performanceTests,
        );

        final results = await harness.runEvaluation();

        for (final result in results) {
          expect(result.executionTime.inMilliseconds, lessThan(150),
            reason: 'Performance test ${result.promptId} exceeded latency budget');
        }
      });

      test('should generate comprehensive evaluation report', () async {
        final harness = GoldenPromptsHarness(
          memoryService: memoryService,
          goldenPrompts: StandardGoldenPrompts.all.take(5).toList(),
        );

        final results = await harness.runEvaluation();
        final report = harness.generateReport(results);

        expect(report, contains('Golden Prompts Evaluation Report'));
        expect(report, contains('Summary'));
        expect(report, contains('Pass Rate'));
        expect(report, contains('Average Score'));
        expect(report, contains('Memory Precision'));
        expect(report, contains('Attribution Coverage'));

        print('Evaluation Report:');
        print(report);
      });
    });

    group('E. Error Handling and Edge Cases', () {
      test('should handle empty memory gracefully', () async {
        // Query with no stored memories
        final result = await memoryService.retrieveMemories(
          query: 'Tell me about something that does not exist',
          domains: [MemoryDomain.personal],
          responseId: 'empty_test',
        );

        expect(result.nodes, isEmpty);
        expect(result.attributions, isEmpty);
      });

      test('should handle invalid memory commands', () async {
        await lumaraCubit.sendMessage('/memory invalidcommand');

        final state = lumaraCubit.state as LumaraAssistantLoaded;
        final lastMessage = state.messages.last;

        expect(lastMessage.content, contains('Enhanced Memory Commands'));
        expect(lastMessage.content, contains('/memory show'));
      });

      test('should maintain performance with large memory sets', () async {
        // Store many memories
        for (int i = 0; i < 50; i++) {
          await memoryService.storeMemory(
            content: 'Performance test memory $i with various content',
            domain: MemoryDomain.personal,
            keywords: ['performance', 'test$i'],
          );
        }

        final stopwatch = Stopwatch()..start();

        await lumaraCubit.sendMessage('Tell me about performance tests');

        stopwatch.stop();

        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));

        // Verify response was generated
        final state = lumaraCubit.state as LumaraAssistantLoaded;
        expect(state.messages.last.content, isNotEmpty);
      });
    });
  });
}

class MockContextProvider extends ContextProvider {
  @override
  Future<ContextWindow> buildContext() async {
    return ContextWindow(
      nodes: [
        {
          'type': 'phase',
          'text': 'Expansion',
          'meta': {'current': true},
        },
      ],
    );
  }

  @override
  Future<String> getContextSummary() async {
    return 'Mock context summary for testing';
  }
}

class ContextWindow {
  final List<Map<String, dynamic>> nodes;

  ContextWindow({required this.nodes});
}

enum MessageRole {
  user,
  assistant,
}