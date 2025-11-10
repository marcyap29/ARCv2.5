import '../../../services/lumara/pii_scrub.dart';

class PrismScrubber {
  /// Scrub PII from transcript using existing PiiScrubber service
  static String scrub(String transcript) {
    return PiiScrubber.rivetScrub(transcript);
  }

  /// Check if text contains PII
  static bool containsPII(String text) {
    return PiiScrubber.containsPii(text);
  }
}

