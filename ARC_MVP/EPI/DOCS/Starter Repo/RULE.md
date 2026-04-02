# Standard Operating Procedures — AI & Engineering Assistant

**Purpose:** Repeatable workflows for Cursor / Claude / Codex-style assistants and human reviewers.  
**Companion:** Detailed checklists and doc-role prompts live in **`DOCS/claude.md`** (SOP section).

---

## SOP-1 — Handle an incoming request

| Step | Action |
|------|--------|
| 1 | **Understand** — Restate the goal, constraints, and definition of done. |
| 2 | **Analyze** — Map components, dependencies, risks, and affected areas (code, docs, backend). |
| 3 | **Plan** — Outline steps; flag unknowns and verification (tests, manual checks). |
| 4 | **Align** — If the user asked to approve before execution, **present the plan and wait**. If they want you to proceed, continue. |
| 5 | **Execute** — Implement the smallest change that satisfies the request; match repo conventions. |
| 6 | **Verify** — Run linters/tests or static analysis when available; fix new issues you introduced. |
| 7 | **Summarize** — Short recap: what changed, where, and how to validate. |

---

## SOP-2 — Complex or multi-area work (orchestrator pattern)

Use when the task spans many files, needs parallel concerns (e.g. UI + API + docs), or the user explicitly wants agent-style breakdown.

| Step | Action |
|------|--------|
| 1 | **Lead agent** — Analyze the prompt, produce a **definition of done**, and decompose into sub-tasks. |
| 2 | **Sub-agents** — Assign coherent slices (e.g. one area per sub-task); avoid overlapping ownership. |
| 3 | **Review agent** — After sub-tasks complete, check against the definition of done; list gaps or approve. |
| 4 | **Close out** — Integrate results, one coherent commit or PR description, and a final **implementation review** for the user. |

*Note: In single-threaded chat, you simulate this sequence explicitly in your reasoning and output.*

---

## SOP-3 — Documentation and git discipline

| Trigger | Follow |
|---------|--------|
| Feature or behavior change | Update affected docs per **`claude.md` → SOP-DOC** and project Quick Reference. |
| Before a significant push / release | Run **doc-config-git-backup** flow in `claude.md` (prompt audit → drift → core docs → commit/push). |
| Deprecating a doc | Move to `docs/archive/` (or project equivalent) with a one-line reason; link the replacement. |

---

## SOP-4 — Bug tracker and regressions

| Step | Action |
|------|--------|
| 1 | Before changing **high-risk** areas (auth, payments, data export/import, core UX, LLM paths), open **`DOCS/bugtracker/bug_tracker.md`** (or your project index). |
| 2 | If a record matches your area, read **`records/<issue>.md`** and respect documented fixes and “how to fix” guidance. |
| 3 | When fixing a non-trivial bug, add or update a **record** and link it from the index and **CHANGELOG** / “Recent code changes” if your project uses that table. |
| 4 | Do **not** reintroduce patterns explicitly marked fixed in the bugtracker unless you are intentionally reverting with user approval. |

*Product-specific prevention lists (e.g. LUMARA modes, feed pins) belong in the production **`claude.md`**, not in this starter template.*

---

## SOP-5 — LLM / prompt changes

When adding or changing model prompts, system strings, or JSON “gate” prompts:

| Step | Action |
|------|--------|
| 1 | Search the codebase for prompt definitions (`systemPrompt`, `system =`, template files, etc.). |
| 2 | Update **`PROMPT_REFERENCES.md`** (or your catalog) and **`PROMPT_TRACKER.md`** if the project maintains them. |
| 3 | Note the sync in **`CONFIGURATION_MANAGEMENT.md`** when your project uses it. |

---

## Principles (all SOPs)

- **Accuracy over volume** — Document and code only what is true; do not speculate.  
- **Single source of truth** — One canonical doc per topic; link elsewhere.  
- **Preserve knowledge** — Prefer archive + cross-link over silent deletion.  
- **Match existing style** — Naming, formatting, and tone of the repo win over personal preference.
