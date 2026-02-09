/// Entry mode for initial screen state.
///
/// Used by the unified feed to know which input to activate on launch
/// (e.g., from the welcome screen or deep link).
enum EntryMode {
  /// Conversational back-and-forth - focus the text field
  chat,

  /// Thoughtful capture / reflection - open the reflection screen
  reflect,

  /// Audio capture - launch voice mode
  voice,
}
