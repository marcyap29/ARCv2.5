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
  
  // Shake detection parameters
  static const double shakeThreshold = 2.5; // G-force threshold
  static const int shakeCountThreshold = 3; // Number of shakes needed
  static const Duration shakeResetDuration = Duration(milliseconds: 500);
  
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  
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
    _triggerShake();
  }
  
  void _startAccelerometerFallback() {
    // This would use sensors_plus package if available
    // For now, we rely on native implementation
    _isListening = true;
    print('ShakeDetector: Fallback mode active');
  }
  
  /// Manually trigger a shake event (for testing or alternative triggers)
  void triggerShakeManually() {
    _triggerShake();
  }
  
  void _triggerShake() {
    final now = DateTime.now();
    
    // Reset count if too much time has passed
    if (_lastShakeTime != null && 
        now.difference(_lastShakeTime!) > shakeResetDuration) {
      _shakeCount = 0;
    }
    
    _shakeCount++;
    _lastShakeTime = now;
    
    if (_shakeCount >= shakeCountThreshold) {
      _shakeCount = 0;
      _shakeController.add(null);
      print('ShakeDetector: Shake detected!');
      
      // Haptic feedback
      HapticFeedback.mediumImpact();
    }
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

