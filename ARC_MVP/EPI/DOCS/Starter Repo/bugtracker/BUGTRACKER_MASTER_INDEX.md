# Bugtracker Master Index

**Document Version:** 1.0.0  
**Last Updated:** [YYYY-MM-DD]  
**Purpose:** Canonical index for the bug tracker. Defines structure, format, and maintenance procedures.

---

## Overview

The bugtracker consolidates bug information into:
- **Primary index:** [bug_tracker.md](bug_tracker.md) — category index, links to all records
- **Individual records:** `records/` — one file per bug
- **Template:** [records/_TEMPLATE_BUG_RECORD.md](records/_TEMPLATE_BUG_RECORD.md)

---

## Standardized Bug Entry Format

New records in `records/` should follow this structure:

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
- **Prevention Measures:** [How to prevent similar]
- **Related Issues:** [Links to related bugs]

#### 📋 **TRACKING INFORMATION**
- **Bug ID:** BUG-[Unique Identifier]
- **Component Tags:** [#tag1, #tag2]
- **Version Fixed:** [Software version]
- **Verification Status:** [Confirmed fixed/Under review]
- **Documentation Updated:** [Date]
```

---

## Severity

- **Critical** — Production-blocking
- **High** — Significant impairment
- **Medium** — Notable, non-blocking
- **Low** — Minor / enhancement

---

## Maintenance Procedures

### Adding a new bug

1. Assign severity and component tags.
2. Create a new file in `records/` (e.g. `short-name-description.md`).
3. Add a link and one-line description in [bug_tracker.md](bug_tracker.md).
4. If the fix is in CHANGELOG, add a row to the "Recent code changes" table.

### Version control

- **Format:** MAJOR.MINOR.PATCH
- **MAJOR:** Restructure or new part.
- **MINOR:** New bugs or significant updates.
- **PATCH:** Typo, link, or small correction.
