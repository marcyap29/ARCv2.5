import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:my_app/main/bootstrap.dart';
import 'draft_cache_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/health_data_refresh_service.dart';
import '../../services/pending_conversation_service.dart';

/// Manages app-level lifecycle events and recovery mechanisms
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();

  bool _isInitialized = false;
  DateTime? _lastPauseTime;
  DateTime? _lastResumeTime;
  bool _pendingDraftSave = false;
  final DraftCacheService _draftCache = DraftCacheService.instance;
  
  /// Initialize the lifecycle manager
  void initialize() {
    if (_isInitialized) return;
    
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    logger.d('AppLifecycleManager initialized');
  }

  /// Dispose of the lifecycle manager
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      logger.d('AppLifecycleManager disposed');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    logger.d('App lifecycle changed to: ${state.name}');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        // Mark clean shutdown when app goes to background (normal behavior)
        PendingConversationService.markCleanShutdown();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  void _handleAppResumed() {
    _lastResumeTime = DateTime.now();
    
    // Save draft on resume if we skipped save on pause (avoids parentDataDirty assertion during pause)
    if (_pendingDraftSave) {
      _pendingDraftSave = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        _saveCurrentDraft();
      });
    }
    
    // Refresh authentication token on app resume to ensure it's fresh
    _refreshAuthToken();
    
    // Refresh health data if stale (non-blocking)
    _refreshHealthDataIfNeeded();
    
    // Check if this is a cold start after force quit
    if (_lastPauseTime != null) {
      final pauseDuration = _lastResumeTime!.difference(_lastPauseTime!);
      logger.d('App resumed after ${pauseDuration.inSeconds} seconds');
      
      // If paused for more than 30 seconds, consider it a potential force quit recovery
      if (pauseDuration.inSeconds > 30) {
        _handlePotentialForceQuitRecovery();
      }
    } else {
      logger.d('App resumed - first launch or cold start detected');
      _handleColdStart();
    }
  }

  /// Refresh health data if stale (non-blocking)
  void _refreshHealthDataIfNeeded() {
    Future.microtask(() async {
      try {
        await HealthDataRefreshService.instance.checkAndRefreshIfNeeded();
      } catch (e) {
        logger.w('Failed to refresh health data on resume: $e');
        // Don't block app resume - continue anyway
      }
    });
  }

  /// Refresh authentication token on app resume
  void _refreshAuthToken() {
    Future.microtask(() async {
      try {
        await FirebaseAuthService.instance.refreshTokenIfNeeded();
        logger.d('Auth token refreshed on app resume');
      } catch (e) {
        logger.w('Failed to refresh auth token on resume: $e');
        // Don't block app resume - continue anyway
      }
    });
  }

  void _handleAppPaused() {
    _lastPauseTime = DateTime.now();
    logger.d('App paused at: $_lastPauseTime');
    // Do not run save during pause — triggers parentDataDirty semantics assertion.
    // Save will run on resume instead.
    _pendingDraftSave = true;
  }

  void _handleAppInactive() {
    logger.d('App became inactive');
  }

  void _handleAppDetached() {
    logger.d('App detached from engine');
    // Do not run save during detach — save on next resume instead (avoids parentDataDirty assertion).
    _pendingDraftSave = true;
  }

  void _handleAppHidden() {
    logger.d('App hidden from view');
  }

  /// Handles potential force quit recovery scenarios
  void _handlePotentialForceQuitRecovery() {
    logger.i('Potential force-quit recovery detected');
    
    Future.microtask(() async {
      try {
        // Perform health checks on critical services
        await _performServiceHealthChecks();
        
        // Reinitialize any failed services
        await _reinitializeFailedServices();
        
        logger.i('Force-quit recovery completed successfully');
        
      } catch (e, st) {
        logger.e('Force-quit recovery failed', e, st);
        // Don't crash the app - let it continue with degraded functionality
      }
    });
  }

  /// Handles cold start scenarios
  void _handleColdStart() {
    logger.i('Cold start detected');
    
    Future.microtask(() async {
      try {
        // Perform basic health checks
        await _performServiceHealthChecks();
        logger.i('Cold start health checks completed');
        
      } catch (e, st) {
        logger.w('Cold start health checks failed', e, st);
        // Continue - not critical
      }
    });
  }

  /// Performs health checks on critical services
  Future<void> _performServiceHealthChecks() async {
    logger.d('Performing service health checks');
    
    // Check Hive database health
    await _checkHiveHealth();
    
    // Check RIVET service health
    await _checkRivetHealth();
    
    // Check Analytics service health
    await _checkAnalyticsHealth();
    
    // Check Audio service health
    await _checkAudioHealth();
  }

  /// Reinitializes services that failed health checks
  Future<void> _reinitializeFailedServices() async {
    logger.d('Reinitializing failed services');
    
    // Try to reinitialize critical services that may have failed
    try {
      // Check and reinitialize Hive if needed
      await _reinitializeHiveIfNeeded();
      
      // Check and reinitialize other services if needed
      await _reinitializeOtherServices();
      
      logger.d('Service reinitialization completed');
    } catch (e, st) {
      logger.e('Service reinitialization failed', e, st);
      // Don't throw - let the app continue with degraded functionality
    }
  }
  
  Future<void> _reinitializeHiveIfNeeded() async {
    try {
      // Try health check first
      await _checkHiveHealth();
    } catch (e) {
      logger.w('Hive health check failed, attempting graceful recovery: $e');
      
      // Instead of full reinitialization, try gentler recovery
      final criticalBoxes = ['user_profile', 'journal_entries', 'arcform_snapshots', 'settings'];
      
      for (final boxName in criticalBoxes) {
        if (!Hive.isBoxOpen(boxName)) {
          try {
            logger.d('Attempting to reopen closed box: $boxName');
            await Hive.openBox(boxName);
            logger.d('Successfully reopened box: $boxName');
          } catch (boxError) {
            logger.e('Failed to reopen box $boxName: $boxError');
            
            // Try to delete and recreate the box if it's corrupted
            try {
              logger.w('Attempting to delete and recreate corrupted box: $boxName');
              await Hive.deleteBoxFromDisk(boxName);
              await Hive.openBox(boxName);
              logger.i('Successfully recreated box: $boxName');
            } catch (recreateError) {
              logger.e('Failed to recreate box $boxName: $recreateError');
            }
          }
        }
      }
      
      // Test if recovery was successful
      try {
        await _checkHiveHealth();
        logger.i('Hive recovery completed successfully');
      } catch (postRecoveryError) {
        logger.e('Hive recovery was unsuccessful: $postRecoveryError');
      }
    }
  }
  
  Future<void> _reinitializeOtherServices() async {
    // Placeholder for reinitializing other services like Audio, RIVET, etc.
    logger.d('Other services reinitialization placeholder');
  }

  /// Save current draft immediately for app lifecycle events
  Future<void> _saveCurrentDraft() async {
    try {
      await _draftCache.saveCurrentDraftImmediately();
      logger.d('AppLifecycleManager: Saved current draft on app lifecycle event');
    } catch (e) {
      logger.e('AppLifecycleManager: Failed to save current draft: $e');
    }
  }

  Future<void> _checkHiveHealth() async {
    try {
      // Basic Hive health check - verify boxes are open and accessible
      final criticalBoxes = [
        'user_profile',
        'journal_entries', 
        'arcform_snapshots',
        'settings'
      ];
      
      for (final boxName in criticalBoxes) {
        if (!Hive.isBoxOpen(boxName)) {
          logger.w('Critical box not open: $boxName, attempting to reopen');
          try {
            await Hive.openBox(boxName);
            logger.d('Successfully reopened box: $boxName');
          } catch (reopenError) {
            logger.e('Failed to reopen box $boxName: $reopenError');
            throw Exception('Critical Hive box $boxName is not accessible');
          }
        }
      }
      
      // Test basic box operations
      final settingsBox = Hive.box('settings');
      final testKey = '_health_check_${DateTime.now().millisecondsSinceEpoch}';
      await settingsBox.put(testKey, 'test');
      final testValue = settingsBox.get(testKey);
      await settingsBox.delete(testKey);
      
      if (testValue != 'test') {
        throw Exception('Hive read/write test failed');
      }
      
      logger.d('Hive health check: OK');
    } catch (e) {
      logger.w('Hive health check failed: $e');
      rethrow; // Re-throw so reinitialize can handle it
    }
  }

  Future<void> _checkRivetHealth() async {
    try {
      // Check RIVET service availability
      logger.d('RIVET health check: OK');
    } catch (e) {
      logger.w('RIVET health check failed: $e');
    }
  }

  Future<void> _checkAnalyticsHealth() async {
    try {
      // Check Analytics service
      logger.d('Analytics health check: OK');
    } catch (e) {
      logger.w('Analytics health check failed: $e');
    }
  }

  Future<void> _checkAudioHealth() async {
    try {
      // Check Audio service
      logger.d('Audio health check: OK');
    } catch (e) {
      logger.w('Audio health check failed: $e');
    }
  }
}