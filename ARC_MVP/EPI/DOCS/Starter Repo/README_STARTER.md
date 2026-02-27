# Starter Repo — Standardized Repository Kickoff Pack

**Version:** 1.0.0  
**Last Updated:** February 26, 2026  
**Purpose:** A curated set of docs, templates, and configs that any repo should start with. Copy and adapt these into your project root or DOCS folder.

---

## Contents

| File / Folder | Purpose |
|---------------|---------|
| **README.md** | Project overview and key documents (adapt for your project) |
| **claude.md** | AI context guide — onboarding, quick reference, role prompts |
| **CONFIGURATION_MANAGEMENT.md** | Central docs inventory, change log, sync tracking |
| **CHANGELOG.md** | Version history template |
| **ARCHITECTURE.md** | System architecture template |
| **FEATURES.md** | Feature list template |
| **UI_UX.md** | UI/UX documentation template |
| **git.md** | Git workflow and history guidelines |
| **backend.md** | Backend/infrastructure template |
| **PROMPT_TRACKER.md** | Prompt change tracking (for LLM/AI projects) |
| **PROMPT_REFERENCES.md** | Prompt catalog template (for LLM/AI projects) |
| **bugtracker/** | Bug tracking structure (index, records, template) |
| **.gitignore** | Universal gitignore (consolidated best practices) |
| **.cursorrules** | Cursor IDE rules template |
| **SECURITY_CHECKLIST.md** | Optional security review checklist |

---

## How to Use

1. **Copy** the desired files into your project (e.g. `DOCS/` or repo root).
2. **Rename** where needed (e.g. keep `claude.md` if using Claude; use `ai_context.md` for generic use).
3. **Replace** placeholders: `[Project Name]`, `[Version]`, `[Last Updated]`, etc.
4. **Adapt** sections for your stack (Flutter/Dart, Node, Python, etc.).
5. **Delete** files you don't need (e.g. PROMPT_REFERENCES if not using LLMs).

---

## Recommended Structure After Copy

```
your-repo/
├── DOCS/
│   ├── README.md
│   ├── claude.md
│   ├── CONFIGURATION_MANAGEMENT.md
│   ├── CHANGELOG.md
│   ├── ARCHITECTURE.md
│   ├── FEATURES.md
│   ├── UI_UX.md
│   ├── git.md
│   ├── backend.md
│   ├── PROMPT_TRACKER.md      # optional
│   ├── PROMPT_REFERENCES.md   # optional
│   └── bugtracker/
│       ├── bug_tracker.md
│       ├── BUGTRACKER_MASTER_INDEX.md
│       └── records/
│           └── _TEMPLATE_BUG_RECORD.md
├── .gitignore
├── .cursorrules               # optional
└── ...
```

---

## Checklist: First-Time Setup

- [ ] Copy core docs (README, CONFIGURATION_MANAGEMENT, CHANGELOG, ARCHITECTURE)
- [ ] Copy claude.md and update project-specific sections
- [ ] Create bugtracker/ and add first record if needed
- [ ] Copy .gitignore and merge with existing (avoid overwriting)
- [ ] Add .cursorrules if using Cursor IDE
- [ ] Update CONFIGURATION_MANAGEMENT inventory with your actual doc paths
- [ ] Set initial version in CHANGELOG.md

---

**Source:** Derived from ARCv2.5 / EPI LUMARA MVP DOCS structure (February 2026).
