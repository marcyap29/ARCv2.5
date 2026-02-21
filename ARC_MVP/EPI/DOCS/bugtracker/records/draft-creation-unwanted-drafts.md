# Draft Creation When Viewing Entries

Date: 2025-10-19
Status: Resolved ✅
Area: Journal UX

Summary
- Viewing timeline entries created new drafts unintentionally.

Impact
- Cluttered drafts, user confusion, potential data mix-ups.

Root Cause
- Entries opened in an editor state that auto-created/saved drafts despite no edits.

Fix
- Default open in read-only mode; drafts only created when editing starts.
- Clear mode switch via explicit "Edit" action.

Files
- `lib/ui/journal/journal_screen.dart`

Verification
- Viewing no longer creates drafts; edit mode behaves as expected.

References
- Tracked in `docs/bugtracker/Bug_Tracker.md` (Draft Creation Bug Fix Complete)

