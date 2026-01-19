/// Voice System Initializer
/// 
/// Initializes all voice components with proper configuration
/// - Sets up transcription (AssemblyAI primary, Apple On-Device fallback)
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
  /// 1. AssemblyAI (primary) - cloud-based, high accuracy, PRO/BETA tier
  /// 2. Apple On-Device (fallback) - always available, no network required
  Future<VoiceSessionService?> initialize() async {
    try {
      debugPrint('VoiceSystem: Initializing...');
      
      // 1. Create AssemblyAI service
      final assemblyAIService = AssemblyAIService.instance;
      
      // 2. Check if any backend is available
      final assemblyAIAvailable = await assemblyAIService.isAvailable();
      
      debugPrint('VoiceSystem: Backends available - '
          'AssemblyAI: $assemblyAIAvailable, Apple On-Device: always');
      
      // 3. Create unified transcription service
      final unifiedTranscription = UnifiedTranscriptionService(
        assemblyAIService: assemblyAIService,
      );
      
      // 4. Create audio capture
      final audioCapture = AudioCaptureService();
      
      // 5. Create endpoint detector
      final endpointDetector = SmartEndpointDetector();
      
      // 6. Create TTS client
      final tts = TtsJournalClient();
      
      // 7. Create session service
      final sessionService = VoiceSessionService(
        audioCapture: audioCapture,
        endpointDetector: endpointDetector,
        prism: prism,
        tts: tts,
        lumaraApi: lumaraApi,
        userId: userId,
        unifiedTranscription: unifiedTranscription,
      );
      
      debugPrint('VoiceSystem: Initialization complete '
          '(AssemblyAI primary, Apple On-Device fallback)');
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
    // Check if AssemblyAI (primary) is available for better experience
    try {
      final assemblyAI = AssemblyAIService.instance;
      final assemblyAIAvailable = await assemblyAI.isAvailable();
      debugPrint('VoiceSystem: canInitialize check - '
          'AssemblyAI: $assemblyAIAvailable, On-Device: always');
      return true; // Always return true since on-device is always available
    } catch (e) {
      debugPrint('VoiceSystem: canInitialize check failed: $e');
      return true; // Still return true - on-device should work
    }
  }
}
