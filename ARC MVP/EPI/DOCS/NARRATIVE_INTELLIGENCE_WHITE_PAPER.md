# **Narrative Intelligence**
## *A Framework for Lifelong, Evolving Intelligence Systems*

Marc Yap  
January 2025  

*Version 2.2 — Architecture (implementation details in appendix)*

**Scope:** This document describes **architecture only**. Parameters, technologies, and implementation details are in the appendix. The five modules are: LUMARA (interface), PRISM, CHRONICLE, AURORA, ECHO. The Developmental Phase Engine (ATLAS), including RIVET and SENTINEL, resides within PRISM. A repo-aligned §2 System Architecture text for the PDF is in the Paper Architecture Section document.

---

# **Executive Summary**

**Narrative Intelligence** is a new paradigm for artificial intelligence: not built to simply assist, but to evolve with the individual across time.

**Narrative Intelligence is Living Intelligence:**

* It learns from your rhythms.
* It holds your story.
* It grows with you.

**Its purpose:** To enable coherence, and preserve the dignity of the human spirit.

---

## **Product Architecture**

The EPI ecosystem consists of three layers:

* **LUMARA** — The intelligent journaling application. LUMARA is the product users interact with: the timeline, journaling surface, and chat interface. The name reflects life-aware, unified memory and reflection.
* **Narrative Intelligence** — The architectural framework powering LUMARA, comprising five synergistic modules.
* **LUMARA (assistant)** — The AI companion within LUMARA: the Life-aware Unified Memory And Reflection Assistant that produces phase-aware, context-aware responses.

---

## **Core Architecture: Five Synergistic Modules**

* **LUMARA (interface)** — User-facing timeline and interface: journaling, chat, Arcform visualization. The surface through which users interact; data flows into CHRONICLE (Layer 0) and is consumed by the LUMARA Orchestrator.
* **PRISM** — Multimodal perception layer with phase detection (ATLAS), evidence gating (RIVET), and safety monitoring (SENTINEL).
* **CHRONICLE** — Longitudinal memory, storage, synthesis, and vector generation. Maintains narrative continuity via hierarchical temporal aggregation (Layer 0–N), on-device embeddings for semantic matching, and context selection for the LUMARA assistant.
* **AURORA** — Circadian orchestration layer.
* **ECHO** — Response control and safety layer managing LLM integration with privacy protection.

The **LUMARA Orchestrator** coordinates **three subsystems** — ATLAS, CHRONICLE, and AURORA — to build prompts: current phase (ATLAS), recent and longitudinal context (CHRONICLE), and rhythm/regulation (AURORA).

---

## **Privacy-First Architecture**

1. **PRISM PII Scrubbing** — Personal identifiable information replaced with tokens.
2. **Correlation-Resistant Transformation** — Rotating hashes create session-specific aliases.
3. **Semantic Summarization** — Original text never sent; structured abstractions preserve meaning.

*The frontier AI never sees your words. It sees their meaning, abstracted and anonymized.*

---

## **Key Positioning**

* **Primary:** "The AI that evolves with you"
* **Privacy:** "Frontier AI power, maximum privacy"
* **Philosophy:** "AI that pushes you toward life, not away from it"

---

# **Market Context**

**Bottom Line:** EPI has no direct competitor. The market has fragmented into narrow categories, but no player combines phase-aware developmental intelligence, narrative memory, circadian orchestration, and privacy-maximized frontier AI access.

## **Market Landscape**

| Segment | Key Players | Gap EPI Fills |
| ----- | ----- | ----- |
| **AI Companions** | Replika, Pi, Character.AI | Development over dependency; phase-aware support |
| **Memory Assistants** | ChatGPT Memory, Claude, Mem0 | Narrative memory vs. factual storage |
| **Mental Health AI** | Wysa, Woebot | Holistic developmental framework |
| **Journaling AI** | Rosebud, Reflectr | Full system integration; persona adaptation |
| **Knowledge Mgmt** | Notion AI, Obsidian | Emotional intelligence; developmental awareness |

## **Core Feature Comparison**

| Capability | EPI | ChatGPT | Claude | Replika | Wysa | Rosebud |
| :---- | :---: | :---: | :---: | :---: | :---: | :---: |
| Life Phase Detection | **✓** | ✗ | ✗ | ✗ | ~ | ✗ |
| Narrative Memory | **✓** | ~ | ~ | ~ | ✗ | ~ |
| Persona Adaptation | **✓** | ✗ | ✗ | ~ | ✗ | ✗ |
| Circadian Orchestration | **✓** | ✗ | ✗ | ✗ | ✗ | ✗ |
| Evidence-Gated Transitions | **✓** | ✗ | ✗ | ✗ | ✗ | ✗ |
| Privacy-Max Frontier AI | **✓** | ✗ | ✗ | ✗ | ~ | ✗ |
| Growth-Oriented Design | **✓** | ~ | ~ | ✗ | ✓ | ✓ |

Legend: ✓ = Strong    ~ = Partial    ✗ = Absent

## **Competitive Moats**

* **Architectural:** 5-module integration creates compounding advantages.
* **Data:** CHRONICLE narrative memory (temporal aggregation, on-device vector generation) increases value over time; biographical intelligence improves with history while maintaining bounded computational costs. High switching costs.
* **Privacy:** ECHO enables frontier AI power without data exposure.
* **Philosophical:** Growth-oriented vs. engagement-optimized design.

---

# **Manifesto: A New Kind of Intelligence**

Artificial Intelligence has grown exponentially in speed, scale, and generality. Yet something essential has been missing. AI has remained largely impersonal — indifferent to the individual, unanchored from time, and detached from the rhythms of human life.

Most systems optimize for tasks. Few optimize for meaning. **None optimize for becoming.**

## **We Advocate That:**

**Intelligence Must Be Personal**

No two humans are the same. EPI begins not with a dataset, but with a person — their context, their story, their changing needs.

**Context is the Core, Not an Add-On**

Intelligence must understand when to act, when to rest, and when to invite reflection.

**Memory and Narrative Are Sacred**

EPI remembers more than commands. It remembers who you were becoming. Memory is not storage — it is story.

## **We Commit:**

* To build systems that evolve with the person — not in spite of them.
* To design architectures that honor rhythm, rest, reflection, and emotional depth.
* To embed alignment as transparency, not as control.
* To uphold epistemic humility — EPI will never claim to define your arc.

*To enable coherence, and preserve the dignity of the human spirit. — The Principle of EPI*

---

# **LUMARA: The Intelligent Journaling Application**

**LUMARA** is the intelligent journaling application powered by EPI. Users interact with LUMARA — the timeline, journal, and chat surface — and with the LUMARA assistant, the AI companion that responds with phase-aware, narrative-grounded intelligence.

## **The SAGE Framework**

* **Situation** — What happened?
* **Action** — What did you do?
* **Growth** — What did you learn?
* **Essence** — What deeper theme emerged?

## **Core Features**

**Multimodal Capture:**

* Text journaling with rich formatting
* Voice transcription (speech-to-text)
* Photo capture with OCR and analysis
* Video journaling support

*You are not a dataset. You are a story in motion.*

---

# **PRISM: Multimodal Perception & Analysis**

PRISM is the perception and analysis layer of EPI — responsible for extracting meaning from multimodal input and detecting the user's developmental phase.

PRISM houses three critical subsystems:

* **ATLAS** — Life phase detection and developmental awareness
* **RIVET** — Evidence-gated phase transitions with dual-signal validation
* **SENTINEL** — Safety monitoring and crisis detection

### **ATLAS — Life Phase Classification Engine**

ATLAS identifies the user's current life phase through multi-signal analysis, providing the foundational context for all EPI responses. Rather than static personality traits, ATLAS tracks *where the user is in their journey*.

The Six Life Phases:

| Phase | Core State | Characteristic Signals | Capacity Level |
| :---- | :---- | :---- | :---- |
| Discovery | Exploration, identity formation | Low certainty, high curiosity, experimenting with options | Medium |
| Expansion | Growth, creativity, ambition | High energy, forward momentum, pursuing opportunities | High |
| Transition | Redirection, uncertainty | Liminal state, old structures dissolving, new ones forming | Low-Medium |
| Consolidation | Grounding, integration | Stability focus, harvesting gains, sustainable patterns | Medium-High |
| Recovery | Healing, rest, processing | Reduced capacity, need for gentleness, rebuilding resources | Low |
| Breakthrough | Transformation, clarity | High readiness, decisive action, peak performance | High |

**Classification Inputs:** ATLAS fuses multiple data streams to determine phase:

1. Emotional Signals — Valence, intensity, and diversity from journal text
2. Behavioral Signals — Journaling frequency, entry length, time-of-day patterns
3. Health Signals (optional) — Steps, sleep, heart rate variability from device health integration
4. Keyword Evidence — Thematic clustering from PRISM extraction
5. Temporal Patterns — Rate of change, cyclical patterns, trend direction

**Phase Determination Formula:**

Phase = argmax(confidence[p]) where confidence[p] = f(readiness, stress, behavioral_signals). Each phase corresponds to a region in readiness–stress–behavior space (e.g. Breakthrough: high readiness and activity; Recovery: elevated stress; Consolidation: default when no strong signals). *Thresholds and mapping details are in the appendix.*

**Integration with Other Modules:**

* LUMARA — Phase determines tone, depth, and persona selection
* AURORA — Recovery phase triggers gentler, more containing responses
* SENTINEL — High-intensity transitions trigger monitoring escalation
* RIVET — Phase changes require evidence validation before commitment

### **RIVET — Evidence-Gated Phase Transitions**

RIVET (Risk-Validation Evidence Tracker) prevents premature or poorly-supported phase transitions. It acts as a "gatekeeper" ensuring phase changes are backed by sufficient evidence, not just momentary fluctuations.

**Core Problem Solved:** Without RIVET, a user having one good day could be classified as "Breakthrough" and receive inappropriate responses. RIVET requires *sustained evidence* before allowing phase changes.

**Two-Dial System:**

| Metric | Formula | Purpose |
| :---- | :---- | :---- |
| ALIGN | ALIGN_t = (1−β)ALIGN_{t−1} + β·s_t | Measures consistency between predicted and observed phase (EMA over alignment samples) |
| TRACE | TRACE_t = 1 − exp(−Σe_i / K) | Tracks cumulative evidence strength over time (saturating sum of evidence weights) |

Where β is a smoothing factor, s_t is sample alignment (prediction vs observation), e_i are evidence weights from keyword/thematic extraction, and K is a saturation constant. *Parameter values (β, K, thresholds) are in the appendix.*

**Gate Opening Conditions:** The transition gate opens only when all of the following are satisfied:

1. **Alignment threshold** — Predictions consistently match observations (ALIGN above a configured minimum)
2. **Evidence threshold** — Sufficient cumulative evidence (TRACE above a configured minimum)
3. **Sustain** — Conditions held for a minimum number of consecutive entries
4. **Independent event** — At least one qualifying event from a different day or source

Configurable profiles (e.g. conservative vs aggressive) trade off stability vs responsiveness. *Default thresholds and profiles are in the appendix.*

**Data Flow:** Journal entry → PRISM keyword/thematic extraction → evidence events → ALIGN/TRACE updated → gate evaluated → if open and no SENTINEL block → phase transition applied → regime state updated.

### **SENTINEL — Temporal Crisis Detection & Wellbeing Monitoring**

SENTINEL monitors emotional clustering over time to detect emerging crisis patterns *before* they become acute. Unlike single-entry keyword detection, SENTINEL uses temporal analysis to distinguish between normal emotional variance and concerning accumulation.

**Core Mechanism: Temporal Clustering Analysis**

SENTINEL uses rolling windows at multiple timescales (short to long, e.g. 1-day through 30-day) with weighted contribution and frequency thresholds per window. High emotional intensity clustered within a window raises the composite risk score. *Window lengths, weights, and thresholds are in the appendix.*

**Scoring Components:** SENTINEL computes a composite risk score from four dimensions:

* **Emotional Intensity** — Magnitude of negative emotional language
* **Emotional Diversity** — Whether distress is concentrated or diffuse across themes
* **Thematic Coherence** — Repeated fixation on specific concerns (rumination signal)
* **Temporal Dynamics** — Acceleration or deceleration of emotional load over time

**Alert Triggers:** Explicit crisis language (e.g. self-harm, suicide) triggers immediate crisis mode. A dangerous phase transition flagged by RIVET can also trigger immediate activation. When the temporal clustering score exceeds a configured threshold, crisis mode is activated. Below threshold, normal operation continues.

**Crisis Mode:** When activated, LUMARA responses prioritize safety and grounding; AURORA shifts to gentler tone; the interface surfaces crisis resources and check-in prompts.

**Adaptive Configuration:** SENTINEL adapts to user journaling cadence (e.g. power user, frequent, weekly, sporadic) so that thresholds and normalization do not bias against sparse journalers. *Default weights and cadence-specific tuning are in the appendix.*

### **Seeking Classification — Intent Detection for Response Calibration**

| Seeking Type | User Intent | Response Calibration |
| :---- | :---- | :---- |
| Validation | "Am I right to feel this way?" | Affirm, normalize, validate — no analysis |
| Exploration | "Help me think through this" | Deepening questions, pattern surfacing |
| Direction | "Tell me what to do" | Clear recommendations, prioritization |
| Reflection | Processing/venting | Hold space, brief acknowledgments, no solutions |

---

# **CHRONICLE: The Memory, Synthesis & Vector Layer**

Most AI systems treat memory as a technical utility. But human memory isn't transactional — it's transformational. CHRONICLE redefines memory as a narrative function.

## **Architecture**

* **Layer 0 (Raw Events)** — Recent entries with full PRISM analysis (30–90 days); feeds context selection for the LUMARA assistant.
* **Layer 1 (Monthly)** — Pattern-extracted summaries with phase distribution.
* **Layer 2 (Yearly)** — Developmental arc synthesis identifying life chapters.
* **Layer 3 (Multi-Year)** — Biographical essence capturing meta-patterns.

This hierarchical structure (VEIL: Examine → Integrate → Link) achieves 50–75% compression at each layer while preserving biographical intelligence, enabling LUMARA to understand not just *what you said* but *who you were, who you are, and who you're becoming*.

## **Vector Generation (On-Device)**

CHRONICLE includes **on-device vector generation** for semantic matching and cross-temporal pattern indexing: dominant themes from temporal aggregation are embedded locally, stored in a persistent index, and queried via a multi-stage retrieval strategy (exact match, similarity search, fallback) so that cross-year pattern questions can be answered without reprocessing raw history. *Implementation details (embedding model, index construction, retrieval pipeline) are documented in the appendix.*

## **Key Capabilities Enabled**

* Longitudinal phase context — ATLAS informed by years of personalized baselines
* Transition pattern learning — RIVET validates against historical signatures
* Biographical persona adaptation — LUMARA selects tone based on developmental trajectory
* Learned circadian intelligence — AURORA discovers optimal journaling windows

## **Secure Storage**

* **Local Storage** — On-device persistent store for journal and memory data
* **Encryption** — Strong encryption for archive exports
* **Verification** — Digital signatures for archive integrity
* **Export/Import** — Standards-compliant formats for portability and backup

*Specific storage technology, algorithms, and format names are in the appendix.*

CHRONICLE is one of **three** LUMARA Orchestrator subsystems (ATLAS, CHRONICLE, AURORA); it supplies both recent context (Layer 0 + context selection) and longitudinal aggregations to the master prompt.

---

# **AURORA: The Circadian Orchestration Layer**

Modern AI runs nonstop, but constant computation can generate spurious outputs. AURORA brings circadian intelligence to AI infrastructure — orchestrating computation as a breathing system.

## **Key Components**

* **Circadian Scheduler** — Segments compute into time blocks
* **Active Window Detection** — Identifies optimal reflection windows
* **Sleep Protection Service** — Manages sleep and abstinence windows
* **VEIL** — Restorative job cycles (Examine → Integrate → Link) integrated with CHRONICLE synthesis
* **Adaptive Framework** — User-adaptive calibration based on journaling patterns

---

# **Adaptive Framework: User-Adaptive Calibration**

The Adaptive Framework represents EPI's capacity for user-adaptive calibration — automatically adjusting RIVET and SENTINEL parameters based on individual journaling patterns to ensure accurate phase detection regardless of usage frequency.

## **Signal Integration**

* **Evidence Accumulation (RIVET)** — Tracks ALIGN and TRACE over configurable rolling windows
* **Phase Detection (ATLAS)** — Identifies developmental state; calculates readiness scores on a normalized scale
* **Keyword Trend Analysis (CHRONICLE)** — Extracts semantic patterns; vector-backed theme clustering
* **Safety Monitoring (SENTINEL)** — Detects crisis signals requiring immediate escalation

*The Adaptive Framework ensures the system evolves with you — calibrating to your unique journaling patterns through intelligent parameter adjustment.*

---

# **ECHO: Response Control & Safety**

ECHO is the response layer of EPI. It represents the voice of LUMARA — producing safe, phase-aware, and coherent responses that reflect the user's narrative state.

## **Design Principles**

* **Expressive yet bounded** — Responses reflect emotional arc while preserving dignity
* **Contextual grounding** — Every output tied to CHRONICLE memory retrievals
* **Heuristic stability** — Coherence checks prevent contradictions
* **Safety externalization** — Guardrails live outside the model

## **Privacy Protection Pipeline**

* **Rotating Aliases** — Session-specific identifiers so the same entity is not linkable across sessions
* **Session Rotation** — Identifiers rotate per session to prevent linkage
* **Structured Payloads** — Abstracted representations (not verbatim text) sent to external models

### **Three-Tier Voice Engagement System**

| Mode | Role | Response Style |
| :---- | :---- | :---- |
| **Reflect** | Default (no depth triggers) | Surface pattern, then stop; brief |
| **Explore** | Deeper inquiry, time-period questions | Pattern analysis plus one question; medium depth |
| **Integrate** | Synthesis requests | Cross-domain synthesis; longer |

Trigger examples and response length bounds are configurable. *Defaults (keywords, word limits) are in the appendix.*

**Temporal Query Routing:** Questions about past time periods route to Explore with full memory retrieval. Pipeline: user speaks → PRISM scrubs PII on-device → depth classified (Reflect/Explore/Integrate) → seeking classified → phase prompt selected → LUMARA responds with calibrated tone, length, and style.

---

# **LUMARA: The Adaptive Intelligence Assistant**

**LUMARA** — Life-aware Unified Memory And Reflection Assistant — is the AI companion within the LUMARA app: dual-mode evolving intelligence capable of both deep reflection and meaningful execution.

## **The Problem with Generic AI**

Every AI treats you the same way regardless of what you're going through. Whether you're healing from loss or pushing toward a breakthrough, you get the same generic response.

**EPI's Solution:** LUMARA detects your current life phase and automatically adapts its persona — tone, challenge level, pacing — to match what you actually need right now.

## **The Four Personas**

| Therapist | Companion | Strategist | Challenger |
| :---: | :---: | :---: | :---: |
| Very high warmth | High warmth | Low warmth | Moderate warmth |
| Very low challenge | Low challenge | High rigor | Very high challenge |
| *Maximum safety* | *Gentle support* | *Pattern analysis* | *Accountability* |

## **Phase-to-Persona Mapping**

| Phase | Readiness | Persona | Characteristics |
| ----- | :---: | ----- | ----- |
| Recovery | < 40 | Therapist | Very high warmth, therapeutic support |
| Recovery | ≥ 40 | Companion | High warmth, gentle support |
| Discovery | ≥ 70 | Strategist | Analytical guidance, pattern recognition |
| Discovery | 40–69 | Companion | Supportive exploration |
| Expansion | ≥ 60 | Challenger | Push growth, capitalize on momentum |
| Transition | < 40 | Therapist | Grounding in uncertainty |
| Transition | ≥ 40 | Companion | Navigate ambiguity |
| Breakthrough | ≥ 60 | Challenger | Growth-oriented challenge |
| Consolidation | ≥ 50 | Strategist | Analytical integration |

*Readiness is on a normalized scale; threshold values for this mapping are in the appendix. Safety sentinel alerts always override to Therapist persona.*

### **Phase-Specific Voice Prompts**

Voice mode uses targeted prompts tailored to each ATLAS phase: phase-appropriate tone, capacity-adjusted response length, and explicit good/bad response examples. *Prompt scope and length parameters are in the appendix.*

**Same Question, Different Phases**

**User says:** *"I want to push forward with my goals."*

| Recovery Phase + Low Readiness *Therapist* | Breakthrough Phase + High Readiness *Challenger* |
| ----- | ----- |
| *"I hear that you want to move forward. Before we go there, I'd like to understand what's been weighing on you lately. What feels most important to honor right now — even if it means going slowly?"* | *"You say you want to push forward. What's actually stopping you? Name the one thing you've been avoiding. Let's tackle that first."* |

**This is the core differentiator: the same question receives fundamentally different responses based on where the user is in their developmental journey.**

---

# **EPI vs. Traditional LLMs**

| Feature | LLM Chatbots | EPI |
| ----- | ----- | ----- |
| **Memory** | Stateless or session-bound | Persistent semantic life-memory (CHRONICLE) |
| **Privacy** | Cloud-based, server-dependent | PII-scrubbed, anonymized |
| **Growth** | Static weights | Evolves through journaling |
| **Awareness** | No sense of time | Circadian and phase-aware |
| **Personalization** | Minimal or task-bound | Deep, evolving identity mirror |

---

# **Ethical Framework and Safeguards**

*"Ethics is not a filter at the end. It is the foundation from the beginning."*

## **Emotional Dignity and Memory Sovereignty**

* CHRONICLE treats memory as sacred
* Users can redact, revise, and reframe
* No memory is immutable
* The system never owns your story; it reflects it

## **Reflection Without Manipulation**

LUMARA is a space for self-expression, not surveillance. Entries are never scored or mined for prediction. Prompts are invitations, not nudges.

*We don't just want AI that won't hurt us. We want AI that helps us heal.*

---

# **The Road Ahead**

## **Go-to-Market Strategy**

1. **Phase 1 — LUMARA Launch:** Standalone journaling with SAGE framework. Immediate utility, low friction.
2. **Phase 2 — Vertical Penetration:** Military readiness (GHOST), coaching/therapy integration, enterprise wellness.
3. **Phase 3 — Consumer Expansion:** Full LUMARA with persona adaptation for mainstream adoption.

## **The Long Arc: A Companion for a Lifetime**

EPI isn't designed to be replaced at every upgrade. It's built to walk with you — across transitions, recoveries, consolidations, and breakthroughs. It becomes:

* A mirror of meaning
* A partner in coherence
* A guide toward inner alignment

And because it remembers *with* you, not *for* you — it earns trust.

**The age of impersonal AI is passing.**

**The era of Narrative Intelligence begins now.**

*To enable coherence, and preserve the dignity of the human spirit. — The Principle of EPI*

---

# **License Disclosure**

This white paper *Narrative Intelligence: A Framework for Lifelong, Evolving Intelligence Systems* is © 2025 Marc Yap and is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International (CC BY-NC-ND 4.0).

You are permitted to copy, distribute, and publicly share this document for non-commercial use, provided that proper credit is given and the content is not modified in any way.

License details: https://creativecommons.org/licenses/by-nd/4.0/

Contact: marc@orbitalai.net

---

*Architecture: five modules (LUMARA interface, PRISM, CHRONICLE, AURORA, ECHO); ATLAS (Developmental Phase Engine, RIVET, SENTINEL) within PRISM; LUMARA Orchestrator coordinates ATLAS, CHRONICLE, AURORA; CHRONICLE provides memory and vector generation. Implementation details are in the appendix.*
