/// Unified Transcription Service
/// 
/// Provides seamless fallback between transcription backends:
/// 1. Wispr Flow (optional) - if user has their own API key configured
/// 2. Apple On-Device (default) - always available, no network required
/// 
/// Fallback chain: Wispr (if configured) → Apple On-Device

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'ondevice_provider.dart';
import 'transcription_provider.dart';
import '../config/wispr_config_service.dart';
import '../wispr/wispr_flow_service.dart';

/// Active transcription provider
enum TranscriptionBackend {
  wisprFlow,
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
/// Fallback chain: Wispr (if configured) → Apple On-Device
class UnifiedTranscriptionService {
  final WisprConfigService _wisprConfigService;
  
  UnifiedTranscriptionStatus _status = UnifiedTranscriptionStatus.idle;
  TranscriptionBackend _activeBackend = TranscriptionBackend.none;
  
  // Providers
  WisprFlowService? _wisprService;
  OnDeviceTranscriptionProvider? _onDeviceProvider;
  
  // Callbacks (unified interface)
  Function(String transcript, bool isFinal)? onTranscript;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  UnifiedTranscriptionService({
    WisprConfigService? wisprConfigService,
  }) : _wisprConfigService = wisprConfigService ?? WisprConfigService.instance;
  
  /// Current status
  UnifiedTranscriptionStatus get status => _status;
  
  /// Currently active backend
  TranscriptionBackend get activeBackend => _activeBackend;
  
  /// Wispr service (for direct access if needed)
  WisprFlowService? get wisprService => _wisprService;
  
  /// Whether any transcription backend is connected/ready
  bool get isConnected {
    switch (_activeBackend) {
      case TranscriptionBackend.wisprFlow:
        return _wisprService?.isConnected ?? false;
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
      case TranscriptionBackend.wisprFlow:
        return 'Wispr Flow';
      case TranscriptionBackend.appleOnDevice:
        return 'On-Device';
      case TranscriptionBackend.none:
        return 'None';
    }
  }
  
  /// Initialize the service and determine best available backend
  /// 
  /// Priority (fallback chain):
  /// 1. Wispr Flow (if user has their own API key configured)
  /// 2. Apple On-Device (default) - always available
  Future<TranscriptionStartResult> initialize() async {
    _status = UnifiedTranscriptionStatus.initializing;
    debugPrint('UnifiedTranscription: Initializing (Wispr → Apple On-Device)...');
    
    // Step 1: Try Wispr Flow (if user has their own API key)
    final wisprAvailable = await _wisprConfigService.isAvailable();
    if (wisprAvailable) {
      debugPrint('UnifiedTranscription: User has Wispr API key configured');
      
      final apiKey = await _wisprConfigService.getApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        final config = WisprFlowConfig(apiKey: apiKey);
        _wisprService = WisprFlowService(config: config);
        
        try {
          debugPrint('UnifiedTranscription: Attempting Wispr Flow connection...');
          await _wisprService!.connect();
          
          if (_wisprService!.isConnected && _wisprService!.isAuthenticated) {
            _activeBackend = TranscriptionBackend.wisprFlow;
            _status = UnifiedTranscriptionStatus.ready;
            
            debugPrint('UnifiedTranscription: Using Wispr Flow backend (user API key)');
            return TranscriptionStartResult.success(TranscriptionBackend.wisprFlow);
          } else {
            debugPrint('UnifiedTranscription: Wispr Flow connection failed');
          }
        } catch (e) {
          debugPrint('UnifiedTranscription: Wispr Flow error: $e');
        }
      }
    } else {
      debugPrint('UnifiedTranscription: No user Wispr API key configured');
    }
    
    // Step 2: Use Apple On-Device transcription (default)
    debugPrint('UnifiedTranscription: Using Apple On-Device transcription...');
    
    _onDeviceProvider = OnDeviceTranscriptionProvider();
    final onDeviceInitialized = await _onDeviceProvider!.initialize();
    
    if (onDeviceInitialized) {
      _activeBackend = TranscriptionBackend.appleOnDevice;
      _status = UnifiedTranscriptionStatus.ready;
      
      debugPrint('UnifiedTranscription: Using Apple On-Device backend');
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
    
    // Reset status to ready first in case we're restarting
    if (_status == UnifiedTranscriptionStatus.listening) {
      debugPrint('UnifiedTranscription: Already listening, stopping first...');
      await stopListening();
    }
    
    _status = UnifiedTranscriptionStatus.listening;
    debugPrint('UnifiedTranscription: Starting to listen (backend: $activeBackendName)');
    
    switch (_activeBackend) {
      case TranscriptionBackend.wisprFlow:
        _setupWisprCallbacks();
        _wisprService?.startSession();
        debugPrint('UnifiedTranscription: Started Wispr Flow session');
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
  
  /// Setup Wispr Flow callbacks
  void _setupWisprCallbacks() {
    if (_wisprService == null) return;
    
    _wisprService!.onConnected = () {
      debugPrint('UnifiedTranscription: Wispr connected');
      onConnected?.call();
    };
    
    _wisprService!.onTranscript = (transcript) {
      onTranscript?.call(transcript.text, transcript.isFinal);
    };
    
    _wisprService!.onError = (error) {
      debugPrint('UnifiedTranscription: Wispr error: $error');
      onError?.call(error);
    };
    
    _wisprService!.onDisconnected = () {
      debugPrint('UnifiedTranscription: Wispr disconnected');
      onDisconnected?.call();
    };
  }
  
  /// Send audio data to the active backend (only for Wispr)
  void sendAudioData(Uint8List audioData) {
    if (_activeBackend == TranscriptionBackend.wisprFlow) {
      _wisprService?.sendAudio(audioData);
    }
    // On-Device handles its own audio capture
  }
  
  /// Commit session (for Wispr Flow)
  void commitSession() {
    if (_activeBackend == TranscriptionBackend.wisprFlow) {
      _wisprService?.commitSession();
    }
  }
  
  /// Stop listening and get final transcript
  Future<void> stopListening() async {
    debugPrint('UnifiedTranscription: Stopping (status: $_status, backend: $activeBackendName)...');
    
    switch (_activeBackend) {
      case TranscriptionBackend.wisprFlow:
        _wisprService?.commitSession();
        break;
        
      case TranscriptionBackend.appleOnDevice:
        await _onDeviceProvider?.stopListening();
        break;
        
      case TranscriptionBackend.none:
        break;
    }
    
    _status = UnifiedTranscriptionStatus.ready;
    debugPrint('UnifiedTranscription: Stopped, status now: $_status');
  }
  
  /// Disconnect and cleanup
  Future<void> disconnect() async {
    debugPrint('UnifiedTranscription: Disconnecting...');
    
    switch (_activeBackend) {
      case TranscriptionBackend.wisprFlow:
        _wisprService?.dispose();
        _wisprService = null;
        break;
        
      case TranscriptionBackend.appleOnDevice:
        await _onDeviceProvider?.stopListening();
        _onDeviceProvider = null;
        break;
        
      case TranscriptionBackend.none:
        break;
    }
    
    _activeBackend = TranscriptionBackend.none;
    _status = UnifiedTranscriptionStatus.idle;
    onDisconnected?.call();
  }
  
  /// Check if user has Wispr configured
  Future<bool> isWisprConfigured() async {
    return await _wisprConfigService.isAvailable();
  }
  
  /// Dispose of resources
  void dispose() {
    _wisprService?.dispose();
    _onDeviceProvider = null;
  }
}
