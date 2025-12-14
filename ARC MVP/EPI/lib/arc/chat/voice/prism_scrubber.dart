import '../../../services/lumara/pii_scrub.dart';

class PrismScrubber {
  /// Scrub PII from transcript using existing PiiScrubber service
  static String scrub(String transcript) {
    return PiiScrubber.rivetScrub(transcript);
  }

  /// Scrub PII with reversible mapping for restoration
  static ScrubbingResult scrubWithMapping(String transcript) {
    return PiiScrubber.rivetScrubWithMapping(transcript);
  }

  /// Restore PII from scrubbed text using reversible map
  static String restore(String scrubbedText, Map<String, String> reversibleMap) {
    return PiiScrubber.restore(scrubbedText, reversibleMap);
  }

  /// Check if text contains PII
  static bool containsPII(String text) {
    return PiiScrubber.containsPii(text);
  }
}

