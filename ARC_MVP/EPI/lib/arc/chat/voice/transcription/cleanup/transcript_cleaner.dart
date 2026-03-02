/// transcript_cleaner.dart
/// On-device voice transcript cleanup for LUMARA
/// Zero network calls. Zero PII exposure. Runs synchronously in microseconds.
///
/// Pipeline order (matters):
///   1. Fix false starts (before normalize — em-dash patterns must be intact)
///   2. Normalize whitespace & punctuation artifacts from ASR
///   3. Remove ASR markup (inaudible, unclear, pause)
///   4. Fix common ASR misrecognitions (homophones, LUMARA/PRISM/ATLAS)
///   5. Remove filler words
///   6. Fix mid-sentence self-corrections ("no wait" / "I mean")
///   7. Fix word stutters / repetitions (including hyphenated: I-I, the-the)
///   8. Fix run-on sentences (missing punctuation at natural breaks)
///   9. Capitalize sentences
///  10. Final whitespace cleanup
///
/// Integration: Call TranscriptCleaner.clean() once on recording stop, before
/// Firestore write. Do NOT run on live display or chat — only on finalized
/// voice journal entries.
library;

class TranscriptCleaner {
  // ─── Public API ──────────────────────────────────────────────────────────

  /// Returns a cleaned transcript string ready for display, CHRONICLE storage,
  /// and PRISM/ATLAS processing.
  static String clean(String raw) {
    if (raw.trim().isEmpty) return raw;

    String text = raw;

    text = _fixFalseStarts(text); // Before _normalizeArtifacts so em-dash patterns are intact
    text = _normalizeArtifacts(text);
    text = _removeAsrMarkup(text);
    text = _fixCommonMisrecognitions(text);
    text = _removeFillers(text);
    text = _fixSelfCorrections(text);
    text = _fixWordStutters(text);
    text = _fixRunOnSentences(text);
    text = _capitalizeSentences(text);
    text = _finalCleanup(text);

    return text;
  }

  // ─── Step 1: Normalize ASR artifacts ─────────────────────────────────────

  static String _normalizeArtifacts(String text) {
    // Apple Speech sometimes outputs em dashes for pauses — strip them
    text = text.replaceAll(RegExp(r'\s*—\s*'), ' ');
    text = text.replaceAll(RegExp(r'\s*–\s*'), ' ');

    // Multiple punctuation collapses
    text = text.replaceAll(RegExp(r'[.]{2,}'), '.');
    text = text.replaceAll(RegExp(r'[,]{2,}'), ',');
    text = text.replaceAll(RegExp(r'[?]{2,}'), '?');
    text = text.replaceAll(RegExp(r'[!]{2,}'), '!');

    // Spaces before punctuation
    text = text.replaceAllMapped(
      RegExp(r'\s+([.,?!;:])'),
      (m) => m.group(1)!,
    );

    return text;
  }

  // ─── Step 2a: Remove ASR markup ───────────────────────────────────────────
  //
  // Some ASR engines insert markup for uncertain or inaudible segments.
  // Remove these entirely — we don't want "[inaudible]" or "(pause)" in output.

  static String _removeAsrMarkup(String text) {
    // [inaudible], [unclear], [inaudible 2.5s], etc.
    text = text.replaceAll(RegExp(r'\[inaudible[^\]]*\]', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\[unclear[^\]]*\]', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\[crosstalk[^\]]*\]', caseSensitive: false), ' ');
    // (pause), (silence), (unclear), (inaudible)
    text = text.replaceAll(RegExp(r'\(pause\)', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\(silence\)', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\(unclear\)', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'\(inaudible\)', caseSensitive: false), ' ');
    return text;
  }

  // ─── Step 2b: Common ASR misrecognitions ──────────────────────────────────
  //
  // Homophones and frequent ASR errors. Apple Speech and others often confuse
  // "of" for "have", "their/there" for "they're", etc. Also fix LUMARA brand.

  static String _fixCommonMisrecognitions(String text) {
    const corrections = {
      'their they\'re': "they're",
      'there they\'re': "they're",
      'their they are': "they're",
      'there they are': "they're",
      'its it\'s': "it's",
      'its it is': "it's",
      'your you\'re': "you're",
      'your you are': "you're",
      'would of': 'would have',
      'could of': 'could have',
      'should of': 'should have',
      'must of': 'must have',
      'might of': 'might have',
      'lumera': 'LUMARA',
      'lumara': 'LUMARA',
      'prism': 'PRISM',
      'atlas': 'ATLAS',
    };
    for (final entry in corrections.entries) {
      text = text.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        entry.value,
      );
    }
    return text;
  }

  // ─── Step 3: Filler word removal ─────────────────────────────────────────
  //
  // Organized by category. Boundary-aware so we don't strip
  // meaningful partial words (e.g. "literally" in a valid sentence is fine,
  // but "like" as a discourse filler is not).
  //
  // We handle fillers in their common spoken positions:
  //   - Sentence-initial:  "Um, I think..."     → "I think..."
  //   - Mid-sentence:      "I was, you know, tired" → "I was tired"
  //   - Sentence-final:    "It was hard, like."  → "It was hard."
  //
  // Preserve "like" when it's comparative ("it felt like rain") — handled
  // by the word-boundary + surrounding context checks below.

  static String _removeFillers(String text) {
    // Explicit ", filler," pattern first — ensures preceding comma is consumed
    const commaFillerPhrases = ['you know', 'I guess', 'I suppose', 'kind of', 'sort of'];
    for (final phrase in commaFillerPhrases) {
      text = text.replaceAll(
        RegExp(r',\s*' + phrase + r'\s*,', caseSensitive: false),
        ' ',
      );
    }

    // ── Standalone filler phrases (must be surrounded by non-word chars) ──
    final fillerPhrases = [
      // Uncertainty / stalling
      r'you know what I mean',
      r"you know what I'm saying",
      r'if that makes sense',
      r'if you know what I mean',
      r'you know',
      // 'I mean' handled separately below (preserve "what I mean")
      r'I guess',
      r'I suppose',
      r'sort of speak',
      r'so to speak',
      r'in a sense',
      r'in a way',
      r'kind of sort of',
      r'kind of',
      r'sort of',
      // Filler openers
      r'so like',
      r'so basically',
      r'basically',
      r'literally',
      r'honestly',
      r'truthfully',
      r'genuinely',
      r'obviously',
      r'clearly',
      r'right\?',
      r'right',
      r'okay so',
      r'and so',
      r'anyway',
      r'whatever',
      r"I don't know",
      // Hesitation sounds
      r'um+h*',
      r'uh+',
      r'uhm+',
      r'erm+',
      r'eh+',
      r'er+',
      r'ah+',
      r'hmm+',
      r'mhm',
      r'mm-?hmm',
    ];

    for (final phrase in fillerPhrases) {
      // Match phrase with optional surrounding comma/whitespace.
      // Lookbehind allows start, whitespace, or comma (for mid-sentence ", you know,").
      text = text.replaceAll(
        RegExp(
          r'(?:^|(?<=[\s,]))' +
              r',?\s*' +
              phrase +
              r'\s*,?' +
              r'(?=\s|[.,?!;:]|$)',
          caseSensitive: false,
        ),
        ' ',
      );
    }

    // "I mean" as filler — but preserve "what I mean" (meaningful phrase)
    text = text.replaceAll(
      RegExp(
        r'(?:^|(?<=[\s,])),?\s*(?<!what\s)I mean\s*,?(?=\s|[.,?!;:]|$)',
        caseSensitive: false,
      ),
      ' ',
    );

    // "like" as discourse filler: preceded by comma/start or followed by comma,
    // but NOT when preceded by verbs (felt, feel, look(s), seem(s), sound(s),
    // was, were, is, are, be) and NOT when followed by a noun/pronoun
    // (comparative "like rain"). Edge case: "things like that" may strip
    // "like" — acceptable trade-off for journaling.
    text = text.replaceAll(
      RegExp(
        r'(?<!felt |feel |look |looks |seem |seems |sound |sounds |was |were |is |are |be |,\s)'
        r'\blike\b'
        r'(?!\s+(?:a |an |the |[A-Z]|I |he |she |they |we |it |my |your |his |her |their ))',
        caseSensitive: false,
      ),
      ' ',
    );

    return text;
  }

  // ─── Step 1 (pre-normalize): False starts ──────────────────────────────────
  //
  // Pattern: speaker starts a word or partial phrase, then abandons it.
  // Apple Speech typically transcribes these as:
  //   "I was go— I went to the store"
  //   "She told me that she— that he was fine"
  //   "The thing is, the, the point is"
  //
  // Strategy: detect abandoned fragments followed by the speaker restarting.

  static String _fixFalseStarts(String text) {
    // Em/en dash false start: "I was go— I went" → "I went"
    // Remove fragment (1–3 words) ending in em-dash or en-dash + space
    text = text.replaceAll(
      RegExp(r'\b\w+(?:\s+\w+){0,2}[—–]\s+', caseSensitive: false),
      '',
    );

    // Repeated article/pronoun false start: "the the", "a a", "I I"
    text = text.replaceAllMapped(
      RegExp(
        r'\b(the|a|an|I|he|she|they|we|it|that|this|these|those|my|your|his|her|their|our)\s+\1\b',
        caseSensitive: false,
      ),
      (m) => m.group(1)!,
    );

    // Fragment restart: "I was go, I went" — short fragment + same subject restart
    // Match: 1-3 words, comma, same opening word
    text = text.replaceAllMapped(
      RegExp(
        r'\b(\w+(?: \w+){0,2}),\s+(I |he |she |they |we |it )',
        caseSensitive: false,
      ),
      (Match m) {
        final restart = m.group(2)!;
        final fragment = m.group(1)!.split(' ').first.toLowerCase();
        // Only strip if fragment is very short (likely abandoned)
        if (fragment.length <= 4) return restart;
        return m.group(0)!; // keep original
      },
    );

    return text;
  }

  // ─── Step 6: Self-corrections ─────────────────────────────────────────────
  //
  // Speaker changes their mind mid-sentence. Patterns:
  //   "Call him tomorrow, no wait, call him Friday" → "Call him Friday"
  //   "I was angry, or rather, I was disappointed"  → "I was disappointed"
  //   "She left on Monday, actually Tuesday"         → "She left on Tuesday"
  //
  // We keep the LAST stated version (what the speaker settled on).

  static String _fixSelfCorrections(String text) {
    final correctionTriggers = [
      r'no wait,?\s*',
      r'no,?\s*actually,?\s*',
      r'wait no,?\s*',
      r'I mean,?\s*',
      r'or rather,?\s*',
      r'actually,?\s*',
      r'well,?\s*I mean,?\s*',
      r'correction,?\s*',
      r'scratch that,?\s*',
      r'never mind,?\s*',
    ];

    for (final trigger in correctionTriggers) {
      // "...previous phrase, [trigger] corrected phrase..."
      // Remove the previous short phrase + trigger. Match at start or after space
      // so we capture the full phrase (e.g. "Call her Monday" not just "her Monday").
      text = text.replaceAll(
        RegExp(
          r'(?:^|(?<=\s))([^,!?.]{3,40}),\s*' + trigger,
          caseSensitive: false,
        ),
        '',
      );
    }

    return text;
  }

  // ─── Step 7: Word stutters / immediate repetitions ────────────────────────
  //
  // "I I was going" → "I was going"
  // "the the thing" → "the thing"
  // "and and then"  → "and then"
  // Does NOT collapse intentional repetition like "very very good" (keep those).

  static String _fixWordStutters(String text) {
    // Only collapse function words / articles / pronouns stuttered
    // (leave content word repetition like "very very" intact — user may mean it)
    final stutterWords = [
      'I', 'a', 'an', 'the', 'and', 'but', 'or', 'so', 'that',
      'this', 'it', 'he', 'she', 'they', 'we', 'to', 'of', 'in',
      'is', 'was', 'are', 'were', 'be', 'been', 'have', 'had',
      'do', 'did', 'will', 'would', 'could', 'should', 'my', 'your',
    ];

    for (final word in stutterWords) {
      // Spaced repetition: "I I was" → "I was"
      text = text.replaceAll(
        RegExp(r'\b' + word + r'\s+' + word + r'\b', caseSensitive: false),
        word,
      );
      // Hyphenated stutter (ASR sometimes outputs "I-I" or "the-the")
      text = text.replaceAll(
        RegExp(r'\b' + word + r'[-–—]\s*' + word + r'\b', caseSensitive: false),
        word,
      );
    }

    return text;
  }

  // ─── Step 8: Run-on sentence detection ─────────────────────────────────────
  //
  // Apple Speech often omits sentence-ending punctuation when the speaker
  // doesn't pause long enough. We detect natural break patterns:
  //   "I felt really tired and I went to bed early the next day I woke up..."
  //
  // Heuristic: conjunction + subject pronoun after a long clause → likely new sentence.
  // We insert a period, not a comma, to preserve sentence structure for PRISM.

  static String _fixRunOnSentences(String text) {
    // "...long clause and I/he/she/they/we..." → "...long clause. I/he/she/they/we..."
    // Only trigger when preceding clause is 7+ words (avoid over-splitting)
    text = text.replaceAllMapped(
      RegExp(
        r'(\b\w+(?:\s+\w+){6,})\s+(?:and|but|so)\s+(I|he|she|they|we|you)\b',
        caseSensitive: false,
      ),
      (Match m) => '${m.group(1)}. ${_capitalize(m.group(2)!)}',
    );

    return text;
  }

  // ─── Step 9: Capitalize sentences ────────────────────────────────────────

  static String _capitalizeSentences(String text) {
    // Capitalize after sentence-ending punctuation
    text = text.replaceAllMapped(
      RegExp(r'([.!?]\s+)([a-z])'),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );

    // Capitalize the very first character
    if (text.isNotEmpty) {
      text = text[0].toUpperCase() + text.substring(1);
    }

    // Always capitalize "I" as standalone pronoun
    text = text.replaceAll(RegExp(r'\bi\b'), 'I');

    return text;
  }

  // ─── Step 10: Final whitespace cleanup ────────────────────────────────────

  static String _finalCleanup(String text) {
    // Collapse multiple spaces
    text = text.replaceAll(RegExp(r'  +'), ' ');

    // Strip spaces before punctuation (again, in case earlier steps introduced them)
    text = text.replaceAllMapped(
      RegExp(r'\s+([.,?!;:])'),
      (m) => m.group(1)!,
    );

    // Strip leading/trailing whitespace
    text = text.trim();

    // Ensure ends with punctuation
    if (text.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(text)) {
      text += '.';
    }

    return text;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
