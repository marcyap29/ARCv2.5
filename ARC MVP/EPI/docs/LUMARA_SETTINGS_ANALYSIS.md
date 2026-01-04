# LUMARA Settings Analysis: Why LUMARA Goes Off-Topic

## The Problem

When you ask a direct question (like "does this make sense?" about calculus), LUMARA sometimes:
- Avoids answering the question directly
- Connects to unrelated past entries (faith, imposter syndrome, etc.)
- Goes off-topic instead of staying focused

## Root Causes Identified

### 1. **Response Structure Conflict** ⚠️ CRITICAL

The engagement mode response structures are **conflicting** with the "answer direct questions first" rule:

**Current Response Structures:**
- **REFLECT mode**: `Grounding → Temporal connection → Request fulfillment → STOP`
- **EXPLORE mode**: `Grounding → Temporal connection → Request fulfillment → Optional question`
- **INTEGRATE mode**: `Grounding → Temporal connections → Cross-domain synthesis → Request fulfillment`

**The Problem:**
These structures put "Grounding" and "Temporal connection" **BEFORE** "Request fulfillment", which means LUMARA is being instructed to make connections **BEFORE** answering your question.

Even though we added the rule "ANSWER DIRECT QUESTIONS FIRST", the response structure templates are still putting connections first. This creates a conflict where LUMARA tries to follow both instructions.

**Solution Needed:**
The response structure should be conditional:
- **If direct question detected**: `Answer question → Optional relevant context → STOP`
- **If no direct question**: `Grounding → Temporal connection → Request fulfillment → STOP`

---

### 2. **Max Temporal Connections Setting**

**What it does:**
- Controls how many references to past entries LUMARA can make in a single response
- Default: 2 connections
- Range: 1-5 connections

**How it affects off-topic behavior:**
- If set to **3-5**: LUMARA might feel compelled to use all available connections, even when they're not relevant
- If set to **1**: LUMARA will make fewer connections, staying more focused

**Recommendation for direct questions:**
- Set to **1** when you want focused, on-topic responses
- This forces LUMARA to be selective about which connections to make

---

### 3. **Max Similar Entries (Max Matches) Setting**

**What it does:**
- Controls how many past journal entries LUMARA retrieves when building context
- Default: 5 entries
- Range: 1-20 entries

**How it affects off-topic behavior:**
- If set to **10-20**: LUMARA has access to many entries, increasing the chance of finding tangentially related entries
- If set to **1-3**: LUMARA has less context, but more focused on the most relevant entries

**Recommendation for direct questions:**
- Set to **3-5** for more focused responses
- Lower values (1-3) might miss relevant context, but higher values (10-20) increase noise

---

### 4. **Engagement Mode Setting**

**What it does:**
- Controls how LUMARA engages with your entries
- Options: REFLECT, EXPLORE, INTEGRATE

**How it affects off-topic behavior:**

**REFLECT mode:**
- Response structure: `Grounding → Temporal connection → Request fulfillment → STOP`
- Makes 1-2 connections, then stops
- **Best for direct questions** - less likely to go off-topic

**EXPLORE mode:**
- Response structure: `Grounding → Temporal connection → Request fulfillment → Optional question`
- Similar to REFLECT but can ask questions
- Moderate risk of off-topic connections

**INTEGRATE mode:** ⚠️ HIGHEST RISK
- Response structure: `Grounding → Temporal connections → Cross-domain synthesis → Request fulfillment`
- **Explicitly encourages "Cross-domain synthesis"** - connecting themes across different life areas
- This is likely why your calculus question got connected to faith, imposter syndrome, etc.
- **Not recommended for direct questions**

**Recommendation:**
- Use **REFLECT mode** when asking direct questions
- Avoid **INTEGRATE mode** if you want focused, on-topic responses

---

### 5. **Synthesis Settings**

**What it does:**
- Controls whether LUMARA can synthesize themes across different domains
- Options:
  - `faith_work`: Can connect faith/spiritual themes with professional decisions
  - `relationship_work`: Can connect personal relationships to work context
  - `health_emotional`: Can relate physical health to emotional patterns
  - `creative_intellectual`: Can connect creative pursuits to intellectual work

**How it affects off-topic behavior:**
- If enabled, LUMARA is **explicitly allowed** to connect across domains
- This can lead to connections that feel off-topic (e.g., calculus → faith → imposter syndrome)
- Even if the connection exists in your journal history, it might not be relevant to the current question

**Recommendation:**
- Disable synthesis settings if you want more focused responses
- Or keep them enabled but rely on the "relevance filter" rule to prevent off-topic connections

---

### 6. **Similarity Threshold Setting**

**What it does:**
- Controls how similar an entry must be to be included in context
- Default: 0.55 (55% similarity)
- Range: 0.0-1.0

**How it affects off-topic behavior:**
- **Lower threshold (0.4-0.5)**: More entries included, but some might be tangentially related
- **Higher threshold (0.7-0.8)**: Only very relevant entries included, more focused context

**Recommendation:**
- Increase to **0.7-0.8** for more focused responses
- This ensures only highly relevant entries are included

---

## Recommended Settings for Direct Questions

If you want LUMARA to stay focused when answering direct questions:

### Minimal Historical Context (Most Focused)
- **Engagement Mode**: REFLECT
- **Max Temporal Connections**: 1
- **Max Similar Entries**: 3
- **Similarity Threshold**: 0.7
- **Synthesis Settings**: All disabled
- **Response Length**: Manual, 5-10 sentences

### Balanced (Some Context, Still Focused)
- **Engagement Mode**: REFLECT or EXPLORE
- **Max Temporal Connections**: 2
- **Max Similar Entries**: 5
- **Similarity Threshold**: 0.6
- **Synthesis Settings**: Selectively enabled (only if you want cross-domain connections)
- **Response Length**: Auto or Manual, 10-15 sentences

### Comprehensive (More Context, Higher Risk of Off-Topic)
- **Engagement Mode**: INTEGRATE (⚠️ Not recommended for direct questions)
- **Max Temporal Connections**: 3-5
- **Max Similar Entries**: 10-15
- **Similarity Threshold**: 0.55
- **Synthesis Settings**: All enabled
- **Response Length**: Auto or Manual, 15-20 sentences

---

## The Fix We Just Implemented

We added new rules to the LUMARA Master Prompt:

1. **ANSWER DIRECT QUESTIONS FIRST** - Answer the question before making connections
2. **STAY ON TOPIC** - Only reference past entries if directly relevant
3. **RELEVANCE FILTER** - Before referencing a past entry, ask: "Does this directly help answer the user's question?"
4. **Grounding After Answering** - For direct questions, answer first, then add context if relevant

However, **the response structure templates still need to be updated** to reflect this priority. Currently, they still put "Grounding → Temporal connection" before "Request fulfillment", which creates a conflict.

---

## Next Steps

1. **Update response structure templates** to be conditional based on question detection
2. **Test with recommended settings** to see if behavior improves
3. **Consider adding a "Question Mode"** toggle that automatically adjusts settings for direct questions

