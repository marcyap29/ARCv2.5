/// Unified Transcription Service
/// 
/// Provides seamless fallback between Wispr Flow and AssemblyAI:
/// 1. Check Wispr rate limits
/// 2. If under limit → use Wispr (faster, lower latency)
/// 3. If limit exceeded → fall back to AssemblyAI (requires PRO/BETA tier)
/// 4. If both unavailable → return error

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../wispr/wispr_flow_service.dart';
import '../wispr/wispr_rate_limiter.dart';
import 'assemblyai_provider.dart';
import '../../../../services/assemblyai_service.dart';

/// Active transcription provider
enum TranscriptionBackend {
  wispr,
  assemblyAI,
  none,
}

/// Status of the unified transcription service
enum UnifiedTranscriptionStatus {
  idle,
  initializing,
  ready,
  listening,
  error,
}

/// Result of attempting to start transcription
class TranscriptionStartResult {
  final bool success;
  final TranscriptionBackend backend;
  final String? errorMessage;
  final bool wisprLimitExceeded;
  
  const TranscriptionStartResult({
    required this.success,
    required this.backend,
    this.errorMessage,
    this.wisprLimitExceeded = false,
  });
  
  factory TranscriptionStartResult.success(TranscriptionBackend backend) {
    return TranscriptionStartResult(
      success: true,
      backend: backend,
    );
  }
  
  factory TranscriptionStartResult.wisprLimited() {
    return const TranscriptionStartResult(
      success: false,
      backend: TranscriptionBackend.none,
      errorMessage: 'Wispr rate limit exceeded',
      wisprLimitExceeded: true,
    );
  }
  
  factory TranscriptionStartResult.error(String message) {
    return TranscriptionStartResult(
      success: false,
      backend: TranscriptionBackend.none,
      errorMessage: message,
    );
  }
}

/// Unified transcription service with automatic fallback
class UnifiedTranscriptionService {
  final WisprFlowService _wisprService;
  final WisprRateLimiter _wisprRateLimiter;
  final AssemblyAIService _assemblyAIService;
  
  UnifiedTranscriptionStatus _status = UnifiedTranscriptionStatus.idle;
  TranscriptionBackend _activeBackend = TranscriptionBackend.none;
  AssemblyAIProvider? _assemblyAIProvider;
  
  // Callbacks (unified interface)
  Function(String transcript, bool isFinal)? onTranscript;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  UnifiedTranscriptionService({
    required WisprFlowService wisprService,
    required WisprRateLimiter wisprRateLimiter,
    required AssemblyAIService assemblyAIService,
  })  : _wisprService = wisprService,
        _wisprRateLimiter = wisprRateLimiter,
        _assemblyAIService = assemblyAIService;
  
  /// Current status
  UnifiedTranscriptionStatus get status => _status;
  
  /// Currently active backend
  TranscriptionBackend get activeBackend => _activeBackend;
  
  /// Whether any transcription backend is connected
  bool get isConnected {
    if (_activeBackend == TranscriptionBackend.wispr) {
      return _wisprService.isConnected && _wisprService.isAuthenticated;
    } else if (_activeBackend == TranscriptionBackend.assemblyAI) {
      return _assemblyAIProvider?.isListening ?? false;
    }
    return false;
  }
  
  /// Initialize the service and determine best available backend
  /// 
  /// Priority:
  /// 1. Wispr (if under rate limit)
  /// 2. AssemblyAI (if user is eligible - PRO/BETA tier)
  /// 3. Error (no backend available)
  Future<TranscriptionStartResult> initialize() async {
    _status = UnifiedTranscriptionStatus.initializing;
    debugPrint('UnifiedTranscription: Initializing...');
    
    // Step 1: Check Wispr rate limits
    final wisprLimitResult = await _wisprRateLimiter.checkLimit();
    final wisprStats = await _wisprRateLimiter.getUsageStats();
    
    debugPrint('UnifiedTranscription: Wispr status - '
        'daily: ${wisprStats.dailyMinutesRemaining}min remaining, '
        'hourly: ${wisprStats.hourlyMinutesRemaining}min remaining');
    
    // Step 2: Try Wispr if under limit
    if (wisprLimitResult == RateLimitResult.allowed || 
        wisprLimitResult == RateLimitResult.approachingLimit) {
      debugPrint('UnifiedTranscription: Wispr available, attempting connection...');
      
      try {
        await _wisprService.connect();
        
        if (_wisprService.isConnected && _wisprService.isAuthenticated) {
          _activeBackend = TranscriptionBackend.wispr;
          _status = UnifiedTranscriptionStatus.ready;
          _setupWisprCallbacks();
          
          // Log if approaching limit
          if (wisprLimitResult == RateLimitResult.approachingLimit) {
            debugPrint('UnifiedTranscription: WARNING - Approaching Wispr limit. '
                'Daily: ${wisprStats.dailyMinutesRemaining}min, '
                'Hourly: ${wisprStats.hourlyMinutesRemaining}min remaining');
          }
          
          debugPrint('UnifiedTranscription: Using Wispr backend');
          return TranscriptionStartResult.success(TranscriptionBackend.wispr);
        }
      } catch (e) {
        debugPrint('UnifiedTranscription: Wispr connection failed: $e');
      }
    } else {
      debugPrint('UnifiedTranscription: Wispr rate limit exceeded '
          '(${wisprLimitResult.name})');
    }
    
    // Step 3: Fall back to AssemblyAI
    debugPrint('UnifiedTranscription: Attempting AssemblyAI fallback...');
    
    final assemblyAIAvailable = await _assemblyAIService.isAvailable();
    if (assemblyAIAvailable) {
      final token = await _assemblyAIService.getToken();
      
      if (token != null && token.isNotEmpty) {
        _assemblyAIProvider = AssemblyAIProvider(token: token);
        final initialized = await _assemblyAIProvider!.initialize();
        
        if (initialized) {
          _activeBackend = TranscriptionBackend.assemblyAI;
          _status = UnifiedTranscriptionStatus.ready;
          _setupAssemblyAICallbacks();
          
          debugPrint('UnifiedTranscription: Using AssemblyAI backend (fallback)');
          return TranscriptionStartResult.success(TranscriptionBackend.assemblyAI);
        } else {
          debugPrint('UnifiedTranscription: AssemblyAI failed to initialize');
        }
      } else {
        debugPrint('UnifiedTranscription: Could not get AssemblyAI token');
      }
    } else {
      debugPrint('UnifiedTranscription: AssemblyAI not available for user '
          '(requires PRO/BETA tier)');
    }
    
    // Step 4: No backend available
    _status = UnifiedTranscriptionStatus.error;
    _activeBackend = TranscriptionBackend.none;
    
    // Provide helpful error message
    final bool wisprLimited = wisprLimitResult == RateLimitResult.dailyLimitExceeded ||
        wisprLimitResult == RateLimitResult.hourlyLimitExceeded;
    
    if (wisprLimited) {
      final errorMsg = _wisprRateLimiter.getWarningMessage(wisprStats);
      debugPrint('UnifiedTranscription: No backend available - Wispr limited, '
          'AssemblyAI unavailable');
      return TranscriptionStartResult(
        success: false,
        backend: TranscriptionBackend.none,
        errorMessage: '$errorMsg AssemblyAI requires a PRO subscription.',
        wisprLimitExceeded: true,
      );
    }
    
    return TranscriptionStartResult.error(
      'Voice transcription unavailable. Please try again later.',
    );
  }
  
  /// Start listening with the active backend
  Future<bool> startListening() async {
    if (_activeBackend == TranscriptionBackend.none) {
      debugPrint('UnifiedTranscription: Cannot start - no backend initialized');
      return false;
    }
    
    _status = UnifiedTranscriptionStatus.listening;
    
    if (_activeBackend == TranscriptionBackend.wispr) {
      _wisprRateLimiter.startSession();
      await _wisprService.startSession();
      debugPrint('UnifiedTranscription: Started Wispr session');
      return true;
    } else if (_activeBackend == TranscriptionBackend.assemblyAI) {
      await _assemblyAIProvider?.startListening(
        onPartialResult: (segment) {
          onTranscript?.call(segment.text, false);
        },
        onFinalResult: (segment) {
          onTranscript?.call(segment.text, true);
        },
        onError: (error) {
          onError?.call(error);
        },
      );
      debugPrint('UnifiedTranscription: Started AssemblyAI session');
      return true;
    }
    
    return false;
  }
  
  /// Stop listening and get final transcript
  Future<void> stopListening() async {
    debugPrint('UnifiedTranscription: Stopping...');
    
    if (_activeBackend == TranscriptionBackend.wispr) {
      await _wisprService.commitSession();
      await _wisprRateLimiter.endSession();
    } else if (_activeBackend == TranscriptionBackend.assemblyAI) {
      await _assemblyAIProvider?.stopListening();
    }
    
    _status = UnifiedTranscriptionStatus.ready;
  }
  
  /// Send audio data to the active backend
  void sendAudioData(Uint8List audioData) {
    if (_activeBackend == TranscriptionBackend.wispr) {
      _wisprService.sendAudio(audioData);
    }
    // AssemblyAI handles its own audio capture internally
  }
  
  /// Disconnect and cleanup
  Future<void> disconnect() async {
    debugPrint('UnifiedTranscription: Disconnecting...');
    
    if (_activeBackend == TranscriptionBackend.wispr) {
      await _wisprService.disconnect();
    } else if (_activeBackend == TranscriptionBackend.assemblyAI) {
      await _assemblyAIProvider?.stopListening();
      _assemblyAIProvider = null;
    }
    
    _activeBackend = TranscriptionBackend.none;
    _status = UnifiedTranscriptionStatus.idle;
  }
  
  /// Setup Wispr callbacks to unified interface
  void _setupWisprCallbacks() {
    _wisprService.onTranscript = (wisprTranscript) {
      onTranscript?.call(wisprTranscript.text, wisprTranscript.isFinal);
    };
    
    _wisprService.onError = (error) {
      onError?.call(error);
    };
    
    _wisprService.onConnected = () {
      onConnected?.call();
    };
    
    _wisprService.onDisconnected = () {
      onDisconnected?.call();
    };
  }
  
  /// Setup AssemblyAI callbacks to unified interface
  void _setupAssemblyAICallbacks() {
    // AssemblyAI callbacks are set in startListening
  }
  
  /// Get usage warning message if approaching limits
  Future<String?> getUsageWarning() async {
    if (_activeBackend == TranscriptionBackend.wispr) {
      final stats = await _wisprRateLimiter.getUsageStats();
      if (stats.isApproachingLimit) {
        return _wisprRateLimiter.getWarningMessage(stats);
      }
    }
    return null;
  }
  
  /// Check if fallback to AssemblyAI is available
  Future<bool> isFallbackAvailable() async {
    return await _assemblyAIService.isAvailable();
  }
}
