# LUMARA Notification & Reflective Query Integration Status

## ✅ Completed: Reflective Queries UI/UX

### What Works Now
1. **Query Detection**: Users can type natural language queries and they're automatically detected:
   - "Show me three times I handled something hard"
   - "What was I struggling with around this time last year?"
   - "Which themes have softened in the last six months?"

2. **UI Display**: 
   - Queries are processed through `LumaraAssistantCubit.sendMessage()`
   - Responses are formatted by `ReflectiveQueryFormatter`
   - Results appear in the existing `LumaraAssistantScreen` chat interface
   - Messages are displayed via `_buildMessageBubble()` widget

3. **Response Formatting**:
   - Structured, conversational responses
   - Phase-aware context
   - Safety filtering (trauma detection, night mode)
   - Follow-up suggestions

### Files Involved
- `lib/arc/chat/ui/lumara_assistant_screen.dart` - Main chat UI
- `lib/arc/chat/bloc/lumara_assistant_cubit.dart` - Query handling
- `lib/arc/chat/services/reflective_query_service.dart` - Query logic
- `lib/arc/chat/services/reflective_query_formatter.dart` - Response formatting

---

## ⚠️ Needs Integration: Notification System

### What Exists (Backend Services)
1. **Notification Service**: `LumaraNotificationService`
   - Time Echo reminder scheduling logic
   - Active Window reminder scheduling logic
   - Sleep protection and abstinence window management

2. **Supporting Services**:
   - `ActiveWindowDetector` - Learns user's reflection patterns
   - `SleepProtectionService` - Manages sleep/abstinence windows
   - `ThemeAnalysisService` - Tracks theme frequencies

3. **Data Models**: `notification_models.dart`
   - `TimeEchoNotification`
   - `ActiveWindowNotification`
   - `AbstinenceWindow`
   - `ActiveWindow`

### What's Missing

#### 1. Notification Plugin Integration
**Status**: Not integrated

**Needed**:
- Add `flutter_local_notifications` to `pubspec.yaml`
- Create notification scheduling bridge that:
  - Takes `TimeEchoNotification` and `ActiveWindowNotification` objects
  - Schedules them using the plugin
  - Handles notification taps to open LUMARA chat

**Suggested File**: `lib/arc/chat/services/notification_scheduler.dart`

```dart
class NotificationScheduler {
  // Bridge between LumaraNotificationService and flutter_local_notifications
  Future<void> scheduleTimeEcho(TimeEchoNotification notification);
  Future<void> scheduleActiveWindow(ActiveWindowNotification notification);
  Future<void> cancelAllNotifications();
}
```

#### 2. Notification Service Initialization
**Status**: Not initialized

**Needed**:
- Initialize `LumaraNotificationService` in app startup
- Schedule Time Echo reminders when journal entries are created
- Schedule Active Window reminders daily
- Check and reschedule as needed

**Suggested Location**: 
- `lib/arc/core/journal_capture_cubit.dart` - When entry is saved
- `lib/main/main.dart` or app initialization - Daily scheduling

#### 3. Notification Settings UI
**Status**: Not created

**Needed**:
- Add notification preferences to `LumaraSettingsScreen`
- Allow users to:
  - Enable/disable Time Echo reminders
  - Enable/disable Active Window reminders
  - Configure abstinence windows
  - View detected active windows
  - Adjust sleep window detection

**Suggested File**: `lib/arc/chat/ui/lumara_notification_settings_screen.dart`

#### 4. Notification Tap Handling
**Status**: Not implemented

**Needed**:
- Handle notification taps to:
  - Open LUMARA chat screen
  - Pre-populate query or show relevant content
  - Navigate to specific journal entry (for Time Echo)

**Suggested Location**: 
- `lib/main/main.dart` - Notification tap handler
- Deep linking support

---

## Implementation Checklist

### Phase 1: Basic Notification Integration
- [ ] Add `flutter_local_notifications` dependency
- [ ] Create `NotificationScheduler` service
- [ ] Initialize notification permissions
- [ ] Test basic notification display

### Phase 2: Time Echo Reminders
- [ ] Schedule Time Echo when journal entry created
- [ ] Handle notification tap → open chat with query
- [ ] Test all 7 intervals (1 month, 3 months, 6 months, 1 year, 2 years, 5 years, 10 years)

### Phase 3: Active Window Reminders
- [ ] Daily scheduling of active window reminders
- [ ] Respect sleep/abstinence windows
- [ ] Update active windows as patterns change

### Phase 4: Settings UI
- [ ] Create notification settings screen
- [ ] Add to `LumaraSettingsScreen` navigation
- [ ] Implement preference persistence
- [ ] Show detected active windows

### Phase 5: Polish
- [ ] Error handling for notification failures
- [ ] Background task for daily scheduling
- [ ] Notification grouping/categorization
- [ ] Analytics for notification effectiveness

---

## Current State Summary

✅ **Reflective Queries**: Fully functional through existing UI  
⚠️ **Notifications**: Backend services ready, but need plugin integration and UI

The reflective query system is production-ready and works through the existing chat interface. The notification system has all the logic but needs integration with a notification plugin and settings UI to be fully functional.

