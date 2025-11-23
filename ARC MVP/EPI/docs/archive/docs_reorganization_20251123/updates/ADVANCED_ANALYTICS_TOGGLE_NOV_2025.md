# Advanced Analytics Toggle & UI/UX Improvements

**Date:** November 15, 2025  
**Version:** 2.1.15  
**Status:** ✅ Complete

---

## Overview

This update introduces an Advanced Analytics toggle feature that allows users to show/hide the Health and Analytics tabs in the Insights section. The feature also includes significant UI/UX improvements to tab sizing, centering, and organization.

---

## Key Features

### Advanced Analytics Toggle

- **Settings Integration**: New "Advanced Analytics" section in Settings with toggle switch
- **Default State**: Advanced Analytics disabled by default (tabs hidden for simplified interface)
- **Visual Feedback**: Snackbar notifications when toggling to show/hide tabs
- **Preference Persistence**: Uses `SharedPreferences` to persist user preference
- **Automatic Refresh**: Insights view automatically updates when returning from Settings

### Sentinel Relocation

- **Moved to Analytics**: Sentinel moved from "Insights->Phase->Phase Analysis->Sentinel" to "Insights->Analytics" as its own expandable card
- **Better Organization**: Sentinel now grouped with other analytics tools (Patterns, AURORA, VEIL)
- **Removed Redundant Routes**: Removed "Phase->Analysis->Phase Analysis->Timeline" route (redundant with "Phase->Timeline")

### Tab UI/UX Improvements

#### Journal Tabs (Timeline|LUMARA|Settings)
- **Larger Icons**: Increased icon size from 16px to 20px for better visibility

#### Insights Tabs
**When Advanced Analytics OFF (2 tabs):**
- **Tabs**: Phase, Settings
- **Icon Size**: 24px (larger)
- **Font Size**: 17px (larger)
- **Font Weight**: w600 (bolder)
- **Tab Bar Height**: 48px (taller)
- **Label Padding**: 16px horizontal
- **Centering**: Automatically centered (not scrollable)

**When Advanced Analytics ON (4 tabs):**
- **Tabs**: Phase, Health, Analytics, Settings
- **Icon Size**: 16px (smaller)
- **Font Size**: 13px (smaller)
- **Font Weight**: normal
- **Tab Bar Height**: 36px (shorter)
- **Label Padding**: 8px horizontal
- **Scrollable**: Yes (if needed)

---

## Technical Implementation

### New Service

**`AdvancedAnalyticsPreferenceService`**
- Location: `lib/shared/ui/settings/advanced_analytics_preference_service.dart`
- Purpose: Manages Advanced Analytics visibility preference
- Storage: `SharedPreferences` with key `advanced_analytics_enabled`
- Default: `false` (tabs hidden)

### Modified Components

**`UnifiedInsightsView`**
- Changed from `SingleTickerProviderStateMixin` to `TickerProviderStateMixin` to allow TabController recreation
- Dynamic tab building based on `_advancedAnalyticsEnabled` preference
- Removed `didChangeDependencies()` and `didUpdateWidget()` to prevent infinite loops
- Improved TabController lifecycle management with post-frame callbacks
- Automatic preference reload when returning from Settings

**`SettingsView`**
- Added "Advanced Analytics" section with `SwitchListTile`
- Shows loading indicator while preference loads
- Displays snackbar notifications when toggling
- Automatically pops Settings screen when toggle changes to trigger refresh

**`PhaseAnalysisView`**
- Removed Timeline button and route (redundant)
- Removed Sentinel button and route (moved to Analytics)

**`AnalyticsPage`**
- Added Sentinel as new expandable card
- Consistent with other analytics tools (Patterns, AURORA, VEIL)

**`UnifiedJournalView`**
- Increased icon sizes from 16px to 20px for Timeline, LUMARA, and Settings tabs

---

## Bug Fixes

### Infinite Loop Fix
- **Issue**: Toggling Advanced Analytics caused infinite rebuild loop
- **Root Cause**: `didChangeDependencies()` and `didUpdateWidget()` calling `_loadPreference()` repeatedly
- **Solution**: Removed these lifecycle methods, only reload preference when returning from Settings

### Blank Screen Fix
- **Issue**: After toggling Advanced Analytics, screen went blank and tabs didn't update
- **Root Cause**: `SingleTickerProviderStateMixin` doesn't allow TabController recreation
- **Solution**: Changed to `TickerProviderStateMixin` and improved controller lifecycle with post-frame callbacks

### Insights Tab Not Displaying
- **Issue**: Insights tab showed blank screen on initial load
- **Root Cause**: TabController wasn't being created on initial load (only when preference changed)
- **Solution**: Ensure controller is always created on initial load or when preference changes

---

## Files Modified

- `lib/shared/ui/settings/advanced_analytics_preference_service.dart` - New service
- `lib/shared/ui/settings/settings_view.dart` - Added Advanced Analytics toggle
- `lib/shared/ui/insights/unified_insights_view.dart` - Dynamic tabs, TickerProviderStateMixin, lifecycle fixes
- `lib/shared/ui/journal/unified_journal_view.dart` - Increased icon sizes
- `lib/ui/phase/phase_analysis_view.dart` - Removed Timeline and Sentinel routes
- `lib/insights/analytics_page.dart` - Added Sentinel card

---

## User Experience

### Default Experience (Advanced Analytics OFF)
- Simplified interface with only Phase and Settings tabs
- Larger, more prominent tabs for easier navigation
- Cleaner, less cluttered interface

### Advanced Experience (Advanced Analytics ON)
- Full analytics suite with Health and Analytics tabs
- Compact tab layout to fit all options
- Sentinel accessible in Analytics page

### Toggle Behavior
- Toggle in Settings immediately updates Insights view
- Visual feedback via snackbar notifications
- Smooth transitions between 2-tab and 4-tab layouts
- No need to restart app or navigate away

---

## Testing Recommendations

1. **Toggle Functionality**: Verify tabs appear/disappear when toggling
2. **Preference Persistence**: Verify preference persists across app restarts
3. **Tab Sizing**: Verify correct icon/font sizes for both layouts
4. **Centering**: Verify 2-tab layout is properly centered
5. **Navigation**: Verify all routes work correctly after Sentinel relocation
6. **No Infinite Loops**: Verify no performance issues when toggling
7. **No Blank Screens**: Verify Insights always displays correctly

---

## Status

✅ **Complete** - All features implemented, tested, and working correctly

---

## Related Documentation

- [Changelog](../changelog/CHANGELOG.md) - Version 2.1.15
- [Status](../status/STATUS.md) - System status
- [Features Guide](../features/EPI_MVP_Features_Guide.md) - Feature documentation
- [Bug Tracker](../bugtracker/bug_tracker.md) - Bug resolutions

