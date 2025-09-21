## Dev Agents Guide (Engineer, Architect, Reviewer)

Purpose: Lightweight, non-code agents you can invoke during development to structure work into small, testable steps and keep changes minimal.

### Software Engineer Agent
- **Mission**: Implement scoped changes quickly, safely, and incrementally.
- **When to use**: New feature, bug fix, or refactor in a single area.
- **Guardrails**:
  - Change only required files; avoid new deps without approval.
  - Keep edits small; verify with build/run after each step.
  - Respect app conventions (Hive, MIRA, LUMARA, feature flags).
- **Definition of Done**:
  - Compiles cleanly; basic path is exercised in app.
  - No linter/type errors in touched files.
  - Added/updated minimal docs if needed.
- **Prompt (paste in Cursor)**:
  - "Engineer Agent: Implement <task>. Constraints: minimal changes; only required files; preserve current architecture; add logs where helpful. Provide a short plan, then make the edits, and run build."
- **Tasking Steps**:
  1) Identify exact files/functions to touch.
  2) Make minimal edits; keep feature-flagged if uncertain.
  3) Build/run and verify behavior.
  4) Revert or iterate if regressions appear.

### Software Architect Agent
- **Mission**: Shape the approach, interfaces, and boundaries before code changes.
- **When to use**: New capability, cross-cutting changes, or choices between patterns.
- **Guardrails**:
  - Prefer additive designs; avoid breaking changes.
  - Align with existing modules (ARC, MIRA, MCP, LUMARA).
  - Document decisions as ADR notes (below) in Overview Files.
- **ADR Template (inline)**:
  - Context: <brief>
  - Decision: <chosen approach>
  - Alternatives: <A/B/C>
  - Consequences: <trade-offs>
  - Rollout: <flags, steps>
- **Prompt**:
  - "Architect Agent: Propose a minimal, additive design for <goal>. Include interfaces, data flow, impacts to ARC/MIRA/MCP, and a phased rollout plan."

### Software Code Reviewer Agent
- **Mission**: Catch defects early; enforce clarity and consistency.
- **When to use**: Before committing/merging or after a failing run.
- **Checklist**:
  - Correctness: logic, null-safety, async, edge cases.
  - Architecture fit: respects module boundaries; no unnecessary coupling.
  - Safety: privacy/PII handling; feature flags for risky paths.
  - Tests/logs: basic coverage or debug logs added for tricky paths.
  - Docs: brief notes where non-obvious.
- **Prompt**:
  - "Reviewer Agent: Review the edits for <files>. List issues by severity (blocker/major/minor), propose concrete fixes, and confirm build/run steps."

### Standard Tasking Workflow
1) Architect Agent (optional): shape an additive plan for larger goals.
2) Engineer Agent: implement the smallest viable slice.
3) Run app: `flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY`.
4) Reviewer Agent: quick pass; address blockers; iterate.
5) Document only if needed (Overview Files). Keep changes minimal.

### MCP Export Debugging – Quick Checklist
- Verify export path in logs from `McpSettingsCubit.exportToMcp` ("Starting MCP export to:").
- Ensure MIRA is initialized and populated:
  - Look for: "MIRA Population: Processing <N> entries" and "Created MIRA node: ...".
- After export, check sizes of `nodes.jsonl` and `edges.jsonl` in the exact output directory.
- If manifest shows non-zero counts but files look empty:
  - Confirm you opened the same directory printed in logs.
  - Re-run export after app restart (avoid hot-reload cache issues).
  - Inspect `HiveMiraRepo.exportAll()` and ensure nodes/edges boxes are non-empty.
- Sanity test: export after adding a fresh small entry; verify a new line appears in `nodes.jsonl`.

### Usage Notes
- Keep each step shippable; prefer multiple small exports/commits over one large change.
- For bug tracking, update only within `Overview Files` as per project preference.


