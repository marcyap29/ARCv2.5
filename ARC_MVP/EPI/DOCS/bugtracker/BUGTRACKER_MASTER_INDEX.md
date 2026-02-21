# EPI MVP – Bugtracker Master Index

**Document Version:** 1.3.0  
**Last Updated:** 2026-02-20  
**Change Summary:** Bugtracker-consolidator run 2026-02-20: 3 new records added (BUG-PRISM-001, BUG-CHRONICLE-001, BUG-JOURNAL-001); record count 35 → 38; CHRONICLE category tag added; master index synced  
**Editor:** Bugtracker-consolidator (DOCS/claude.md)

---

## Overview

This is the **canonical master index** for the EPI MVP Bug Tracker. The bugtracker consolidates all bug information into a standardized, versioned structure with a primary category index, individual records, and chronological/chronicle-style parts.

### Consolidation Statistics (2026-02-20)

- **Individual records:** 38 detailed bug reports in [records/](records/)
- **Primary index:** [bug_tracker.md](bug_tracker.md) — category index, links to all records, recent code changes table
- **Changelog-style parts:** [bug_tracker_part1.md](bug_tracker_part1.md), [bug_tracker_part2.md](bug_tracker_part2.md), [bug_tracker_part3.md](bug_tracker_part3.md) (by date range)
- **Audit:** [BUGTRACKER_AUDIT_REPORT.md](BUGTRACKER_AUDIT_REPORT.md) — full inventory and format analysis
- **Archive:** Legacy files in [archive/](archive/) (Bug_Tracker.md, Bug_Tracker-1..9, prior BUG_TRACKER_MASTER_INDEX, BUG_TRACKER_PART1_CRITICAL)

---

## Document Structure

**Primary entry point:** [bug_tracker.md](bug_tracker.md). Use it to find bugs by category and to open individual records.

| Document | Coverage | Description |
|----------|----------|-------------|
| **[bug_tracker.md](bug_tracker.md)** | Main index | Category index (LUMARA, Timeline & UI, Export/Import, CHRONICLE, etc.), links to all 38 records, recent code changes, archive note. **Start here.** |
| **[bug_tracker_part1.md](bug_tracker_part1.md)** | Dec 2025 – Jan 2026 | v2.1.43 – v2.1.86 (recent) |
| **[bug_tracker_part2.md](bug_tracker_part2.md)** | Nov 2025 | v2.1.27 – v2.1.42 |
| **[bug_tracker_part3.md](bug_tracker_part3.md)** | Jan – Oct 2025 | v2.0.0 – v2.1.26 & earlier |
| **records/** | Per-bug | 38 detailed bug reports; each linked from bug_tracker.md |
| **[BUGTRACKER_AUDIT_REPORT.md](BUGTRACKER_AUDIT_REPORT.md)** | Audit | Inventory, format analysis, recommendations (consolidator Phase 1) |
| **archive/** | Legacy | BUG_TRACKER_MASTER_INDEX (superseded by this file), BUG_TRACKER_PART1_CRITICAL, Bug_Tracker.md, Bug_Tracker-1..9 |

---

## Bug Categories & Tags

### Component tags

- `#lumara` – LUMARA reflection system  
- `#timeline` – Timeline visualization  
- `#export` / `#import` – Export/import  
- `#ui-ux` – User interface  
- `#data-storage` – Hive/database  
- `#phase-system` – Phase analysis  
- `#arcform` – ARCForm visualization  
- `#voice` – Voice chat  
- `#subscription` – Payment/subscription  
- `#ios` – iOS-specific  
- `#chronicle` – CHRONICLE layer / aggregation / routing  
- `#privacy` – PII / PRISM scrubbing / egress  
- `#cloud-functions` – Firebase backend  
- `#build` – Build / Dart / tooling  

### Severity

- `#critical` – Production-blocking  
- `#high` – Significant impairment  
- `#medium` – Notable, non-blocking  
- `#low` – Minor / enhancement  

### Status

- `#resolved` / `#verified` – Fixed and confirmed  
- `#reopened` – Regressed  

---

## Quick Navigation

- **By category:** [bug_tracker.md](bug_tracker.md) (sections: LUMARA, Timeline & UI, Export/Import, Data & Storage, API & Integration, Subscription, Build & Platform, Environment, Feature-Specific).
- **By date range:** bug_tracker_part1 (Dec 2025 – Jan 2026), part2 (Nov 2025), part3 (Jan – Oct 2025).
- **Critical/high (archived view):** [archive/BUG_TRACKER_PART1_CRITICAL.md](archive/BUG_TRACKER_PART1_CRITICAL.md).
- **Recent code changes vs records:** Table in [bug_tracker.md](bug_tracker.md) (synced with CHANGELOG and git).

---

## Standardized Bug Entry Format (Target for New Records)

New records in `records/` should follow this structure when possible. Existing records may use alternate formats; see [BUGTRACKER_AUDIT_REPORT.md](BUGTRACKER_AUDIT_REPORT.md).

```markdown
### BUG-[ID]: [Brief Bug Title]
**Version:** [Document Version] | **Date Logged:** [YYYY-MM-DD] | **Status:** [Open/Fixed/Verified]

#### 🐛 **BUG DESCRIPTION**
- **Issue Summary:** [Concise description]
- **Affected Components:** [Systems/modules/features]
- **Reproduction Steps:** [How to reproduce]
- **Expected Behavior:** / **Actual Behavior:**
- **Severity Level:** [Critical/High/Medium/Low]
- **First Reported:** [Date] | **Reporter:** [Who]

#### 🔧 **FIX IMPLEMENTATION**
- **Fix Summary:** [What the fix does]
- **Technical Details:** [Implementation and code changes]
- **Files Modified:** [List of files]
- **Testing Performed:** [How validated]
- **Fix Applied:** [Date] | **Implementer:** [Who]

#### 🎯 **RESOLUTION ANALYSIS**
- **Root Cause:** [Why it occurred]
- **Fix Mechanism:** [How the fix addresses root cause]
- **Impact Mitigation:** [What it resolves]
- **Prevention Measures:** [How to prevent similar]
- **Related Issues:** [Links to related bugs]

#### 📋 **TRACKING INFORMATION**
- **Bug ID:** BUG-[Unique Identifier]
- **Component Tags:** [#tag1, #tag2]
- **Version Fixed:** [Software version]
- **Verification Status:** [Confirmed fixed/Under review/Reopened]
- **Documentation Updated:** [Date]
```

Full specification and consolidator prompt: **DOCS/claude.md** (section “Bugtracker Consolidation & Optimization Prompt”).

---

## Resolution Patterns (Summary)

Common fix types observed across records (details in [archive/BUG_TRACKER_PART1_CRITICAL.md](archive/BUG_TRACKER_PART1_CRITICAL.md) and in individual records):

1. **Initialization order** – Services/adapters before dependencies; fix: sequential init, conditional checks.  
2. **API / SDK usage** – Wrong imports, deprecated APIs; fix: correct imports (e.g. `dart:ui` for `AppLifecycleState`), API updates.  
3. **State / rebuild** – Infinite rebuilds, state desync; fix: state tracking, conditional updates.  
4. **Types / nullability** – Model mismatches (e.g. `timestamp` vs `createdAt`); fix: align with actual models, null safety.  
5. **Permissions / auth** – Cloud Functions invoker, token refresh; fix: `invoker: "public"` where appropriate, refresh ID token before calls.  
6. **Build / scope** – Method order, target membership; fix: declaration order, compile sources.

---

## Maintenance Procedures

### Adding a new bug

1. **Severity and category** – Assign severity and component tags (see above).  
2. **Create record** – Add a new file in `records/` (e.g. `short-name-description.md`). Prefer the standardized format (BUG-[ID], 🐛🔧🎯📋).  
3. **Update index** – Add a link and one-line description under the right category in [bug_tracker.md](bug_tracker.md).  
4. **Recent code changes** – If the fix is in CHANGELOG/git, add or update the row in the “Recent code changes” table in bug_tracker.md with the record link.  
5. **Versioning** – Bump MINOR of this master index when adding new bugs; PATCH for typos/links.

### Version control

- **Format:** MAJOR.MINOR.PATCH  
  - MAJOR: Restructure or new part.  
  - MINOR: New bugs or significant updates.  
  - PATCH: Typo, link, or small correction.  
- **This document:** 1.3.0 (2026-02-20).  
- **bug_tracker.md:** Own version (e.g. 3.3.0); keep “Last Updated” and record count in sync.

### Regular maintenance

- **When releasing:** Sync “Recent code changes” in bug_tracker.md with CHANGELOG and tag new records.  
- **Periodic:** Review resolved bugs still fixed; archive very old resolved items if desired.  
- **After consolidator runs:** Update this master index and audit report dates/counts.

---

## CHANGELOG Integration

- **DOCS/CHANGELOG.md** – Main project changelog (e.g. v3.3.46).  
- **DOCS/CHANGELOG_part1/2/3.md** – Split by date range.  
- bug_tracker.md “Recent code changes” table links fixes to records and CHANGELOG versions.

---

## Contact & Reporting

- **New bugs:** Add record in `records/`, link from [bug_tracker.md](bug_tracker.md), use standardized format when possible.  
- **Prompt reference:** DOCS/claude.md — “Bugtracker Consolidation & Optimization Prompt” (name: bugtracker-consolidator).

---

**Last synchronized:** 2026-02-20  
**Next review due:** 2026-03-20  
**Master index version:** 1.3.0
