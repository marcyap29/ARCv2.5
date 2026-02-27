// test/mira/memory/memory_mode_service_test.dart
// Unit tests for MemoryModeService

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_app/mira/memory/memory_mode_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/core/schema.dart';

void main() {
  group('MemoryModeService', () {
    late MemoryModeService service;

    setUp(() async {
      service = MemoryModeService();
      await service.initialize();
    });

    tearDown(() async {
      // Clean up Hive boxes
      try {
        await Hive.deleteFromDisk();
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Initialization', () {
      test('should initialize with default config', () {
        expect(service.config.globalMode, equals(MemoryMode.suggestive));
        expect(service.config.domainModes, isEmpty);
        expect(service.config.sessionMode, isNull);
        expect(service.config.highConfidenceThreshold, equals(0.75));
        expect(service.config.showSuggestions, isTrue);
      });

      test('should initialize with custom config', () async {
        final customService = MemoryModeService(
          config: const MemoryModeConfig(
            globalMode: MemoryMode.alwaysOn,
            highConfidenceThreshold: 0.85,
            showSuggestions: false,
          ),
        );
        await customService.initialize();

        expect(customService.config.globalMode, equals(MemoryMode.alwaysOn));
        expect(customService.config.highConfidenceThreshold, equals(0.85));
        expect(customService.config.showSuggestions, isFalse);
      });
    });

    group('Mode Priority', () {
      test('should return global mode when no overrides', () {
        final mode = service.getEffectiveMode();
        expect(mode, equals(MemoryMode.suggestive));
      });

      test('should prioritize domain mode over global', () async {
        await service.setDomainMode(MemoryDomain.work, MemoryMode.hard);

        final workMode = service.getEffectiveMode(domain: MemoryDomain.work);
        final personalMode = service.getEffectiveMode(domain: MemoryDomain.personal);

        expect(workMode, equals(MemoryMode.hard));
        expect(personalMode, equals(MemoryMode.suggestive)); // Falls back to global
      });

      test('should prioritize session mode over all', () async {
        await service.setGlobalMode(MemoryMode.alwaysOn);
        await service.setDomainMode(MemoryDomain.work, MemoryMode.hard);
        service.setSessionMode(MemoryMode.askFirst);

        final mode = service.getEffectiveMode(domain: MemoryDomain.work);
        expect(mode, equals(MemoryMode.askFirst));
      });

      test('should revert to lower priority when session mode cleared', () async {
        await service.setDomainMode(MemoryDomain.work, MemoryMode.hard);
        service.setSessionMode(MemoryMode.askFirst);

        expect(service.getEffectiveMode(domain: MemoryDomain.work),
               equals(MemoryMode.askFirst));

        service.clearSessionMode();

        expect(service.getEffectiveMode(domain: MemoryDomain.work),
               equals(MemoryMode.hard));
      });
    });

    group('Configuration Persistence', () {
      test('should persist global mode', () async {
        await service.setGlobalMode(MemoryMode.alwaysOn);

        // Create new service instance
        final newService = MemoryModeService();
        await newService.initialize();

        expect(newService.config.globalMode, equals(MemoryMode.alwaysOn));
      });

      test('should persist domain modes', () async {
        await service.setDomainMode(MemoryDomain.work, MemoryMode.hard);
        await service.setDomainMode(MemoryDomain.health, MemoryMode.alwaysOn);

        // Create new service instance
        final newService = MemoryModeService();
        await newService.initialize();

        expect(newService.config.domainModes[MemoryDomain.work],
               equals(MemoryMode.hard));
        expect(newService.config.domainModes[MemoryDomain.health],
               equals(MemoryMode.alwaysOn));
      });

      test('should persist confidence threshold', () async {
        await service.setHighConfidenceThreshold(0.85);

        // Create new service instance
        final newService = MemoryModeService();
        await newService.initialize();

        expect(newService.config.highConfidenceThreshold, equals(0.85));
      });

      test('should not persist session mode', () async {
        service.setSessionMode(MemoryMode.askFirst);

        // Create new service instance
        final newService = MemoryModeService();
        await newService.initialize();

        expect(newService.config.sessionMode, isNull);
      });
    });

    group('Mode Filtering', () {
      late List<EnhancedMiraNode> testMemories;
      late Map<String, double> confidenceScores;

      setUp(() {
        testMemories = [
          _createTestNode('node1'),
          _createTestNode('node2'),
          _createTestNode('node3'),
          _createTestNode('node4'),
          _createTestNode('node5'),
        ];

        confidenceScores = {
          'node1': 0.95,
          'node2': 0.80,
          'node3': 0.70,
          'node4': 0.60,
          'node5': 0.40,
        };
      });

      test('disabled mode should return empty list', () {
        final filtered = service.applyModeFilter(
          memories: testMemories,
          mode: MemoryMode.disabled,
        );

        expect(filtered, isEmpty);
      });

      test('highConfidenceOnly should filter by threshold', () async {
        await service.setHighConfidenceThreshold(0.75);

        final filtered = service.applyModeFilter(
          memories: testMemories,
          mode: MemoryMode.highConfidenceOnly,
          confidenceScores: confidenceScores,
        );

        expect(filtered, hasLength(2)); // node1 (0.95) and node2 (0.80)
      });

      test('highConfidenceOnly with custom threshold', () async {
        await service.setHighConfidenceThreshold(0.85);

        final filtered = service.applyModeFilter(
          memories: testMemories,
          mode: MemoryMode.highConfidenceOnly,
          confidenceScores: confidenceScores,
        );

        expect(filtered, hasLength(1)); // Only node1 (0.95)
      });

      test('other modes should not filter', () {
        final modes = [
          MemoryMode.alwaysOn,
          MemoryMode.suggestive,
          MemoryMode.askFirst,
          MemoryMode.soft,
          MemoryMode.hard,
        ];

        for (final mode in modes) {
          final filtered = service.applyModeFilter(
            memories: testMemories,
            mode: mode,
          );

          expect(filtered, hasLength(testMemories.length),
                 reason: '$mode should not filter');
        }
      });
    });

    group('Mode Behavior Checks', () {
      test('shouldRetrieveMemories', () {
        expect(service.shouldRetrieveMemories(MemoryMode.disabled), isFalse);
        expect(service.shouldRetrieveMemories(MemoryMode.alwaysOn), isTrue);
        expect(service.shouldRetrieveMemories(MemoryMode.suggestive), isTrue);
        expect(service.shouldRetrieveMemories(MemoryMode.askFirst), isTrue);
        expect(service.shouldRetrieveMemories(MemoryMode.highConfidenceOnly), isTrue);
      });

      test('needsUserPrompt', () {
        expect(service.needsUserPrompt(MemoryMode.askFirst), isTrue);
        expect(service.needsUserPrompt(MemoryMode.suggestive), isTrue);
        expect(service.needsUserPrompt(MemoryMode.alwaysOn), isFalse);
        expect(service.needsUserPrompt(MemoryMode.highConfidenceOnly), isFalse);
        expect(service.needsUserPrompt(MemoryMode.disabled), isFalse);
      });

      test('isAuthoritativeMode', () {
        expect(service.isAuthoritativeMode(MemoryMode.hard), isTrue);
        expect(service.isAuthoritativeMode(MemoryMode.alwaysOn), isTrue);
        expect(service.isAuthoritativeMode(MemoryMode.soft), isFalse);
        expect(service.isAuthoritativeMode(MemoryMode.suggestive), isFalse);
      });

      test('isGentleMode', () {
        expect(service.isGentleMode(MemoryMode.soft), isTrue);
        expect(service.isGentleMode(MemoryMode.suggestive), isTrue);
        expect(service.isGentleMode(MemoryMode.hard), isFalse);
        expect(service.isGentleMode(MemoryMode.alwaysOn), isFalse);
      });
    });

    group('Prompt Generation', () {
      test('getAskFirstPrompt for zero memories', () {
        final prompt = service.getAskFirstPrompt(
          memoryCount: 0,
          domain: MemoryDomain.personal,
        );

        expect(prompt, contains('No'));
        expect(prompt, contains('personal'));
      });

      test('getAskFirstPrompt for one memory', () {
        final prompt = service.getAskFirstPrompt(
          memoryCount: 1,
          domain: MemoryDomain.work,
        );

        expect(prompt, contains('1 relevant'));
        expect(prompt, contains('work'));
        expect(prompt, contains('Would you like me to use it?'));
      });

      test('getAskFirstPrompt for multiple memories', () {
        final prompt = service.getAskFirstPrompt(
          memoryCount: 5,
          domain: MemoryDomain.health,
        );

        expect(prompt, contains('5 relevant'));
        expect(prompt, contains('health'));
        expect(prompt, contains('Would you like me to use them?'));
      });

      test('getSuggestionText for empty list', () {
        final text = service.getSuggestionText(
          memories: [],
          domain: MemoryDomain.personal,
        );

        expect(text, isEmpty);
      });

      test('getSuggestionText for one memory', () {
        final memory = _createTestNode('test1', content: 'Test memory content here');

        final text = service.getSuggestionText(
          memories: [memory],
          domain: MemoryDomain.personal,
        );

        expect(text, contains('Memory available'));
        expect(text, contains('Test memory content'));
      });

      test('getSuggestionText for multiple memories', () {
        final memories = [
          _createTestNode('test1', content: 'First memory'),
          _createTestNode('test2', content: 'Second memory'),
          _createTestNode('test3', content: 'Third memory'),
          _createTestNode('test4', content: 'Fourth memory'),
        ];

        final text = service.getSuggestionText(
          memories: memories,
          domain: MemoryDomain.work,
        );

        expect(text, contains('4 memories available'));
        expect(text, contains('First memory'));
        expect(text, contains('Second memory'));
        expect(text, contains('Third memory'));
        expect(text, isNot(contains('Fourth memory'))); // Only shows top 3
      });
    });

    group('Statistics', () {
      test('should return correct statistics', () async {
        await service.setGlobalMode(MemoryMode.alwaysOn);
        await service.setDomainMode(MemoryDomain.work, MemoryMode.hard);
        await service.setDomainMode(MemoryDomain.health, MemoryMode.soft);
        service.setSessionMode(MemoryMode.askFirst);

        final stats = service.getStatistics();

        expect(stats['global_mode'], equals('alwaysOn'));
        expect(stats['domain_overrides'], equals(2));
        expect(stats['session_mode_active'], isTrue);
        expect(stats['domain_modes'], isA<Map>());
        expect(stats['domain_modes']['work'], equals('hard'));
        expect(stats['domain_modes']['health'], equals('soft'));
      });
    });

    group('Reset', () {
      test('should reset to defaults', () async {
        await service.setGlobalMode(MemoryMode.alwaysOn);
        await service.setDomainMode(MemoryDomain.work, MemoryMode.hard);
        await service.setHighConfidenceThreshold(0.85);
        service.setSessionMode(MemoryMode.askFirst);

        await service.resetToDefaults();

        expect(service.config.globalMode, equals(MemoryMode.suggestive));
        expect(service.config.domainModes, isEmpty);
        expect(service.config.sessionMode, isNull);
        expect(service.config.highConfidenceThreshold, equals(0.75));
        expect(service.config.showSuggestions, isTrue);
      });
    });

    group('Display Names and Descriptions', () {
      test('getModeDisplayName should return proper names', () {
        expect(MemoryModeService.getModeDisplayName(MemoryMode.alwaysOn),
               equals('Always On'));
        expect(MemoryModeService.getModeDisplayName(MemoryMode.suggestive),
               equals('Suggestive'));
        expect(MemoryModeService.getModeDisplayName(MemoryMode.askFirst),
               equals('Ask First'));
        expect(MemoryModeService.getModeDisplayName(MemoryMode.highConfidenceOnly),
               equals('High Confidence Only'));
        expect(MemoryModeService.getModeDisplayName(MemoryMode.soft),
               equals('Soft'));
        expect(MemoryModeService.getModeDisplayName(MemoryMode.hard),
               equals('Hard'));
        expect(MemoryModeService.getModeDisplayName(MemoryMode.disabled),
               equals('Disabled'));
      });

      test('getModeDescription should return descriptions', () {
        final desc = MemoryModeService.getModeDescription(MemoryMode.alwaysOn);
        expect(desc, isNotEmpty);
        expect(desc, contains('automatically'));
      });

      test('getModeDescription should include threshold for highConfidenceOnly', () {
        final desc = MemoryModeService.getModeDescription(
          MemoryMode.highConfidenceOnly,
          threshold: 0.85,
        );
        expect(desc, contains('85%'));
      });
    });

    group('Threshold Validation', () {
      test('should accept valid thresholds', () async {
        await service.setHighConfidenceThreshold(0.5);
        expect(service.config.highConfidenceThreshold, equals(0.5));

        await service.setHighConfidenceThreshold(0.75);
        expect(service.config.highConfidenceThreshold, equals(0.75));

        await service.setHighConfidenceThreshold(1.0);
        expect(service.config.highConfidenceThreshold, equals(1.0));
      });

      test('should reject invalid thresholds', () async {
        expect(() => service.setHighConfidenceThreshold(-0.1),
               throwsArgumentError);
        expect(() => service.setHighConfidenceThreshold(1.1),
               throwsArgumentError);
      });
    });
  });

  group('MemoryModeConfig', () {
    test('should serialize to JSON', () {
      const config = MemoryModeConfig(
        globalMode: MemoryMode.alwaysOn,
        domainModes: {
          MemoryDomain.work: MemoryMode.hard,
          MemoryDomain.health: MemoryMode.soft,
        },
        sessionMode: MemoryMode.askFirst,
        highConfidenceThreshold: 0.85,
        showSuggestions: false,
      );

      final json = config.toJson();

      expect(json['global_mode'], equals('alwaysOn'));
      expect(json['domain_modes']['work'], equals('hard'));
      expect(json['domain_modes']['health'], equals('soft'));
      expect(json['session_mode'], equals('askFirst'));
      expect(json['high_confidence_threshold'], equals(0.85));
      expect(json['show_suggestions'], equals(false));
    });

    test('should deserialize from JSON', () {
      final json = {
        'global_mode': 'hard',
        'domain_modes': {
          'work': 'soft',
          'personal': 'alwaysOn',
        },
        'session_mode': 'suggestive',
        'high_confidence_threshold': 0.9,
        'show_suggestions': false,
      };

      final config = MemoryModeConfig.fromJson(json);

      expect(config.globalMode, equals(MemoryMode.hard));
      expect(config.domainModes[MemoryDomain.work], equals(MemoryMode.soft));
      expect(config.domainModes[MemoryDomain.personal], equals(MemoryMode.alwaysOn));
      expect(config.sessionMode, equals(MemoryMode.suggestive));
      expect(config.highConfidenceThreshold, equals(0.9));
      expect(config.showSuggestions, equals(false));
    });

    test('should handle null session mode in JSON', () {
      final json = {
        'global_mode': 'alwaysOn',
        'domain_modes': {},
        'session_mode': null,
        'high_confidence_threshold': 0.75,
        'show_suggestions': true,
      };

      final config = MemoryModeConfig.fromJson(json);

      expect(config.sessionMode, isNull);
    });

    test('copyWith should create new instance', () {
      const original = MemoryModeConfig(
        globalMode: MemoryMode.alwaysOn,
        highConfidenceThreshold: 0.75,
      );

      final updated = original.copyWith(
        globalMode: MemoryMode.suggestive,
      );

      expect(updated.globalMode, equals(MemoryMode.suggestive));
      expect(updated.highConfidenceThreshold, equals(0.75)); // Unchanged
      expect(original.globalMode, equals(MemoryMode.alwaysOn)); // Original unchanged
    });
  });
}

/// Helper to create test memory node
EnhancedMiraNode _createTestNode(String id, {String? content}) {
  return EnhancedMiraNode(
    id: id,
    type: NodeType.entry,
    schemaVersion: 1,
    domain: MemoryDomain.personal,
    privacy: PrivacyLevel.personal,
    data: {
      'content': content ?? 'Test content for $id',
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    lifecycle: const LifecycleMetadata(
      lastAccessed: null,
      accessCount: 0,
      reinforcementScore: 1.0,
      scheduledDecay: null,
      isArchived: false,
      decayTriggers: [],
      veilHooks: {},
    ),
    provenance: const ProvenanceData(
      source: 'test',
      version: '1.0.0',
      device: 'test_device',
      userId: 'test_user',
    ),
    piiFlags: const PIIFlags(
      containsPII: false,
      facesDetected: false,
      locationData: false,
      sensitiveContent: false,
      detectedTypes: [],
      requiresRedaction: false,
    ),
  );
}