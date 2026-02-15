/// Transcript Cleanup Service (LUMARA Voice Spec)
///
/// Mandatory post-ASR pass: remove filler words, fix common misrecognitions,
/// correct repetitions and false starts, light grammatical cleanup.
/// Preserves semantic meaning; target <10ms per utterance.

class TranscriptCleanupService {
  TranscriptCleanupService() : _fillerWords = _buildFillerSet();

  final Set<String> _fillerWords;
  static const List<String> _multiWordFillers = [
    'you know',
    'i mean',
    'kind of',
    'sort of',
    'i guess',
    'i suppose',
  ];

  static Set<String> _buildFillerSet() {
    return {
      'um', 'uh', 'er', 'ah', 'hmm', 'mm',
      'like', 'basically', 'actually', 'literally', 'honestly',
      'so', 'well', 'right', 'okay', 'yeah',
      'anyway', 'whatever',
    };
  }

  static const Map<String, String> _commonCorrections = {
    "their they're": "they're",
    "there they're": "they're",
    "its it's": "it's",
    "would of": "would have",
    "could of": "could have",
    "should of": "should have",
    "lumera": "LUMARA",
    "prism": "PRISM",
    "atlas": "ATLAS",
  };

  /// Run full cleanup on a raw transcript. Use for final segments only.
  String cleanup(String transcript) {
    if (transcript.trim().isEmpty) return transcript;
    String cleaned = transcript;
    cleaned = _removeFillerWords(cleaned);
    cleaned = _fixCommonErrors(cleaned);
    cleaned = _removeRepetitions(cleaned);
    cleaned = _removeFalseStarts(cleaned);
    cleaned = _lightGrammarFix(cleaned);
    cleaned = _normalizeWhitespace(cleaned);
    return cleaned;
  }

  String _removeFillerWords(String text) {
    final words = text.split(RegExp(r'\s+'));
    final kept = words.where((w) {
      final normalized = w.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      return normalized.isNotEmpty && !_fillerWords.contains(normalized);
    }).toList();
    String result = kept.join(' ');
    for (final filler in _multiWordFillers) {
      result = result.replaceAll(RegExp(RegExp.escape(filler), caseSensitive: false), ' ');
    }
    return result;
  }

  String _fixCommonErrors(String text) {
    String result = text;
    for (final entry in _commonCorrections.entries) {
      result = result.replaceAll(RegExp(RegExp.escape(entry.key), caseSensitive: false), entry.value);
    }
    return result;
  }

  String _removeRepetitions(String text) {
    // Word word -> word
    String result = text.replaceAllMapped(
      RegExp(r'\b(\w+)\s+\1\b', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );
    // word word word -> word
    result = result.replaceAllMapped(
      RegExp(r'\b(\w+)\s+\1\s+\1\b', caseSensitive: false),
      (m) => m.group(1) ?? '',
    );
    return result;
  }

  String _removeFalseStarts(String text) {
    // "I was— I mean I went to" -> remove "I was— I mean " (keep "I went to")
    return text.replaceAll(
      RegExp(r'[^\s—]+—\s*(?:I mean|actually|no)\s+', caseSensitive: false),
      '',
    );
  }

  String _lightGrammarFix(String text) {
    if (text.isEmpty) return text;
    String result = text.trim();
    if (result.isEmpty) return text;
    result = result[0].toUpperCase() + result.substring(1);
    const endings = {'.', '!', '?'};
    if (result.isNotEmpty && !endings.contains(result[result.length - 1])) {
      result = '$result.';
    }
    result = result.replaceAllMapped(
      RegExp(r'([.!?])\s+([a-z])'),
      (m) => '${m.group(1)} ${(m.group(2) ?? '').toUpperCase()}',
    );
    return result;
  }

  String _normalizeWhitespace(String text) {
    String result = text.replaceAll(RegExp(r'\s+'), ' ');
    result = result.replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1');
    result = result.replaceAll(RegExp(r'([.,!?;:])([^ ])'), r'$1 $2');
    return result.trim();
  }
}
