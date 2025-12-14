/// Transcription Router - Policy-based provider selection
/// 
/// Selects the appropriate transcription provider based on:
/// - User preference (SttMode setting)
/// - Subscription tier (FREE, BETA, PRO)
/// - Network availability
/// - Provider availability

import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'transcription_provider.dart';
import 'assemblyai_provider.dart';
import 'ondevice_provider.dart';
import '../../../../services/assemblyai_service.dart';

/// Transcription settings storage keys
class _TranscriptionPrefs {
  static const String sttMode = 'stt_mode';
}

/// Router that selects and manages transcription providers
class TranscriptionRouter {
  final AssemblyAIService _assemblyAIService;
  
  TranscriptionProvider? _activeProvider;
  TranscriptionProvider? _cloudProvider;
  TranscriptionProvider? _localProvider;
  
  SttMode _currentMode = SttMode.auto;
  SttTier _userTier = SttTier.free;
  bool _isInitialized = false;
  
  // Callbacks for mid-session fallback
  Function(String message)? onProviderSwitch;
  
  TranscriptionRouter({
    required AssemblyAIService assemblyAIService,
  }) : _assemblyAIService = assemblyAIService;
  
  /// Current STT mode setting
  SttMode get currentMode => _currentMode;
  
  /// Current user tier
  SttTier get userTier => _userTier;
  
  /// Currently active provider (if any)
  TranscriptionProvider? get activeProvider => _activeProvider;
  
  /// Whether router is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the router
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Load saved mode preference
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_TranscriptionPrefs.sttMode);
    if (savedMode != null) {
      _currentMode = SttMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => SttMode.auto,
      );
    }
    
    // Initialize local provider (always available)
    _localProvider = OnDeviceTranscriptionProvider();
    await _localProvider!.initialize();
    
    // Get user tier from AssemblyAI service
    _userTier = await _assemblyAIService.getUserTier();
    
    _isInitialized = true;
  }

  /// Set the STT mode and persist preference
  Future<void> setMode(SttMode mode) async {
    _currentMode = mode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_TranscriptionPrefs.sttMode, mode.name);
  }

  /// Update user tier (call when subscription changes)
  void updateUserTier(SttTier tier) {
    _userTier = tier;
  }

  /// Check if cloud transcription is available
  Future<bool> isCloudAvailable() async {
    // Check network connectivity using simple DNS lookup
    try {
      final result = await InternetAddress.lookup('api.assemblyai.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        return false;
      }
    } catch (e) {
      // No network
      return false;
    }
    
    // Check if user is eligible for cloud
    if (_userTier == SttTier.free) {
      return false;
    }
    
    // Check if we can get a token
    return await _assemblyAIService.isAvailable();
  }

  /// Get the appropriate provider based on current settings
  Future<TranscriptionProvider> getProvider() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    switch (_currentMode) {
      case SttMode.auto:
        return await _getAutoProvider();
      case SttMode.cloud:
        return await _getCloudProvider();
      case SttMode.local:
        return _getLocalProvider();
    }
  }

  /// AUTO mode: Try cloud first, fallback to local
  Future<TranscriptionProvider> _getAutoProvider() async {
    // Check if user is eligible for cloud
    if (_userTier == SttTier.free) {
      print('TranscriptionRouter: FREE tier - using local provider');
      return _getLocalProvider();
    }
    
    // Try cloud provider
    if (await isCloudAvailable()) {
      try {
        final cloudProvider = await _createCloudProvider();
        if (cloudProvider != null) {
          print('TranscriptionRouter: AUTO mode - using cloud provider');
          return cloudProvider;
        }
      } catch (e) {
        print('TranscriptionRouter: Cloud provider failed, falling back to local: $e');
      }
    }
    
    // Fallback to local
    print('TranscriptionRouter: AUTO mode - falling back to local provider');
    onProviderSwitch?.call('Using on-device transcription (cloud unavailable)');
    return _getLocalProvider();
  }

  /// CLOUD mode: Use cloud or fail
  Future<TranscriptionProvider> _getCloudProvider() async {
    // Check eligibility
    if (_userTier == SttTier.free) {
      throw TranscriptionException(
        'Cloud transcription requires BETA or PRO subscription',
        canFallback: true,
      );
    }
    
    // Check availability
    if (!await isCloudAvailable()) {
      throw TranscriptionException(
        'Cloud transcription unavailable (no network)',
        canFallback: true,
      );
    }
    
    // Create cloud provider
    final cloudProvider = await _createCloudProvider();
    if (cloudProvider == null) {
      throw TranscriptionException(
        'Failed to initialize cloud transcription',
        canFallback: true,
      );
    }
    
    return cloudProvider;
  }

  /// LOCAL mode: Always use on-device
  TranscriptionProvider _getLocalProvider() {
    return _localProvider ?? OnDeviceTranscriptionProvider();
  }

  /// Create a cloud provider with token
  Future<TranscriptionProvider?> _createCloudProvider() async {
    final token = await _assemblyAIService.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    
    _cloudProvider = AssemblyAIProvider(token: token);
    await _cloudProvider!.initialize();
    return _cloudProvider;
  }

  /// Start transcription with automatic provider selection
  Future<void> startTranscription({
    required Function(TranscriptSegment segment) onPartialResult,
    required Function(TranscriptSegment segment) onFinalResult,
    Function(String error)? onError,
    Function(double level)? onSoundLevel,
  }) async {
    try {
      _activeProvider = await getProvider();
      
      await _activeProvider!.startListening(
        onPartialResult: onPartialResult,
        onFinalResult: onFinalResult,
        onError: (error) {
          // Handle errors and potentially fallback
          _handleProviderError(error, onPartialResult, onFinalResult, onError, onSoundLevel);
        },
        onSoundLevel: onSoundLevel,
      );
    } catch (e) {
      if (e is TranscriptionException && e.canFallback && _currentMode == SttMode.auto) {
        // Fallback to local in AUTO mode
        _activeProvider = _getLocalProvider();
        onProviderSwitch?.call('Switched to on-device transcription');
        await _activeProvider!.startListening(
          onPartialResult: onPartialResult,
          onFinalResult: onFinalResult,
          onError: onError,
          onSoundLevel: onSoundLevel,
        );
      } else {
        onError?.call(e.toString());
      }
    }
  }

  /// Handle provider errors with potential fallback
  void _handleProviderError(
    String error,
    Function(TranscriptSegment segment) onPartialResult,
    Function(TranscriptSegment segment) onFinalResult,
    Function(String error)? onError,
    Function(double level)? onSoundLevel,
  ) async {
    print('TranscriptionRouter: Provider error: $error');
    
    // In AUTO mode, try to fallback
    if (_currentMode == SttMode.auto && _activeProvider?.requiresNetwork == true) {
      print('TranscriptionRouter: Attempting fallback to local provider');
      
      // Stop current provider
      await _activeProvider?.cancelListening();
      
      // Switch to local
      _activeProvider = _getLocalProvider();
      onProviderSwitch?.call('Switched to on-device transcription');
      
      // Resume with local provider
      await _activeProvider!.startListening(
        onPartialResult: onPartialResult,
        onFinalResult: onFinalResult,
        onError: onError,
        onSoundLevel: onSoundLevel,
      );
    } else {
      // Pass error through
      onError?.call(error);
    }
  }

  /// Stop transcription
  Future<void> stopTranscription() async {
    await _activeProvider?.stopListening();
    _activeProvider = null;
  }

  /// Cancel transcription
  Future<void> cancelTranscription() async {
    await _activeProvider?.cancelListening();
    _activeProvider = null;
  }

  /// Check if currently transcribing
  bool get isTranscribing => _activeProvider?.isListening ?? false;

  /// Dispose of router resources
  Future<void> dispose() async {
    await _cloudProvider?.dispose();
    await _localProvider?.dispose();
    _activeProvider = null;
  }
}

/// Exception for transcription errors
class TranscriptionException implements Exception {
  final String message;
  final bool canFallback;

  TranscriptionException(this.message, {this.canFallback = false});

  @override
  String toString() => message;
}
