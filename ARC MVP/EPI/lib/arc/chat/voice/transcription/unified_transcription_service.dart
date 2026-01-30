/// Unified Transcription Service
/// 
/// Provides seamless fallback between transcription backends:
/// 1. Wispr Flow (optional) - if user has their own API key configured
/// 2. Assembly AI (optional) - premium cloud streaming, high accuracy
/// 3. Apple On-Device (default) - always available, no network required
/// 
/// Fallback chain: Wispr (if configured) → Assembly AI (if premium) → Apple On-Device

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'ondevice_provider.dart';
import 'transcription_provider.dart';
import 'assemblyai_provider.dart';
import '../config/wispr_config_service.dart';
import '../wispr/wispr_flow_service.dart';
import '../../../../services/assemblyai_service.dart';

/// Active transcription provider
enum TranscriptionBackend {
  wisprFlow,
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
/// Fallback chain: Wispr (if configured) → Assembly AI (if premium) → Apple On-Device
class UnifiedTranscriptionService {
  final WisprConfigService _wisprConfigService;
  final AssemblyAIService _assemblyAIService;
  
  UnifiedTranscriptionStatus _status = UnifiedTranscriptionStatus.idle;
  TranscriptionBackend _activeBackend = TranscriptionBackend.none;
  
  // Providers
  WisprFlowService? _wisprService;
  AssemblyAIProvider? _assemblyAIProvider;
  OnDeviceTranscriptionProvider? _onDeviceProvider;
  
  // Callbacks (unified interface)
  Function(String transcript, bool isFinal)? onTranscript;
  Function(String error)? onError;
  Function()? onConnected;
  Function()? onDisconnected;
  
  UnifiedTranscriptionService({
    WisprConfigService? wisprConfigService,
    AssemblyAIService? assemblyAIService,
  }) : _wisprConfigService = wisprConfigService ?? WisprConfigService.instance,
       _assemblyAIService = assemblyAIService ?? AssemblyAIService();
  
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
      case TranscriptionBackend.assemblyAI:
        return _assemblyAIProvider?.status == ProviderStatus.idle ||
               _assemblyAIProvider?.status == ProviderStatus.listening;
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
      case TranscriptionBackend.assemblyAI:
        return 'Assembly AI';
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
  /// 2. Assembly AI (if premium user) - cloud streaming backup
  /// 3. Apple On-Device (default) - always available
  Future<TranscriptionStartResult> initialize() async {
    _status = UnifiedTranscriptionStatus.initializing;
    debugPrint('UnifiedTranscription: Initializing (Wispr → Assembly AI → Apple On-Device)...');
    
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
    
    // Step 2: Try Assembly AI (premium users - backup cloud STT)
    final assemblyAIAvailable = await _assemblyAIService.isAvailable();
    if (assemblyAIAvailable) {
      try {
        final token = await _assemblyAIService.getToken();
        if (token != null && token.isNotEmpty) {
          _assemblyAIProvider = AssemblyAIProvider(token: token);
          final assemblyAIInitialized = await _assemblyAIProvider!.initialize();
          if (assemblyAIInitialized) {
            _activeBackend = TranscriptionBackend.assemblyAI;
            _status = UnifiedTranscriptionStatus.ready;
            debugPrint('UnifiedTranscription: Using Assembly AI backend (premium)');
            return TranscriptionStartResult.success(TranscriptionBackend.assemblyAI);
          }
        }
      } catch (e) {
        debugPrint('UnifiedTranscription: Assembly AI error: $e');
      }
      _assemblyAIProvider = null;
    } else {
      debugPrint('UnifiedTranscription: Assembly AI not available for user');
    }
    
    // Step 3: Use Apple On-Device transcription (default)
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
    
    // Step 4: No backend available (shouldn't happen - on-device should always work)
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
      // Brief delay to ensure clean state before starting new session
      await Future.delayed(const Duration(milliseconds: 150));
    }
    
    _status = UnifiedTranscriptionStatus.listening;
    debugPrint('UnifiedTranscription: Starting to listen (backend: $activeBackendName)');
    
    switch (_activeBackend) {
      case TranscriptionBackend.wisprFlow:
        _setupWisprCallbacks();
        // Ensure Wispr service is still connected before starting new session
        if (_wisprService?.isConnected != true) {
          debugPrint('UnifiedTranscription: Wispr not connected, reconnecting...');
          final reconnected = await _wisprService?.connect();
          if (reconnected != true) {
            debugPrint('UnifiedTranscription: Failed to reconnect Wispr');
            _status = UnifiedTranscriptionStatus.error;
            return false;
          }
        }
        _wisprService?.startSession();
        debugPrint('UnifiedTranscription: Started Wispr Flow session');
        return true;
        
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
        debugPrint('UnifiedTranscription: Started Assembly AI session');
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
    // Assembly AI and On-Device handle their own audio capture
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
        
      case TranscriptionBackend.assemblyAI:
        await _assemblyAIProvider?.stopListening();
        await _assemblyAIProvider?.dispose();
        _assemblyAIProvider = null;
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
    _assemblyAIProvider?.dispose();
    _assemblyAIProvider = null;
    _onDeviceProvider = null;
  }
}
