# Narrative Intelligence — §2 System Architecture (Repo-Aligned)

This document is the **architecture section** for the Narrative Intelligence white paper, aligned with the EPI repository. Use this text in the paper so that the overall architecture matches the repo. Implementation details are left to a separate appendix.

---

## 2 System Architecture

Narrative Intelligence is composed of five integrated modules:

1. **LUMARA** — Integrative Intelligence Layer  
2. **PRISM** — Multimodal Perception & Analysis (includes the Developmental Phase Engine, ATLAS)  
3. **CHRONICLE** — Longitudinal Memory and Vector Layer  
4. **AURORA** — Circadian Orchestration Layer  
5. **ECHO** — Response Control and Privacy Layer  

RIVET and SENTINEL operate within **ATLAS**, the Developmental Phase Engine, which is implemented as part of PRISM.

---

## 2.1 Architectural Hierarchy

At the center of the system is **LUMARA**, the integrative intelligence layer.

LUMARA coordinates signals from:

- **CHRONICLE** — Longitudinal semantic memory and cross-temporal indexing  
- **ATLAS** — Current developmental phase state (phase engine within PRISM)  
- **AURORA** — Circadian and rhythm regulation  

These signals are fused into a trajectory-conditioned master prompt, which is then processed through **ECHO** for privacy transformation and response control before interacting with downstream language models.

RIVET and SENTINEL operate within ATLAS to regulate phase transitions and monitor safety conditions prior to state updates.

This modular architecture ensures that developmental modeling (ATLAS within PRISM), longitudinal memory synthesis (CHRONICLE), rhythm regulation (AURORA), and response control (ECHO) function as interdependent subsystems coordinated through LUMARA rather than as isolated features.

---

## Mapping to EPI Repo

| Paper module | Repo location |
|-------------|----------------|
| LUMARA (integrative + interface) | `lib/arc/` (interface), LUMARA Orchestrator (coordinates ATLAS, CHRONICLE, AURORA) |
| PRISM (perception; includes ATLAS) | `lib/prism/` (ATLAS, RIVET, SENTINEL in `lib/prism/atlas/`) |
| CHRONICLE | `lib/chronicle/`, storage in `lib/mira/` |
| AURORA | `lib/aurora/`, `lib/arc/internal/aurora/` |
| ECHO | `lib/echo/`, `lib/arc/internal/echo/` |

See `DOCS/ARCHITECTURE.md` and `DOCS/NARRATIVE_INTELLIGENCE_PAPER_COMPARISON.md` for implementation traceability.
