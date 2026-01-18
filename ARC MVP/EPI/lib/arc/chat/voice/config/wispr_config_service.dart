/// Wispr Config Service - API key management for Wispr Flow
/// 
/// Handles:
/// - Fetching API key from Firebase Functions
/// - Caching key for performance
/// - Checking user authentication
/// 
/// Architecture follows AssemblyAI service pattern for consistency

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';

class WisprConfigService {
  static final WisprConfigService _instance = WisprConfigService._internal();
  factory WisprConfigService() => _instance;
  WisprConfigService._internal();

  static WisprConfigService get instance => _instance;

  FirebaseFunctions? _functions;
  
  /// Get Firebase Functions instance (lazy initialization)
  /// Uses FirebaseService to get the correct instance with region support
  FirebaseFunctions get _functionsInstance {
    if (_functions == null) {
      try {
        // Use FirebaseService to get the properly configured instance
        _functions = FirebaseService.instance.getFunctions();
      } catch (e) {
        // Fallback to default instance if FirebaseService not ready
        debugPrint('WisprConfigService: Using default Firebase Functions instance (FirebaseService not ready)');
        _functions = FirebaseFunctions.instance;
      }
    }
    return _functions!;
  }
  
  // Cached API key
  String? _cachedApiKey;
  DateTime? _keyExpiry;
  
  // Key refresh buffer (refresh 5 minutes before expiry)
  static const Duration _refreshBuffer = Duration(minutes: 5);
  // Default expiry is 1 hour
  static const Duration _defaultExpiry = Duration(hours: 1);

  /// Check if Wispr is available (has valid API key)
  Future<bool> isAvailable() async {
    try {
      final key = await getApiKey();
      return key != null && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Alias for isAvailable (for compatibility)
  Future<bool> isConfigured() async => isAvailable();

  /// Get a valid Wispr API key
  /// Returns null if user is not eligible or key fetch fails
  Future<String?> getApiKey() async {
    // Check if cached key is still valid
    if (_cachedApiKey != null && _keyExpiry != null) {
      final now = DateTime.now();
      if (now.isBefore(_keyExpiry!.subtract(_refreshBuffer))) {
        return _cachedApiKey;
      }
    }
    
    // Fetch new key
    return await _fetchApiKey();
  }

  /// Fetch API key from Firebase
  Future<String?> _fetchApiKey() async {
    try {
      // Ensure Firebase is ready
      await FirebaseService.instance.ensureReady();
      
      // Check if user is authenticated
      final authService = FirebaseAuthService.instance;
      if (!authService.isSignedIn) {
        debugPrint('WisprConfigService: User not authenticated, cannot fetch API key');
        return null;
      }
      
      // Force refresh auth token to ensure it's valid
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        debugPrint('WisprConfigService: No current user, cannot fetch API key');
        return null;
      }
      
      // Refresh ID token to ensure it's valid for the function call
      try {
        await currentUser.getIdToken(true); // Force refresh
        debugPrint('WisprConfigService: Auth token refreshed');
      } catch (e) {
        debugPrint('WisprConfigService: Failed to refresh auth token: $e');
        return null;
      }
      
      debugPrint('WisprConfigService: Fetching API key from Firebase (user: ${currentUser.uid})...');
      
      final callable = _functionsInstance.httpsCallable('getWisprApiKey');
      final result = await callable.call<Map<String, dynamic>>();
      
      final data = result.data;
      
      // Parse response
      final apiKey = data['apiKey'] as String?;
      
      // Check if key is valid
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('WisprConfigService: No API key returned from function');
        _cachedApiKey = null;
        _keyExpiry = null;
        return null;
      }
      
      // Cache the key
      _cachedApiKey = apiKey;
      _keyExpiry = DateTime.now().add(_defaultExpiry);
      
      debugPrint('WisprConfigService: API key fetched successfully (expires: $_keyExpiry)');
      return _cachedApiKey;
      
    } on FirebaseFunctionsException catch (e) {
      debugPrint('WisprConfigService: Firebase error: ${e.code} - ${e.message}');
      if (e.code == 'not-found') {
        debugPrint('WisprConfigService: Function "getWisprApiKey" not found. '
            'This may mean the Firebase function is not deployed.');
      } else if (e.code == 'unauthenticated') {
        debugPrint('WisprConfigService: User not authenticated. '
            'Please sign in to use voice transcription.');
      }
      _cachedApiKey = null;
      _keyExpiry = null;
      return null;
    } catch (e) {
      debugPrint('WisprConfigService: Error fetching API key: $e');
      _cachedApiKey = null;
      _keyExpiry = null;
      return null;
    }
  }

  /// Clear cached key (call on logout)
  void clearCache() {
    _cachedApiKey = null;
    _keyExpiry = null;
    debugPrint('WisprConfigService: Cache cleared');
  }

  /// Force refresh API key
  Future<String?> refreshApiKey() async {
    _cachedApiKey = null;
    _keyExpiry = null;
    return await _fetchApiKey();
  }
}
