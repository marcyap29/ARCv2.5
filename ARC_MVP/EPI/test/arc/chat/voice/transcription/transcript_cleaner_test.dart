/// Tests for TranscriptCleaner — on-device voice transcript cleanup.
///
/// Run: flutter test test/arc/chat/voice/transcription/transcript_cleaner_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/chat/voice/transcription/cleanup/transcript_cleaner.dart';

void main() {
  group('TranscriptCleaner', () {
    group('fillers', () {
      test('removes sentence-initial um', () {
        expect(
          TranscriptCleaner.clean('Um, I went to the store today.'),
          'I went to the store today.',
        );
      });
      test('removes mid-sentence you know', () {
        expect(
          TranscriptCleaner.clean('It was, you know, really hard for me.'),
          'It was really hard for me.',
        );
      });
      test('removes basically opener', () {
        expect(
          TranscriptCleaner.clean('Basically I think we need to talk.'),
          'I think we need to talk.',
        );
      });
      test('preserves comparative like', () {
        expect(
          TranscriptCleaner.clean('It felt like rain was coming.'),
          'It felt like rain was coming.',
        );
      });
      test('preserves sounds like', () {
        expect(
          TranscriptCleaner.clean('It sounds like a good idea.'),
          'It sounds like a good idea.',
        );
      });
    });

    group('false starts', () {
      test('fixes em-dash false start', () {
        expect(
          TranscriptCleaner.clean('I was go— I went home early.'),
          'I went home early.',
        );
      });
      test('fixes repeated article', () {
        expect(
          TranscriptCleaner.clean('The the point is I was tired.'),
          'The point is I was tired.',
        );
      });
      test('fixes fragment restart with short fragment', () {
        expect(
          TranscriptCleaner.clean('I was go, I went to the store.'),
          'I went to the store.',
        );
      });
    });

    group('self-corrections', () {
      test('keeps last version after no wait', () {
        expect(
          TranscriptCleaner.clean('Call her Monday, no wait, call her Friday.'),
          'Call her Friday.',
        );
      });
      test('keeps last version after actually', () {
        expect(
          TranscriptCleaner.clean('I was sad, actually I was relieved.'),
          'I was relieved.',
        );
      });
    });

    group('stutters', () {
      test('collapses repeated function word', () {
        expect(
          TranscriptCleaner.clean('And and then I realized it was over.'),
          'And then I realized it was over.',
        );
      });
      test('preserves intentional repetition', () {
        expect(
          TranscriptCleaner.clean('It was very very important to me.'),
          'It was very very important to me.',
        );
      });
    });

    group('run-on sentences', () {
      test('inserts period before new subject after long clause', () {
        expect(
          TranscriptCleaner.clean(
            'I felt really tired and exhausted today and I went to bed early.',
          ),
          contains('I felt really tired and exhausted today. I went to bed early.'),
        );
      });
    });

    group('capitalization', () {
      test('capitalizes first letter', () {
        expect(
          TranscriptCleaner.clean('hello world'),
          'Hello world.',
        );
      });
      test('capitalizes after sentence end', () {
        expect(
          TranscriptCleaner.clean('First sentence. second sentence here.'),
          'First sentence. Second sentence here.',
        );
      });
      test('capitalizes standalone I', () {
        expect(
          TranscriptCleaner.clean('i think i know what i mean.'),
          'I think I know what I mean.',
        );
      });
    });

    group('ASR markup removal', () {
      test('removes [inaudible]', () {
        expect(
          TranscriptCleaner.clean('I was thinking [inaudible] about it.'),
          'I was thinking about it.',
        );
      });
      test('removes (pause)', () {
        expect(
          TranscriptCleaner.clean('And then (pause) I went home.'),
          'And then I went home.',
        );
      });
    });

    group('common misrecognitions', () {
      test('fixes would of → would have', () {
        expect(
          TranscriptCleaner.clean('I would of gone but I was tired.'),
          'I would have gone but I was tired.',
        );
      });
      test('fixes lumera → LUMARA', () {
        expect(
          TranscriptCleaner.clean('I asked lumera about it.'),
          'I asked LUMARA about it.',
        );
      });
      test('fixes their they\'re → they\'re', () {
        expect(
          TranscriptCleaner.clean('Their they\'re going to the store.'),
          "They're going to the store.",
        );
      });
    });

    group('hyphenated stutters', () {
      test('collapses I-I', () {
        expect(
          TranscriptCleaner.clean('I-I was going to say something.'),
          'I was going to say something.',
        );
      });
      test('collapses the-the', () {
        expect(
          TranscriptCleaner.clean('The-the point is we need to talk.'),
          'The point is we need to talk.',
        );
      });
    });

    group('additional fillers', () {
      test('removes sentence-initial I don\'t know', () {
        expect(
          TranscriptCleaner.clean("I don't know I think we should go."),
          'I think we should go.',
        );
      });
      test('removes so like opener', () {
        expect(
          TranscriptCleaner.clean('So like I went to the store today.'),
          'I went to the store today.',
        );
      });
    });

    group('edge cases', () {
      test('returns empty string unchanged', () {
        expect(TranscriptCleaner.clean(''), '');
        expect(TranscriptCleaner.clean('   '), '   ');
      });
      test('normalizes multiple punctuation', () {
        expect(
          TranscriptCleaner.clean('Really??   Yes!!!'),
          'Really? Yes!',
        );
      });
      test('strips spaces before punctuation', () {
        expect(
          TranscriptCleaner.clean('Hello , world .'),
          'Hello, world.',
        );
      });
    });
  });
}
