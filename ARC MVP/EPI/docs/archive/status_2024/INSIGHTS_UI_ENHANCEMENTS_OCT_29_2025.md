# Insights Tab UI Enhancements (October 29, 2025)

**Status:** PRODUCTION READY ✅

## Overview
Enhanced the Insights tab with comprehensive information cards for Patterns, AURORA, and VEIL systems, providing users with detailed explanations of how each system works and what options are available.

## Changes

### 1. Enhanced "Your Patterns" Card
- **Added "How it works" section**: Explains how patterns are analyzed from journal entries
- **Added info chips**: 
  - Keywords: Explains repeated words from entries
  - Emotions: Explains positive, reflective, neutral emotions
- **Added comparison note**: Highlights that Patterns show what you write about, not your life stage (unlike Phase)
- **Visual improvements**: Better structured layout with nested containers and improved spacing

### 2. New AURORA Dashboard Card
- **Real-time circadian display**: Shows current time window, chronotype, and rhythm score
- **Visual rhythm coherence**: Progress bar with color coding (green for coherent, orange for moderate, red for fragmented)
- **Expandable "Available Options" section**: Shows all chronotypes and time windows when expanded
  - Available Chronotypes: Morning, Balanced, Evening with descriptions
  - Available Time Windows: Morning (6 AM-11 AM), Afternoon (11 AM-5 PM), Evening (5 PM-6 AM)
- **Current selection highlighting**: Active chronotype and time window highlighted with purple checkmarks
- **Activation info**: Explains how circadian state affects LUMARA behavior (e.g., "Evening + Fragmented: Commit blocks restricted")
- **Data sufficiency warning**: Shows warning if insufficient journal entries (< 8) for reliable analysis

### 3. Enhanced VEIL Card
- **Added expandable toggle**: "Show Available Options" / "Hide Details" button
- **Available Strategies section**: Lists all 5 strategies with current strategy highlighted
  - Exploration (Discovery ↔ Breakthrough)
  - Bridge (Transition ↔ Discovery)
  - Restore (Recovery ↔ Transition)
  - Stabilize (Consolidation ↔ Recovery)
  - Growth (Expansion ↔ Consolidation)
- **Available Response Blocks section**: Lists all 6 blocks with chip styling
  - Mirror - Reflect understanding
  - Orient - Provide direction
  - Nudge - Gentle encouragement
  - Commit - Action commitment
  - Safeguard - Safety first
  - Log - Record outcomes
- **Available Variants section**: Lists all 3 variants
  - Standard - Normal operation
  - :safe - Reduced activation, increased containment
  - :alert - Maximum safety, grounding focus
- **Current strategy highlighting**: Active strategy shown with checkmark icon

## Technical Implementation

### Files Modified
- `lib/shared/ui/home/home_view.dart`
  - Enhanced `_buildMiraGraphCard()` with detailed explanations and info chips
  - Added `_buildPatternInfoChip()` helper method
  - Integrated `AuroraCard` between Patterns and VEIL cards
  
- `lib/atlas/phase_detection/cards/aurora_card.dart` (New)
  - Created comprehensive AURORA dashboard card
  - Implements `CircadianProfileService` integration for real-time data
  - Expandable sections with conditional rendering
  - Consistent styling with VEIL card
  
- `lib/atlas/phase_detection/cards/veil_card.dart`
  - Added `_showMoreInfo` state variable for expandable sections
  - Added `_getAvailableStrategies()`, `_getAvailableBlocks()`, `_getAvailableVariants()` methods
  - Added `_buildAvailableStrategiesSection()`, `_buildAvailableBlocksSection()`, `_buildAvailableVariantsSection()` widgets
  - Consistent styling with AURORA card

## User Experience Impact

### Before
- Patterns card showed basic information only
- No AURORA dashboard in Insights tab
- VEIL card showed minimal information about current strategy only

### After
- Patterns card provides comprehensive explanation of how patterns work
- AURORA dashboard gives users full visibility into circadian intelligence
- VEIL card shows all available options and strategies
- Consistent expandable UI pattern across all cards
- Better user understanding of how each system affects their experience

## Design Consistency

All three cards now follow a consistent pattern:
- Expandable sections with toggle buttons
- Checkmarks for active/current selections
- Consistent color coding (purple for AURORA, blue for VEIL)
- Info sections with nested containers
- Responsive layout with proper spacing

## Status
✅ **PRODUCTION READY** - All enhancements implemented and tested

