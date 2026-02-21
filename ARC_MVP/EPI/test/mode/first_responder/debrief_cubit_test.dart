import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:my_app/mode/first_responder/debrief/debrief_cubit.dart';
import 'package:my_app/mode/first_responder/debrief/debrief_models.dart';

void main() {
  group('DebriefCubit', () {
    late DebriefCubit debriefCubit;

    setUp(() {
      debriefCubit = DebriefCubit();
    });

    tearDown(() {
      debriefCubit.close();
    });

    test('initial state is DebriefInitial', () {
      expect(debriefCubit.state, equals(const DebriefInitial()));
    });

    group('Starting Debrief', () {
      blocTest<DebriefCubit, DebriefState>(
        'emits DebriefInProgress when startDebrief is called',
        build: () => debriefCubit,
        act: (cubit) => cubit.startDebrief(),
        expect: () => [
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.snapshot)
            .having((state) => state.stepCount, 'stepCount', 0)
            .having((state) => state.record.snapshot, 'snapshot', isEmpty)
        ],
      );
    });

    group('Step Navigation', () {
      blocTest<DebriefCubit, DebriefState>(
        'navigates to next step correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.goToNextStep();
        },
        expect: () => [
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.snapshot),
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.reflection)
            .having((state) => state.stepCount, 'stepCount', 1),
        ],
      );

      blocTest<DebriefCubit, DebriefState>(
        'navigates to previous step correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.goToNextStep();
          cubit.goToPreviousStep();
        },
        expect: () => [
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.snapshot),
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.reflection),
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.snapshot)
            .having((state) => state.stepCount, 'stepCount', 0),
        ],
      );

      blocTest<DebriefCubit, DebriefState>(
        'skips step correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.skipStep();
        },
        expect: () => [
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.snapshot),
          isA<DebriefInProgress>()
            .having((state) => state.currentStep, 'currentStep', DebriefStep.reflection),
        ],
      );
    });

    group('Data Updates', () {
      blocTest<DebriefCubit, DebriefState>(
        'updates snapshot correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.updateSnapshot('Test snapshot content');
        },
        expect: () => [
          isA<DebriefInProgress>(),
          isA<DebriefInProgress>()
            .having((state) => state.record.snapshot, 'snapshot', 'Test snapshot content'),
        ],
      );

      blocTest<DebriefCubit, DebriefState>(
        'updates went well list correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.updateWentWell(['Communication', 'Teamwork']);
        },
        expect: () => [
          isA<DebriefInProgress>(),
          isA<DebriefInProgress>()
            .having((state) => state.record.wentWell, 'wentWell', ['Communication', 'Teamwork']),
        ],
      );

      blocTest<DebriefCubit, DebriefState>(
        'updates body score correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.updateBodyScore(4);
        },
        expect: () => [
          isA<DebriefInProgress>(),
          isA<DebriefInProgress>()
            .having((state) => state.record.bodyScore, 'bodyScore', 4),
        ],
      );

      blocTest<DebriefCubit, DebriefState>(
        'marks breath completed correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.markBreathCompleted();
        },
        expect: () => [
          isA<DebriefInProgress>(),
          isA<DebriefInProgress>()
            .having((state) => state.record.breathCompleted, 'breathCompleted', true),
        ],
      );
    });

    group('Completion', () {
      blocTest<DebriefCubit, DebriefState>(
        'completes debrief correctly',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.updateSnapshot('Test snapshot');
          cubit.updateEssence('Key takeaway');
          cubit.completeDebrief();
        },
        expect: () => [
          isA<DebriefInProgress>(),
          isA<DebriefInProgress>()
            .having((state) => state.record.snapshot, 'snapshot', 'Test snapshot'),
          isA<DebriefInProgress>()
            .having((state) => state.record.essence, 'essence', 'Key takeaway'),
          isA<DebriefCompleted>()
            .having((state) => state.record.snapshot, 'snapshot', 'Test snapshot')
            .having((state) => state.record.essence, 'essence', 'Key takeaway')
            .having((state) => state.stepsCompleted, 'stepsCompleted', 1),
        ],
      );
    });

    group('Helper Methods', () {
      test('canGoBack returns correct value', () {
        debriefCubit.startDebrief();
        expect(debriefCubit.canGoBack, false);

        debriefCubit.goToNextStep();
        expect(debriefCubit.canGoBack, true);
      });

      test('canGoNext returns correct value', () {
        debriefCubit.startDebrief();
        expect(debriefCubit.canGoNext, true);

        // Navigate to last step
        for (int i = 0; i < DebriefStep.values.length - 1; i++) {
          debriefCubit.goToNextStep();
        }
        expect(debriefCubit.canGoNext, false);
      });

      test('isLastStep returns correct value', () {
        debriefCubit.startDebrief();
        expect(debriefCubit.isLastStep, false);

        // Navigate to last step
        for (int i = 0; i < DebriefStep.values.length - 1; i++) {
          debriefCubit.goToNextStep();
        }
        expect(debriefCubit.isLastStep, true);
      });

      test('estimatedRemainingTime returns correct duration', () {
        debriefCubit.startDebrief();
        final remainingTime = debriefCubit.estimatedRemainingTime;
        
        // Should have time for all steps except the first (snapshot)
        final expectedSeconds = DebriefStep.values
            .skip(1)
            .fold(0, (sum, step) => sum + step.estimatedSeconds);
        
        expect(remainingTime.inSeconds, expectedSeconds);
      });
    });

    group('Reset', () {
      blocTest<DebriefCubit, DebriefState>(
        'resets to initial state',
        build: () => debriefCubit,
        act: (cubit) {
          cubit.startDebrief();
          cubit.updateSnapshot('Test');
          cubit.reset();
        },
        expect: () => [
          isA<DebriefInProgress>(),
          isA<DebriefInProgress>(),
          const DebriefInitial(),
        ],
      );
    });
  });
}