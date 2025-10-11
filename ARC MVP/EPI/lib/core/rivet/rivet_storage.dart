import 'package:hive/hive.dart';
import 'rivet_models.dart';

/// Persistent storage for RIVET state and event history using Hive
/// Updated to support deterministic recompute with event log and checkpoints
class RivetBox {
  static const String boxName = 'rivet_state_v2';
  static const String eventsBoxName = 'rivet_events_v2';
  static const String checkpointsBoxName = 'rivet_checkpoints_v2';
  static const int checkpointInterval = 100; // Create checkpoint every 100 events
  
  /// Load complete event history for a user
  Future<List<RivetEvent>> loadEventHistory(String userId) async {
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
      
      // Sort by date to ensure deterministic order
      events.sort((a, b) => a.date.compareTo(b.date));
      
      return events;
    } catch (e) {
      print('ERROR: Failed to load RIVET event history for user $userId: $e');
      return [];
    }
  }

  /// Load the latest RIVET state for a user (computed from event history)
  Future<RivetState?> loadLatestState(String userId) async {
    try {
      final events = await loadEventHistory(userId);
      if (events.isEmpty) return null;
      
      // Get the latest state from the last event
      final lastEvent = events.last;
      return RivetState(
        align: 0, // Will be recomputed
        trace: 0, // Will be recomputed
        sustainCount: 0, // Will be recomputed
        sawIndependentInWindow: false, // Will be recomputed
        eventId: lastEvent.eventId,
        date: lastEvent.date,
        gateOpen: false, // Will be recomputed
      );
    } catch (e) {
      print('ERROR: Failed to load latest RIVET state for user $userId: $e');
      return null;
    }
  }

  /// Save complete event history for a user
  Future<void> saveEventHistory(String userId, List<RivetEvent> events) async {
    try {
      if (!Hive.isBoxOpen(eventsBoxName)) {
        await Hive.openBox(eventsBoxName);
      }
      
      final box = Hive.box(eventsBoxName);
      final eventData = events.map((event) => event.toJson()).toList();
      await box.put(userId, eventData);
      
      print('DEBUG: Saved ${events.length} RIVET events for user $userId');
    } catch (e) {
      print('ERROR: Failed to save RIVET event history for user $userId: $e');
      rethrow;
    }
  }

  /// Save a single event to the history
  Future<void> saveEvent(String userId, RivetEvent event) async {
    try {
      final events = await loadEventHistory(userId);
      events.add(event);
      await saveEventHistory(userId, events);
      
      // Create checkpoint if needed
      if (events.length % checkpointInterval == 0) {
        await _createCheckpoint(userId, events);
      }
    } catch (e) {
      print('ERROR: Failed to save RIVET event for user $userId: $e');
      rethrow;
    }
  }

  /// Delete an event from the history
  Future<void> deleteEvent(String userId, String eventId) async {
    try {
      final events = await loadEventHistory(userId);
      events.removeWhere((event) => event.eventId == eventId);
      await saveEventHistory(userId, events);
      
      print('DEBUG: Deleted RIVET event $eventId for user $userId');
    } catch (e) {
      print('ERROR: Failed to delete RIVET event for user $userId: $e');
      rethrow;
    }
  }

  /// Update an event in the history
  Future<void> updateEvent(String userId, RivetEvent updatedEvent) async {
    try {
      final events = await loadEventHistory(userId);
      final index = events.indexWhere((event) => event.eventId == updatedEvent.eventId);
      if (index != -1) {
        events[index] = updatedEvent;
        await saveEventHistory(userId, events);
        print('DEBUG: Updated RIVET event ${updatedEvent.eventId} for user $userId');
      } else {
        print('WARNING: Event ${updatedEvent.eventId} not found for user $userId');
      }
    } catch (e) {
      print('ERROR: Failed to update RIVET event for user $userId: $e');
      rethrow;
    }
  }

  /// Create a checkpoint for faster recompute
  Future<void> _createCheckpoint(String userId, List<RivetEvent> events) async {
    try {
      if (!Hive.isBoxOpen(checkpointsBoxName)) {
        await Hive.openBox(checkpointsBoxName);
      }
      
      final box = Hive.box(checkpointsBoxName);
      final checkpointId = '${userId}_${events.length}';
      
      // For now, just store the event count as a simple checkpoint
      // In a full implementation, you'd store the computed state values
      final checkpoint = RivetSnapshot(
        checkpointId: checkpointId,
        timestamp: DateTime.now(),
        eventCount: events.length,
        align: 0, // Would be computed from events
        trace: 0, // Would be computed from events
        sumEvidenceSoFar: 0, // Would be computed from events
      );
      
      await box.put(checkpointId, checkpoint.toJson());
      print('DEBUG: Created RIVET checkpoint $checkpointId for user $userId');
    } catch (e) {
      print('ERROR: Failed to create RIVET checkpoint for user $userId: $e');
      // Don't rethrow - checkpoints are optimization, not critical
    }
  }

  /// Load recent RIVET events for a user (for analytics/debugging)
  Future<List<RivetEvent>> loadRecentEvents(String userId, {int limit = 10}) async {
    try {
      final events = await loadEventHistory(userId);
      
      // Return most recent events first
      events.sort((a, b) => b.date.compareTo(a.date));
      
      return events.take(limit).toList();
    } catch (e) {
      print('ERROR: Failed to load recent RIVET events for user $userId: $e');
      return [];
    }
  }

  /// Get the most recent RIVET event for continuity checking
  Future<RivetEvent?> getLastEvent(String userId) async {
    try {
      final events = await loadEventHistory(userId);
      return events.isNotEmpty ? events.last : null;
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
      
      if (Hive.isBoxOpen(checkpointsBoxName)) {
        final checkpointsBox = Hive.box<Map>(checkpointsBoxName);
        // Delete all checkpoints for this user
        final keys = checkpointsBox.keys.where((key) => key.toString().startsWith('${userId}_')).toList();
        for (final key in keys) {
          await checkpointsBox.delete(key);
        }
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
      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(RivetSnapshotAdapter());
      }
      
      print('DEBUG: RIVET storage v2 initialized with event log and checkpoints');
    } catch (e) {
      print('ERROR: Failed to initialize RIVET storage: $e');
      rethrow;
    }
  }
}