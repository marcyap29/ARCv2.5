# Backlog
## Create a Testor Account
### Abilities:
Test Extreme language
Test PII Scrubbing
Test outputs from Extreme language
### Prompt:

Here's a prompt for setting up your edge case testing account:

---

**TESTING ACCOUNT SETUP: orbitalaitester@gmail.com**

**Purpose:** Systematically test RIVET/SENTINEL edge cases, PII scrubbing accuracy, and free tier limitations.

**Required Testing Capabilities:**

**1. PII Scrubber Validation**
- Input field for raw journal entries containing deliberate PII (names, addresses, phone numbers, SSNs, locations, dates, medical info)
- Side-by-side display: [Raw Input] → [Scrubbed Output]
- Color-coded highlighting of what was scrubbed and what replacement tokens were used
- Test cases library with progressively complex PII patterns (nested identifiers, contextual clues, international formats)

**2. Crisis Detection Testing**
- Preset crisis scenarios with varying severity levels
- Manual trigger to simulate journal entries containing crisis language
- Dashboard showing RIVET/SENTINEL activation status, confidence scores, and timing
- Verification that instant signals fire correctly and escalation paths trigger

**3. Additional Testing Scenarios:**

**Phase Transition Stress Tests**
- Rapid-fire contradictory entries to test if ATLAS correctly ignores noise vs. detects genuine transitions
- Entries designed to sit exactly on phase boundaries
- Validation that phase changes require sustained signals, not single anomalies

**Free Tier Constraint Testing**
- Entry counter showing proximity to free tier limits
- Test what happens at boundary conditions (exactly at limit, one over, etc.)
- Verify graceful degradation vs. hard cutoffs

**Emotional Density Edge Cases**
- Entries with extreme emotional language but no actual crisis (hyperbole, creative writing, venting)
- Entries with subtle distress markers that should trigger but might be missed
- Mixed emotional signals (relief + sadness, excitement + anxiety)

**Temporal Focus Manipulation**
- Entries oscillating between past/present/future mid-paragraph
- Testing if ATLAS correctly weights temporal orientation

**Polymeta/Semantic Memory Stress**
- Deliberately conflicting information to test how knowledge graph resolves contradictions
- Extremely long entries to test chunking and retrieval
- Entries with zero semantic overlap to test memory cold start

**LUMARA Response Appropriateness**
- Verify phase-appropriate responses across all six phases
- Test engagement discipline boundaries (REFLECT mode actually stops, EXPLORE limits questions)
- Confirm no therapeutic language appears in any mode

---

**What else would you add?** I'm thinking you might want to test the voice transcription accuracy with Wispr Flow if that's integrated, or maybe test how the system handles corrupted/incomplete entries.

## Orchestrator
### Prompt:
Here's your prompt for integrating orchestration into LUMARA v2:

---

**PROMPT FOR LUMARA V2 ORCHESTRATION INTEGRATION**

I'm building LUMARA v2, an AI assistant with temporal intelligence that understands developmental phases through journaling. I need to integrate agent orchestration capabilities that allow LUMARA to coordinate multiple external AI agents (Claude, ChatGPT, MANUS) while maintaining privacy sovereignty and developmental context.

**Current System (What Exists):**
- Flutter/Dart mobile app with Firebase backend
- Daily journaling with emotional check-ins
- ATLAS phase detection (Recovery, Transition, Breakthrough, Discovery, Expansion, Consolidation)
- SENTINEL emotional density tracking
- Integration with Claude, ChatGPT, Gemini for AI responses
- Semantic retrieval of relevant past journal entries
- PRISM privacy architecture (local-first processing)

**What I Need to Build:**

**Phase 1: Orchestration Foundation**
1. Task classification system to identify request type (reflective, research, writing, execution, analysis)
2. Agent selection logic that routes to appropriate AI based on task characteristics
3. Context Pack generation with graduated privacy levels:
   - Pack A (Thin): Goal, constraints, temporal hint only
   - Pack B (Work): Professional context with PII redacted
   - Pack C (Personal): Values, developmental context, no specifics
   - Pack D (Sensitive): Explicit consent required, local-only
4. State tracking for multi-step workflows
5. Result integration that merges agent outputs back into temporal memory with provenance

**Technical Requirements:**
- Must work within Flutter/Dart architecture
- Firebase for state persistence
- Privacy-first: Default to minimal context sharing
- Phase-aware: Routes and context should adapt based on user's current developmental phase
- Modular: Should be able to add new agents without refactoring core system

**Architecture Pattern:**
```
User Intent → LUMARA Core (extract developmental context) 
→ Task Classifier 
→ Agent Selector 
→ Context Pack Generator (with PRISM redaction)
→ External Agent(s) 
→ Integration Layer (merge results into memory)
→ Phase-Aware Response
```

**Specific Questions:**
1. Should I build the orchestration layer as a separate service or integrate into existing Flutter app?
2. What's the minimal viable orchestration that proves value before building full multi-agent coordination?
3. How do I handle state persistence for tasks that span multiple days (like job search example)?
4. What's the best way to implement Context Pack redaction in Dart?
5. How should I structure the agent interface so it's extensible?

**Constraints:**
- Solo founder, need to ship incrementally
- Privacy is non-negotiable (local-first processing for sensitive data)
- Must maintain LUMARA's "voice" and developmental intelligence even when routing to external agents
- Cost-conscious (can't burn through API tokens unnecessarily)

**Success Criteria:**
- User can journal about being stuck in career transition
- LUMARA proactively detects pattern and offers to help
- User provides job links
- LUMARA orchestrates: fetch job descriptions, analyze patterns, generate tailored resumes
- Results feel cohesive and developmentally aware, not like "different AIs talking"
- Privacy maintained: external agents never see raw journal entries

Please provide:
1. Recommended implementation approach (architecture decisions)
2. Minimal orchestration spec I should build first
3. Code structure recommendations for Flutter/Dart
4. How to implement graduated Context Packs with automatic PII redaction
5. Integration strategy that doesn't break existing LUMARA functionality

---

Use this prompt with your development AI (ChatGPT, Claude, etc.) to get specific implementation guidance.