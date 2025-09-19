import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/prompts_arc.dart';

void main() {
  test('SAGE Echo prompt should interpolate entry', () {
    final p = ArcPrompts.sageEcho.replaceAll('{{entry_text}}', 'hello world');
    expect(p.contains('hello world'), true);
    expect(p.contains('{{entry_text}}'), false);
  });

  test('Phase Hints prompt has all phases', () {
    final p = ArcPrompts.phaseHints;
    for (final phase in const [
      'discovery',
      'expansion',
      'transition',
      'consolidation',
      'recovery',
      'breakthrough',
    ]) {
      expect(p.contains(phase), true);
    }
  });
}
