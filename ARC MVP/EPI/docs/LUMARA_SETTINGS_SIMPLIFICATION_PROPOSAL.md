# LUMARA Settings Simplification Proposal

## Current Settings (Too Many!)

### Main Settings Screen
1. **LUMARA Persona** (5 options: Auto, Companion, Strategist, Challenger, Therapist)
2. **Response Length** (Auto/Manual toggle + sentence count slider + sentences per paragraph slider)
3. **Therapeutic Depth Level** (1-3 slider)
4. **Web Access** (toggle)
5. **Voiceover** (toggle)

### Advanced Settings Screen
**LUMARA Engine Section:**
1. **Memory Lookback** (1-10 years slider)
2. **Matching Precision** (0.1-1.0 slider, 18 divisions)
3. **Max Similar Entries** (1-20 slider)
4. **Include Media** (toggle)

**Engagement Discipline Section:**
5. **Engagement Mode** (3 options: REFLECT, EXPLORE, INTEGRATE)
6. **Cross-Domain Synthesis** (4 separate toggles):
   - Faith ↔ Work
   - Relationship ↔ Work
   - Health ↔ Emotional
   - Creative ↔ Intellectual
7. **Max Temporal Connections** (1-5 slider)
8. **Max Questions** (0-3 slider)
9. **Allow Therapeutic Language** (toggle)
10. **Allow Prescriptive Guidance** (toggle)

**Total: 15+ settings affecting LUMARA behavior!**

---

## Problem

Too many settings create:
- **Decision paralysis** - Users don't know what to change
- **Confusion** - Settings interact in complex ways
- **Maintenance burden** - Hard to test all combinations
- **Poor UX** - Overwhelming interface

---

## Proposed Simplified Structure

### Keep in Main Settings (User-Facing)
1. **LUMARA Persona** ✅ Keep (clear, important)
2. **Response Length** ✅ Keep (users understand this)
3. **Memory Focus** ⭐ NEW: Single preset selector replacing 3 sliders

### Move to Advanced (Power Users Only)
4. **Engagement Mode** (keep but simplify)
5. **Therapeutic Settings** (combine into one section)

### Remove or Auto-Determine
6. **Max Temporal Connections** → Auto-determine based on Engagement Mode
7. **Max Questions** → Auto-determine based on Engagement Mode
8. **Cross-Domain Synthesis** → Simplify to single toggle or remove
9. **Matching Precision** → Combine into Memory Focus preset
10. **Memory Lookback** → Combine into Memory Focus preset
11. **Max Similar Entries** → Combine into Memory Focus preset

---

## New "Memory Focus" Preset System

Replace these 3 sliders:
- Memory Lookback (1-10 years)
- Matching Precision (0.1-1.0)
- Max Similar Entries (1-20)

With a single preset selector:

### **Focused** (Default)
- Lookback: 2 years
- Precision: 0.7 (high)
- Max Entries: 3
- **Use when**: You want concise, on-topic responses
- **Best for**: Direct questions, focused conversations

### **Balanced** (Recommended)
- Lookback: 5 years
- Precision: 0.55 (medium)
- Max Entries: 5
- **Use when**: You want good context without overwhelming
- **Best for**: Most users, general journaling

### **Comprehensive**
- Lookback: 10 years
- Precision: 0.4 (low)
- Max Entries: 10
- **Use when**: You want deep historical context
- **Best for**: Long-term pattern analysis, deep reflection

### **Custom** (Advanced)
- Shows the 3 sliders (only if user selects this)
- For power users who want fine control

---

## Simplified Engagement Settings

### Current (Complex):
- Engagement Mode (3 options)
- Max Temporal Connections (1-5 slider)
- Max Questions (0-3 slider)
- 4 Cross-Domain Synthesis toggles
- Allow Therapeutic Language (toggle)
- Allow Prescriptive Guidance (toggle)

### Proposed (Simple):
- **Engagement Mode** (3 options: REFLECT, EXPLORE, INTEGRATE)
  - Auto-determines Max Temporal Connections and Max Questions based on mode
  - REFLECT: 1 connection, 0 questions
  - EXPLORE: 2 connections, 1 question
  - INTEGRATE: 3 connections, 1-2 questions

- **Cross-Domain Connections** (Single toggle)
  - "Allow LUMARA to connect themes across different life areas"
  - Replaces 4 separate toggles

- **Therapeutic Language** (Single toggle)
  - "Allow therapy-style phrasing"
  - Combines therapeutic language and prescriptive guidance

---

## Final Simplified Structure

### Main Settings Screen
1. **LUMARA Persona** (5 options)
2. **Response Length** (Auto/Manual + sliders)
3. **Memory Focus** (4 presets: Focused, Balanced, Comprehensive, Custom)

### Advanced Settings Screen
1. **Engagement Mode** (3 options with auto-determined limits)
2. **Cross-Domain Connections** (single toggle)
3. **Therapeutic Language** (single toggle)
4. **Include Media** (toggle)
5. **Web Access** (toggle)

**Total: ~8 settings instead of 15+**

---

## Implementation Plan

1. **Create Memory Focus Preset System**
   - Add `MemoryFocusPreset` enum (Focused, Balanced, Comprehensive, Custom)
   - Update `LumaraReflectionSettingsService` to support presets
   - Map presets to underlying values (lookback, precision, maxMatches)

2. **Simplify Engagement Settings**
   - Auto-determine Max Temporal Connections and Max Questions from Engagement Mode
   - Replace 4 synthesis toggles with single toggle
   - Combine therapeutic language settings

3. **Update UI**
   - Replace 3 sliders with preset selector in main settings
   - Show sliders only when "Custom" is selected
   - Simplify Advanced Settings section

4. **Migration**
   - Detect current settings and map to closest preset
   - Preserve custom settings if user has non-default values

---

## Benefits

✅ **Simpler UX** - Fewer decisions, clearer purpose
✅ **Better Defaults** - Presets are tested combinations
✅ **Less Confusion** - Settings don't conflict
✅ **Easier Maintenance** - Fewer combinations to test
✅ **Power Users Still Supported** - Custom option available

---

## User Feedback Questions

1. Should we keep all 4 synthesis toggles or combine into one?
2. Should Therapeutic Language and Prescriptive Guidance be separate or combined?
3. Are the 3 Memory Focus presets (Focused, Balanced, Comprehensive) sufficient?
4. Should Engagement Mode auto-determine Max Temporal Connections and Max Questions, or keep them separate?

