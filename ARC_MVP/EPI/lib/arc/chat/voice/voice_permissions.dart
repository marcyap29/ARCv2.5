import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoicePermState { allGranted, needsMic, needsSpeech, permanentlyDenied }

class VoicePermissions {
  // Cache STT instance to avoid re-initializing
  static stt.SpeechToText? _cachedSTT;
  static bool? _sttInitialized;
  
  /// Check current permission status WITHOUT requesting
  static Future<VoicePermState> check() async {
    // Check microphone permission first
    final mic = await Permission.microphone.status;
    print('VoicePermissions.check: Microphone status = $mic');
    
    // If microphone is not granted, we can't proceed
    if (!mic.isGranted) {
      if (mic.isPermanentlyDenied) {
        return VoicePermState.permanentlyDenied;
      }
      return VoicePermState.needsMic;
    }
    
    // For speech recognition on iOS:
    // - If microphone is granted, we assume speech recognition is also available
    // - The speech_to_text plugin handles its own permission request
    // - We only check STT initialization if we haven't checked before
    // - If STT was previously initialized successfully, we trust that
    bool speechGranted = true;
    if (Platform.isIOS) {
      // If we've already initialized STT successfully, trust that
      if (_sttInitialized == true) {
        speechGranted = true;
        print('VoicePermissions.check: STT previously initialized, assuming granted');
      } else {
        // If microphone is granted, assume speech recognition is also available
        // The actual check will happen when we try to use STT
        // This prevents false negatives from initialization failures
        speechGranted = true;
        print('VoicePermissions.check: Microphone granted, assuming speech recognition available');
      }
    }
    
    if (mic.isGranted && speechGranted) {
      print('VoicePermissions.check: All permissions granted');
      return VoicePermState.allGranted;
    }
    
    if (mic.isPermanentlyDenied) {
      return VoicePermState.permanentlyDenied;
    }
    
    if (!mic.isGranted) {
      return VoicePermState.needsMic;
    }
    
    if (!speechGranted) {
      return VoicePermState.needsSpeech;
    }
    
    return VoicePermState.allGranted;
  }

  /// Request both microphone and speech recognition permissions
  static Future<VoicePermState> request() async {
    // First check if permissions are already granted
    final currentState = await check();
    if (currentState == VoicePermState.allGranted) {
      print('VoicePermissions.request: Permissions already granted, skipping request');
      return VoicePermState.allGranted;
    }
    
    print('VoicePermissions.request: Current state = $currentState, requesting permissions...');
    
    // Request microphone permission only if not granted
    PermissionStatus mic;
    if (currentState == VoicePermState.needsMic) {
      mic = await Permission.microphone.request();
      print('VoicePermissions.request: Microphone request result = $mic');
    } else {
      mic = await Permission.microphone.status;
      print('VoicePermissions.request: Microphone already checked, status = $mic');
    }
    
    // If microphone is granted, try to initialize STT (this will request speech recognition if needed)
    bool speechGranted = true;
    if (Platform.isIOS && mic.isGranted) {
      // Only initialize if not already initialized
      if (_sttInitialized != true) {
        try {
          final sttInstance = _cachedSTT ?? stt.SpeechToText();
          speechGranted = await sttInstance.initialize(
            onError: (error) {
              print('VoicePermissions.request: STT error = ${error.errorMsg}');
              // Don't fail completely on error - might be temporary
            },
            onStatus: (status) {
              print('VoicePermissions.request: STT status = $status');
            },
          );
          _cachedSTT = sttInstance;
          _sttInitialized = speechGranted;
          print('VoicePermissions.request: STT initialized = $speechGranted');
        } catch (e) {
          print('VoicePermissions.request: STT exception = $e');
          // Don't mark as failed - might be temporary issue
          // If microphone is granted, assume speech recognition will work
          speechGranted = true;
        }
      } else {
        speechGranted = true;
        print('VoicePermissions.request: STT already initialized');
      }
    }
    
    // If microphone is granted, we consider permissions granted
    // Speech recognition will be checked when actually used
    if (mic.isGranted) {
      print('VoicePermissions.request: Microphone granted, considering all permissions granted');
      return VoicePermState.allGranted;
    }
    
    if (mic.isPermanentlyDenied) {
      print('VoicePermissions.request: Microphone permanently denied');
      return VoicePermState.permanentlyDenied;
    }
    
    // Re-check to get accurate state
    return await check();
  }
  
  /// Clear cached STT state (useful for testing or when permissions change)
  /// Call this when returning from settings to refresh permission state
  static void clearCache() {
    _cachedSTT = null;
    _sttInitialized = null;
    print('VoicePermissions: Cache cleared');
  }
  
  /// Check if permissions are granted (simplified check)
  /// Returns true if microphone is granted (assumes speech recognition is also available)
  static Future<bool> arePermissionsGranted() async {
    try {
      final mic = await Permission.microphone.status;
      final granted = mic.isGranted;
      print('VoicePermissions.arePermissionsGranted: Microphone status = $mic, granted = $granted');
      
      // Also check if it's permanently denied
      if (mic.isPermanentlyDenied) {
        print('VoicePermissions.arePermissionsGranted: Microphone permanently denied');
        return false;
      }
      
      return granted;
    } catch (e) {
      print('VoicePermissions.arePermissionsGranted: Error checking permissions: $e');
      return false;
    }
  }

  static Future<void> openSettings() => openAppSettings();
}

