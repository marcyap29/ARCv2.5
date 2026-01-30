# Import/Export UI Text and Data Spec

**Purpose:** Spell out the exact UI text and data format for import/export features so a developer (or Agent mode) can implement or verify them without ambiguity.

**Date format:** Use ISO date strings `YYYY-MM-DD` everywhere (e.g. `2023-01-15`, `2024-12-01`).

**Date range separator:** Use en-dash with spaces: ` – ` (e.g. `2023-01-15 – 2024-12-01`).

---

## 1. Verify Backup Dialog – Overall Folder Summary

**Data:**

| Variable        | Type   | Description                                      |
|----------------|--------|--------------------------------------------------|
| `fileCount`    | int    | Number of successfully scanned `.arcx` files     |
| `overallStart` | String?| Min entries date (YYYY-MM-DD) across valid files |
| `overallEnd`   | String?| Max entries date (YYYY-MM-DD) across valid files |
| `totalEntries` | int    | Sum of entries in all valid files                |
| `totalBytes`   | int    | Sum of file sizes in bytes                       |

**Size string logic:**

- If `totalBytes >= 1024 * 1024 * 1024` (1 GB):  
  `sizeStr = '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB'`
- Else:  
  `sizeStr = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'`

**Exact UI text:**

- **With date range** (when `overallStart != null && overallEnd != null`):  
  `Overall: these {fileCount} files cover {overallStart} – {overallEnd}, {totalEntries} entries, {sizeStr}.`

- **Example:**  
  `Overall: these 40 files cover 2023-01-15 – 2024-12-01, 182 entries, 2.1 GB.`

- **Without date range** (when either date is null):  
  `Overall: these {fileCount} files, {totalEntries} entries, {sizeStr}.`

---

## 2. Verify Backup Dialog – Per File Entry

**Data (per `ARCXFileScanResult`):**

| Field                    | Type   | Description                    |
|--------------------------|--------|--------------------------------|
| `r.isOk`                 | bool   | Scan succeeded                 |
| `r.fileName`             | String | File name (e.g. `ARC_Full_001.arcx`) |
| `r.error`                | String?| Error message if failed        |
| `r.entriesCount`         | int    | Entry count                    |
| `r.chatsCount`           | int    | Chat count                     |
| `r.mediaCount`           | int    | Media count                    |
| `r.entriesDateRangeStart`| String?| YYYY-MM-DD                     |
| `r.entriesDateRangeEnd`  | String?| YYYY-MM-DD                     |
| `r.fileSizeBytes`        | int    | File size in bytes             |

**Date range suffix:**  
`dateRange = (r.entriesDateRangeStart != null && r.entriesDateRangeEnd != null) ? ' ${r.entriesDateRangeStart} – ${r.entriesDateRangeEnd}' : ''`

**Exact UI text:**

- **Success line:**  
  `{r.entriesCount} entries, {r.chatsCount} chats, {r.mediaCount} media{dateRange}`

- **File size:**  
  `{(r.fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB`

- **Error line:**  
  `{r.error!}` (when `r.error != null`)

---

## 3. Export Success Dialog (Full/Chunked Backup)

**Data (from `ChunkedBackupResult`):**

| Field                      | Type   | Description                |
|----------------------------|--------|----------------------------|
| `result.totalEntries`      | int    | Entries exported           |
| `result.totalChats`        | int    | Chats exported             |
| `result.totalMedia`        | int    | Media items exported       |
| `result.entriesDateRangeStart` | String? | YYYY-MM-DD              |
| `result.entriesDateRangeEnd`   | String? | YYYY-MM-DD              |
| `result.totalChunks`       | int    | Number of chunk files      |

**Date range:**  
`dateRange = (result.entriesDateRangeStart != null && result.entriesDateRangeEnd != null) ? '${result.entriesDateRangeStart} – ${result.entriesDateRangeEnd}' : null`

**Exact UI text:**

- **Main summary:**  
  `Your entire timeline has been exported: {result.totalEntries} entries, {result.totalChats} chats, {result.totalMedia} media.`

- **Entries date range** (if `dateRange != null`):  
  `Entries date range: {dateRange}`

- **Chunking – multiple files:**  
  `Saved as {result.totalChunks} files (~200MB each):`

- **Chunking – single file:**  
  `Saved as 1 file.`

---

## 4. Import Success Dialog (ARCX)

**Data (from `ARCXImportResultV2`):**

| Field                        | Type         | Description                    |
|-----------------------------|--------------|--------------------------------|
| `result.entriesImported`    | int          | Entries successfully imported  |
| `result.entriesTotalInArchive` | int?      | Total entries in archive       |
| `result.entriesFailed`      | int?         | Entries that failed            |
| `result.mediaImported`      | int          | Media items imported           |
| `result.chatsImported`      | int          | Chat sessions imported         |
| `result.warnings`           | List<String>?| Optional warning messages      |

**Entries summary logic:**  
`entriesSummary = result.entriesTotalInArchive != null ? '${result.entriesImported} of ${result.entriesTotalInArchive}' + (result.entriesFailed != null && result.entriesFailed! > 0 ? ' (${result.entriesFailed} failed)' : '') : '${result.entriesImported}'`

**Exact UI text:**

- **Entries restored:**  
  `Entries restored: {entriesSummary}`  
  (e.g. `Entries restored: 180 of 182 (2 failed)` or `Entries restored: 182 of 182`)

- **Media restored:**  
  `Media restored: {result.mediaImported}`

- **Chat sessions** (if `result.chatsImported > 0`):  
  `Chat sessions: {result.chatsImported}`

- **Warnings** (if `result.warnings != null && result.warnings!.isNotEmpty`):  
  Section title (bold, orange): `Warnings:`  
  Each line: `• {w}` for each `w` in `result.warnings`.

---

## 5. Selective Backup Success SnackBar

**Data:**

| Variable               | Type              | Description                    |
|------------------------|-------------------|--------------------------------|
| `result.entriesExported` | int?            | Entries in the export          |
| `result.chatsExported`   | int?            | Chats in the export            |
| `selectedEntries`        | List<JournalEntry> | Entries user selected        |

**Date coverage:**  
Compute `(start, end)` from `selectedEntries` (min/max `createdAt` as YYYY-MM-DD).  
`dateCoverage = (start != null && end != null) ? ' These ${selectedEntries.length} entries cover $start – $end.' : ''`

**Exact UI text:**  
`Selective backup saved: {result.entriesExported ?? 0} entries, {result.chatsExported ?? 0} chats.{dateCoverage}`

**Example:**  
`Selective backup saved: 12 entries, 3 chats. These 12 entries cover 2023-06-01 – 2024-01-15.`

---

## 6. Import Status Screen (Settings → Import)

**Purpose:** Screen under Settings → Import Data. Shows current import progress and per-file status when an import is running; when idle, offers “Choose files to import”. User can navigate to Settings → Import at any time to view progress while import runs in the background.

**Navigation:** Settings → Import Data opens this screen.

**States:**

| State | Title / Heading | Main content |
|-------|-----------------|--------------|
| Idle (no import) | App bar: `Import` | “No import in progress”; “Restore from .zip, .mcpkg, or .arcx backup files.”; primary button: “Choose files to import” |
| Active import | App bar: `Import` | “Import in progress”; `{state.message}`; progress bar (0–100% or indeterminate); “You can keep using the app”; optional “Files” list (see below) |
| Completed | App bar: `Import` | “Import complete”; `{state.message}`; optional “Files” list; button “Done”; optional “Import more” |
| Failed | App bar: `Import` | “Import failed”; `{state.error}` or `{state.message}`; optional “Files” list; button “Done”; optional “Import more” |

**Files list (when `fileItems` is present):**

- Section title: `Files`
- Per file row: `{fileName}` with status label (see below).

**Per-file status labels:**

| Status | Label |
|--------|--------|
| Pending | `Pending` |
| In progress | `In progress` |
| Completed | `Completed` |
| Failed | `Failed` |

**Home mini status bar (when import is active):**

- Shown below app bar on Home.
- Content: icon, `{state.message}`, “You can keep using the app”, progress bar, and **percentage**: `0%` when indeterminate, otherwise `{round(state.fraction * 100)}%`.

---

## Quick Reference – Example Sentences

| Screen / Dialog      | Example sentence |
|----------------------|------------------|
| Verify backup (overall) | `Overall: these 40 files cover 2023-01-15 – 2024-12-01, 182 entries, 2.1 GB.` |
| Export success       | `Your entire timeline has been exported: 182 entries, 45 chats, 320 media.` |
| Export date range    | `Entries date range: 2023-01-15 – 2024-12-01` |
| Import success       | `Entries restored: 180 of 182 (2 failed)` |
| Selective backup     | `Selective backup saved: 12 entries, 3 chats. These 12 entries cover 2023-06-01 – 2024-01-15.` |
| Import Status (idle)  | `No import in progress`; button: `Choose files to import` |
| Import Status (active) | `Import in progress`; `Importing archive 2 of 5...`; Files: `Pending` / `In progress` / `Completed` / `Failed` |
| Home mini status bar | Message + progress bar + `0%` or `45%`; `You can keep using the app` |

Use this spec when implementing or changing import/export UI so labels and numbers stay consistent across the app.
