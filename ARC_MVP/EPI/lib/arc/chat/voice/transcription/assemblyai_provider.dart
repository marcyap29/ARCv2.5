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

/// AssemblyAI WebSocket message types (Universal Streaming v3)
class _AssemblyAIMessage {
  static const String begin = 'Begin';
  static const String turn = 'Turn'; // v3 uses Turn messages
  static const String partialTranscript = 'PartialTranscript'; // v2
  static const String finalTranscript = 'FinalTranscript'; // v2
  // Legacy v2 message types (for backward compatibility)
  static const String sessionBegins = 'SessionBegins';
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
  bool _sessionReady = false; // v3: wait for Begin message before sending audio
  
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
      // Add inactivity_timeout to prevent connection from closing if audio is delayed
      final wsUrlWithParams = Uri.parse(_wsUrl).replace(
        queryParameters: {
          'sample_rate': '16000',
          'token': _token,
          'inactivity_timeout': '30', // 30 seconds timeout to allow audio capture to start
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
          debugPrint('AssemblyAI: Error occurred - Session ready: $_sessionReady, Listening: $_isListening');
          _handleError('Connection error: $error');
        },
        onDone: () {
          debugPrint('AssemblyAI WebSocket closed (onDone callback)');
          debugPrint('AssemblyAI: Session was ready: $_sessionReady, was listening: $_isListening');
          _isListening = false;
          _sessionReady = false;
          _status = ProviderStatus.idle;
        },
      );
      
      // Start audio capture and streaming
      // Note: For v3, we should start sending audio as soon as Begin message is received
      // But we'll start capture now and it will begin sending once Begin is confirmed
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
      // Always log full message for debugging (v3 messages can be important)
      if (messageStr.length > 500) {
        debugPrint('AssemblyAI: Received message (${messageStr.length} chars): ${messageStr.substring(0, 500)}...');
      } else {
        debugPrint('AssemblyAI: Received message: $messageStr');
      }
      
      final data = jsonDecode(messageStr) as Map<String, dynamic>;
      // Universal Streaming v3 uses 'type', v2 uses 'message_type'
      final messageType = data['type'] as String? ?? data['message_type'] as String?;
      debugPrint('AssemblyAI: Message type: $messageType');
      
      switch (messageType) {
        case _AssemblyAIMessage.begin:
          // v3 Begin message - session started
          final sessionId = data['id'] as String?;
          final expiresAt = data['expires_at'] as int?;
          debugPrint('AssemblyAI v3 session started: id=$sessionId, expires_at=$expiresAt');
          // Session is ready, can now send audio
          _sessionReady = true;
          _isListening = true;
          _status = ProviderStatus.listening;
          _audioChunksSent = 0; // Reset counter
          debugPrint('AssemblyAI: Session ready, audio can now be sent (chunks sent so far: $_audioChunksSent)');
          break;
          
        case _AssemblyAIMessage.sessionBegins:
          // Legacy v2 message
          debugPrint('AssemblyAI v2 session started: ${data['session_id']}');
          break;
          
        case _AssemblyAIMessage.turn:
          // v3 Turn message - handles both partial and final transcripts
          debugPrint('AssemblyAI: Received Turn message');
          final transcript = data['transcript'] as String? ?? '';
          final endOfTurn = data['end_of_turn'] as bool? ?? false;
          final words = data['words'] as List<dynamic>?;
          
          debugPrint('AssemblyAI: Turn - transcript: "$transcript", end_of_turn: $endOfTurn, words: ${words?.length ?? 0}');
          
          if (transcript.isNotEmpty || (words != null && words.isNotEmpty)) {
            // Extract timing from words if available
            int? startMs;
            int? endMs;
            double? confidence;
            
            if (words != null && words.isNotEmpty) {
              final firstWord = words.first as Map<String, dynamic>?;
              final lastWord = words.last as Map<String, dynamic>?;
              startMs = ((firstWord?['start'] as num?)?.toDouble() ?? 0.0 * 1000).round();
              endMs = ((lastWord?['end'] as num?)?.toDouble() ?? 0.0 * 1000).round();
              // Use average confidence from words
              final confidences = words
                  .map((w) => (w as Map<String, dynamic>?)?['confidence'] as num?)
                  .whereType<num>()
                  .toList();
              if (confidences.isNotEmpty) {
                confidence = (confidences.reduce((a, b) => a + b) / confidences.length).toDouble();
              }
            }
            
            // Use transcript if available, otherwise build from words
            String text = transcript;
            if (text.isEmpty && words != null) {
              // Build transcript from final words
              final finalWords = words
                  .where((w) => (w as Map<String, dynamic>?)?['word_is_final'] == true)
                  .map((w) => (w as Map<String, dynamic>?)?['text'] as String?)
                  .whereType<String>()
                  .toList();
              text = finalWords.join(' ');
            }
            
            if (text.isNotEmpty) {
              debugPrint('AssemblyAI: Processing Turn transcript: "$text" (end_of_turn: $endOfTurn)');
              final segment = TranscriptSegment(
                text: _capitalizeText(text),
                isFinal: endOfTurn,
                startMs: startMs,
                endMs: endMs,
                confidence: confidence,
              );
              
              if (endOfTurn) {
                debugPrint('AssemblyAI: Calling onFinalResult with: "$text"');
                _onFinalResult?.call(segment);
              } else {
                debugPrint('AssemblyAI: Calling onPartialResult with: "$text"');
                _onPartialResult?.call(segment);
              }
            } else {
              debugPrint('AssemblyAI: Turn message has empty transcript, skipping');
            }
          }
          break;
          
        case _AssemblyAIMessage.partialTranscript:
          debugPrint('AssemblyAI: Received PartialTranscript message');
          // Handle both v3 and v2 formats
          String text;
          int? startMs;
          int? endMs;
          double? confidence;
          
          if (data.containsKey('transcript')) {
            // v3 format
            text = data['transcript'] as String? ?? '';
            debugPrint('AssemblyAI: v3 PartialTranscript - transcript: "$text"');
            final words = data['words'] as List<dynamic>?;
            debugPrint('AssemblyAI: v3 PartialTranscript - words count: ${words?.length ?? 0}');
            if (words != null && words.isNotEmpty) {
              final firstWord = words.first as Map<String, dynamic>?;
              final lastWord = words.last as Map<String, dynamic>?;
              startMs = ((firstWord?['start'] as num?)?.toDouble() ?? 0.0 * 1000).round();
              endMs = ((lastWord?['end'] as num?)?.toDouble() ?? 0.0 * 1000).round();
              // Use average confidence from words
              final confidences = words
                  .map((w) => (w as Map<String, dynamic>?)?['confidence'] as num?)
                  .whereType<num>()
                  .toList();
              if (confidences.isNotEmpty) {
                confidence = (confidences.reduce((a, b) => a + b) / confidences.length).toDouble();
              }
            }
          } else {
            // v2 format
            text = data['text'] as String? ?? '';
            debugPrint('AssemblyAI: v2 PartialTranscript - text: "$text"');
            startMs = data['audio_start'] as int?;
            endMs = data['audio_end'] as int?;
            confidence = (data['confidence'] as num?)?.toDouble();
          }
          
          if (text.isNotEmpty) {
            debugPrint('AssemblyAI: Calling onPartialResult with text: "$text"');
            final segment = TranscriptSegment(
              text: _capitalizeText(text),
              isFinal: false,
              startMs: startMs,
              endMs: endMs,
              confidence: confidence,
            );
            _onPartialResult?.call(segment);
          } else {
            debugPrint('AssemblyAI: PartialTranscript text is empty, skipping');
          }
          break;
          
        case _AssemblyAIMessage.finalTranscript:
          debugPrint('AssemblyAI: Received FinalTranscript message');
          // Handle both v3 and v2 formats
          String text;
          int? startMs;
          int? endMs;
          double? confidence;
          
          if (data.containsKey('transcript')) {
            // v3 format
            text = data['transcript'] as String? ?? '';
            debugPrint('AssemblyAI: v3 FinalTranscript - transcript: "$text"');
            final words = data['words'] as List<dynamic>?;
            debugPrint('AssemblyAI: v3 FinalTranscript - words count: ${words?.length ?? 0}');
            if (words != null && words.isNotEmpty) {
              final firstWord = words.first as Map<String, dynamic>?;
              final lastWord = words.last as Map<String, dynamic>?;
              startMs = ((firstWord?['start'] as num?)?.toDouble() ?? 0.0 * 1000).round();
              endMs = ((lastWord?['end'] as num?)?.toDouble() ?? 0.0 * 1000).round();
              // Use average confidence from words
              final confidences = words
                  .map((w) => (w as Map<String, dynamic>?)?['confidence'] as num?)
                  .whereType<num>()
                  .toList();
              if (confidences.isNotEmpty) {
                confidence = (confidences.reduce((a, b) => a + b) / confidences.length).toDouble();
              }
            }
          } else {
            // v2 format
            text = data['text'] as String? ?? '';
            debugPrint('AssemblyAI: v2 FinalTranscript - text: "$text"');
            startMs = data['audio_start'] as int?;
            endMs = data['audio_end'] as int?;
            confidence = (data['confidence'] as num?)?.toDouble();
          }
          
          if (text.isNotEmpty) {
            debugPrint('AssemblyAI: Calling onFinalResult with text: "$text"');
            final segment = TranscriptSegment(
              text: _capitalizeText(text),
              isFinal: true,
              startMs: startMs,
              endMs: endMs,
              confidence: confidence,
            );
            _onFinalResult?.call(segment);
          } else {
            debugPrint('AssemblyAI: FinalTranscript text is empty, skipping');
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
          
        default:
          debugPrint('AssemblyAI: Unknown message type: $messageType');
          debugPrint('AssemblyAI: Full message data: $data');
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('Error parsing AssemblyAI message: $e');
      debugPrint('Stack trace: $stackTrace');
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
        if (audioData.isNotEmpty) {
        _sendAudioToWebSocket(audioData);
        }
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

  int _audioChunksSent = 0;

  /// Send audio data to AssemblyAI WebSocket
  void _sendAudioToWebSocket(Uint8List audioData) {
    if (_webSocket != null && _isListening && _sessionReady) {
      try {
        // Universal Streaming v3 expects raw binary audio data (NOT base64 JSON)
        // Audio chunks should be 50-1000ms (100-450ms optimal)
        // At 16000Hz, 16-bit mono: 100ms = 3200 bytes, 450ms = 14400 bytes
        final chunkDurationMs = (audioData.length / (16000 * 2 / 1000)).round();
        // Send raw binary audio directly (v3 format)
        _webSocket!.add(audioData);
        _audioChunksSent++;
        if (_audioChunksSent <= 5 || _audioChunksSent % 10 == 0) {
          debugPrint('AssemblyAI: Sent chunk $_audioChunksSent (${audioData.length} bytes, ~${chunkDurationMs}ms)');
        }
      } catch (e) {
        debugPrint('AssemblyAI: Error sending audio data: $e');
        _handleError('Failed to send audio: $e');
      }
    } else if (!_sessionReady && _webSocket != null) {
      // Wait for Begin message - drop audio silently until session is ready
      // This is expected behavior for v3
      if (_audioChunksSent == 0) {
        debugPrint('AssemblyAI: Dropping audio chunks until Begin message received (session not ready yet)');
      }
    } else if (_webSocket == null) {
      debugPrint('AssemblyAI: Cannot send audio - WebSocket is null');
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
    _sessionReady = false;
    debugPrint('AssemblyAI: Cleanup - total audio chunks sent: $_audioChunksSent');
    _audioChunksSent = 0;
    
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
