import 'package:flutter/foundation.dart';
import 'rivet_service.dart';
import 'rivet_storage.dart';
import 'rivet_models.dart';
import 'rivet_telemetry.dart';

/// Singleton provider for RIVET service instances
/// Provides safe access to RIVET functionality with fallback handling
class RivetProvider {
  static final RivetProvider _instance = RivetProvider._internal();
  factory RivetProvider() => _instance;
  RivetProvider._internal();

  RivetService? _service;
  RivetBox? _storage;
  bool _initialized = false;
  String? _initError;

  /// Check if RIVET is available and properly initialized
  bool get isAvailable => _initialized && _service != null && _storage != null;

  /// Get the initialization error, if any
  String? get initError => _initError;

  /// Initialize RIVET service with user-specific state
  Future<void> initialize(String userId) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _storage = RivetBox();
      
      // Load existing state and event history for user
      final state = await _storage!.load(userId);
      final events = await _storage!.loadAllEvents(userId);
      
      // Create service with loaded state and event history
      _service = RivetService(initial: state);
      _service!.setEventHistory(events);
      
      _initialized = true;
      _initError = null;
      
      stopwatch.stop();
      
      // Log successful initialization
      RivetTelemetry().logInitialization(
        userId: userId,
        success: true,
        initTime: stopwatch.elapsed,
      );
      
      if (kDebugMode) {
        print('DEBUG: RIVET provider initialized for user $userId with ${events.length} events');
      }
    } catch (e) {
      stopwatch.stop();
      
      _initError = 'Failed to initialize RIVET: $e';
      _service = null;
      _storage = null;
      _initialized = false;
      
      // Log failed initialization
      RivetTelemetry().logInitialization(
        userId: userId,
        success: false,
        errorMessage: e.toString(),
        initTime: stopwatch.elapsed,
      );
      
      if (kDebugMode) {
        print('ERROR: RIVET provider initialization failed: $e');
      }
    }
  }

  /// Get RIVET service instance (null if not available)
  RivetService? get service => _service;

  /// Get RIVET storage instance (null if not available)
  RivetBox? get storage => _storage;

  /// Safely execute RIVET gating with fallback handling
  Future<RivetGateDecision?> safeIngest(RivetEvent event, String userId) async {
    final stopwatch = Stopwatch()..start();
    
    if (!isAvailable) {
      if (kDebugMode) {
        print('DEBUG: RIVET unavailable, skipping gate check');
      }
      return null;
    }

    try {
      // Apply event and get decision
      final decision = _service!.apply(event);
      
      // Save updated state
      await _storage!.save(userId, decision.stateAfter);
      
      // Save event for history
      await _storage!.saveEvent(userId, event);
      
      stopwatch.stop();
      
      // Log telemetry
      RivetTelemetry().logGateDecision(
        userId: userId,
        rivetEvent: event,
        decision: decision,
        processingTime: stopwatch.elapsed,
      );
      
      return decision;
    } catch (e) {
      stopwatch.stop();
      
      if (kDebugMode) {
        print('ERROR: RIVET gating failed: $e');
      }
      return null;
    }
  }

  /// Safely delete an event and recompute state
  Future<RivetGateDecision?> safeDelete(String eventId, String userId) async {
    final stopwatch = Stopwatch()..start();
    
    if (!isAvailable) {
      if (kDebugMode) {
        print('DEBUG: RIVET unavailable, skipping delete');
      }
      return null;
    }

    try {
      // Delete event and get decision
      final decision = _service!.delete(eventId);
      
      // Save updated state
      await _storage!.save(userId, decision.stateAfter);
      
      // Remove event from storage
      await _storage!.removeEvent(userId, eventId);
      
      stopwatch.stop();
      
      // Log telemetry
      RivetTelemetry().logRecompute(
        userId: userId,
        operation: 'delete',
        eventId: eventId,
        decision: decision,
        processingTime: stopwatch.elapsed,
      );
      
      return decision;
    } catch (e) {
      stopwatch.stop();
      
      if (kDebugMode) {
        print('ERROR: RIVET delete failed: $e');
      }
      return null;
    }
  }

  /// Safely edit an event and recompute state
  Future<RivetGateDecision?> safeEdit(RivetEvent updatedEvent, String userId) async {
    final stopwatch = Stopwatch()..start();
    
    if (!isAvailable) {
      if (kDebugMode) {
        print('DEBUG: RIVET unavailable, skipping edit');
      }
      return null;
    }

    try {
      // Edit event and get decision
      final decision = _service!.edit(updatedEvent);
      
      // Save updated state
      await _storage!.save(userId, decision.stateAfter);
      
      // Update event in storage
      await _storage!.updateEvent(userId, updatedEvent);
      
      stopwatch.stop();
      
      // Log telemetry
      RivetTelemetry().logRecompute(
        userId: userId,
        operation: 'edit',
        eventId: updatedEvent.eventId,
        decision: decision,
        processingTime: stopwatch.elapsed,
      );
      
      return decision;
    } catch (e) {
      stopwatch.stop();
      
      if (kDebugMode) {
        print('ERROR: RIVET edit failed: $e');
      }
      return null;
    }
  }

  /// Safely get current RIVET state
  Future<RivetState?> safeGetState(String userId) async {
    if (!isAvailable) {
      return null;
    }

    try {
      return await _storage!.load(userId);
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Failed to get RIVET state: $e');
      }
      return null;
    }
  }

  /// Safely clear user data
  Future<void> safeClearUserData(String userId) async {
    if (!isAvailable) {
      return;
    }

    try {
      await _storage!.clearUserData(userId);
      // Reset service state
      _service?.reset();
    } catch (e) {
      if (kDebugMode) {
        print('ERROR: Failed to clear RIVET data: $e');
      }
    }
  }

  /// Reset provider (for testing or user logout)
  void reset() {
    _service = null;
    _storage = null;
    _initialized = false;
    _initError = null;
  }
}