/// Voice System Initializer
/// 
/// Initializes all voice components with proper configuration
/// - Loads API key from Firebase Cloud Functions or env vars
/// - Sets up all services with Wispr primary and AssemblyAI fallback
/// - Handles initialization failures gracefully

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../wispr/wispr_flow_service.dart';
import '../wispr/wispr_rate_limiter.dart';
import '../audio/audio_capture_service.dart';
import '../endpoint/smart_endpoint_detector.dart';
import '../transcription/unified_transcription_service.dart';
import '../../../internal/echo/prism_adapter.dart';
import '../voice_journal/tts_client.dart';
import '../../services/enhanced_lumara_api.dart';
import '../services/voice_session_service.dart';
import 'wispr_config_service.dart';
import 'env_config.dart';
import '../../../../services/assemblyai_service.dart';

/// Voice System Initializer
/// 
/// Centralized initialization for all voice components
class VoiceSystemInitializer {
  final String userId;
  final FirebaseFirestore firestore;
  final EnhancedLumaraApi lumaraApi;
  final PrismAdapter prism;
  
  WisprConfigService? _configService;
  
  VoiceSystemInitializer({
    required this.userId,
    required this.firestore,
    required this.lumaraApi,
    required this.prism,
  });
  
  /// Initialize voice system and return session service
  /// 
  /// Transcription backends (in order of preference):
  /// 1. Wispr Flow (primary) - if under rate limit
  /// 2. AssemblyAI (fallback) - if Wispr limit exceeded and user is PRO/BETA
  Future<VoiceSessionService?> initialize() async {
    try {
      debugPrint('VoiceSystem: Initializing...');
      
      // 1. Get Wispr API key (try Cloud Functions first, then env vars)
      String? apiKey = await _getApiKey();
      
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('VoiceSystem: No Wispr API key configured');
        // Can still try AssemblyAI only
      }
      
      // 2. Create Wispr service (may be null if no API key)
      WisprFlowService? wisprService;
      if (apiKey != null && apiKey.isNotEmpty) {
        final wisprConfig = WisprFlowConfig(
          apiKey: apiKey,
          useBinaryEncoding: false, // Use base64 for better compatibility
        );
        wisprService = WisprFlowService(config: wisprConfig);
      }
      
      // 3. Create rate limiter
      final rateLimiter = WisprRateLimiter(
        firestore: firestore,
        userId: userId,
        limits: const WisprUsageLimits(
          dailyMinutes: 60,
          hourlyMinutes: 15,
        ),
      );
      
      // 4. Create AssemblyAI service (fallback)
      final assemblyAIService = AssemblyAIService.instance;
      
      // 5. Check if either backend is available
      final wisprAvailable = wisprService != null;
      final assemblyAIAvailable = await assemblyAIService.isAvailable();
      
      if (!wisprAvailable && !assemblyAIAvailable) {
        debugPrint('VoiceSystem: No transcription backend available');
        return null;
      }
      
      debugPrint('VoiceSystem: Backends available - '
          'Wispr: $wisprAvailable, AssemblyAI: $assemblyAIAvailable');
      
      // 6. Create unified transcription service
      UnifiedTranscriptionService? unifiedTranscription;
      if (wisprService != null) {
        unifiedTranscription = UnifiedTranscriptionService(
          wisprService: wisprService,
          wisprRateLimiter: rateLimiter,
          assemblyAIService: assemblyAIService,
        );
      }
      
      // 7. Create audio capture
      final audioCapture = AudioCaptureService();
      
      // 8. Create endpoint detector
      final endpointDetector = SmartEndpointDetector();
      
      // 9. Create TTS client
      final tts = TtsJournalClient();
      
      // 10. Create session service
      // If Wispr is not available, we need to handle this differently
      if (wisprService == null) {
        debugPrint('VoiceSystem: Wispr not configured, voice mode requires Wispr API key');
        return null;
      }
      
      final sessionService = VoiceSessionService(
        wisprService: wisprService,
        rateLimiter: rateLimiter,
        audioCapture: audioCapture,
        endpointDetector: endpointDetector,
        prism: prism,
        tts: tts,
        lumaraApi: lumaraApi,
        userId: userId,
        unifiedTranscription: unifiedTranscription,
      );
      
      debugPrint('VoiceSystem: Initialization complete '
          '(Wispr primary, AssemblyAI fallback: $assemblyAIAvailable)');
      return sessionService;
      
    } catch (e) {
      debugPrint('VoiceSystem: Initialization error: $e');
      return null;
    }
  }
  
  /// Get API key from Cloud Functions or environment
  Future<String?> _getApiKey() async {
    // Try Cloud Functions first (production) - use singleton pattern
    try {
      _configService = WisprConfigService.instance;
      
      final cloudKey = await _configService!.getApiKey();
      if (cloudKey != null && cloudKey.isNotEmpty) {
        debugPrint('VoiceSystem: Using API key from Cloud Functions');
        return cloudKey;
      }
    } catch (e) {
      debugPrint('VoiceSystem: Cloud Functions not available: $e');
    }
    
    // Fallback to environment variables (development)
    final envKey = EnvConfig.wisprApiKey;
    if (envKey != null && envKey.isNotEmpty) {
      debugPrint('VoiceSystem: Using API key from environment');
      return envKey;
    }
    
    debugPrint('VoiceSystem: No API key found');
    return null;
  }
  
  /// Check if voice system can be initialized
  static Future<bool> canInitialize() async {
    // Check Cloud Functions (use singleton pattern like AssemblyAI)
    try {
      final configService = WisprConfigService.instance;
      if (await configService.isConfigured()) {
        return true;
      }
    } catch (e) {
      debugPrint('VoiceSystem: Cloud Functions check failed: $e');
    }
    
    // Check environment
    if (EnvConfig.isDevelopmentMode) {
      return true;
    }
    
    return false;
  }
}
