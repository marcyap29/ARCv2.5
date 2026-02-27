/// Voice Input Mode
/// 
/// Defines how the user interacts with voice mode:
/// - pushToTalk: Hold to talk, release to process (default, recommended)
/// - handsFree: Smart endpoint detection for accessibility
library;

enum VoiceInputMode {
  /// Push-to-talk mode (default, recommended)
  /// 
  /// User holds the sigil to speak, releases to process.
  /// Benefits:
  /// - Zero ambiguity about recording state
  /// - Natural conversation rhythm
  /// - User has explicit control
  /// - No pressure from countdown timers
  pushToTalk,
  
  /// Hands-free mode (accessibility option)
  /// 
  /// Smart endpoint detection automatically detects when user finishes speaking.
  /// Best for:
  /// - Driving
  /// - Cooking/working with hands
  /// - Accessibility needs
  /// - Extended reflections where holding becomes uncomfortable
  handsFree,
}

/// Extension for VoiceInputMode
extension VoiceInputModeExtension on VoiceInputMode {
  String get displayName {
    switch (this) {
      case VoiceInputMode.pushToTalk:
        return 'Push to Talk';
      case VoiceInputMode.handsFree:
        return 'Hands-Free Mode';
    }
  }
  
  String get description {
    switch (this) {
      case VoiceInputMode.pushToTalk:
        return 'Hold to talk, release to send (Recommended)';
      case VoiceInputMode.handsFree:
        return 'Auto-detect when you finish speaking';
    }
  }
  
  bool get isDefault => this == VoiceInputMode.pushToTalk;
}
