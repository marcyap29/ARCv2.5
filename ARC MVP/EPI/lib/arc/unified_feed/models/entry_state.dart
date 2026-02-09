/// Entry lifecycle state for unified feed entries.
///
/// Simplified enum matching the spec:
/// - active:   Currently happening (live conversation)
/// - saving:   AI processing / auto-save in progress
/// - saved:    Persisted to timeline
/// - edited:   User has modified after save
/// - archived: Hidden from default feed view

enum EntryState {
  active,   // 🟢 Currently happening
  saving,   // 💾 AI processing
  saved,    // 💬 In timeline
  edited,   // ✏️ User modified
  archived, // 📦 Hidden
}
