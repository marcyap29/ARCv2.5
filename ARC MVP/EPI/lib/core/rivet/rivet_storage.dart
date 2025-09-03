import 'package:hive/hive.dart';
import 'rivet_models.dart';

/// Persistent storage for RIVET state and event history using Hive
class RivetBox {
  static const String boxName = 'rivet_state_v1';
  static const String eventsBoxName = 'rivet_events_v1';
  
  /// Load RIVET state for a specific user
  Future<RivetState> load(String userId) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      
      final box = Hive.box(boxName);
      final stateData = box.get(userId);
      
      if (stateData == null) {
        // Return initial state if no saved state exists
        return const RivetState(
          align: 0,
          trace: 0,
          sustainCount: 0,
          sawIndependentInWindow: false,
        );
      }
      
      return RivetState.fromJson(Map<String, dynamic>.from(stateData));
    } catch (e) {
      print('ERROR: Failed to load RIVET state for user $userId: $e');
      // Return safe default state on error
      return const RivetState(
        align: 0,
        trace: 0,
        sustainCount: 0,
        sawIndependentInWindow: false,
      );
    }
  }

  /// Save RIVET state for a specific user
  Future<void> save(String userId, RivetState state) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
      }
      
      final box = Hive.box(boxName);
      await box.put(userId, state.toJson());
      
      print('DEBUG: Saved RIVET state for user $userId: '
            'ALIGN=${state.align.toStringAsFixed(3)}, '
            'TRACE=${state.trace.toStringAsFixed(3)}, '
            'Sustain=${state.sustainCount}');
    } catch (e) {
      print('ERROR: Failed to save RIVET state for user $userId: $e');
      rethrow;
    }
  }

  /// Store a RIVET event for historical tracking (optional, for analytics)
  Future<void> saveEvent(String userId, RivetEvent event) async {
    try {
      if (!Hive.isBoxOpen(eventsBoxName)) {
        await Hive.openBox(eventsBoxName);
      }
      
      final box = Hive.box(eventsBoxName);
      final userEvents = (box.get(userId, defaultValue: <Map<String, dynamic>>[]) as List).cast<Map<String, dynamic>>();
      
      userEvents.add(event.toJson());
      
      // Keep only last 100 events to avoid unbounded growth
      if (userEvents.length > 100) {
        userEvents.removeAt(0);
      }
      
      await box.put(userId, userEvents);
    } catch (e) {
      print('ERROR: Failed to save RIVET event for user $userId: $e');
      // Don't rethrow - event storage is nice-to-have, not critical
    }
  }

  /// Load recent RIVET events for a user (for analytics/debugging)
  Future<List<RivetEvent>> loadEvents(String userId, {int limit = 10}) async {
    try {
      if (!Hive.isBoxOpen(eventsBoxName)) {
        await Hive.openBox(eventsBoxName);
      }
      
      final box = Hive.box(eventsBoxName);
      final userEvents = (box.get(userId, defaultValue: <Map<String, dynamic>>[]) as List).cast<Map<String, dynamic>>();
      
      final events = userEvents
          .cast<Map<String, dynamic>>()
          .map((data) => RivetEvent.fromJson(data))
          .toList();
      
      // Return most recent events first
      events.sort((a, b) => b.date.compareTo(a.date));
      
      return events.take(limit).toList();
    } catch (e) {
      print('ERROR: Failed to load RIVET events for user $userId: $e');
      return [];
    }
  }

  /// Get the most recent RIVET event for continuity checking
  Future<RivetEvent?> getLastEvent(String userId) async {
    try {
      final events = await loadEvents(userId, limit: 1);
      return events.isNotEmpty ? events.first : null;
    } catch (e) {
      print('ERROR: Failed to get last RIVET event for user $userId: $e');
      return null;
    }
  }

  /// Clear all RIVET data for a user (for privacy/reset)
  Future<void> clearUserData(String userId) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        final stateBox = Hive.box<Map>(boxName);
        await stateBox.delete(userId);
      }
      
      if (Hive.isBoxOpen(eventsBoxName)) {
        final eventsBox = Hive.box<Map>(eventsBoxName);
        await eventsBox.delete(userId);
      }
      
      print('DEBUG: Cleared all RIVET data for user $userId');
    } catch (e) {
      print('ERROR: Failed to clear RIVET data for user $userId: $e');
      rethrow;
    }
  }

  /// Initialize RIVET storage (call during app startup)
  static Future<void> initialize() async {
    try {
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(EvidenceSourceAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(RivetEventAdapter());
      }
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(RivetStateAdapter());
      }
      
      print('DEBUG: RIVET storage initialized');
    } catch (e) {
      print('ERROR: Failed to initialize RIVET storage: $e');
      rethrow;
    }
  }
}