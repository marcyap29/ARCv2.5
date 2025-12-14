/// AssemblyAI Service - Token management and eligibility checking
/// 
/// Handles:
/// - Fetching temporary tokens from Firebase
/// - Caching tokens with expiration
/// - Checking user eligibility for cloud transcription

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import '../arc/chat/voice/transcription/transcription_provider.dart';

class AssemblyAIService {
  static final AssemblyAIService _instance = AssemblyAIService._internal();
  factory AssemblyAIService() => _instance;
  AssemblyAIService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
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
      print('AssemblyAIService: Error getting user tier: $e');
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
      print('AssemblyAIService: Fetching token from Firebase...');
      
      final callable = _functions.httpsCallable('getAssemblyAIToken');
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
        print('AssemblyAIService: User not eligible for cloud STT (tier: $tier)');
        _cachedToken = null;
        _tokenExpiry = null;
        return null;
      }
      
      // Cache the token
      _cachedToken = token;
      _tokenExpiry = expiresAt != null 
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt)
          : DateTime.now().add(const Duration(hours: 1));
      
      print('AssemblyAIService: Token fetched successfully (tier: $tier, expires: $_tokenExpiry)');
      return _cachedToken;
      
    } on FirebaseFunctionsException catch (e) {
      print('AssemblyAIService: Firebase error: ${e.code} - ${e.message}');
      _cachedToken = null;
      _tokenExpiry = null;
      return null;
    } catch (e) {
      print('AssemblyAIService: Error fetching token: $e');
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
