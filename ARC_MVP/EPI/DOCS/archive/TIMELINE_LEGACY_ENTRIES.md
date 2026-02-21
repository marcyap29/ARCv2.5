# Timeline: Why Only Entries After a Certain Date Show (e.g. Post–Jan 20)

## Comparison: Post–Jan 20 vs Pre–Jan 20 Entries

**Observed:** Only entries after January 20th display in the timeline; older entries (e.g. from ARCX import dating to September 2025) do not.

**Crucial difference:** It is not that the app filters by date. The timeline loads all entries from the same source (`getAllJournalEntriesSync()` → sort by `createdAt` desc → paginate). The difference is **which entries survive loading**:

| Aspect | Post–Jan 20 (displaying) | Pre–Jan 20 (missing) |
|--------|---------------------------|----------------------|
| **Source** | Often created in-app or imported with current schema | Often from older ARCX backup or written with older app version |
| **Hive schema** | Written with current adapter (29 fields, incl. `lumaraBlocks`, `overview`) | May have been written with fewer fields (e.g. 13 or 27) |
| **On read** | All fields present → adapter and `_normalize` succeed | Missing fields → adapter or `_normalize` could throw → entry **skipped** in try/catch |
| **Result** | Entry appears in list | Entry skipped; timeline never sees it |

So “only entries after Jan 20” usually means: **older entries are the ones that fail during load (Hive read or normalize) and get skipped**, not that there is a date filter.

## Root Causes Addressed

1. **Hive adapter (`journal_entry_model.g.dart`)**  
   Legacy records can lack field 27 (`lumaraBlocks`), field 28 (`overview`), or fields 16/22 (`isEdited`/`isPhaseLocked`). The generated adapter used strict casts (`fields[27] as List`, etc.), so **missing fields caused a cast exception** and the entry was never returned.  
   **Fix:** Null-safe reads with defaults (e.g. `(fields[27] as List?)?.cast<InlineBlock>() ?? []`, `fields[16] as bool? ?? false`).

2. **`_normalize` in `journal_repository.dart`**  
   - **SAGE narrative:** `e.metadata!['narrative'] as Map?` throws if `narrative` is a string or other non-Map.  
   **Fix:** Only migrate when `raw is Map`.  
   - **inlineBlocks (String path):** One malformed block in the JSON string caused the whole migration to throw.  
   **Fix:** Per-block try + `whereType<InlineBlock>()`, same as the List path.

3. **`InlineBlock.fromJson`**  
   Legacy blocks sometimes have missing or wrong-typed fields (`type`, `intent`, `content`, `timestamp`).  
   **Fix:** Defensive parsing with defaults so one bad block does not drop the whole entry.

## Diagnostic Logging

In `getAllJournalEntriesSync()`:

- When an entry is **skipped**, a log line includes its **id** and **createdAt** and the error, e.g.:  
  `Skipping entry <id> (createdAt: 2025-09-15..., normalize failed in sync load): <err>`
- After the loop, a single summary line:  
  `getAllJournalEntriesSync: N loaded, M skipped; date range: YYYY-MM-DD .. YYYY-MM-DD`

From that you can see whether skipped entries are the older ones and what error they hit.

## Pagination Note

The timeline shows 20 entries at a time (newest first). “Load more” is triggered when the user scrolls (e.g. ~75% down). If **all** entries were loading correctly but you only looked at the first page, you would see only the 20 newest (which could all be after Jan 20). The fixes above ensure older entries are **in** the list so that loading more pages will show them.
