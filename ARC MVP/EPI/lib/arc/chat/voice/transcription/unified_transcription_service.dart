/// Unified Transcription Service
///
/// Backends: Wispr Flow (optional, via Settings) → Apple On-Device (primary).
/// A mandatory cleanup pass (filler removal, corrections) is applied to final transcripts
/// before PRISM.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'ondevice_provider.dart';
import 'transcription_provider.dart';
import 'cleanup/transcript_cleanup_service.dart';
import '../config/wispr_config_service.dart';
import '../wispr/wispr_flow_service.dart';
import '../../../../services/firebase_auth_service.dart';

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

/// Unified transcription service: Wispr (optional) or Apple On-Device (primary).
///
/// Cleanup applied to final transcripts.
class UnifiedTranscriptionService {
  final WisprConfigService _wisprConfigService;
  final TranscriptCleanupService _cleanup = TranscriptCleanupService();

  UnifiedTranscriptionStatus _status = UnifiedTranscriptionStatus.idle;
  TranscriptionBackend _activeBackend = TranscriptionBackend.none;

  // Providers
  WisprFlowService? _wisprService;
  TranscriptionProvider? _onDeviceProvider; // OnDeviceTranscriptionProvider (Apple)
  
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
        return 'Apple On-Device';
      case TranscriptionBackend.none:
        return 'None';
    }
  }
  
  /// Initialize the service and determine backend: Wispr (optional) or Apple On-Device (primary).
  Future<TranscriptionStartResult> initialize() async {
    _status = UnifiedTranscriptionStatus.initializing;
    debugPrint('UnifiedTranscription: Initializing (Wispr optional → Apple On-Device primary)...');
    
    // Check if current user is admin (Wispr is restricted to admin for testing)
    final currentUserEmail = FirebaseAuthService.instance.currentUser?.email?.toLowerCase();
    const adminEmail = 'marcyap@orbitalai.net';
    final isAdmin = currentUserEmail == adminEmail;
    
    debugPrint('UnifiedTranscription: Current user: $currentUserEmail, isAdmin: $isAdmin');
    
    // Step 1: Try Wispr Flow (ADMIN ONLY - if admin has their own API key)
    if (isAdmin) {
      final wisprAvailable = await _wisprConfigService.isAvailable();
      debugPrint('UnifiedTranscription: Wispr config check - available: $wisprAvailable');
      
      if (wisprAvailable) {
        debugPrint('UnifiedTranscription: Admin has Wispr API key configured');
        
        final apiKey = await _wisprConfigService.getApiKey();
        final keyLength = apiKey?.length ?? 0;
        final keyPreview = keyLength > 8 ? '${apiKey!.substring(0, 4)}...${apiKey.substring(keyLength - 4)}' : '(too short)';
        debugPrint('UnifiedTranscription: API key retrieved - length: $keyLength, preview: $keyPreview');
        
        if (apiKey != null && apiKey.isNotEmpty) {
          final config = WisprFlowConfig(apiKey: apiKey);
          _wisprService = WisprFlowService(config: config);
          
          try {
            debugPrint('UnifiedTranscription: Attempting Wispr Flow connection...');
            final connected = await _wisprService!.connect();
            debugPrint('UnifiedTranscription: Wispr connect() returned: $connected');
            debugPrint('UnifiedTranscription: Wispr state - connected: ${_wisprService!.isConnected}, authenticated: ${_wisprService!.isAuthenticated}');
            
            if (_wisprService!.isConnected && _wisprService!.isAuthenticated) {
              _activeBackend = TranscriptionBackend.wisprFlow;
              _status = UnifiedTranscriptionStatus.ready;
              
              debugPrint('UnifiedTranscription: ✓ Using Wispr Flow backend (admin API key)');
              return TranscriptionStartResult.success(TranscriptionBackend.wisprFlow);
            } else {
              debugPrint('UnifiedTranscription: ✗ Wispr Flow connection failed - connected: ${_wisprService!.isConnected}, authenticated: ${_wisprService!.isAuthenticated}');
              _wisprService?.dispose();
              _wisprService = null;
            }
          } catch (e, stackTrace) {
            debugPrint('UnifiedTranscription: ✗ Wispr Flow error: $e');
            debugPrint('UnifiedTranscription: Stack trace: $stackTrace');
            _wisprService?.dispose();
            _wisprService = null;
          }
        } else {
          debugPrint('UnifiedTranscription: API key is null or empty');
        }
      } else {
        debugPrint('UnifiedTranscription: No admin Wispr API key configured in Settings → External Services');
      }
    } else {
      debugPrint('UnifiedTranscription: Wispr Flow skipped (not admin user)');
    }
    
    // Step 2: Apple On-Device (primary and only on-device backend)
    debugPrint('UnifiedTranscription: Initializing Apple On-Device...');
    _onDeviceProvider = OnDeviceTranscriptionProvider();
    final appleInitialized = await _onDeviceProvider!.initialize();
    if (appleInitialized) {
      _activeBackend = TranscriptionBackend.appleOnDevice;
      _status = UnifiedTranscriptionStatus.ready;
      debugPrint('UnifiedTranscription: Using Apple On-Device backend');
      return TranscriptionStartResult.success(TranscriptionBackend.appleOnDevice);
    }
    
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
        
      case TranscriptionBackend.appleOnDevice:
        await _onDeviceProvider?.startListening(
          onPartialResult: (segment) {
            onTranscript?.call(segment.text, false);
          },
          onFinalResult: (segment) {
            final cleaned = _cleanup.cleanup(segment.text);
            onTranscript?.call(cleaned.isEmpty ? segment.text : cleaned, true);
          },
          onError: (error) {
            onError?.call(error);
          },
        );
        onConnected?.call();
        debugPrint('UnifiedTranscription: Started on-device session ($activeBackendName)');
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
        await _onDeviceProvider?.dispose();
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
