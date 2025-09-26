/// Strings for micro-tips and help dialogs
class InsightTipsStrings {
  static const gotIt = "Got it";
  static const learnMore = "Learn more";

  // Patterns card (on Insights)
  static const patterns_title = "Patterns";
  static const patterns_points = [
    "Bubbles are your most-used words in this window.",
    "Size = how often it appears.",
    "Glow = emotional intensity.",
    "Tap a word to see its moments."
  ];

  // Patterns screen (full view)
  static const patterns_screen_title = "What is this view?";
  static const patterns_screen_points = [
    "Full-screen pattern map.",
    "Tap a word to open its moments.",
    "Pull to refresh after new journals."
  ];

  // Phase change safety check (small ⓘ)
  static const safety_title = "Phase change safety check";
  static const safety_points = [
    "ARC only changes phases when the signal is clear.",
    "Match: how much recent writing fits the new phase.",
    "Confidence: overall evidence strength.",
    "Consistency: a short run of days that agree.",
    "Independent check: one separate moment that agrees."
  ];

  // Why held? sheet (link inside the card)
  static const whyHeld_title = "Why your phase is held";
  static const whyHeld_intro =
      "Your phase stays steady until the signal clears. To unlock:";
  static const whyHeld_unlockers = [
    "Add another journal clearly reflecting the new phase.",
    "Write for 1–2 more days to build consistency.",
    "Include a separate entry at a different time/context.",
    "Optional: add emotion tags to express the shift."
  ];
  static const whyHeld_footer =
      "ARC favors stability before change to keep your timeline trustworthy.";

  // Coming soon cards
  static const aurora_title = "AURORA — Rhythm & restoration";
  static const aurora_points = [
    "Find gentle daily pacing from patterns and habits.",
    "Suggestions for energy and recovery.",
    "Not active yet on this device."
  ];
  static const veil_title = "VEIL — Rest & recovery";
  static const veil_points = [
    "Summarizes recovery and reset moments.",
    "Shows when you tend to restore well.",
    "Not active yet on this device."
  ];
}
