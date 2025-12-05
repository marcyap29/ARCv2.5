// lib/services/firebase_service.dart
// Firebase initialization and readiness service

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service to manage Firebase initialization and ensure readiness.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static FirebaseService get instance => _instance;

  bool _isReady = false;
  bool _initializing = false;
  FirebaseApp? _app;
  Completer<bool>? _readyCompleter;

  final String _functionsRegion = const String.fromEnvironment(
    'FIREBASE_FUNCTIONS_REGION',
    defaultValue: 'us-central1',
  );

  bool get isReady => _isReady;

  Future<bool> waitForReady({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isReady) return true;
    try {
      if (_readyCompleter == null) return false;
      return await _readyCompleter!.future.timeout(timeout);
    } on TimeoutException {
      print('FirebaseService: Timeout waiting for Firebase to be ready');
      return false;
    }
  }

  Future<bool> initialize() async {
    if (_isReady) return true;
    if (_initializing) return waitForReady();

    if (_readyCompleter == null || (_readyCompleter?.isCompleted ?? false) && !_isReady) {
      _readyCompleter = Completer<bool>();
    }
    _initializing = true;

    try {
      await _initFirebaseApp();
      await _testServices();

      _isReady = true;
      if (!(_readyCompleter?.isCompleted ?? true)) {
        _readyCompleter!.complete(true);
      }
      print('FirebaseService: Firebase services are ready');
      return true;
    } catch (e) {
      print('FirebaseService: Failed to initialize Firebase: $e');
      if (!(_readyCompleter?.isCompleted ?? true)) {
        _readyCompleter!.complete(false);
      }
      return false;
    } finally {
      _initializing = false;
    }
  }

  Future<void> _initFirebaseApp() async {
    if (Firebase.apps.isNotEmpty) {
      _app = Firebase.app();
      print('FirebaseService: Using existing Firebase app');
      return;
    }

    try {
      _app = await Firebase.initializeApp();
      print('FirebaseService: Firebase initialized with platform config');
      return;
    } catch (e) {
      print('FirebaseService: Default platform config initialization failed: $e');
    }

    final envOptions = _loadEnvOptions();
    if (envOptions != null) {
      print('FirebaseService: Initializing Firebase with env options (dart-define)');
      _app = await Firebase.initializeApp(options: envOptions);
      return;
    }

    throw Exception(
      'Firebase configuration missing. Add GoogleService-Info.plist / google-services.json, '
      'or provide dart-define FIREBASE_API_KEY/FIREBASE_APP_ID/FIREBASE_PROJECT_ID/'
      'FIREBASE_MESSAGING_SENDER_ID (optional: FIREBASE_STORAGE_BUCKET, '
      'FIREBASE_DATABASE_URL, FIREBASE_MEASUREMENT_ID, FIREBASE_FUNCTIONS_REGION).',
    );
  }

  FirebaseOptions? _loadEnvOptions() {
    final apiKey = const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    final appId = const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
    final projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    final messagingSenderId = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');

    if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty || messagingSenderId.isEmpty) {
      print('FirebaseService: Env options not found or incomplete (apiKey/appId/projectId/messagingSenderId)');
      return null;
    }

    final storageBucket = const String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
    final databaseUrl = const String.fromEnvironment('FIREBASE_DATABASE_URL', defaultValue: '');
    final measurementId = const String.fromEnvironment('FIREBASE_MEASUREMENT_ID', defaultValue: '');

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }

  Future<void> _testServices() async {
    if (_app == null) throw Exception('Firebase app not initialized');

    try {
      FirebaseAuth.instanceFor(app: _app!);
      print('FirebaseService: Auth service ready');
    } catch (e) {
      print('FirebaseService: Auth service not ready: $e');
    }

    try {
      FirebaseFunctions.instanceFor(app: _app!, region: _functionsRegion);
      print('FirebaseService: Functions service ready');
    } catch (e) {
      print('FirebaseService: Functions service not ready: $e');
      throw e;
    }
  }

  FirebaseApp getApp() {
    if (!_isReady || _app == null) {
      throw Exception('Firebase not ready - call initialize() and wait for readiness');
    }
    return _app!;
  }

  FirebaseAuth getAuth() {
    final app = getApp();
    return FirebaseAuth.instanceFor(app: app);
  }

  FirebaseFunctions getFunctions() {
    final app = getApp();
    return FirebaseFunctions.instanceFor(app: app, region: _functionsRegion);
  }

  Future<bool> ensureReady() async {
    if (_isReady) return true;
    try {
      final ready = await initialize();
      if (!ready) {
        print('FirebaseService: ensureReady -> initialization returned false');
      }
      return ready;
    } catch (e) {
      print('FirebaseService: Failed to ensure readiness: $e');
      return false;
    }
  }
}
