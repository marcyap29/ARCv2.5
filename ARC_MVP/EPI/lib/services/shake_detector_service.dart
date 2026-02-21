import 'dart:async';
import 'package:flutter/services.dart';

/// Service to detect device shake gestures
/// Used to trigger bug report dialog similar to ChatGPT
class ShakeDetectorService {
  static final ShakeDetectorService _instance = ShakeDetectorService._internal();
  factory ShakeDetectorService() => _instance;
  ShakeDetectorService._internal();

  static const _eventChannel = EventChannel('com.epi.arcmvp/shake_events');
  
  StreamSubscription? _shakeSubscription;
  final _shakeController = StreamController<void>.broadcast();
  
  bool _isEnabled = true;
  bool _isListening = false;
  
  /// Stream of shake events
  Stream<void> get onShake => _shakeController.stream;
  
  /// Whether shake detection is enabled
  bool get isEnabled => _isEnabled;
  
  /// Enable or disable shake detection
  set isEnabled(bool value) {
    _isEnabled = value;
    if (value && !_isListening) {
      startListening();
    } else if (!value && _isListening) {
      stopListening();
    }
  }
  
  /// Start listening for shake gestures
  Future<void> startListening() async {
    if (_isListening || !_isEnabled) return;
    
    try {
      // Try to use native shake detection first
      _shakeSubscription = _eventChannel
          .receiveBroadcastStream()
          .listen(_onNativeShakeDetected);
      _isListening = true;
      print('ShakeDetector: Started listening (native)');
    } catch (e) {
      // Fall back to accelerometer-based detection
      print('ShakeDetector: Native detection not available, using fallback');
      _startAccelerometerFallback();
    }
  }
  
  void _onNativeShakeDetected(dynamic event) {
    if (!_isEnabled) return;
    print('ShakeDetector: Native shake event received: $event');
    
    // Trigger immediately on native shake detection
    // Native iOS already handles the shake gesture recognition
    _shakeController.add(null);
    print('ShakeDetector: Shake detected!');
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
  }
  
  void _startAccelerometerFallback() {
    // This would use sensors_plus package if available
    // For now, we rely on native implementation
    _isListening = true;
    print('ShakeDetector: Fallback mode active');
  }
  
  /// Manually trigger a shake event (for testing or alternative triggers)
  void triggerShakeManually() {
    _shakeController.add(null);
    print('ShakeDetector: Manual shake triggered!');
    HapticFeedback.mediumImpact();
  }
  
  /// Stop listening for shake gestures
  void stopListening() {
    _shakeSubscription?.cancel();
    _shakeSubscription = null;
    _isListening = false;
    print('ShakeDetector: Stopped listening');
  }
  
  /// Dispose of resources
  void dispose() {
    stopListening();
    _shakeController.close();
  }
}

