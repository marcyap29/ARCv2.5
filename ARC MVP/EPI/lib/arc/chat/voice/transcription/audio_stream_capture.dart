/// Audio Stream Capture - Raw PCM audio capture for AssemblyAI streaming
/// 
/// Uses the `record` package to capture raw audio from the microphone
/// and stream it in PCM format suitable for AssemblyAI's WebSocket API.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Configuration for audio capture
class AudioCaptureConfig {
  /// Sample rate in Hz (AssemblyAI requires 16000)
  final int sampleRate;
  
  /// Number of audio channels (AssemblyAI requires mono = 1)
  final int numChannels;
  
  /// Bits per sample (AssemblyAI requires 16-bit)
  final int bitsPerSample;
  
  const AudioCaptureConfig({
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitsPerSample = 16,
  });
  
  /// Default config for AssemblyAI
  static const assemblyAI = AudioCaptureConfig(
    sampleRate: 16000,
    numChannels: 1,
    bitsPerSample: 16,
  );
}

/// Captures raw PCM audio from the microphone for streaming
class AudioStreamCapture {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioCaptureConfig _config;
  
  StreamSubscription<Uint8List>? _streamSubscription;
  StreamController<Uint8List>? _audioController;
  StreamController<double>? _levelController;
  
  bool _isCapturing = false;
  
  AudioStreamCapture({AudioCaptureConfig? config})
      : _config = config ?? AudioCaptureConfig.assemblyAI;

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Check if currently capturing audio
  bool get isCapturing => _isCapturing;
  
  /// Stream of raw PCM audio bytes
  Stream<Uint8List>? get audioStream => _audioController?.stream;
  
  /// Stream of audio levels (0.0 to 1.0)
  Stream<double>? get levelStream => _levelController?.stream;

  /// Start capturing audio
  /// 
  /// Returns a stream of raw PCM audio bytes suitable for AssemblyAI.
  /// The audio is:
  /// - 16-bit signed little-endian PCM
  /// - 16000 Hz sample rate
  /// - Mono channel
  Future<Stream<Uint8List>?> startCapture({
    Function(double level)? onLevel,
  }) async {
    if (_isCapturing) {
      debugPrint('AudioStreamCapture: Already capturing');
      return _audioController?.stream;
    }
    
    // Check permission
    if (!await hasPermission()) {
      debugPrint('AudioStreamCapture: No microphone permission');
      return null;
    }
    
    // Create stream controllers
    _audioController = StreamController<Uint8List>.broadcast();
    _levelController = StreamController<double>.broadcast();
    
    // Set up level listener
    if (onLevel != null) {
      _levelController!.stream.listen(onLevel);
    }
    
    try {
      // Configure recorder for PCM streaming
      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _config.sampleRate,
        numChannels: _config.numChannels,
        // bitRate not applicable for PCM
      );
      
      // Start streaming
      final stream = await _recorder.startStream(recordConfig);
      
      _isCapturing = true;
      debugPrint('AudioStreamCapture: Started capturing (${_config.sampleRate}Hz, ${_config.numChannels}ch, ${_config.bitsPerSample}bit)');
      
      // Listen to audio stream
      _streamSubscription = stream.listen(
        (data) {
          // Forward audio data
          if (!(_audioController?.isClosed ?? true)) {
            _audioController!.add(data);
          }
          
          // Calculate audio level from PCM data
          final level = _calculateLevel(data);
          if (!(_levelController?.isClosed ?? true)) {
            _levelController!.add(level);
          }
        },
        onError: (error) {
          debugPrint('AudioStreamCapture: Stream error: $error');
          _audioController?.addError(error);
        },
        onDone: () {
          debugPrint('AudioStreamCapture: Stream done');
          _isCapturing = false;
        },
      );
      
      return _audioController!.stream;
      
    } catch (e) {
      debugPrint('AudioStreamCapture: Failed to start: $e');
      await _cleanup();
      return null;
    }
  }

  /// Stop capturing audio
  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    
    debugPrint('AudioStreamCapture: Stopping capture');
    _isCapturing = false;
    
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('AudioStreamCapture: Error stopping recorder: $e');
    }
    
    await _cleanup();
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    
    await _audioController?.close();
    _audioController = null;
    
    await _levelController?.close();
    _levelController = null;
  }

  /// Calculate normalized audio level from PCM data (0.0 to 1.0)
  double _calculateLevel(Uint8List data) {
    if (data.isEmpty) return 0.0;
    
    // Convert bytes to 16-bit samples (little-endian)
    final samples = data.buffer.asInt16List();
    if (samples.isEmpty) return 0.0;
    
    // Calculate RMS (Root Mean Square) for audio level
    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    final rms = (sumSquares / samples.length);
    
    // Normalize to 0.0-1.0 range
    // 16-bit audio max value is 32767, so max RMS is ~32767^2
    // We use a lower threshold for practical speaking levels
    const maxRms = 1000000000.0; // Adjusted for typical speech
    final normalized = (rms / maxRms).clamp(0.0, 1.0);
    
    // Apply some smoothing via sqrt for better visualization
    return normalized > 0 ? (normalized * normalized).clamp(0.0, 1.0) : 0.0;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopCapture();
    _recorder.dispose();
  }
}
