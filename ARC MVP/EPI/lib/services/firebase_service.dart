// lib/services/firebase_service.dart
// Firebase initialization and readiness service

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service to manage Firebase initialization and ensure readiness
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static FirebaseService get instance => _instance;

  bool _isReady = false;
  FirebaseApp? _app;
  final Completer<bool> _readyCompleter = Completer<bool>();

  /// Check if Firebase is ready for use
  bool get isReady => _isReady;

  /// Wait for Firebase to be ready
  Future<bool> waitForReady({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isReady) return true;

    try {
      return await _readyCompleter.future.timeout(timeout);
    } on TimeoutException {
      print('FirebaseService: Timeout waiting for Firebase to be ready');
      return false;
    }
  }

  /// Initialize Firebase and mark as ready
  Future<void> initialize() async {
    if (_isReady) return;

    try {
      // Get or initialize Firebase app
      if (Firebase.apps.isEmpty) {
        _app = await Firebase.initializeApp();
        print('FirebaseService: Firebase initialized successfully');
      } else {
        _app = Firebase.app();
        print('FirebaseService: Using existing Firebase app');
      }

      // Test service readiness
      await _testServices();

      _isReady = true;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete(true);
      }
      print('FirebaseService: Firebase services are ready');

    } catch (e) {
      print('FirebaseService: Failed to initialize Firebase: $e');
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete(false);
      }
      rethrow;
    }
  }

  /// Test Firebase services readiness
  Future<void> _testServices() async {
    if (_app == null) throw Exception('Firebase app not initialized');

    // Test Auth service
    try {
      FirebaseAuth.instanceFor(app: _app!);
      print('FirebaseService: Auth service ready');
    } catch (e) {
      print('FirebaseService: Auth service not ready: $e');
    }

    // Test Functions service
    try {
      FirebaseFunctions.instanceFor(app: _app!);
      print('FirebaseService: Functions service ready');
    } catch (e) {
      print('FirebaseService: Functions service not ready: $e');
      throw e; // Functions are critical for LUMARA
    }
  }

  /// Get Firebase app instance (throws if not ready)
  FirebaseApp getApp() {
    if (!_isReady || _app == null) {
      throw Exception('Firebase not ready - call initialize() and wait for readiness');
    }
    return _app!;
  }

  /// Get Firebase Auth instance (throws if not ready)
  FirebaseAuth getAuth() {
    final app = getApp();
    return FirebaseAuth.instanceFor(app: app);
  }

  /// Get Firebase Functions instance (throws if not ready)
  FirebaseFunctions getFunctions() {
    final app = getApp();
    return FirebaseFunctions.instanceFor(app: app);
  }

  /// Ensure Firebase is ready before making calls
  Future<bool> ensureReady() async {
    if (_isReady) return true;

    try {
      await initialize();
      return true;
    } catch (e) {
      print('FirebaseService: Failed to ensure readiness: $e');
      return false;
    }
  }
}