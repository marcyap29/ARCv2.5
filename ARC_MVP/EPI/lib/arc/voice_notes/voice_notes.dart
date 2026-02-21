/// Voice Notes / Ideas System
/// 
/// Provides quick voice capture functionality that saves transcribed
/// voice notes to an "Ideas" inbox. Users can later convert these
/// notes to full journal entries.
/// 
/// Usage:
/// 1. After voice transcription completes, show VoiceProcessingModal
/// 2. If user selects "Save as Voice Note", save to VoiceNoteRepository
/// 3. If user selects "Talk with LUMARA", continue to full conversation
/// 4. Voice notes appear in the Ideas tab of the Conversations screen

library voice_notes;

export 'models/voice_note.dart';
export 'repositories/voice_note_repository.dart';
export 'widgets/voice_processing_modal.dart';
export 'widgets/voice_note_detail_sheet.dart';
export 'screens/voice_notes_view.dart';
