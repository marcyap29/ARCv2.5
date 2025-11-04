// test/mcp/bundle_doctor/golden_bundle_test.dart
// Golden contract tests for MCP bundle format stability

import 'package:test/test.dart';
import 'package:my_app/polymeta/store/mcp/bundle_doctor/bundle_doctor.dart';

void main() {
  group('Golden Contract Tests', () {
    test('golden bundle stays valid', () {
      final goldenBundle = _getGoldenBundle();
      final bundle = BundleDoctor.repair(goldenBundle);
      final validation = BundleDoctor.validate(bundle);

      expect(validation.isValid, isTrue,
        reason: 'Golden bundle validation failed: ${validation.errors}');
      expect(validation.errors, isEmpty);
      expect(bundle.repairLog, isEmpty,
        reason: 'Golden bundle should not need repairs');
    });

    test('golden bundle round-trip stability', () {
      final goldenBundle = _getGoldenBundle();
      final bundle1 = BundleDoctor.repair(goldenBundle);
      final json = BundleDoctor.toJson(bundle1);
      final bundle2 = BundleDoctor.fromJson(json);

      expect(bundle2.schemaVersion, equals(bundle1.schemaVersion));
      expect(bundle2.bundleId, equals(bundle1.bundleId));
      expect(bundle2.nodes.length, equals(bundle1.nodes.length));
      expect(bundle2.edges.length, equals(bundle1.edges.length));
      expect(bundle2.pointers.length, equals(bundle1.pointers.length));
    });

    test('schema version compatibility', () {
      final versions = ['mcp-1.0', 'mcp-1.1', 'mcp-1.2'];

      for (final version in versions) {
        final bundle = _getGoldenBundle();
        bundle['schemaVersion'] = version;

        final repaired = BundleDoctor.repair(bundle);
        final validation = BundleDoctor.validate(repaired);

        expect(validation.isValid, isTrue,
          reason: 'Version $version should be valid');
      }
    });

    test('real-world sample bundle validates', () {
      final realWorldBundle = _getRealWorldSample();
      final bundle = BundleDoctor.repair(realWorldBundle);
      final validation = BundleDoctor.validate(bundle);

      expect(validation.isValid, isTrue,
        reason: 'Real-world sample should validate: ${validation.errors}');
    });

    test('generated test data maintains format', () {
      final testBundle = _generateTestBundle();
      final bundle = BundleDoctor.repair(testBundle);
      final validation = BundleDoctor.validate(bundle);

      expect(validation.isValid, isTrue);

      // Check that all required conventions are followed
      expect(bundle.bundleId, startsWith('b-'));
      for (final node in bundle.nodes) {
        expect(node.id, startsWith('n-'));
        expect(() => DateTime.parse(node.timestamp), returnsNormally);
      }
    });
  });
}

/// Golden bundle - stable reference format
Map<String, dynamic> _getGoldenBundle() {
  return {
    "schemaVersion": "mcp-1.0",
    "bundleId": "b-golden-reference",
    "pointers": [
      {
        "id": "p-chat-session-001",
        "kind": "chat_session",
        "ref": "lumara://sessions/golden-chat"
      }
    ],
    "nodes": [
      {
        "id": "n-entry-001",
        "type": "entry",
        "timestamp": "2025-09-24T21:00:00.000Z",
        "content": {
          "text": "Golden sample entry for contract testing"
        },
        "emotions": ["focused", "optimistic"],
        "phaseHint": "Expansion",
        "provenance": {
          "source": "lumara.chat",
          "pointer": "p-chat-session-001"
        }
      },
      {
        "id": "n-keyword-golden",
        "type": "keyword",
        "timestamp": "2025-09-24T21:00:01.000Z",
        "label": "golden",
        "frequency": 3
      },
      {
        "id": "n-phase-expansion",
        "type": "phase",
        "timestamp": "2025-09-24T21:00:02.000Z",
        "label": "Expansion",
        "confidence": 0.85
      }
    ],
    "edges": [
      {
        "from": "n-entry-001",
        "to": "n-keyword-golden",
        "type": "mentions",
        "weight": 0.9
      },
      {
        "from": "n-entry-001",
        "to": "n-phase-expansion",
        "type": "phase_hint",
        "weight": 0.85
      }
    ]
  };
}

/// Real-world sample that should validate
Map<String, dynamic> _getRealWorldSample() {
  return {
    "schemaVersion": "mcp-1.0",
    "bundleId": "b-2025-09-24T21:05:00Z",
    "nodes": [
      {
        "id": "n-journal-20250924-001",
        "type": "entry",
        "timestamp": "2025-09-24T21:00:00.000Z",
        "content": {
          "text": "Working on ARC MVP today. Feeling momentum but also some anxiety about the iOS build process."
        },
        "emotions": ["focused", "anxious"],
        "phaseHint": "Transition",
        "sage": {
          "situation": "Developing ARC MVP with build concerns",
          "action": "Continuing development while monitoring build issues",
          "growth": "Learning to balance momentum with technical challenges",
          "essence": "Productive anxiety as creative fuel"
        },
        "keywords": ["ARC", "MVP", "momentum", "anxiety", "iOS", "build"]
      },
      {
        "id": "n-keyword-arc",
        "type": "keyword",
        "timestamp": "2025-09-24T21:00:01.000Z",
        "label": "ARC",
        "frequency": 5,
        "category": "project"
      },
      {
        "id": "n-emotion-focused",
        "type": "emotion",
        "timestamp": "2025-09-24T21:00:02.000Z",
        "label": "focused",
        "valence": 0.7,
        "arousal": 0.6
      }
    ],
    "edges": [
      {
        "from": "n-journal-20250924-001",
        "to": "n-keyword-arc",
        "type": "mentions",
        "weight": 0.95,
        "context": "primary project focus"
      },
      {
        "from": "n-journal-20250924-001",
        "to": "n-emotion-focused",
        "type": "emotion_hint",
        "weight": 0.7,
        "detected_by": "mood_analysis"
      }
    ]
  };
}

/// Generate a test bundle with current timestamp
Map<String, dynamic> _generateTestBundle() {
  final now = DateTime.now().toUtc().toIso8601String();
  final bundleId = 'b-test-${DateTime.now().millisecondsSinceEpoch}';

  return {
    "schemaVersion": "mcp-1.0",
    "bundleId": bundleId,
    "nodes": [
      {
        "id": "n-test-001",
        "type": "entry",
        "timestamp": now,
        "content": {
          "text": "Generated test entry at $now"
        }
      }
    ],
    "edges": []
  };
}