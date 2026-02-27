/// AssemblyAI Service - Token management and eligibility checking
/// 
/// Handles:
/// - Fetching temporary tokens from Firebase
/// - Caching tokens with expiration
/// - Checking user eligibility for cloud transcription
library;

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../arc/chat/voice/transcription/transcription_provider.dart';
import 'firebase_service.dart';
import 'firebase_auth_service.dart';

class AssemblyAIService {
  static final AssemblyAIService _instance = AssemblyAIService._internal();
  factory AssemblyAIService() => _instance;
  AssemblyAIService._internal();

  static AssemblyAIService get instance => _instance;

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
        if (kDebugMode) print('AssemblyAIService: Using default Firebase Functions instance (FirebaseService not ready)');
        _functions = FirebaseFunctions.instance;
      }
    }
    return _functions!;
  }
  
  // Cached token
  String? _cachedToken;
  DateTime? _tokenExpiry;
  SttTier? _cachedTier;
  
  // Token refresh buffer (refresh 5 minutes before expiry)
  static const Duration _refreshBuffer = Duration(minutes: 5);

  /// Get user's STT tier
  Future<SttTier> getUserTier() async {
    // If we have a cached tier from a recent token request, use it
    if (_cachedTier != null) {
      return _cachedTier!;
    }
    
    // Otherwise, fetch a token to get the tier
    try {
      await _fetchToken();
      return _cachedTier ?? SttTier.free;
    } catch (e) {
      if (kDebugMode) print('AssemblyAIService: Error getting user tier: $e');
      return SttTier.free;
    }
  }

  /// Check if AssemblyAI is available for this user
  Future<bool> isAvailable() async {
    try {
      final tier = await getUserTier();
      return tier == SttTier.beta || tier == SttTier.pro;
    } catch (e) {
      return false;
    }
  }

  /// Get a valid AssemblyAI token
  /// Returns null if user is not eligible or token fetch fails
  Future<String?> getToken() async {
    // Check if cached token is still valid
    if (_cachedToken != null && _tokenExpiry != null) {
      final now = DateTime.now();
      if (now.isBefore(_tokenExpiry!.subtract(_refreshBuffer))) {
        return _cachedToken;
      }
    }
    
    // Fetch new token
    return await _fetchToken();
  }

  /// Fetch a new token from Firebase
  Future<String?> _fetchToken() async {
    try {
      // Ensure Firebase is ready
      await FirebaseService.instance.ensureReady();
      
      // Check if user is authenticated
      final authService = FirebaseAuthService.instance;
      if (!authService.isSignedIn) {
        if (kDebugMode) print('AssemblyAIService: User not authenticated, cannot fetch token');
        return null;
      }
      
      // Force refresh auth token to ensure it's valid
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        if (kDebugMode) print('AssemblyAIService: No current user, cannot fetch token');
        return null;
      }
      
      // Refresh ID token to ensure it's valid for the function call
      try {
        await currentUser.getIdToken(true); // Force refresh
        if (kDebugMode) print('AssemblyAIService: Auth token refreshed');
      } catch (e) {
        if (kDebugMode) print('AssemblyAIService: Failed to refresh auth token: $e');
        return null;
      }
      
      if (kDebugMode) print('AssemblyAIService: Fetching token from Firebase (user: ${currentUser.uid})...');
      
      final callable = _functionsInstance.httpsCallable('getAssemblyAIToken');
      final result = await callable.call<Map<String, dynamic>>();
      
      final data = result.data;
      
      // Parse response
      final token = data['token'] as String?;
      final expiresAt = data['expiresAt'] as int?;
      final tier = data['tier'] as String?;
      final eligibleForCloud = data['eligibleForCloud'] as bool? ?? false;
      
      // Update cached tier
      _cachedTier = _parseTier(tier);
      
      // Check eligibility
      if (!eligibleForCloud || token == null || token.isEmpty) {
        if (kDebugMode) print('AssemblyAIService: User not eligible for cloud STT (tier: $tier)');
        _cachedToken = null;
        _tokenExpiry = null;
        return null;
      }
      
      // Cache the token
      _cachedToken = token;
      _tokenExpiry = expiresAt != null 
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt)
          : DateTime.now().add(const Duration(hours: 1));
      
      if (kDebugMode) print('AssemblyAIService: Token fetched successfully (tier: $tier, expires: $_tokenExpiry)');
      return _cachedToken;
      
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) print('AssemblyAIService: Firebase error: ${e.code} - ${e.message}');
      if (e.code == 'not-found') {
        if (kDebugMode) {
          print('AssemblyAIService: Function "getAssemblyAIToken" not found. '
            'This may mean the Firebase function is not deployed. '
            'Falling back to on-device transcription.');
        }
      } else if (e.code == 'unauthenticated') {
        if (kDebugMode) {
          print('AssemblyAIService: User not authenticated. '
            'Please sign in to use cloud transcription. '
            'Falling back to on-device transcription.');
        }
      }
      _cachedToken = null;
      _tokenExpiry = null;
      return null;
    } catch (e) {
      if (kDebugMode) print('AssemblyAIService: Error fetching token: $e');
      _cachedToken = null;
      _tokenExpiry = null;
      return null;
    }
  }

  /// Parse tier string to enum
  SttTier _parseTier(String? tier) {
    switch (tier?.toUpperCase()) {
      case 'PRO':
        return SttTier.pro;
      case 'BETA':
        return SttTier.beta;
      case 'FREE':
      default:
        return SttTier.free;
    }
  }

  /// Clear cached token (call on logout or tier change)
  void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
    _cachedTier = null;
  }

  /// Force refresh token
  Future<String?> refreshToken() async {
    _cachedToken = null;
    _tokenExpiry = null;
    return await _fetchToken();
  }
}
