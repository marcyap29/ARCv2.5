# [Project Name] AI Context Guide

**Version:** 1.1.0  
**Last Updated:** 2026-03-30  
**Current Branch:** `main`

This file is the **starter** template. Production repos (e.g. LUMARA / ARC) extend it with product-specific paths, bug-prevention lists, and long-form prompts. Keep **SOP sections** in sync when you copy this pack to a new repo.

---

## Standard Operating Procedures (SOPs)

SOPs are the **repeatable procedures** extracted from full context guides. Day-to-day rules for assistants: see also **`DOCS/RULE.md`**.

### SOP-TASK — Implementation task (default)

1. Clarify goal and definition of done.  
2. Inspect relevant code; do not assume APIs you have not read.  
3. Plan minimal changes; run analyzers/tests when available.  
4. Implement; update **DOCS** if behavior or architecture changed.  
5. Summarize changes and verification steps.

### SOP-TASK-ORCH — Large or multi-surface task

1. **Orchestrator:** Definition of done + ordered sub-tasks.  
2. **Workers:** Execute sub-tasks (by file/area).  
3. **Reviewer:** Checklist pass/fail against definition of done.  
4. **Integrate:** Single narrative + commit/PR notes.

*(Same pattern as RULE.md SOP-2.)*

### SOP-DOC — Documentation, configuration management, and git backup

**Role ID:** `doc-config-git-backup` — keep docs accurate, single source of truth, commits backed by documentation.

#### When to run

- After a release or large merge  
- On request (“doc sync”, “git backup sync”, “drift check”)  
- Whenever prompts, architecture, or features change materially  

#### Orchestrator order (do not skip)

| Order | Agent / phase | Purpose |
|-------|----------------|---------|
| 1 | **Prompt References** | Audit LLM prompts vs `PROMPT_REFERENCES.md`; update `PROMPT_TRACKER.md` if needed. Skip only if the repo has no LLM prompts. |
| 2 | **Doc inventory & drift** | Compare repo vs docs; short drift report (what docs lag). |
| 3 | **Core artifacts** | Update README, CHANGELOG, ARCHITECTURE, FEATURES, backend, bugtracker index / “Recent code changes” as applicable. |
| 4 | **Configuration & consolidation** *(optional)* | Deduplicate, archive obsolete docs, fix links — only when explicitly requested. |
| 5 | **Git backup sync** | `git log` / `git diff` vs last documented version; bump versions; **commit + push** doc (and code if in scope). |
| 6 | **Reviewer** | Run checklist below; output pass/fail. |

#### Core artifact touch list (typical)

| Document | Update when… |
|----------|----------------|
| `CHANGELOG.md` | Any user-visible or structural change |
| `CONFIGURATION_MANAGEMENT.md` | Inventory dates, change log entry |
| `FEATURES.md` | Capabilities changed |
| `ARCHITECTURE.md` | Modules, data flow, major dependencies |
| `backend.md` | Functions, APIs, infra |
| `bugtracker/` | Fixes, regressions, triage row |
| `PROMPT_TRACKER.md` | Every doc-sync run (row or “no prompt changes”) |
| `PROMPT_REFERENCES.md` | Prompt audit found deltas |
| `README.md` | Overview or key-doc list changed |

#### Reviewer checklist (short)

- [ ] Prompt catalog in sync (if project uses prompts).  
- [ ] Drift report addressed or “no drift” justified.  
- [ ] Core docs versioned; no invented facts.  
- [ ] Bug tracker / recent-changes table updated if required.  
- [ ] Commit message clear; push done if sync requested.  

#### Principles

Preserve knowledge; one canonical location per topic; traceability via CHANGELOG; match existing doc style; be fast and factual.

---

### SOP-BUG — Before coding in risky areas

1. Open `DOCS/bugtracker/bug_tracker.md` (or project index).  
2. Skim entries for the subsystem you touch.  
3. Read `records/…` when an entry matches.  
4. Do not contradict documented fixes without explicit user approval.

*(Add a product-specific “do not regress” list in your production `claude.md`.)*

---

### SOP-PROMPT — Prompt catalog maintenance

1. Search codebase for prompt definitions.  
2. Reconcile with `PROMPT_REFERENCES.md`.  
3. Append `PROMPT_TRACKER.md` and bump catalog version when entries change.  
4. Log in `CONFIGURATION_MANAGEMENT.md` if used.

---

## Quick Reference

| Document | Purpose | Path |
|----------|---------|------|
| **README.md** | Project overview and key documents | `DOCS/README.md` |
| **RULE.md** | SOPs for assistants (request handling, docs, bugs) | `DOCS/RULE.md` |
| **ARCHITECTURE.md** | System architecture | `DOCS/ARCHITECTURE.md` |
| **FEATURES.md** | Feature list | `DOCS/FEATURES.md` |
| **UI_UX.md** | UI/UX patterns | `DOCS/UI_UX.md` |
| **CHANGELOG.md** | Version history | `DOCS/CHANGELOG.md` |
| **git.md** | Git workflow | `DOCS/git.md` |
| **backend.md** | Backend services | `DOCS/backend.md` |
| **CONFIGURATION_MANAGEMENT.md** | Docs inventory and change tracking | `DOCS/CONFIGURATION_MANAGEMENT.md` |
| **bugtracker/** | Bug tracker | `DOCS/bugtracker/` |
| **PROMPT_TRACKER.md** | Prompt change log (optional) | `DOCS/PROMPT_TRACKER.md` |
| **PROMPT_REFERENCES.md** | Prompt catalog (optional) | `DOCS/PROMPT_REFERENCES.md` |

---

## Core Documentation

### README
- Main overview: `DOCS/README.md`
- Read first to understand the project and key docs

### Architecture
- System design: `DOCS/ARCHITECTURE.md`
- Modules, data flow, tech stack

### Features
- Capabilities: `DOCS/FEATURES.md`

### UI/UX
- Patterns and components: `DOCS/UI_UX.md`
- Review before making UI changes

---

## Role prompt block (doc-config-git-backup)

Paste or attach for AI tools that use structured role metadata:

```
name: doc-config-git-backup
description: Documentation & Configuration Manager — keeps docs accurate and consolidated, maintains single source of truth, ensures every git push is backed by up-to-date documentation; runs prompt-reference audit when applicable; uses SOP-DOC in claude.md.
```

---

## Documentation Update Rules

When updating documentation:

1. Update all documents listed in the Quick Reference that are affected.  
2. Version documents as necessary.  
3. Replace outdated context.  
4. Archive deprecated content to `docs/archive/` or equivalent.  
5. Update `CONFIGURATION_MANAGEMENT.md` with any significant doc changes.  
6. For releases: follow **SOP-DOC** (orchestrator order + reviewer checklist).

---

## Optional: embedded multi-agent preamble (legacy)

Some teams paste this at the top of `claude.md` instead of using `RULE.md`:

1. Analyze the prompt and break work into sub-tasks with a clear **definition of done**.  
2. Use sub-agents (or explicit phases) for parallel slices.  
3. Use a review pass against the definition of done before closing.  
4. End with a concise implementation review.

Prefer **`RULE.md` SOP-1 / SOP-2** for clarity.

---

*Starter pack version 1.1.0 — SOP block aligned with ARC/LUMARA doc-config workflow; trim sections you do not need.*
