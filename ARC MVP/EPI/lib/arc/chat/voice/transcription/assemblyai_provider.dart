/// AssemblyAI cloud streaming transcription provider
/// 
/// Uses AssemblyAI's Streaming Speech-to-Text API v3 for high-accuracy
/// real-time transcription. Requires network connectivity and valid token.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'transcription_provider.dart';

/// AssemblyAI WebSocket message types
class _AssemblyAIMessage {
  static const String sessionBegins = 'SessionBegins';
  static const String partialTranscript = 'PartialTranscript';
  static const String finalTranscript = 'FinalTranscript';
  static const String sessionTerminated = 'SessionTerminated';
  static const String error = 'Error';
}

class AssemblyAIProvider implements TranscriptionProvider {
  final String _token;
  
  WebSocket? _webSocket;
  StreamSubscription? _socketSubscription;
  ProviderStatus _status = ProviderStatus.idle;
  bool _isListening = false;
  
  // Callbacks
  Function(TranscriptSegment segment)? _onPartialResult;
  Function(TranscriptSegment segment)? _onFinalResult;
  Function(String error)? _onError;
  Function(double level)? _onSoundLevel;
  
  // Audio recording (platform-specific implementation needed)
  // For now, this is a placeholder - actual audio capture needs platform channels
  
  static const String _wsUrl = 'wss://api.assemblyai.com/v2/realtime/ws';
  
  AssemblyAIProvider({required String token}) : _token = token;
  
  @override
  String get name => 'AssemblyAI Cloud';
  
  @override
  bool get requiresNetwork => true;
  
  @override
  ProviderStatus get status => _status;
  
  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize() async {
    if (_token.isEmpty) {
      _status = ProviderStatus.unavailable;
      return false;
    }
    _status = ProviderStatus.idle;
    return true;
  }

  @override
  Future<void> startListening({
    required Function(TranscriptSegment segment) onPartialResult,
    required Function(TranscriptSegment segment) onFinalResult,
    Function(String error)? onError,
    Function(double level)? onSoundLevel,
  }) async {
    _onPartialResult = onPartialResult;
    _onFinalResult = onFinalResult;
    _onError = onError;
    _onSoundLevel = onSoundLevel;
    
    _status = ProviderStatus.initializing;
    
    try {
      // Build WebSocket URL with token and configuration
      final wsUrlWithParams = Uri.parse(_wsUrl).replace(
        queryParameters: {
          'sample_rate': '16000',
          'encoding': 'pcm_s16le',
        },
      );
      
      // Connect to AssemblyAI WebSocket
      _webSocket = await WebSocket.connect(
        wsUrlWithParams.toString(),
        headers: {
          'Authorization': _token,
        },
      );
      
      _isListening = true;
      _status = ProviderStatus.listening;
      
      // Listen for messages from AssemblyAI
      _socketSubscription = _webSocket!.listen(
        _handleMessage,
        onError: (error) {
          print('AssemblyAI WebSocket error: $error');
          _handleError('Connection error: $error');
        },
        onDone: () {
          print('AssemblyAI WebSocket closed');
          _isListening = false;
          _status = ProviderStatus.idle;
        },
      );
      
      // Start audio capture and streaming
      // NOTE: This requires platform-specific implementation
      // For iOS: AVAudioEngine or similar
      // For Android: AudioRecord
      // This is a placeholder - actual implementation needs native code
      _startAudioCapture();
      
    } catch (e) {
      print('AssemblyAI connection error: $e');
      _handleError('Failed to connect: $e');
      _status = ProviderStatus.error;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final messageType = data['message_type'] as String?;
      
      switch (messageType) {
        case _AssemblyAIMessage.sessionBegins:
          print('AssemblyAI session started: ${data['session_id']}');
          break;
          
        case _AssemblyAIMessage.partialTranscript:
          final text = data['text'] as String? ?? '';
          if (text.isNotEmpty) {
            final segment = TranscriptSegment(
              text: _capitalizeText(text),
              isFinal: false,
              startMs: data['audio_start'] as int?,
              endMs: data['audio_end'] as int?,
              confidence: (data['confidence'] as num?)?.toDouble(),
            );
            _onPartialResult?.call(segment);
          }
          break;
          
        case _AssemblyAIMessage.finalTranscript:
          final text = data['text'] as String? ?? '';
          if (text.isNotEmpty) {
            final segment = TranscriptSegment(
              text: _capitalizeText(text),
              isFinal: true,
              startMs: data['audio_start'] as int?,
              endMs: data['audio_end'] as int?,
              confidence: (data['confidence'] as num?)?.toDouble(),
            );
            _onFinalResult?.call(segment);
          }
          break;
          
        case _AssemblyAIMessage.sessionTerminated:
          print('AssemblyAI session terminated');
          _isListening = false;
          _status = ProviderStatus.idle;
          break;
          
        case _AssemblyAIMessage.error:
          final errorMsg = data['error'] as String? ?? 'Unknown error';
          _handleError(errorMsg);
          break;
      }
    } catch (e) {
      print('Error parsing AssemblyAI message: $e');
    }
  }

  void _handleError(String error) {
    _status = ProviderStatus.error;
    _onError?.call(error);
  }

  /// Start capturing audio from microphone
  /// NOTE: This is a placeholder - needs platform-specific implementation
  void _startAudioCapture() {
    // TODO: Implement platform-specific audio capture
    // 
    // For Flutter, options include:
    // 1. flutter_sound package for recording
    // 2. Custom platform channels to AVAudioEngine (iOS) / AudioRecord (Android)
    // 3. record package
    //
    // Audio must be:
    // - PCM 16-bit signed little-endian
    // - 16000 Hz sample rate
    // - Mono channel
    //
    // Send audio chunks to WebSocket:
    // _webSocket?.add(audioBytes);
    //
    // Call _onSoundLevel with normalized audio level (0.0-1.0) for visualization
    // Example: _onSoundLevel?.call(normalizedLevel);
    
    print('AssemblyAI: Audio capture placeholder - needs platform implementation');
    // Placeholder: notify that sound level callback is available
    _onSoundLevel?.call(0.0);
  }

  /// Send audio data to AssemblyAI
  void sendAudio(Uint8List audioData) {
    if (_webSocket != null && _isListening) {
      // AssemblyAI expects base64-encoded audio
      final base64Audio = base64Encode(audioData);
      _webSocket!.add(jsonEncode({'audio_data': base64Audio}));
    }
  }

  @override
  Future<void> stopListening() async {
    _status = ProviderStatus.processing;
    
    // Send terminate message
    if (_webSocket != null) {
      _webSocket!.add(jsonEncode({'terminate_session': true}));
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    await _cleanup();
    _status = ProviderStatus.idle;
  }

  @override
  Future<void> cancelListening() async {
    await _cleanup();
    _status = ProviderStatus.idle;
  }

  Future<void> _cleanup() async {
    _isListening = false;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _webSocket?.close();
    _webSocket = null;
  }

  @override
  Future<bool> isAvailable() async {
    // Check if we have a valid token and network
    if (_token.isEmpty) return false;
    
    // Simple connectivity check
    try {
      final result = await InternetAddress.lookup('api.assemblyai.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await _cleanup();
  }

  /// Capitalize text with sentence capitalization
  String _capitalizeText(String text) {
    if (text.isEmpty) return text;
    
    final sentencePattern = RegExp(r'([.!?]\s*)');
    final parts = text.split(sentencePattern);
    
    final buffer = StringBuffer();
    bool capitalizeNext = true;
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      
      if (part.isEmpty) continue;
      
      if (sentencePattern.hasMatch(part)) {
        buffer.write(part);
        capitalizeNext = true;
      } else {
        if (capitalizeNext && part.isNotEmpty) {
          final firstChar = part[0].toUpperCase();
          final rest = part.length > 1 ? part.substring(1) : '';
          buffer.write(firstChar + rest);
          capitalizeNext = false;
        } else {
          buffer.write(part);
        }
      }
    }
    
    final result = buffer.toString();
    if (result.isNotEmpty && result[0] != result[0].toUpperCase()) {
      return result[0].toUpperCase() + (result.length > 1 ? result.substring(1) : '');
    }
    
    return result.isNotEmpty ? result : text;
  }
}
