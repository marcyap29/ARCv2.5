import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/prism/atlas/phase/phase_change_notifier.dart';

void main() {
  group('PhaseChangeNotifier', () {
    testWidgets('should show phase change notification', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    PhaseChangeNotifier.showPhaseChangeNotification(
                      context,
                      fromPhase: 'Discovery',
                      toPhase: 'Expansion',
                      reason: 'Phase changed from Discovery to Expansion (score: 0.900)',
                    );
                  },
                  child: const Text('Test Notification'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to trigger notification
      await tester.tap(find.text('Test Notification'));
      await tester.pump();

      // Verify notification is shown
      expect(find.text('Phase Evolution'), findsOneWidget);
      expect(find.text('Your journey has evolved from Discovery to Expansion'), findsOneWidget);
      expect(find.text('Phase changed from Discovery to Expansion (score: 0.900)'), findsOneWidget);
    });

    testWidgets('should show phase stability notification', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    PhaseChangeNotifier.showPhaseStabilityNotification(
                      context,
                      currentPhase: 'Discovery',
                      reason: 'No phase change needed - current phase remains optimal',
                    );
                  },
                  child: const Text('Test Stability'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to trigger notification
      await tester.tap(find.text('Test Stability'));
      await tester.pump();

      // Verify notification is shown
      expect(find.text('Phase Stability'), findsOneWidget);
      expect(find.text('Your Discovery phase continues to serve you well'), findsOneWidget);
    });

    testWidgets('should show phase change celebration dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    PhaseChangeNotifier.showPhaseChangeCelebration(
                      context,
                      fromPhase: 'Discovery',
                      toPhase: 'Breakthrough',
                    );
                  },
                  child: const Text('Test Celebration'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to trigger dialog
      await tester.tap(find.text('Test Celebration'));
      await tester.pump();

      // Verify dialog is shown
      expect(find.text('Phase Evolution!'), findsOneWidget);
      expect(find.text('Your journey has evolved from Discovery to Breakthrough'), findsOneWidget);
      expect(find.text('Continue Journey'), findsOneWidget);
    });

    test('should return correct colors for phases', () {
      expect(PhaseChangeNotifier.getPhaseColor('Discovery'), equals(Colors.purple));
      expect(PhaseChangeNotifier.getPhaseColor('Expansion'), equals(Colors.green));
      expect(PhaseChangeNotifier.getPhaseColor('Transition'), equals(Colors.orange));
      expect(PhaseChangeNotifier.getPhaseColor('Consolidation'), equals(Colors.blue));
      expect(PhaseChangeNotifier.getPhaseColor('Recovery'), equals(Colors.teal));
      expect(PhaseChangeNotifier.getPhaseColor('Breakthrough'), equals(Colors.amber));
      expect(PhaseChangeNotifier.getPhaseColor('Unknown'), equals(Colors.grey));
    });

    test('should handle case insensitive phase names', () {
      expect(PhaseChangeNotifier.getPhaseColor('discovery'), equals(Colors.purple));
      expect(PhaseChangeNotifier.getPhaseColor('EXPANSION'), equals(Colors.green));
      expect(PhaseChangeNotifier.getPhaseColor('Transition'), equals(Colors.orange));
    });
  });
}
