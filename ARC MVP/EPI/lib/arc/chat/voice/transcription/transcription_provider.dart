/// Unified transcription provider interface for ARC
/// 
/// This abstraction allows seamless switching between:
/// - AssemblyAI cloud streaming (high accuracy)
/// - On-device transcription (offline fallback)

/// A single segment of transcribed text
class TranscriptSegment {
  final String text;
  final bool isFinal;
  final int? startMs;
  final int? endMs;
  final double? confidence;
  final DateTime timestamp;

  TranscriptSegment({
    required this.text,
    required this.isFinal,
    this.startMs,
    this.endMs,
    this.confidence,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'TranscriptSegment(text: "$text", isFinal: $isFinal, confidence: $confidence)';
}

/// Speech-to-text mode configuration
enum SttMode {
  /// Automatically select best available provider
  /// - BETA/PRO users: AssemblyAI first, fallback to on-device
  /// - FREE users: On-device only (future)
  auto,
  
  /// Force cloud transcription (AssemblyAI)
  /// Fails if not available or not eligible
  cloud,
  
  /// Force on-device transcription
  /// Always available, works offline
  local,
}

/// User subscription tier for STT access
enum SttTier {
  /// Free tier - on-device only (future default)
  free,
  
  /// Beta tier - cloud access during beta period
  beta,
  
  /// Pro tier - full cloud access ($30/month)
  pro,
}

/// Provider status
enum ProviderStatus {
  /// Provider is idle and ready
  idle,
  
  /// Provider is initializing
  initializing,
  
  /// Provider is actively listening
  listening,
  
  /// Provider is processing (between utterances)
  processing,
  
  /// Provider encountered an error
  error,
  
  /// Provider is not available
  unavailable,
}

/// Abstract interface for transcription providers
abstract class TranscriptionProvider {
  /// Human-readable name for this provider
  String get name;
  
  /// Whether this provider requires network connectivity
  bool get requiresNetwork;
  
  /// Current status of the provider
  ProviderStatus get status;
  
  /// Initialize the provider
  /// Returns true if initialization succeeded
  Future<bool> initialize();
  
  /// Start listening for speech
  /// 
  /// [onPartialResult] - Called with partial transcription as user speaks
  /// [onFinalResult] - Called when a final segment is ready
  /// [onError] - Called when an error occurs
  /// [onSoundLevel] - Called with audio level (0.0 to 1.0)
  Future<void> startListening({
    required Function(TranscriptSegment segment) onPartialResult,
    required Function(TranscriptSegment segment) onFinalResult,
    Function(String error)? onError,
    Function(double level)? onSoundLevel,
  });
  
  /// Stop listening and get final transcript
  Future<void> stopListening();
  
  /// Cancel listening without final result
  Future<void> cancelListening();
  
  /// Check if provider is currently listening
  bool get isListening;
  
  /// Check if provider is available (can be used)
  Future<bool> isAvailable();
  
  /// Dispose of provider resources
  Future<void> dispose();
}

/// Result from provider availability check
class ProviderAvailability {
  final bool isAvailable;
  final String? reason;
  final bool canFallback;

  ProviderAvailability({
    required this.isAvailable,
    this.reason,
    this.canFallback = true,
  });
}
