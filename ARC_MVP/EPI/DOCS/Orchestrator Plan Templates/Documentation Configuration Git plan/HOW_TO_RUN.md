# How to Run — Documentation, Config & Git Backup

## 1. Doc/Config/Git run = orchestration plan

The Documentation, Configuration Management and Git Backup flow is defined in a **single plan document** (no doc changes until you run the agents):

**DOCS/Orchestrator Plan Templates/DOC_CONFIG_GIT_ORCHESTRATION_PLAN.md**

It contains:

- **Prompt inventory:** Doc/Config/Git prompt and Task Orchestrator prompt (purpose, triggers, inputs, outputs, dependencies).
- **Concrete work:**
  - **Prompt references audit** — Check/create PROMPT_REFERENCES.md; compare repo prompts to catalog; update PROMPT_TRACKER and CONFIGURATION_MANAGEMENT. Required before any doc pass.
  - **Git scan** — Identify what changed (`git log` / `git diff` since last documented state); produce change summary for Phase 2.
  - **Doc updates by domain** — CHANGELOG, ARCHITECTURE/FEATURES, bugtracker/README/backend, CONFIGURATION_MANAGEMENT/key docs.
  - **Optional consolidation** — Reduce redundancy, archive obsolete, fix links.
  - **Single commit + push** — All doc updates in one commit.
- **Phased, divisible work packages** with IDs (e.g. P1-AUDIT, P1-GIT-SCAN, P2-CHANGELOG, P2-ARCH) and dependencies.

---

## 2. Divisible plan and agent roles

Execution is split into phases and work packages so multiple agents can work in parallel after the setup step:

| Phase | Focus | Parallelizable? |
|-------|--------|------------------|
| **Phase 1** | Setup: refresh plan (optional), prompt references audit, identify what changed (git scan) | Yes — Coordinator + Agent A + Agent B at once |
| **Phase 2** | Doc updates: CHANGELOG, ARCHITECTURE/FEATURES, bugtracker/README/backend, CONFIGURATION_MANAGEMENT | Yes — 4 agents (C, D, E, A or F) at once; all use change summary from P1-GIT-SCAN |
| **Phase 3** | Optional consolidation; then commit and push | Sequential — F (optional), then Coordinator or B |

**Agent roles** (in the plan and in the Assignments folder):

| Agent | Role | Main work packages |
|-------|------|---------------------|
| **Coordinator** | Plan owner + git backup | P1-PLAN (refresh plan), (P1-GIT-SCAN), (P3-COMMIT-PUSH) |
| **A** | Prompt references & config | P1-AUDIT (prompt catalog), P2-CONFIG (CONFIGURATION_MANAGEMENT, key docs) |
| **B** | Git scan & backup | P1-GIT-SCAN (change summary), P3-COMMIT-PUSH |
| **C** | Changelog & versioning | P2-CHANGELOG |
| **D** | Architecture & features | P2-ARCH (ARCHITECTURE, FEATURES) |
| **E** | Bugtracker & README | P2-BUG-README (bugtracker/, README, backend.md) |
| **F** | Config inventory & consolidation | P2-CONFIG, P3-CONSOLIDATE (optional) |

**Suggested execution waves:**

- **Wave 1:** Coordinator (P1-PLAN if needed), Agent A (P1-AUDIT), Agent B (P1-GIT-SCAN) — in parallel.
- **Wave 2:** Share change summary from P1-GIT-SCAN with C, D, E, and A or F. Run P2-CHANGELOG (C), P2-ARCH (D), P2-BUG-README (E), P2-CONFIG (A or F) — in parallel.
- **Wave 3:** Optionally run Agent F (P3-CONSOLIDATE). Then run P3-COMMIT-PUSH (Coordinator or Agent B).

---

## 3. Where to get tasking for each agent

**Cut-and-paste prompt blocks** for each role are in the orchestration plan:  
**DOC_CONFIG_GIT_ORCHESTRATION_PLAN.md** → section “Cut-and-paste blocks for agents” (Block 1 = Coordinator, Block 2 = Agent A, etc.).

If your repo has a **Documentation Configuration Git Agents Assignments** folder with ASSIGNMENT_*.md files, use those: each file has the same blocks plus task lists and dependencies. Give each agent its assignment file (and, for Wave 2 agents, the **change summary** from P1-GIT-SCAN).
