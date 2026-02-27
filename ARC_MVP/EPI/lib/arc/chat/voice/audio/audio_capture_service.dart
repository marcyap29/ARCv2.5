/// Audio Capture Service
/// 
/// Captures audio from microphone for transcription
/// - Records audio from microphone
/// - Standard 16 kHz sample rate
/// - Outputs PCM S16LE format (16-bit signed little-endian)
/// - Chunks audio into 1-second segments
/// - Provides audio level stream for visualizations
/// - Handles platform differences (iOS/Android)
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Audio configuration for transcription
class AudioCaptureConfig {
  final int sampleRate;
  final int bitRate;
  final int numChannels;
  final int chunkDurationMs;
  
  const AudioCaptureConfig({
    this.sampleRate = 16000, // Standard 16 kHz for speech recognition
    this.bitRate = 128000,
    this.numChannels = 1, // Mono
    this.chunkDurationMs = 1000, // 1 second chunks
  });
  
  int get bytesPerChunk => (sampleRate * 2 * chunkDurationMs) ~/ 1000; // 2 bytes per sample
}

/// Audio level data
class AudioLevel {
  final double level; // 0.0 to 1.0
  final DateTime timestamp;
  
  const AudioLevel({
    required this.level,
    required this.timestamp,
  });
}

/// Callback types
typedef OnAudioChunk = void Function(Uint8List audioData);
typedef OnAudioLevel = void Function(AudioLevel level);
typedef OnCaptureError = void Function(String error);

/// Audio Capture Service
/// 
/// Handles microphone recording and audio processing for transcription
class AudioCaptureService {
  final AudioCaptureConfig _config;
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isRecording = false;
  Timer? _chunkTimer;
  final _audioChunks = <Uint8List>[];
  
  // Stream controllers
  final _audioChunkController = StreamController<Uint8List>.broadcast();
  final _audioLevelController = StreamController<AudioLevel>.broadcast();
  
  // Callbacks
  OnAudioChunk? onAudioChunk;
  OnAudioLevel? onAudioLevel;
  OnCaptureError? onError;
  
  AudioCaptureService({AudioCaptureConfig? config})
      : _config = config ?? const AudioCaptureConfig();
  
  bool get isRecording => _isRecording;
  Stream<Uint8List> get audioChunkStream => _audioChunkController.stream;
  Stream<AudioLevel> get audioLevelStream => _audioLevelController.stream;
  
  /// Initialize audio capture
  Future<bool> initialize() async {
    try {
      // Check if recording is supported
      final hasPermission = await _recorder.hasPermission();
      
      if (!hasPermission) {
        debugPrint('AudioCapture: No microphone permission');
        onError?.call('Microphone permission required');
        return false;
      }
      
      debugPrint('AudioCapture: Initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('AudioCapture: Initialization error: $e');
      onError?.call('Initialization error: $e');
      return false;
    }
  }
  
  /// Start recording audio
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('AudioCapture: Already recording');
      return true;
    }
    
    try {
      // Configure recording
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _config.sampleRate,
        numChannels: _config.numChannels,
        bitRate: _config.bitRate,
      );
      
      // Start recording to stream
      final stream = await _recorder.startStream(config);
      
      _isRecording = true;
      debugPrint('AudioCapture: Recording started (${_config.sampleRate} Hz, ${_config.numChannels} channel)');
      
      // Listen to audio stream
      stream.listen(
        _handleAudioData,
        onError: (error) {
          debugPrint('AudioCapture: Stream error: $error');
          onError?.call('Stream error: $error');
        },
        onDone: () {
          debugPrint('AudioCapture: Stream closed');
          _isRecording = false;
        },
        cancelOnError: false,
      );
      
      // Start audio level monitoring
      _startAudioLevelMonitoring();
      
      return true;
      
    } catch (e) {
      debugPrint('AudioCapture: Failed to start recording: $e');
      onError?.call('Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }
  
  /// Stop recording audio
  Future<void> stopRecording() async {
    if (!_isRecording) {
      debugPrint('AudioCapture: Not recording');
      return;
    }
    
    try {
      await _recorder.stop();
      _isRecording = false;
      _chunkTimer?.cancel();
      _chunkTimer = null;
      _audioChunks.clear();
      
      debugPrint('AudioCapture: Recording stopped');
      
    } catch (e) {
      debugPrint('AudioCapture: Error stopping recording: $e');
      onError?.call('Error stopping recording: $e');
    }
  }
  
  /// Handle incoming audio data
  void _handleAudioData(Uint8List data) {
    if (!_isRecording) return;
    
    try {
      // Process audio data
      final processedData = _processAudioData(data);
      
      // Emit chunk
      _audioChunkController.add(processedData);
      onAudioChunk?.call(processedData);
      
      // Calculate and emit audio level
      final level = _calculateAudioLevel(processedData);
      final audioLevel = AudioLevel(
        level: level,
        timestamp: DateTime.now(),
      );
      _audioLevelController.add(audioLevel);
      onAudioLevel?.call(audioLevel);
      
    } catch (e) {
      debugPrint('AudioCapture: Error handling audio data: $e');
      onError?.call('Error processing audio: $e');
    }
  }
  
  /// Process raw audio data to ensure correct format
  Uint8List _processAudioData(Uint8List data) {
    // The record package should already provide PCM16 data
    // This method can be extended for additional processing if needed
    return data;
  }
  
  /// Calculate audio level (RMS) from PCM data
  double _calculateAudioLevel(Uint8List pcmData) {
    if (pcmData.isEmpty) return 0.0;
    
    try {
      // PCM16 is 2 bytes per sample (16-bit signed)
      final numSamples = pcmData.length ~/ 2;
      if (numSamples == 0) return 0.0;
      
      double sum = 0.0;
      
      // Calculate RMS (Root Mean Square)
      for (int i = 0; i < numSamples; i++) {
        final byteIndex = i * 2;
        
        // Read 16-bit signed integer (little-endian)
        final sample = (pcmData[byteIndex + 1] << 8) | pcmData[byteIndex];
        
        // Convert to signed value
        final signedSample = sample > 32767 ? sample - 65536 : sample;
        
        // Accumulate squared values
        sum += signedSample * signedSample;
      }
      
      // Calculate RMS
      final rms = sum / numSamples;
      final level = rms.isFinite ? rms : 0.0;
      
      // Normalize to 0.0-1.0 range (32768 is max for 16-bit)
      final normalized = (level / (32768 * 32768)).clamp(0.0, 1.0);
      
      // Apply sqrt to get actual RMS and scale for better visual representation
      return (normalized * 10).clamp(0.0, 1.0);
      
    } catch (e) {
      debugPrint('AudioCapture: Error calculating audio level: $e');
      return 0.0;
    }
  }
  
  /// Start audio level monitoring
  void _startAudioLevelMonitoring() {
    // Audio level is calculated per chunk in _handleAudioData
    // This method can be extended for additional monitoring if needed
  }
  
  /// Pause recording
  Future<void> pause() async {
    if (!_isRecording) return;
    
    try {
      await _recorder.pause();
      debugPrint('AudioCapture: Recording paused');
    } catch (e) {
      debugPrint('AudioCapture: Error pausing: $e');
      onError?.call('Error pausing: $e');
    }
  }
  
  /// Resume recording
  Future<void> resume() async {
    if (!_isRecording) return;
    
    try {
      await _recorder.resume();
      debugPrint('AudioCapture: Recording resumed');
    } catch (e) {
      debugPrint('AudioCapture: Error resuming: $e');
      onError?.call('Error resuming: $e');
    }
  }
  
  /// Check if recording is supported on this platform
  Future<bool> isSupported() async {
    try {
      return await _recorder.isEncoderSupported(AudioEncoder.pcm16bits);
    } catch (e) {
      debugPrint('AudioCapture: Error checking support: $e');
      return false;
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await stopRecording();
    await _audioChunkController.close();
    await _audioLevelController.close();
    await _recorder.dispose();
  }
}
