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
import 'audio_stream_capture.dart';

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
  StreamSubscription<Uint8List>? _audioSubscription;
  ProviderStatus _status = ProviderStatus.idle;
  bool _isListening = false;
  
  // Audio capture
  final AudioStreamCapture _audioCapture = AudioStreamCapture();
  
  // Callbacks
  Function(TranscriptSegment segment)? _onPartialResult;
  Function(TranscriptSegment segment)? _onFinalResult;
  Function(String error)? _onError;
  Function(double level)? _onSoundLevel;
  
  static const String _wsUrl = 'wss://streaming.assemblyai.com/v3/ws';
  
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
    
    // Check if audio capture has permission
    if (!await _audioCapture.hasPermission()) {
      debugPrint('AssemblyAI: No microphone permission');
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
      // Universal Streaming v3 uses token as query parameter, not Authorization header
      final wsUrlWithParams = Uri.parse(_wsUrl).replace(
        queryParameters: {
          'sample_rate': '16000',
          'token': _token,
        },
      );
      
      debugPrint('AssemblyAI: Connecting to WebSocket...');
      debugPrint('AssemblyAI: Token length: ${_token.length}, starts with: ${_token.substring(0, _token.length > 10 ? 10 : _token.length)}...');
      
      // Connect to AssemblyAI WebSocket
      // Universal Streaming v3 uses token in query parameter, no headers needed
      _webSocket = await WebSocket.connect(
        wsUrlWithParams.toString(),
      );
      
      debugPrint('AssemblyAI: WebSocket connected');
      
      _isListening = true;
      _status = ProviderStatus.listening;
      
      // Listen for messages from AssemblyAI
      _socketSubscription = _webSocket!.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('AssemblyAI WebSocket error: $error');
          _handleError('Connection error: $error');
        },
        onDone: () {
          debugPrint('AssemblyAI WebSocket closed (onDone callback)');
          _isListening = false;
          _status = ProviderStatus.idle;
        },
      );
      
      // Start audio capture and streaming
      await _startAudioCapture();
      
    } catch (e, stackTrace) {
      debugPrint('AssemblyAI connection error: $e');
      debugPrint('AssemblyAI connection stack trace: $stackTrace');
      _handleError('Failed to connect: $e');
      _status = ProviderStatus.error;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final messageStr = message as String;
      debugPrint('AssemblyAI: Received message: ${messageStr.substring(0, messageStr.length > 200 ? 200 : messageStr.length)}');
      
      final data = jsonDecode(messageStr) as Map<String, dynamic>;
      final messageType = data['message_type'] as String?;
      
      switch (messageType) {
        case _AssemblyAIMessage.sessionBegins:
          debugPrint('AssemblyAI session started: ${data['session_id']}');
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
          debugPrint('AssemblyAI session terminated');
          _isListening = false;
          _status = ProviderStatus.idle;
          break;
          
        case _AssemblyAIMessage.error:
          final errorMsg = data['error'] as String? ?? 'Unknown error';
          debugPrint('AssemblyAI: Error message received: $errorMsg');
          debugPrint('AssemblyAI: Full error data: $data');
          _handleError(errorMsg);
          break;
      }
    } catch (e) {
      debugPrint('Error parsing AssemblyAI message: $e');
    }
  }

  void _handleError(String error) {
    _status = ProviderStatus.error;
    _onError?.call(error);
  }

  /// Start capturing audio from microphone and stream to AssemblyAI
  Future<void> _startAudioCapture() async {
    debugPrint('AssemblyAI: Starting audio capture...');
    
    // Start the audio stream
    final audioStream = await _audioCapture.startCapture(
      onLevel: (level) {
        // Forward audio level to callback
        _onSoundLevel?.call(level);
      },
    );
    
    if (audioStream == null) {
      _handleError('Failed to start audio capture');
      return;
    }
    
    debugPrint('AssemblyAI: Audio capture started, streaming to WebSocket');
    
    // Listen to audio stream and send to AssemblyAI
    _audioSubscription = audioStream.listen(
      (audioData) {
        _sendAudioToWebSocket(audioData);
      },
      onError: (error) {
        debugPrint('AssemblyAI: Audio stream error: $error');
        _handleError('Audio capture error: $error');
      },
      onDone: () {
        debugPrint('AssemblyAI: Audio stream ended');
      },
    );
  }

  /// Send audio data to AssemblyAI WebSocket
  void _sendAudioToWebSocket(Uint8List audioData) {
    if (_webSocket != null && _isListening) {
      // AssemblyAI expects base64-encoded audio
      final base64Audio = base64Encode(audioData);
      _webSocket!.add(jsonEncode({'audio_data': base64Audio}));
    }
  }

  /// Public method to send audio data (for external audio sources)
  void sendAudio(Uint8List audioData) {
    _sendAudioToWebSocket(audioData);
  }

  @override
  Future<void> stopListening() async {
    _status = ProviderStatus.processing;
    
    // Stop audio capture first
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioCapture.stopCapture();
    
    // Send terminate message to AssemblyAI
    if (_webSocket != null) {
      try {
        _webSocket!.add(jsonEncode({'terminate_session': true}));
        // Give AssemblyAI time to process final audio
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('AssemblyAI: Error sending terminate: $e');
      }
    }
    
    await _cleanup();
    _status = ProviderStatus.idle;
  }

  @override
  Future<void> cancelListening() async {
    // Stop audio capture
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioCapture.stopCapture();
    
    await _cleanup();
    _status = ProviderStatus.idle;
  }

  Future<void> _cleanup() async {
    _isListening = false;
    
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    
    try {
      await _webSocket?.close();
    } catch (e) {
      debugPrint('AssemblyAI: Error closing WebSocket: $e');
    }
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
    await _audioSubscription?.cancel();
    await _audioCapture.dispose();
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
