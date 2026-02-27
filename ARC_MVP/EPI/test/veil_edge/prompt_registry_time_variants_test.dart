/// Tests for VEIL-EDGE Prompt Registry Time Variants
/// 
/// Tests for time-aware prompt variants and circadian guidance
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/veil_edge/registry/prompt_registry.dart';

void main() {
  group('VeilEdgePromptRenderer Time Variants', () {
    late VeilEdgePromptRenderer renderer;

    setUp(() {
      renderer = VeilEdgePromptRenderer();
    });

    group('time guidance', () {
      test('should provide morning guidance', () {
        final prompt = renderer.renderPrompt(
          phaseGroup: 'D-B',
          variant: '',
          blocks: ['Mirror', 'Orient', 'Log'],
          variables: {'themes': 'exploration'},
          circadianWindow: 'morning',
        );

        expect(prompt, contains('Time Guidance: Keep it clear and energizing. Favor intent and next step.'));
      });

      test('should provide afternoon guidance', () {
        final prompt = renderer.renderPrompt(
          phaseGroup: 'T-D',
          variant: '',
          blocks: ['Mirror', 'Orient', 'Log'],
          variables: {'themes': 'transition'},
          circadianWindow: 'afternoon',
        );

        expect(prompt, contains('Time Guidance: Favor synthesis and decision clarity.'));
      });

      test('should provide evening guidance', () {
        final prompt = renderer.renderPrompt(
          phaseGroup: 'R-T',
          variant: '',
          blocks: ['Mirror', 'Safeguard', 'Log'],
          variables: {'themes': 'restoration'},
          circadianWindow: 'evening',
        );

        expect(prompt, contains('Time Guidance: Favor closure and gentle tone. Keep it light.'));
      });

      test('should not include time guidance when not provided', () {
        final prompt = renderer.renderPrompt(
          phaseGroup: 'D-B',
          variant: '',
          blocks: ['Mirror', 'Orient', 'Log'],
          variables: {'themes': 'exploration'},
        );

        expect(prompt, isNot(contains('Time Guidance:')));
      });
    });

    group('block variants', () {
      test('should render morning Mirror variant', () {
        final block = renderer.renderBlock(
          'Mirror',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'themes': 'clarity'},
          'morning',
        );

        expect(block, contains('I am hearing clarity and intention around clarity.'));
      });

      test('should render evening Mirror variant', () {
        final block = renderer.renderBlock(
          'Mirror',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'themes': 'reflection'},
          'evening',
        );

        expect(block, contains('I am hearing reflection and integration around reflection.'));
      });

      test('should render morning Orient variant', () {
        final block = renderer.renderBlock(
          'Orient',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'A': 'path1', 'B': 'path2'},
          'morning',
        );

        expect(block, contains('Which aligns with your energy this morning?'));
      });

      test('should render afternoon Orient variant', () {
        final block = renderer.renderBlock(
          'Orient',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'A': 'path1', 'B': 'path2'},
          'afternoon',
        );

        expect(block, contains('Let us synthesize path1 and path2 into a clear direction.'));
      });

      test('should render evening Orient variant', () {
        final block = renderer.renderBlock(
          'Orient',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'A': 'path1', 'B': 'path2'},
          'evening',
        );

        expect(block, contains('Which feels right for winding down?'));
      });

      test('should render morning Commit variant', () {
        final block = renderer.renderBlock(
          'Commit',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'start': '09:00', 'stop': '17:00', 'checkpoint': '12:00'},
          'morning',
        );

        expect(block, contains('morning check-in at 12:00'));
      });

      test('should render evening Commit variant', () {
        final block = renderer.renderBlock(
          'Commit',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'start': '19:00', 'stop': '21:00', 'checkpoint': '20:00'},
          'evening',
        );

        expect(block, contains('gentle intention'));
        expect(block, contains('soft check-in at 20:00'));
      });

      test('should render afternoon Nudge variant', () {
        final block = renderer.renderBlock(
          'Nudge',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {},
          'afternoon',
        );

        expect(block, contains('decision point and a clear success metric'));
      });

      test('should render evening Nudge variant', () {
        final block = renderer.renderBlock(
          'Nudge',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {},
          'evening',
        );

        expect(block, contains('gentle step and a simple completion marker'));
      });

      test('should render evening Safeguard variant', () {
        final block = renderer.renderBlock(
          'Safeguard',
          VeilEdgePromptRegistry.getDefault().getFamily('T-D')!,
          {},
          'evening',
        );

        expect(block, contains('calming action in 5 minutes or less'));
      });

      test('should render evening Log variant', () {
        final block = renderer.renderBlock(
          'Log',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {},
          'evening',
        );

        expect(block, contains('gentle reflection for closure'));
      });

      test('should fall back to default when no variant exists', () {
        final block = renderer.renderBlock(
          'Mirror',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'themes': 'test'},
          'afternoon', // No afternoon variant for Mirror
        );

        expect(block, contains('I am hearing curiosity around test.')); // Default template
      });

      test('should fall back to default when circadian window is null', () {
        final block = renderer.renderBlock(
          'Mirror',
          VeilEdgePromptRegistry.getDefault().getFamily('D-B')!,
          {'themes': 'test'},
          null,
        );

        expect(block, contains('I am hearing curiosity around test.')); // Default template
      });
    });

    group('complete prompt rendering', () {
      test('should render complete prompt with morning variants', () {
        final prompt = renderer.renderPrompt(
          phaseGroup: 'D-B',
          variant: '',
          blocks: ['Mirror', 'Orient', 'Commit', 'Log'],
          variables: {
            'themes': 'exploration',
            'A': 'option1',
            'B': 'option2',
            'start': '09:00',
            'stop': '17:00',
            'checkpoint': '12:00',
          },
          circadianWindow: 'morning',
        );

        expect(prompt, contains('Time Guidance: Keep it clear and energizing'));
        expect(prompt, contains('I am hearing clarity and intention around exploration'));
        expect(prompt, contains('Which aligns with your energy this morning?'));
        expect(prompt, contains('morning check-in at 12:00'));
      });

      test('should render complete prompt with evening variants', () {
        final prompt = renderer.renderPrompt(
          phaseGroup: 'R-T',
          variant: '',
          blocks: ['Mirror', 'Safeguard', 'Log'],
          variables: {
            'themes': 'restoration',
          },
          circadianWindow: 'evening',
        );

        expect(prompt, contains('Time Guidance: Favor closure and gentle tone'));
        expect(prompt, contains('I am hearing reflection and integration around restoration'));
        expect(prompt, contains('calming action in 5 minutes or less'));
        expect(prompt, contains('gentle reflection for closure'));
      });

      test('should include variant-specific instructions', () {
        final safePrompt = renderer.renderPrompt(
          phaseGroup: 'D-B',
          variant: ':safe',
          blocks: ['Mirror', 'Orient', 'Log'],
          variables: {'themes': 'test'},
          circadianWindow: 'morning',
        );

        expect(safePrompt, contains('Note: This is a safe mode session'));

        final alertPrompt = renderer.renderPrompt(
          phaseGroup: 'R-T',
          variant: ':alert',
          blocks: ['Mirror', 'Safeguard', 'Log'],
          variables: {'themes': 'test'},
          circadianWindow: 'evening',
        );

        expect(alertPrompt, contains('Note: This is an alert mode session'));
      });
    });
  });
}
