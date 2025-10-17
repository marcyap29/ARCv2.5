import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/features/timeline/timeline_state.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';

void main() {
  group('Timeline Rebuild Control Tests', () {
    testWidgets('BlocBuilder only rebuilds when hashForUi changes', (WidgetTester tester) async {
      int buildCount = 0;
      
      final cubit = MockTimelineCubit();
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocBuilder<TimelineCubit, TimelineState>(
            bloc: cubit,
            buildWhen: (prev, curr) {
              if (prev is TimelineLoaded && curr is TimelineLoaded) {
                return prev.hashForUi != curr.hashForUi;
              }
              return true; // Always rebuild for non-TimelineLoaded states
            },
            builder: (context, state) {
              buildCount++;
              return Text('Build count: $buildCount');
            },
          ),
        ),
      );

      // Initial build
      expect(buildCount, 1);
      expect(find.text('Build count: 1'), findsOneWidget);

      // Emit same state - should not rebuild
      cubit.emitSameState();
      await tester.pump();
      expect(buildCount, 1);
      expect(find.text('Build count: 1'), findsOneWidget);

      // Emit state with different hash - should rebuild
      cubit.emitDifferentHashState();
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Build count: 2'), findsOneWidget);

      // Emit same state again - should not rebuild
      cubit.emitSameState();
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Build count: 2'), findsOneWidget);
    });

    testWidgets('TimelineState hashForUi calculates correctly', (WidgetTester tester) async {
      final entries1 = [
        TimelineEntry(
          id: 'entry1',
          title: 'Title 1',
          preview: 'Preview 1',
          date: '2024-01-01',
          phase: 'discovery',
          media: [],
        ),
      ];
      
      final entries2 = [
        TimelineEntry(
          id: 'entry1',
          title: 'Title 1',
          preview: 'Preview 1',
          date: '2024-01-01',
          phase: 'discovery',
          media: [],
        ),
        TimelineEntry(
          id: 'entry2',
          title: 'Title 2',
          preview: 'Preview 2',
          date: '2024-01-02',
          phase: 'expansion',
          media: [],
        ),
      ];

      final state1 = TimelineLoaded(
        groupedEntries: [
          TimelineMonthGroup(month: 'January 2024', entries: entries1),
        ],
        filter: TimelineFilter.all,
        hasMore: false,
        version: 1,
      );

      final state2 = TimelineLoaded(
        groupedEntries: [
          TimelineMonthGroup(month: 'January 2024', entries: entries2),
        ],
        filter: TimelineFilter.all,
        hasMore: false,
        version: 1,
      );

      final state3 = TimelineLoaded(
        groupedEntries: [
          TimelineMonthGroup(month: 'January 2024', entries: entries1),
        ],
        filter: TimelineFilter.all,
        hasMore: false,
        version: 2,
      );

      // Different entries should have different hashes
      expect(state1.hashForUi, isNot(equals(state2.hashForUi)));
      
      // Same entries but different version should have different hashes
      expect(state1.hashForUi, isNot(equals(state3.hashForUi)));
      
      // Same state should have same hash
      expect(state1.hashForUi, equals(state1.hashForUi));
    });

    testWidgets('TimelineState copyWith increments version', (WidgetTester tester) async {
      final state = TimelineLoaded(
        groupedEntries: [],
        filter: TimelineFilter.all,
        hasMore: false,
        version: 1,
      );

      final newState = state.copyWith();
      expect(newState.version, 2);
      
      final newStateWithVersion = state.copyWith(version: 5);
      expect(newStateWithVersion.version, 5);
    });
  });
}

// Mock TimelineCubit for testing
class MockTimelineCubit extends TimelineCubit {
  MockTimelineCubit() : super();

  void emitSameState() {
    final state = TimelineLoaded(
      groupedEntries: [
        TimelineMonthGroup(
          month: 'January 2024',
          entries: [
            TimelineEntry(
              id: 'entry1',
              title: 'Title',
              preview: 'Preview',
              date: '2024-01-01',
              phase: 'discovery',
              media: [],
            ),
          ],
        ),
      ],
      filter: TimelineFilter.all,
      hasMore: false,
      version: 1,
    );
    emit(state);
  }

  void emitDifferentHashState() {
    final state = TimelineLoaded(
      groupedEntries: [
        TimelineMonthGroup(
          month: 'January 2024',
          entries: [
            TimelineEntry(
              id: 'entry1',
              title: 'Title',
              preview: 'Preview',
              date: '2024-01-01',
              phase: 'discovery',
              media: [],
            ),
            TimelineEntry(
              id: 'entry2',
              title: 'Title 2',
              preview: 'Preview 2',
              date: '2024-01-02',
              phase: 'expansion',
              media: [],
            ),
          ],
        ),
      ],
      filter: TimelineFilter.all,
      hasMore: false,
      version: 1,
    );
    emit(state);
  }
}
