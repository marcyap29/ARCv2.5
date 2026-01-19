/// Voice System Initializer
/// 
/// Initializes all voice components with proper configuration
/// - Sets up transcription (Wispr optional, AssemblyAI primary, Apple On-Device fallback)
/// - Handles initialization failures gracefully

import 'package:flutter/foundation.dart';
import '../audio/audio_capture_service.dart';
import '../endpoint/smart_endpoint_detector.dart';
import '../transcription/unified_transcription_service.dart';
import '../../../internal/echo/prism_adapter.dart';
import '../voice_journal/tts_client.dart';
import '../../services/enhanced_lumara_api.dart';
import '../services/voice_session_service.dart';
import '../../../../services/assemblyai_service.dart';
import 'wispr_config_service.dart';

/// Voice System Initializer
/// 
/// Centralized initialization for all voice components
class VoiceSystemInitializer {
  final String userId;
  final EnhancedLumaraApi lumaraApi;
  final PrismAdapter prism;
  
  VoiceSystemInitializer({
    required this.userId,
    required this.lumaraApi,
    required this.prism,
  });
  
  /// Initialize voice system and return session service
  /// 
  /// Transcription backends (in order of preference):
  /// 1. Wispr Flow (if user has configured their own API key)
  /// 2. AssemblyAI (primary fallback) - cloud-based, high accuracy
  /// 3. Apple On-Device (final fallback) - always available, no network required
  Future<VoiceSessionService?> initialize() async {
    try {
      debugPrint('VoiceSystem: Initializing...');
      
      // 1. Check if user has Wispr API key configured
      final wisprConfigService = WisprConfigService.instance;
      final wisprAvailable = await wisprConfigService.isAvailable();
      
      // 2. Create AssemblyAI service
      final assemblyAIService = AssemblyAIService.instance;
      final assemblyAIAvailable = await assemblyAIService.isAvailable();
      
      debugPrint('VoiceSystem: Backends available - '
          'Wispr: $wisprAvailable, AssemblyAI: $assemblyAIAvailable, On-Device: always');
      
      // 3. Create unified transcription service
      // Note: No rate limiting for user-provided Wispr keys - users manage their own usage
      final unifiedTranscription = UnifiedTranscriptionService(
        assemblyAIService: assemblyAIService,
        wisprConfigService: wisprConfigService,
      );
      
      // 5. Create audio capture
      final audioCapture = AudioCaptureService();
      
      // 6. Create endpoint detector
      final endpointDetector = SmartEndpointDetector();
      
      // 7. Create TTS client
      final tts = TtsJournalClient();
      
      // 8. Create session service
      final sessionService = VoiceSessionService(
        audioCapture: audioCapture,
        endpointDetector: endpointDetector,
        prism: prism,
        tts: tts,
        lumaraApi: lumaraApi,
        userId: userId,
        unifiedTranscription: unifiedTranscription,
      );
      
      final primaryBackend = wisprAvailable ? 'Wispr (user key)' : 
          (assemblyAIAvailable ? 'AssemblyAI' : 'On-Device');
      debugPrint('VoiceSystem: Initialization complete '
          '(primary: $primaryBackend)');
      return sessionService;
      
    } catch (e) {
      debugPrint('VoiceSystem: Initialization error: $e');
      return null;
    }
  }
  
  /// Check if voice system can be initialized
  /// 
  /// Voice mode is always available because Apple On-Device is always available
  static Future<bool> canInitialize() async {
    // Voice mode is always available with Apple On-Device fallback
    try {
      final wisprConfigService = WisprConfigService.instance;
      final wisprAvailable = await wisprConfigService.isAvailable();
      
      final assemblyAI = AssemblyAIService.instance;
      final assemblyAIAvailable = await assemblyAI.isAvailable();
      
      debugPrint('VoiceSystem: canInitialize check - '
          'Wispr: $wisprAvailable, AssemblyAI: $assemblyAIAvailable, On-Device: always');
      return true; // Always return true since on-device is always available
    } catch (e) {
      debugPrint('VoiceSystem: canInitialize check failed: $e');
      return true; // Still return true - on-device should work
    }
  }
}
