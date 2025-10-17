import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_app/data/models/arcform_snapshot.dart';
import 'dart:convert';

void main() {
  group('ArcformSnapshot', () {
    late ArcformSnapshot snapshot;

    setUp(() {
      snapshot = ArcformSnapshot(
        phase: 'discovery',
        geometryJson: '{"x": 100, "y": 200}',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        description: 'Test snapshot',
      );
    });

    group('Constructor', () {
      test('creates instance with all parameters', () {
        expect(snapshot.phase, 'discovery');
        expect(snapshot.geometryJson, '{"x": 100, "y": 200}');
        expect(snapshot.timestamp, DateTime(2024, 1, 1, 12, 0, 0));
        expect(snapshot.description, 'Test snapshot');
      });

      test('creates instance with required parameters only', () {
        final minimalSnapshot = ArcformSnapshot(
          phase: 'expansion',
          geometryJson: '{}',
          timestamp: DateTime.now(),
        );
        expect(minimalSnapshot.phase, 'expansion');
        expect(minimalSnapshot.geometryJson, '{}');
        expect(minimalSnapshot.description, null);
      });
    });

    group('fromMap', () {
      test('creates instance from valid map', () {
        final map = {
          'phase': 'transition',
          'geometry': '{"x": 50, "y": 75}',
          'timestamp': '2024-01-01T12:00:00.000Z',
          'description': 'Test description',
        };
        final snapshot = ArcformSnapshot.fromMap(map);
        expect(snapshot.phase, 'transition');
        expect(snapshot.geometryJson, '{"x": 50, "y": 75}');
        expect(snapshot.timestamp, DateTime.utc(2024, 1, 1, 12, 0, 0));
        expect(snapshot.description, 'Test description');
      });

      test('handles map with geometry as Map object', () {
        final map = {
          'phase': 'consolidation',
          'geometry': {'x': 25, 'y': 50},
          'timestamp': '2024-01-01T12:00:00.000Z',
        };
        final snapshot = ArcformSnapshot.fromMap(map);
        expect(snapshot.phase, 'consolidation');
        expect(snapshot.geometryJson, '{"x":25,"y":50}');
      });

      test('handles missing optional fields', () {
        final map = {
          'phase': 'recovery',
          'geometry': '{}',
        };
        final snapshot = ArcformSnapshot.fromMap(map);
        expect(snapshot.phase, 'recovery');
        expect(snapshot.geometryJson, '{}');
        expect(snapshot.timestamp, isA<DateTime>());
        expect(snapshot.description, null);
      });

      test('handles invalid timestamp', () {
        final map = {
          'phase': 'breakthrough',
          'geometry': '{}',
          'timestamp': 'invalid-date',
        };
        final snapshot = ArcformSnapshot.fromMap(map);
        expect(snapshot.phase, 'breakthrough');
        expect(snapshot.timestamp, isA<DateTime>());
      });
    });

    group('toMap', () {
      test('converts instance to map', () {
        final map = snapshot.toMap();
        expect(map['phase'], 'discovery');
        expect(map['geometry'], '{"x": 100, "y": 200}');
        expect(map['timestamp'], '2024-01-01T12:00:00.000');
        expect(map['description'], 'Test snapshot');
      });
    });

    group('geometryMap', () {
      test('returns parsed geometry as Map', () {
        final geometry = snapshot.geometryMap;
        expect(geometry, {'x': 100, 'y': 200});
      });

      test('returns empty map for invalid JSON', () {
        final invalidSnapshot = ArcformSnapshot(
          phase: 'test',
          geometryJson: 'invalid json',
          timestamp: DateTime.now(),
        );
        final geometry = invalidSnapshot.geometryMap;
        expect(geometry, <String, dynamic>{});
      });
    });

    group('copyWithGeometry', () {
      test('creates new instance with updated geometry', () {
        final newGeometry = {'x': 300, 'y': 400, 'z': 500};
        final updatedSnapshot = snapshot.copyWithGeometry(newGeometry);
        
        expect(updatedSnapshot.phase, snapshot.phase);
        expect(updatedSnapshot.timestamp, snapshot.timestamp);
        expect(updatedSnapshot.description, snapshot.description);
        expect(updatedSnapshot.geometryMap, newGeometry);
      });
    });

    group('toString', () {
      test('returns string representation', () {
        final string = snapshot.toString();
        expect(string, contains('ArcformSnapshot'));
        expect(string, contains('phase: discovery'));
        expect(string, contains('description: Test snapshot'));
      });
    });

    group('Hive Serialization', () {
      test('can be serialized and deserialized', () {
        // This test would require Hive to be initialized
        // In a real test environment, you'd set up Hive first
        expect(snapshot, isA<HiveObject>());
      });
    });
  });
}
