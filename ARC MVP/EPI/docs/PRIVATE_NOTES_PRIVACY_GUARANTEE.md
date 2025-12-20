# Private Notes - Privacy Guarantee

**Version:** 1.0.0  
**Last Updated:** December 20, 2025  
**Status:** ✅ Production Ready

---

## Privacy Guarantee Statement

**Private Notes are architecturally isolated from ARC's intelligence layers.**

Content stored in Private Notes is:
- ✅ **Local-only** - Never transmitted to cloud services
- ✅ **Never processed** - Excluded from all AI analysis
- ✅ **Never indexed** - Not searchable by ARC
- ✅ **Never analyzed** - No semantic analysis, keyword extraction, or phase detection
- ✅ **Never summarized** - Not included in any summaries or reports
- ✅ **Never backed up** - Excluded from automatic backups (unless explicitly enabled by user)

---

## Technical Implementation

### Storage Isolation

Private Notes are stored in a **separate, encrypted directory** that is completely isolated from journal entry storage:

- **Location**: `{appDocuments}/private_notes/`
- **Format**: Encrypted files (`.encrypted` extension)
- **Encryption**: XOR encryption with device-specific key stored in Flutter Secure Storage
- **Key Management**: Encryption key stored in iOS Keychain / Android Keystore

### Architectural Boundaries

The following ARC services **cannot access** Private Notes:

1. **PRISM** - No content analysis or PII scrubbing
2. **ATLAS** - No phase detection or semantic analysis
3. **LUMARA** - No AI reflections or suggestions
4. **MIRA** - No memory indexing or retrieval
5. **RIVET** - No phase calculation or regime analysis
6. **SENTINEL** - No risk assessment or monitoring

### Code Isolation

Private Notes are accessed **only** through:

- `PrivateNotesStorage.savePrivateNote()` - Write access
- `PrivateNotesStorage.loadPrivateNote()` - Read access (UI only)
- `PrivateNotesStorage.deletePrivateNote()` - Delete access

**No other code paths** can access Private Notes content.

---

## User Interface

### Visual Indicators

The Private Notes UI clearly signals privacy:

- **Lock icon** (🔒) - Visual indicator of privacy
- **Header text**: "Private Notes - Stored locally and never analyzed"
- **Distinct styling** - Separate visual language from main journal
- **No autocomplete** - No AI suggestions or autocomplete
- **No tone analysis** - No writing assistance

### Interaction Model

- **Write-only UI surface** - Users can type freely
- **Auto-save** - Content saved automatically after 2 seconds of inactivity
- **No telemetry** - No analytics or logging on content
- **No references** - Private Notes never appear in main journal text

---

## Threat Model

### What Private Notes Protect Against

1. **AI Analysis** - Content is never sent to any AI model
2. **Cloud Sync** - Content never leaves the device (unless user explicitly exports)
3. **Backup Inclusion** - Excluded from automatic backups
4. **Search Indexing** - Not indexed for search
5. **Analytics** - No telemetry or analytics on content

### What Private Notes Do NOT Protect Against

1. **Physical Device Access** - If device is unlocked, files are accessible
2. **Device Backups** - May be included in full device backups (iOS/Android)
3. **User Export** - User can explicitly export encrypted notes
4. **Forensic Analysis** - Encrypted files exist on device storage

---

## Audit Trail

### Verification Method

Use `PrivateNotesStorage.verifyIsolation()` to verify the privacy boundary:

```dart
final verification = await PrivateNotesStorage.instance.verifyIsolation();
// Returns:
// {
//   'storage_location': '/path/to/private_notes',
//   'note_count': 5,
//   'isolation_verified': true,
//   'encryption_enabled': true,
//   'separate_from_journal_storage': true,
// }
```

### Code Inspection

To verify isolation, search codebase for:
- `PrivateNotesStorage` - Only 3 methods should access it
- `private_notes` directory - Should only appear in storage service
- No references in: PRISM, ATLAS, LUMARA, MIRA, RIVET, SENTINEL services

---

## User Control

### Export (User-Initiated)

Users can export Private Notes as encrypted blobs:

```dart
final export = await PrivateNotesStorage.instance.exportPrivateNotes();
// Returns JSON with encrypted notes (key NOT included)
```

### Backup Exclusion

Private Notes are excluded from:
- Automatic ARC backups
- MCP export packages
- ARCX export files
- Cloud sync operations

**Exception**: User can explicitly export encrypted notes for personal backup.

---

## Mental Model

> **"This is paper inside a locked drawer, not part of the system's memory."**

Private Notes are designed to be:
- A **write-only UI surface**
- A **cryptographically and logically isolated store**
- A **"sealed envelope"** inside the journal

ARC treats Private Notes as if they don't exist - they are completely invisible to the system's intelligence layers.

---

## Implementation Files

- **Storage**: `lib/arc/core/private_notes_storage.dart`
- **UI Component**: `lib/arc/ui/widgets/private_notes_panel.dart`
- **Integration**: `lib/ui/journal/journal_screen.dart`

---

## Compliance

This implementation provides:
- ✅ **Architectural isolation** - Not just UI hiding
- ✅ **Cryptographic protection** - Encrypted at rest
- ✅ **Auditable boundary** - Can be verified via code inspection
- ✅ **No telemetry** - Zero analytics on content
- ✅ **User control** - Explicit export only

---

**Last Verified**: December 20, 2025  
**Next Review**: When storage architecture changes
