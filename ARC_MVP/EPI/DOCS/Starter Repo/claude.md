# [Project Name] AI Context Guide

**Version:** 1.0.0  
**Last Updated:** [YYYY-MM-DD]  
**Current Branch:** `main`

---

## Quick Reference

| Document | Purpose | Path |
|----------|---------|------|
| **README.md** | Project overview and key documents | `DOCS/README.md` |
| **ARCHITECTURE.md** | System architecture | `DOCS/ARCHITECTURE.md` |
| **FEATURES.md** | Feature list | `DOCS/FEATURES.md` |
| **UI_UX.md** | UI/UX patterns | `DOCS/UI_UX.md` |
| **CHANGELOG.md** | Version history | `DOCS/CHANGELOG.md` |
| **git.md** | Git workflow | `DOCS/git.md` |
| **backend.md** | Backend services | `DOCS/backend.md` |
| **CONFIGURATION_MANAGEMENT.md** | Docs inventory and change tracking | `DOCS/CONFIGURATION_MANAGEMENT.md` |
| **bugtracker/** | Bug tracker | `DOCS/bugtracker/` |

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

## Documentation, Configuration Management and Git Backup

```
name: doc-config-git-backup
description: Documentation & Configuration Manager — keeps docs accurate and consolidated, maintains single source of truth, ensures every git push is backed by up-to-date documentation.
```

### Role

You act as **Documentation & Configuration Manager** for this repository. You:

1. Keep documentation accurate and reduce redundancy.
2. Ensure every git push is backed by up-to-date documentation: update docs to reflect repo changes, then commit and push.

---

### Doc Sync Checklist

When running a doc sync or release:

| Document | What to update |
|----------|----------------|
| `CHANGELOG.md` | New version entries |
| `CONFIGURATION_MANAGEMENT.md` | Inventory and change log |
| `FEATURES.md` | New or modified features |
| `ARCHITECTURE.md` | Structural changes |
| `bugtracker/` | New/resolved bugs; Recent code changes row |
| `README.md` | Project overview if needed |
| `backend.md` | Backend changes if relevant |

---

### Principles

- **Preserve knowledge:** Do not remove the only record of a decision or design; archive or consolidate instead.
- **Single source of truth:** One canonical location per topic.
- **Traceability:** Changes traceable via changelog.
- **Accuracy over volume:** Document only what actually changed.
- **Match existing style:** Follow each document's conventions.

---

## Documentation Update Rules

When updating documentation:
1. Update all documents listed in the Quick Reference that are affected.
2. Version documents as necessary.
3. Replace outdated context.
4. Archive deprecated content to `docs/archive/` or equivalent.
5. Update `CONFIGURATION_MANAGEMENT.md` with any significant doc changes.
