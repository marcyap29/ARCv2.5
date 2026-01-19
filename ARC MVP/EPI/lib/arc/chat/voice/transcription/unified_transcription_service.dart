/// Unified Transcription Service
/// 
/// Provides seamless fallback between transcription backends:
/// 1. AssemblyAI (primary) - cloud-based, high accuracy, requires PRO/BETA tier
/// 2. Apple On-Device (fallback) - always available, no network required
/// 
/// Fallback chain: AssemblyAI → Apple On-Device

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'assemblyai_provider.dart';
import 'ondevice_provider.dart';
import 'transcription_provider.dart';
import '../../../../services/assemblyai_service.dart';

/// Active transcription provider
enum TranscriptionBackend {
  assemblyAI,
  appleOnDevice,
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
  
  const TranscriptionStartResult({
    required this.success,
    required this.backend,
    this.errorMessage,
  });
  
  factory TranscriptionStartResult.success(TranscriptionBackend backend) {
    return TranscriptionStartResult(
      success: true,
      backend: backend,
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
/// 
/// Fallback chain: AssemblyAI → Apple On-Device
class UnifiedTranscriptionService {
  final AssemblyAIService _assemblyAIService;
  
  UnifiedTranscriptionStatus _status = UnifiedTranscriptionStatus.idle;
  TranscriptionBackend _activeBackend = TranscriptionBackend.none;
  AssemblyAIProvider? _assemblyAIProvider;
  OnDeviceTranscriptionProvider? _onDeviceProvider;
  
  // Callbacks (unified interface)
  Function(String transcript, bool isFinal)? onTranscript;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  UnifiedTranscriptionService({
    required AssemblyAIService assemblyAIService,
  }) : _assemblyAIService = assemblyAIService;
  
  /// Current status
  UnifiedTranscriptionStatus get status => _status;
  
  /// Currently active backend
  TranscriptionBackend get activeBackend => _activeBackend;
  
  /// Whether any transcription backend is connected/ready
  bool get isConnected {
    switch (_activeBackend) {
      case TranscriptionBackend.assemblyAI:
        return _assemblyAIProvider?.isListening ?? false;
      case TranscriptionBackend.appleOnDevice:
        return _onDeviceProvider?.status == ProviderStatus.idle ||
               _onDeviceProvider?.status == ProviderStatus.listening;
      case TranscriptionBackend.none:
        return false;
    }
  }
  
  /// Get human-readable name for active backend
  String get activeBackendName {
    switch (_activeBackend) {
      case TranscriptionBackend.assemblyAI:
        return 'AssemblyAI';
      case TranscriptionBackend.appleOnDevice:
        return 'On-Device';
      case TranscriptionBackend.none:
        return 'None';
    }
  }
  
  /// Initialize the service and determine best available backend
  /// 
  /// Priority (fallback chain):
  /// 1. AssemblyAI (primary) - cloud-based, high accuracy
  /// 2. Apple On-Device (fallback) - always available, no network required
  Future<TranscriptionStartResult> initialize() async {
    _status = UnifiedTranscriptionStatus.initializing;
    debugPrint('UnifiedTranscription: Initializing (AssemblyAI → Apple On-Device)...');
    
    // Step 1: Try AssemblyAI (primary)
    debugPrint('UnifiedTranscription: Attempting AssemblyAI (primary)...');
    
    final assemblyAIAvailable = await _assemblyAIService.isAvailable();
    if (assemblyAIAvailable) {
      final token = await _assemblyAIService.getToken();
      
      if (token != null && token.isNotEmpty) {
        _assemblyAIProvider = AssemblyAIProvider(token: token);
        final initialized = await _assemblyAIProvider!.initialize();
        
        if (initialized) {
          _activeBackend = TranscriptionBackend.assemblyAI;
          _status = UnifiedTranscriptionStatus.ready;
          
          debugPrint('UnifiedTranscription: Using AssemblyAI backend (primary)');
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
    
    // Step 2: Fall back to Apple On-Device transcription
    debugPrint('UnifiedTranscription: Attempting Apple On-Device fallback...');
    
    _onDeviceProvider = OnDeviceTranscriptionProvider();
    final onDeviceInitialized = await _onDeviceProvider!.initialize();
    
    if (onDeviceInitialized) {
      _activeBackend = TranscriptionBackend.appleOnDevice;
      _status = UnifiedTranscriptionStatus.ready;
      
      debugPrint('UnifiedTranscription: Using Apple On-Device backend (fallback)');
      return TranscriptionStartResult.success(TranscriptionBackend.appleOnDevice);
    } else {
      debugPrint('UnifiedTranscription: Apple On-Device failed to initialize');
    }
    
    // Step 3: No backend available (shouldn't happen - on-device should always work)
    _status = UnifiedTranscriptionStatus.error;
    _activeBackend = TranscriptionBackend.none;
    
    debugPrint('UnifiedTranscription: All backends failed!');
    return TranscriptionStartResult.error(
      'Voice transcription unavailable. Please check microphone permissions.',
    );
  }
  
  /// Start listening with the active backend
  Future<bool> startListening() async {
    if (_activeBackend == TranscriptionBackend.none) {
      debugPrint('UnifiedTranscription: Cannot start - no backend initialized');
      return false;
    }
    
    _status = UnifiedTranscriptionStatus.listening;
    
    switch (_activeBackend) {
      case TranscriptionBackend.assemblyAI:
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
        onConnected?.call();
        debugPrint('UnifiedTranscription: Started AssemblyAI session');
        return true;
        
      case TranscriptionBackend.appleOnDevice:
        await _onDeviceProvider?.startListening(
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
        onConnected?.call();
        debugPrint('UnifiedTranscription: Started Apple On-Device session');
        return true;
        
      case TranscriptionBackend.none:
        return false;
    }
  }
  
  /// Stop listening and get final transcript
  Future<void> stopListening() async {
    debugPrint('UnifiedTranscription: Stopping...');
    
    switch (_activeBackend) {
      case TranscriptionBackend.assemblyAI:
        await _assemblyAIProvider?.stopListening();
        break;
        
      case TranscriptionBackend.appleOnDevice:
        await _onDeviceProvider?.stopListening();
        break;
        
      case TranscriptionBackend.none:
        break;
    }
    
    _status = UnifiedTranscriptionStatus.ready;
  }
  
  /// Disconnect and cleanup
  Future<void> disconnect() async {
    debugPrint('UnifiedTranscription: Disconnecting...');
    
    switch (_activeBackend) {
      case TranscriptionBackend.assemblyAI:
        await _assemblyAIProvider?.stopListening();
        _assemblyAIProvider = null;
        break;
        
      case TranscriptionBackend.appleOnDevice:
        await _onDeviceProvider?.dispose();
        _onDeviceProvider = null;
        break;
        
      case TranscriptionBackend.none:
        break;
    }
    
    _activeBackend = TranscriptionBackend.none;
    _status = UnifiedTranscriptionStatus.idle;
  }
  
  /// Check if AssemblyAI (primary) is available
  Future<bool> isPrimaryAvailable() async {
    return await _assemblyAIService.isAvailable();
  }
}
