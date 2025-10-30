import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/arcform_snapshot.dart';

void main() {
  group('ArcformSnapshot', () {
    late ArcformSnapshot snapshot;

    setUp(() {
      snapshot = ArcformSnapshot(
        id: 'test-snapshot-1',
        journalEntryId: 'test-entry-1',
        title: 'Test snapshot',
        keywords: [],
        colorMap: {},
        edges: [],
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        phase: 'discovery',
        userConsentedPhase: false,
      );
    });

    group('Constructor', () {
      test('creates instance with all parameters', () {
        expect(snapshot.phase, 'discovery');
        expect(snapshot.title, 'Test snapshot');
        expect(snapshot.createdAt, DateTime(2024, 1, 1, 12, 0, 0));
        expect(snapshot.id, 'test-snapshot-1');
      });

      test('creates instance with required parameters only', () {
        final minimalSnapshot = ArcformSnapshot(
          id: 'test-2',
          journalEntryId: 'entry-2',
          title: 'Minimal',
          keywords: [],
          colorMap: {},
          edges: [],
          createdAt: DateTime.now(),
          phase: 'expansion',
          userConsentedPhase: false,
        );
        expect(minimalSnapshot.phase, 'expansion');
        expect(minimalSnapshot.title, 'Minimal');
      });
    });

    group('fromJson', () {
      test('creates instance from valid JSON', () {
        final json = {
          'id': 'test-id',
          'journalEntryId': 'entry-id',
          'title': 'Test description',
          'keywords': ['test'],
          'colorMap': {'key': 'value'},
          'edges': [],
          'createdAt': '2024-01-01T12:00:00.000Z',
          'phase': 'transition',
          'userConsentedPhase': false,
          'isGeometryAuto': true,
        };
        final snapshot = ArcformSnapshot.fromJson(json);
        expect(snapshot.phase, 'transition');
        expect(snapshot.title, 'Test description');
        expect(snapshot.createdAt, DateTime.utc(2024, 1, 1, 12, 0, 0));
        expect(snapshot.recommendationRationale, null);
      });

      test('handles optional fields', () {
        final json = {
          'id': 'test-id',
          'journalEntryId': 'entry-id',
          'title': 'Test',
          'keywords': [],
          'colorMap': {},
          'edges': [],
          'createdAt': '2024-01-01T12:00:00.000Z',
          'phase': 'consolidation',
          'userConsentedPhase': false,
          'isGeometryAuto': false,
          'recommendationRationale': 'Test rationale',
        };
        final snapshot = ArcformSnapshot.fromJson(json);
        expect(snapshot.phase, 'consolidation');
        expect(snapshot.recommendationRationale, 'Test rationale');
      });
    });

    group('toJson', () {
      test('converts instance to JSON', () {
        final json = snapshot.toJson();
        expect(json['phase'], 'discovery');
        expect(json['title'], 'Test snapshot');
        expect(json['createdAt'], '2024-01-01T12:00:00.000Z');
        expect(json['id'], 'test-snapshot-1');
      });
    });

    group('copyWith', () {
      test('creates new instance with updated fields', () {
        final updatedSnapshot = snapshot.copyWith(
          phase: 'expansion',
          title: 'Updated title',
        );
        
        expect(updatedSnapshot.phase, 'expansion');
        expect(updatedSnapshot.title, 'Updated title');
        expect(updatedSnapshot.id, snapshot.id);
        expect(updatedSnapshot.createdAt, snapshot.createdAt);
      });
    });

    group('toString', () {
      test('returns string representation', () {
        final string = snapshot.toString();
        expect(string, contains('ArcformSnapshot'));
        expect(string, contains('phase: discovery'));
      });
    });

    group('Equality', () {
      test('uses Equatable for equality', () {
        final snapshot2 = ArcformSnapshot(
          id: snapshot.id,
          journalEntryId: snapshot.journalEntryId,
          title: snapshot.title,
          keywords: snapshot.keywords,
          colorMap: snapshot.colorMap,
          edges: snapshot.edges,
          createdAt: snapshot.createdAt,
          phase: snapshot.phase,
          userConsentedPhase: snapshot.userConsentedPhase,
        );
        expect(snapshot, equals(snapshot2));
      });
    });
  });
}

