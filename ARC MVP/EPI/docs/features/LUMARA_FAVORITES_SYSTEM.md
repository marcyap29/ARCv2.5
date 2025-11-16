# LUMARA Favorites Style System

**Status:** ✅ **COMPLETE**  
**Version:** 1.0  
**Date:** January 2025  
**Branch:** favorites

## Overview

The LUMARA Favorites system allows users to mark exemplary LUMARA replies as style exemplars. LUMARA adapts its response style, tone, structure, and depth based on these favorites while maintaining factual accuracy and proper SAGE/Echo interpretation.

## Features

### Core Functionality

- **25-Item Capacity**: Maximum of 25 favorites per user
- **Dual Interface Support**: Favorites can be added from both chat messages and journal reflection blocks
- **Style Adaptation**: LUMARA uses favorites to guide tone, structure, rhythm, and depth
- **Prompt Integration**: Favorites are automatically included in LUMARA prompts (3-7 examples per turn)

### User Interface

#### Adding Favorites

1. **Star Icon**: Every LUMARA answer displays a star icon next to copy/voiceover buttons
   - Empty star outline = not a favorite
   - Filled star (amber) = currently a favorite
   - Tap to toggle favorite status

2. **Manual Addition**: Use the + button in Favorites Management screen
   - Opens dialog with text field
   - Paste or type answer style you want LUMARA to learn from
   - Saves as manual favorite with `sourceType: 'manual'`

#### Managing Favorites

- **Settings Integration**: Dedicated "LUMARA Favorites" card in Settings
  - Located between "Import & Export" and "Privacy & Security"
  - Shows current count (X/25)
  - Opens Favorites Management screen

- **Favorites Management Screen**:
  - Explainer text: "With favorites, LUMARA can learn how to answer in a way that suits you."
  - View all favorites with timestamps
  - Expandable cards to view full text
  - Delete individual favorites
  - Clear all favorites option
  - + button to manually add favorites (when under 25 limit)
  - Empty state with instructions

#### Capacity Management

- **Capacity Popup**: When limit is reached, shows popup with:
  - Explanation that 25-item limit has been reached
  - Direct link to Favorites Management screen
  - Prevents addition until space is available

#### User Feedback

- **Standard Snackbar**: "Added to Favorites" / "Removed from Favorites"
- **First-Time Snackbar**: Enhanced snackbar on first favorite addition:
  - Explains that LUMARA will adapt style based on favorites
  - Includes "Manage" button to navigate to Settings

## Technical Implementation

### Data Layer

**Model**: `LumaraFavorite` (`lib/arc/chat/data/models/lumara_favorite.dart`)
- Hive storage with typeId 80
- Fields: id, content, timestamp, sourceId, sourceType, metadata
- Supports both chat messages and journal blocks

**Service**: `FavoritesService` (`lib/arc/chat/services/favorites_service.dart`)
- Singleton service for managing favorites
- Enforces 25-item limit
- Provides methods for add, remove, list, check status
- Tracks first-time snackbar state

### UI Components

**Chat Integration**: `lumara_assistant_screen.dart`
- Star icon in message action buttons (copy, voiceover, star, delete)
- Capacity popup and snackbar notifications

**Journal Integration**: `inline_reflection_block.dart`
- Star icon in reflection block actions (copy, voiceover, star, delete)
- Unique block IDs for tracking

**Management Screen**: `favorites_management_view.dart`
- Title font size: 24px
- Explainer text above favorites count
- + button for manual addition (when under 25 limit)
- Full list view with expandable cards
- Delete and clear all functionality
- Empty state with instructions

**Settings Integration**: `settings_view.dart`
- Favorites card with count display
- Navigation to management screen

### Prompt Integration

**Context Builder**: `lumara_context_builder.dart`
- Added `favoriteExamples` field
- Includes favorites in `[FAVORITE_STYLE_EXAMPLES_START]` section
- Randomly selects 3-7 examples per turn for variety

**LLM Adapter**: `llm_adapter.dart`
- Loads favorites before prompt assembly
- Passes favorites to context builder
- Integrated into full prompt path

## Style Adaptation Rules

### How Favorites Are Used

1. **Style Inference**: LUMARA analyzes favorites to infer:
   - Tone: warmth, directness, formality, emotional range
   - Structure: headings, lists, paragraphs, reasoning flow
   - Rhythm: pacing from observation to insight to recommendation
   - Depth: systems-level framing, pattern analysis, synthesis

2. **Content Application**:
   - First: Understand current question/entry
   - Second: Decide what content is needed
   - Third: Apply style from favorites

3. **Conflict Resolution**:
   - Prefer dominant patterns across favorites
   - Default to: clear, structured, concise, analytically grounded, emotionally respectful

### Style vs. Substance

- **Favorites guide style, not facts**: LUMARA maintains autonomy over factual reasoning
- **SAGE/Echo structure preserved**: Information architecture determined by SAGE/Echo
- **Favorites determine delivery**: Pacing, transitions, cognitive style from favorites
- **Merge approach**: Map content through Echo/SAGE, present using favorite style

## Capacity and Limits

- **Maximum**: 25 favorites per user
- **Enforcement**: Host system enforces limit at UI level
- **Prompt Inclusion**: Typically 3-7 examples per turn (randomized for variety)
- **Storage**: Hive-based persistent storage

## User Experience Flow

1. User reads LUMARA answer
2. User taps star icon to add/remove favorite
3. If not at capacity: Favorite added, snackbar shown
4. If at capacity: Popup shown with link to management
5. First-time users: Enhanced snackbar with explanation
6. LUMARA adapts style in future responses based on favorites
7. Users can also manually add favorites via + button in management screen

## Settings Integration

**Location**: Settings → LUMARA section (between Import/Export and Privacy)

**Card Details**:
- Title: "LUMARA Favorites"
- Subtitle: "Manage your favorite answer styles (X/25)"
- Icon: Star icon
- Action: Opens Favorites Management screen

## Future Enhancements

Potential improvements:
- Reordering favorites
- Tagging/categorizing favorites
- Favorite groups/themes
- Style preview before applying

## Export/Import Support

- **MCP Export**: LUMARA Favorites are fully exported in MCP bundles
- **MCP Import**: Favorites are imported and restored with duplicate checking
- **Capacity Limits**: Import respects 25-item limit and shows count in import summary
- **Metadata Preservation**: Source IDs, timestamps, and metadata are preserved

## Related Documentation

- [LUMARA System Architecture](../architecture/ARCHITECTURE_OVERVIEW.md#lumara)
- [LUMARA Prompt System](../implementation/LUMARA_ATTRIBUTION_WEIGHTED_CONTEXT_JAN_2025.md)
- [Settings Guide](../guides/EPI_MVP_Comprehensive_Guide.md#settings)

---

**Status**: ✅ Complete  
**Last Updated**: January 2025  
**Version**: 1.1

