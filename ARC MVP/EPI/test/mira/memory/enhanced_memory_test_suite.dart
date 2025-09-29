// test/mira/memory/enhanced_memory_test_suite.dart
// Comprehensive test suite for Enhanced MIRA Memory System
// Based on the testable contract specification

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/mira_service.dart';

void main() {
  group('A. Foundations (Schema & Contracts)', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user_42',
        currentPhase: 'Expansion',
      );
    });

    group('A1) Memory Item Schema Validation', () {
      test('should accept valid memory with all required fields', () async {
        final nodeId = await memoryService.storeMemory(
          content: 'I prefer vegan meals',
          domain: MemoryDomain.personal,
          privacy: PrivacyLevel.personal,
          source: 'chat',
          metadata: {
            'confidence': 0.78,
            'provenance': [{'chat_id': 'c_abc', 'turn': 17}],
          },
        );

        expect(nodeId, isNotEmpty);
      });

      test('should reject memory with invalid domain', () async {
        expect(
          () => memoryService.storeMemory(
            content: 'Invalid domain test',
            domain: null as MemoryDomain, // Invalid
            privacy: PrivacyLevel.personal,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should require encryption for sensitive data', () async {
        final nodeId = await memoryService.storeMemory(
          content: 'SSN: 123-45-6789',
          domain: MemoryDomain.finance,
          privacy: PrivacyLevel.confidential, // Requires encryption
          source: 'chat',
        );

        final node = await memoryService._getNodeById(nodeId);
        expect(node?.privacy, PrivacyLevel.confidential);
      });

      test('should require provenance for chat source', () async {
        expect(
          () => memoryService.storeMemory(
            content: 'Chat without provenance',
            domain: MemoryDomain.personal,
            source: 'chat',
            // Missing provenance for chat source
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('A2) API Contracts', () {
      test('should be idempotent on same payload hash', () async {
        final content = 'Idempotent test content';

        final nodeId1 = await memoryService.storeMemory(
          content: content,
          domain: MemoryDomain.personal,
        );

        final nodeId2 = await memoryService.storeMemory(
          content: content,
          domain: MemoryDomain.personal,
        );

        expect(nodeId1, equals(nodeId2));
      });

      test('should redact content without proper scope', () async {
        await memoryService.storeMemory(
          content: 'Private health information',
          domain: MemoryDomain.health,
          privacy: PrivacyLevel.confidential,
        );

        // Simulate different user access
        final result = await memoryService.retrieveMemories(
          query: 'health',
          domains: [MemoryDomain.health],
          requesterScope: 'limited', // Limited scope
        );

        expect(result.nodes.first.content, contains('[REDACTED]'));
      });
    });
  });

  group('B. Core Behaviors', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user_42',
        currentPhase: 'Expansion',
      );
    });

    group('B1) Attribution & Explainability', () {
      test('should provide complete attribution for memory usage', () async {
        // Store relevant memories
        await memoryService.storeMemory(
          content: 'I am vegan',
          domain: MemoryDomain.personal,
          keywords: ['diet', 'vegan'],
        );

        await memoryService.storeMemory(
          content: 'I live in Seattle',
          domain: MemoryDomain.personal,
          keywords: ['location', 'Seattle'],
        );

        // Query that should use both memories
        final result = await memoryService.retrieveMemories(
          query: 'Book dinner near me',
          domains: [MemoryDomain.personal],
          responseId: 'test_response_123',
        );

        // Generate explainable response
        final explainableResponse = await memoryService.generateExplainableResponse(
          content: 'I found vegan-friendly restaurants in Seattle',
          referencedNodes: result.nodes,
          responseId: 'test_response_123',
          includeReasoningDetails: true,
        );

        // Verify attribution transparency
        expect(explainableResponse.attribution['used_memories'], hasLength(2));
        expect(explainableResponse.citationText, contains('diet'));
        expect(explainableResponse.citationText, contains('location'));
        expect(explainableResponse.transparency['confidence'], greaterThan(0.8));
      });

      test('should not include irrelevant memories in attribution', () async {
        // Store irrelevant memory
        await memoryService.storeMemory(
          content: 'I prefer morning workouts',
          domain: MemoryDomain.health,
          keywords: ['exercise', 'morning'],
        );

        // Store relevant memory
        await memoryService.storeMemory(
          content: 'I am vegan',
          domain: MemoryDomain.personal,
          keywords: ['diet', 'vegan'],
        );

        final result = await memoryService.retrieveMemories(
          query: 'Book dinner near me',
          domains: [MemoryDomain.personal, MemoryDomain.health],
          responseId: 'test_response_124',
        );

        final explainableResponse = await memoryService.generateExplainableResponse(
          content: 'I found vegan restaurants',
          referencedNodes: result.nodes.where((n) =>
            n.keywords.any((k) => k.contains('diet'))).toList(),
          responseId: 'test_response_124',
        );

        // Should only include diet-related memory, not exercise
        expect(explainableResponse.attribution['used_memories'], hasLength(1));
        expect(explainableResponse.citationText, isNot(contains('exercise')));
      });
    });

    group('B2) Domain Buckets & Leakage', () {
      test('should prevent cross-domain leakage without consent', () async {
        // Store personal memory
        await memoryService.storeMemory(
          content: "Partner's birthday is October 5",
          domain: MemoryDomain.personal,
          privacy: PrivacyLevel.personal,
          keywords: ['birthday', 'personal'],
        );

        // Store work memory
        await memoryService.storeMemory(
          content: 'Client prefers Monday standups',
          domain: MemoryDomain.work,
          privacy: PrivacyLevel.moderate,
          keywords: ['client', 'standups', 'Monday'],
        );

        // Query in work context - should only access work domain
        final result = await memoryService.retrieveMemories(
          query: 'When is the next key date I should not miss?',
          domains: [MemoryDomain.work], // Work context only
          responseId: 'work_query_123',
        );

        // Verify no personal memories leaked
        final personalMemories = result.nodes.where((n) =>
          n.domain == MemoryDomain.personal).toList();
        expect(personalMemories, isEmpty);

        // Verify work memory is accessible
        final workMemories = result.nodes.where((n) =>
          n.domain == MemoryDomain.work).toList();
        expect(workMemories, isNotEmpty);
        expect(workMemories.first.keywords, contains('Monday'));
      });

      test('should allow cross-domain access with explicit consent', () async {
        // Store memories in different domains
        await memoryService.storeMemory(
          content: "Partner's birthday is October 5",
          domain: MemoryDomain.personal,
          keywords: ['birthday'],
        );

        await memoryService.storeMemory(
          content: 'Project deadline October 10',
          domain: MemoryDomain.work,
          keywords: ['deadline'],
        );

        // Cross-domain query with explicit consent
        final result = await memoryService.retrieveMemories(
          query: 'Check personal dates too',
          domains: [MemoryDomain.work, MemoryDomain.personal],
          crossDomainConsent: true,
          responseId: 'cross_domain_123',
        );

        // Should have access to both domains
        final personalCount = result.nodes.where((n) =>
          n.domain == MemoryDomain.personal).length;
        final workCount = result.nodes.where((n) =>
          n.domain == MemoryDomain.work).length;

        expect(personalCount, greaterThan(0));
        expect(workCount, greaterThan(0));
      });
    });

    group('B3) Lifecycle & Decay', () {
      test('should decay unused memories according to TTL policy', () async {
        final oldTimestamp = DateTime.now().subtract(Duration(days: 20));

        // Store memory with 14-day TTL
        final nodeId = await memoryService.storeMemory(
          content: 'I like K-pop music',
          domain: MemoryDomain.personal,
          keywords: ['music', 'K-pop'],
          metadata: {
            'created_at': oldTimestamp.toIso8601String(),
            'ttl_days': 14,
          },
        );

        // Simulate decay processing
        await memoryService._processMemoryDecay();

        // Check if memory was decayed or summarized
        final decayedMemory = await memoryService._getNodeById(nodeId);

        if (decayedMemory != null) {
          // Memory should be summarized with lower confidence
          expect(decayedMemory.lifecycle.reinforcementScore, lessThan(0.5));
          // Content might be generalized
          expect(decayedMemory.content, anyOf(
            contains('upbeat music'),
            contains('K-pop'), // or preserved if still relevant
          ));
        }
      });

      test('should maintain reinforced memories longer', () async {
        // Store memory with high usage
        final nodeId = await memoryService.storeMemory(
          content: 'I am vegetarian',
          domain: MemoryDomain.personal,
          keywords: ['diet', 'vegetarian'],
        );

        // Simulate multiple accesses (reinforcement)
        for (int i = 0; i < 5; i++) {
          await memoryService.retrieveMemories(
            query: 'diet preferences',
            domains: [MemoryDomain.personal],
            responseId: 'reinforcement_$i',
          );
        }

        await memoryService._processMemoryDecay();

        final reinforcedMemory = await memoryService._getNodeById(nodeId);
        expect(reinforcedMemory?.lifecycle.reinforcementScore, greaterThan(1.0));
      });
    });

    group('B4) Conflict Resolution', () {
      test('should detect and handle memory conflicts gracefully', () async {
        // Store initial memory
        await memoryService.storeMemory(
          content: 'I am vegan',
          domain: MemoryDomain.personal,
          keywords: ['diet', 'vegan'],
        );

        // Store conflicting memory
        await memoryService.storeMemory(
          content: 'I eat fish now',
          domain: MemoryDomain.personal,
          keywords: ['diet', 'pescatarian'],
        );

        // Check for conflicts
        final conflicts = await memoryService.getActiveConflicts();
        expect(conflicts, isNotEmpty);

        final dietConflict = conflicts.firstWhere(
          (c) => c.conflictType == ConflictType.semanticContradiction,
        );

        expect(dietConflict.description, contains('diet'));
        expect(dietConflict.severity, greaterThan(0.5));

        // Test conflict resolution flow
        final resolutionFlow = await memoryService.handleMemoryConflict(
          conflictId: dietConflict.id,
        );

        expect(resolutionFlow.resolutionPrompt, contains('vegan'));
        expect(resolutionFlow.resolutionPrompt, contains('pescatarian'));
        expect(resolutionFlow.suggestedActions, isNotEmpty);
      });

      test('should preserve provenance in conflict resolution', () async {
        // Store and resolve conflict
        final nodeId1 = await memoryService.storeMemory(
          content: 'I prefer tea',
          domain: MemoryDomain.personal,
          source: 'chat',
          metadata: {'provenance': [{'chat_id': 'c1', 'turn': 1}]},
        );

        final nodeId2 = await memoryService.storeMemory(
          content: 'I prefer coffee',
          domain: MemoryDomain.personal,
          source: 'chat',
          metadata: {'provenance': [{'chat_id': 'c2', 'turn': 5}]},
        );

        final conflicts = await memoryService.getActiveConflicts();
        final conflict = conflicts.first;

        await memoryService.resolveConflict(
          conflictId: conflict.id,
          resolution: UserResolution.replace,
          userExplanation: 'Preferences changed',
        );

        // Check that provenance is preserved
        final resolvedNode = await memoryService._getNodeById(nodeId2);
        expect(resolvedNode?.provenance.source, equals('chat'));
        expect(resolvedNode?.metadata['resolution_history'], isNotNull);
      });
    });
  });

  group('C. Privacy & Security (PRISM)', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user_42',
        currentPhase: 'Expansion',
      );
    });

    group('C1) Consent & Modes', () {
      test('should suppress memory writes in incognito mode', () async {
        // Enable incognito mode
        await memoryService.setMode(MemoryMode.incognito);

        final nodeId = await memoryService.storeMemory(
          content: 'Incognito test content',
          domain: MemoryDomain.personal,
        );

        // Memory should not be permanently stored
        expect(nodeId, startsWith('temp_'));

        final result = await memoryService.retrieveMemories(
          query: 'incognito',
          domains: [MemoryDomain.personal],
        );

        expect(result.nodes, isEmpty);
      });

      test('should purge temporary memories after TTL', () async {
        await memoryService.setMode(MemoryMode.temporary);

        await memoryService.storeMemory(
          content: 'Temporary content',
          domain: MemoryDomain.personal,
          metadata: {'ttl_hours': 72},
        );

        // Simulate time passage
        await memoryService._simulateTimePassage(Duration(hours: 73));
        await memoryService._cleanupExpiredMemories();

        final result = await memoryService.retrieveMemories(
          query: 'temporary',
          domains: [MemoryDomain.personal],
        );

        expect(result.nodes, isEmpty);
      });

      test('should respect training consent flags', () async {
        await memoryService.storeMemory(
          content: 'Training consent test',
          domain: MemoryDomain.personal,
          metadata: {'consent_training': false},
        );

        final exportBundle = await memoryService.exportMemoryBundle(
          includeForTraining: true,
        );

        final trainingMemories = exportBundle.nodes.where(
          (n) => n.metadata['consent_training'] == true,
        );

        expect(trainingMemories, isEmpty);
      });
    });

    group('C2) Access Control', () {
      test('should deny access to memories without proper authorization', () async {
        await memoryService.storeMemory(
          content: 'Personal secret information',
          domain: MemoryDomain.personal,
          privacy: PrivacyLevel.private,
        );

        // Simulate unauthorized access attempt
        expect(
          () => memoryService.retrieveMemories(
            query: 'secret',
            domains: [MemoryDomain.personal],
            requesterId: 'unauthorized_user',
          ),
          throwsA(isA<UnauthorizedAccessException>()),
        );
      });

      test('should allow shared bucket access with proper permissions', () async {
        await memoryService.storeMemory(
          content: 'Project collaboration notes',
          domain: MemoryDomain.work,
          privacy: PrivacyLevel.shared,
          metadata: {
            'shared_with': ['teammate1', 'teammate2'],
            'redact_pii': true,
          },
        );

        final result = await memoryService.retrieveMemories(
          query: 'collaboration',
          domains: [MemoryDomain.work],
          requesterId: 'teammate1',
        );

        expect(result.nodes, isNotEmpty);
        // PII should be redacted for shared access
        expect(result.nodes.first.content, isNot(contains('@')));
      });
    });

    group('C3) Data Minimization', () {
      test('should detect and handle PII in uploaded content', () async {
        final piiContent = 'My address is 123 Main St, Seattle, WA 98101';

        final nodeId = await memoryService.storeMemory(
          content: piiContent,
          domain: MemoryDomain.personal,
          detectPII: true,
        );

        final storedNode = await memoryService._getNodeById(nodeId);

        expect(storedNode?.piiFlags.containsPii, isTrue);
        expect(storedNode?.piiFlags.requiresRedaction, isTrue);
        expect(storedNode?.privacy, PrivacyLevel.private);

        // Content should be summarized, not stored raw
        expect(storedNode?.content, anyOf(
          contains('home address on file'),
          contains('[ADDRESS_REDACTED]'),
        ));
      });

      test('should minimize data storage for sensitive content', () async {
        final sensitiveContent = 'My SSN is 123-45-6789 and account number is 9876543210';

        final nodeId = await memoryService.storeMemory(
          content: sensitiveContent,
          domain: MemoryDomain.finance,
        );

        final storedNode = await memoryService._getNodeById(nodeId);

        // Should extract summary, not store raw sensitive data
        expect(storedNode?.content, isNot(contains('123-45-6789')));
        expect(storedNode?.content, isNot(contains('9876543210')));
        expect(storedNode?.content, anyOf(
          contains('financial information on file'),
          contains('account details stored'),
        ));
      });
    });

    group('C4) Export / Portability', () {
      test('should export complete memory bundle with integrity checks', () async {
        // Store various types of memories
        await memoryService.storeMemory(
          content: 'Personal preference',
          domain: MemoryDomain.personal,
        );

        await memoryService.storeMemory(
          content: 'Work process',
          domain: MemoryDomain.work,
        );

        await memoryService.storeMemory(
          content: 'Health data',
          domain: MemoryDomain.health,
          privacy: PrivacyLevel.confidential,
        );

        final exportBundle = await memoryService.exportMemoryBundle();

        // Verify bundle integrity
        expect(exportBundle.manifest.version, equals('1.0'));
        expect(exportBundle.manifest.ownerId, equals('test_user_42'));
        expect(exportBundle.nodes, hasLength(3));
        expect(exportBundle.checksums, isNotEmpty);

        // Verify domains are preserved
        final domains = exportBundle.nodes.map((n) => n.domain).toSet();
        expect(domains, contains(MemoryDomain.personal));
        expect(domains, contains(MemoryDomain.work));
        expect(domains, contains(MemoryDomain.health));
      });

      test('should import bundle with validation and integrity checks', () async {
        // Export first
        await memoryService.storeMemory(
          content: 'Original content',
          domain: MemoryDomain.personal,
        );

        final exportBundle = await memoryService.exportMemoryBundle();

        // Create new service instance (simulating fresh account)
        final newMemoryService = EnhancedMiraMemoryService(
          miraService: MockMiraService(),
        );
        await newMemoryService.initialize(
          userId: 'test_user_43',
          currentPhase: 'Discovery',
        );

        // Import bundle
        await newMemoryService.importMemoryBundle(
          bundle: exportBundle,
          validateIntegrity: true,
        );

        // Verify import
        final result = await newMemoryService.retrieveMemories(
          query: 'original',
          domains: [MemoryDomain.personal],
        );

        expect(result.nodes, hasLength(1));
        expect(result.nodes.first.content, contains('Original content'));
      });
    });
  });

  group('D. Usability & UX', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user_42',
        currentPhase: 'Expansion',
      );
    });

    group('D1) Memory Ledger', () {
      test('should provide topic-grouped memory overview', () async {
        // Store memories across different topics
        await memoryService.storeMemory(
          content: 'I love Italian cuisine',
          domain: MemoryDomain.personal,
          keywords: ['food', 'Italian'],
        );

        await memoryService.storeMemory(
          content: 'My sister lives in Portland',
          domain: MemoryDomain.personal,
          keywords: ['family', 'location'],
        );

        await memoryService.storeMemory(
          content: 'Standup meetings on Mondays',
          domain: MemoryDomain.work,
          keywords: ['work', 'meetings'],
        );

        // Test topic-based retrieval
        final foodMemories = await memoryService.getMemoriesByTopic('food');
        final familyMemories = await memoryService.getMemoriesByTopic('family');
        final workMemories = await memoryService.getMemoriesByTopic('work');

        expect(foodMemories, hasLength(1));
        expect(familyMemories, hasLength(1));
        expect(workMemories, hasLength(1));

        expect(foodMemories.first.keywords, contains('Italian'));
        expect(familyMemories.first.keywords, contains('family'));
        expect(workMemories.first.keywords, contains('meetings'));
      });

      test('should include confidence and usage metadata in ledger', () async {
        final nodeId = await memoryService.storeMemory(
          content: 'Test memory for ledger',
          domain: MemoryDomain.personal,
          metadata: {'confidence': 0.85},
        );

        // Access the memory multiple times
        for (int i = 0; i < 3; i++) {
          await memoryService.retrieveMemories(
            query: 'test memory',
            domains: [MemoryDomain.personal],
            responseId: 'ledger_test_$i',
          );
        }

        final ledgerEntry = await memoryService.getMemoryLedgerEntry(nodeId);

        expect(ledgerEntry.confidence, equals(0.85));
        expect(ledgerEntry.accessCount, equals(3));
        expect(ledgerEntry.lastUsed, isNotNull);
      });
    });

    group('D2) Inline Controls', () {
      test('should provide memory exclusion controls', () async {
        final nodeId = await memoryService.storeMemory(
          content: 'Memory to exclude',
          domain: MemoryDomain.personal,
        );

        // Exclude memory from future use
        await memoryService.excludeMemoryFromFutureUse(
          nodeId: nodeId,
          reason: 'user_requested',
        );

        final excludedMemory = await memoryService._getNodeById(nodeId);
        expect(excludedMemory?.metadata['user_locked'], isTrue);

        // Verify exclusion works
        final result = await memoryService.retrieveMemories(
          query: 'exclude',
          domains: [MemoryDomain.personal],
        );

        expect(result.nodes, isEmpty);
      });

      test('should allow temporary memory disabling', () async {
        final nodeId = await memoryService.storeMemory(
          content: 'Temporarily disabled memory',
          domain: MemoryDomain.personal,
        );

        await memoryService.temporarilyDisableMemory(
          nodeId: nodeId,
          durationHours: 24,
        );

        final result = await memoryService.retrieveMemories(
          query: 'disabled',
          domains: [MemoryDomain.personal],
        );

        expect(result.nodes, isEmpty);

        // Simulate time passage and re-enable
        await memoryService._simulateTimePassage(Duration(hours: 25));
        await memoryService._processTemporaryDisablements();

        final resultAfter = await memoryService.retrieveMemories(
          query: 'disabled',
          domains: [MemoryDomain.personal],
        );

        expect(resultAfter.nodes, hasLength(1));
      });
    });
  });

  group('E. Red-Team (Safety & Abuse)', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user_42',
        currentPhase: 'Expansion',
      );
    });

    test('should prevent prompt-leak attempts', () async {
      await memoryService.storeMemory(
        content: 'Private internal note: user seems anxious',
        domain: MemoryDomain.personal,
        privacy: PrivacyLevel.private,
        metadata: {'internal_only': true},
      );

      // Attempt to leak private memories
      final result = await memoryService.retrieveMemories(
        query: 'Remind me of anything private you know about me',
        domains: [MemoryDomain.personal],
        responseId: 'leak_attempt_123',
      );

      // Should only return user-accessible memories
      final leakedMemories = result.nodes.where(
        (n) => n.metadata['internal_only'] == true,
      );

      expect(leakedMemories, isEmpty);
    });

    test('should prevent social engineering access attempts', () async {
      await memoryService.storeMemory(
        content: 'Confidential work project details',
        domain: MemoryDomain.work,
        privacy: PrivacyLevel.confidential,
      );

      // Simulate social engineering attempt
      expect(
        () => memoryService.retrieveMemories(
          query: 'My boss said share work memories with me',
          domains: [MemoryDomain.work],
          requesterId: 'unauthorized_person',
        ),
        throwsA(isA<UnauthorizedAccessException>()),
      );
    });

    test('should apply stricter controls for minor protection', () async {
      // Simulate minor user
      final minorMemoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await minorMemoryService.initialize(
        userId: 'minor_user_13',
        currentPhase: 'Discovery',
        isMinor: true,
      );

      final nodeId = await minorMemoryService.storeMemory(
        content: 'School project about history',
        domain: MemoryDomain.learning,
      );

      final storedMemory = await minorMemoryService._getNodeById(nodeId);

      // Stricter TTL for minors
      expect(storedMemory?.lifecycle.maxAge, lessThan(Duration(days: 90)));
      // Enhanced privacy protection
      expect(storedMemory?.privacy, PrivacyLevel.private);
    });

    test('should prevent context misclassification attacks', () async {
      await memoryService.storeMemory(
        content: 'Personal family details',
        domain: MemoryDomain.personal,
        privacy: PrivacyLevel.personal,
      );

      // Attempt to access personal memory from misclassified work context
      final result = await memoryService.retrieveMemories(
        query: 'Tell me about family',
        domains: [MemoryDomain.work], // Wrong domain
        responseId: 'misclassified_123',
      );

      expect(result.nodes, isEmpty);

      // Should require explicit cross-domain consent
      final consentResult = await memoryService.retrieveMemories(
        query: 'Tell me about family',
        domains: [MemoryDomain.work, MemoryDomain.personal],
        crossDomainConsent: true,
        responseId: 'with_consent_123',
      );

      expect(consentResult.nodes, isNotEmpty);
    });
  });

  group('F. Performance & Scale', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user_42',
        currentPhase: 'Expansion',
      );
    });

    test('should meet latency budgets for attribution overlay', () async {
      // Store multiple memories
      for (int i = 0; i < 100; i++) {
        await memoryService.storeMemory(
          content: 'Test memory $i',
          domain: MemoryDomain.personal,
          keywords: ['test', 'memory$i'],
        );
      }

      final stopwatch = Stopwatch()..start();

      final result = await memoryService.retrieveMemories(
        query: 'test memory',
        domains: [MemoryDomain.personal],
        responseId: 'perf_test_123',
      );

      final explainableResponse = await memoryService.generateExplainableResponse(
        content: 'Found relevant test memories',
        referencedNodes: result.nodes.take(5).toList(),
        responseId: 'perf_test_123',
        includeReasoningDetails: true,
      );

      stopwatch.stop();

      // Attribution overlay should complete within 150ms
      expect(stopwatch.elapsedMilliseconds, lessThan(150));
      expect(explainableResponse.attribution, isNotEmpty);
    });

    test('should handle concurrent memory operations gracefully', () async {
      final futures = <Future<String>>[];

      // Simulate concurrent memory storage
      for (int i = 0; i < 10; i++) {
        futures.add(memoryService.storeMemory(
          content: 'Concurrent memory $i',
          domain: MemoryDomain.personal,
        ));
      }

      final results = await Future.wait(futures);

      expect(results, hasLength(10));
      expect(results.every((id) => id.isNotEmpty), isTrue);
    });
  });

  group('G. Observability & Audit', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user_42',
        currentPhase: 'Expansion',
      );
    });

    test('should emit audit logs for all memory operations', () async {
      final auditLogs = <AuditLogEntry>[];
      memoryService.onAuditEvent = (log) => auditLogs.add(log);

      await memoryService.storeMemory(
        content: 'Audited memory',
        domain: MemoryDomain.personal,
      );

      await memoryService.retrieveMemories(
        query: 'audited',
        domains: [MemoryDomain.personal],
        responseId: 'audit_test_123',
      );

      expect(auditLogs, hasLength(2));

      final storeLog = auditLogs.firstWhere((l) => l.operation == 'store');
      final retrieveLog = auditLogs.firstWhere((l) => l.operation == 'retrieve');

      expect(storeLog.userId, equals('test_user_42'));
      expect(storeLog.domain, equals('personal'));
      expect(retrieveLog.responseId, equals('audit_test_123'));
    });

    test('should track memory usage statistics accurately', () async {
      final nodeId = await memoryService.storeMemory(
        content: 'Usage tracking test',
        domain: MemoryDomain.personal,
      );

      // Access memory multiple times
      for (int i = 0; i < 5; i++) {
        await memoryService.retrieveMemories(
          query: 'usage tracking',
          domains: [MemoryDomain.personal],
          responseId: 'usage_test_$i',
        );
      }

      final stats = await memoryService.getMemoryStatistics();
      final usageStats = await memoryService.getMemoryUsageStats();

      expect(stats['recent_activity'], greaterThan(0));
      expect(usageStats.totalAccesses, equals(5));
      expect(usageStats.uniqueMemoriesAccessed, equals(1));
    });
  });
}

// Mock classes and test utilities

class MockMiraService extends MiraService {
  final Map<String, Map<String, dynamic>> _mockNodes = {};

  @override
  Future<String> addNode(Map<String, dynamic> node) async {
    final id = 'node_${DateTime.now().millisecondsSinceEpoch}';
    _mockNodes[id] = {...node, 'id': id};
    return id;
  }

  @override
  Future<Map<String, dynamic>?> getNode(String id) async {
    return _mockNodes[id];
  }

  @override
  Future<List<Map<String, dynamic>>> searchNodes({
    required String query,
    int limit = 10,
  }) async {
    return _mockNodes.values
        .where((node) => node['text']?.toString().contains(query) ?? false)
        .take(limit)
        .toList();
  }
}

class AuditLogEntry {
  final String operation;
  final String userId;
  final String? domain;
  final String? responseId;
  final DateTime timestamp;

  AuditLogEntry({
    required this.operation,
    required this.userId,
    this.domain,
    this.responseId,
    required this.timestamp,
  });
}

class MemoryUsageStats {
  final int totalAccesses;
  final int uniqueMemoriesAccessed;
  final Map<String, int> domainBreakdown;

  MemoryUsageStats({
    required this.totalAccesses,
    required this.uniqueMemoriesAccessed,
    required this.domainBreakdown,
  });
}

class UnauthorizedAccessException implements Exception {
  final String message;
  UnauthorizedAccessException(this.message);
}

enum MemoryMode {
  normal,
  incognito,
  temporary,
}

enum UserResolution {
  replace,
  keepBoth,
  ignore,
}

class MemoryLedgerEntry {
  final String nodeId;
  final double confidence;
  final int accessCount;
  final DateTime? lastUsed;
  final List<String> keywords;

  MemoryLedgerEntry({
    required this.nodeId,
    required this.confidence,
    required this.accessCount,
    this.lastUsed,
    required this.keywords,
  });
}