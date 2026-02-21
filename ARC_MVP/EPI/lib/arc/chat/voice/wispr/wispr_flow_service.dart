/// Wispr Flow WebSocket Service
/// 
/// Handles streaming audio transcription via Wispr Flow API
/// - WebSocket connection to wss://platform-api.wisprflow.ai/api/v1/dash/ws
/// - Streams 16 kHz PCM audio in 1-second chunks
/// - Receives partial and final transcripts in real-time
/// - Auto-reconnects on connection loss
/// - Tracks latency metrics

import 'dart:async';
import 'dart:convert';
import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Configuration for Wispr Flow service
class WisprFlowConfig {
  final String apiKey;
  final bool useBinaryEncoding;
  final Duration connectionTimeout;
  final int maxReconnectAttempts;
  final Duration reconnectDelay;
  
  const WisprFlowConfig({
    required this.apiKey,
    this.useBinaryEncoding = false, // Base64 by default
    this.connectionTimeout = const Duration(seconds: 10),
    this.maxReconnectAttempts = 3,
    this.reconnectDelay = const Duration(seconds: 2),
  });
}

/// Latency metrics for Wispr Flow
class WisprFlowMetrics {
  DateTime? sessionStart;
  DateTime? connectionEstablished;
  DateTime? firstAudioSent;
  DateTime? firstPartialReceived;
  DateTime? finalTranscriptReceived;
  
  int audioPacketsSent = 0;
  int partialTranscriptsReceived = 0;
  
  void reset() {
    sessionStart = null;
    connectionEstablished = null;
    firstAudioSent = null;
    firstPartialReceived = null;
    finalTranscriptReceived = null;
    audioPacketsSent = 0;
    partialTranscriptsReceived = 0;
  }
  
  Map<String, dynamic> toReport() {
    return {
      'time_to_connect_ms': _diffMs(sessionStart, connectionEstablished),
      'time_to_first_audio_ms': _diffMs(sessionStart, firstAudioSent),
      'time_to_first_partial_ms': _diffMs(sessionStart, firstPartialReceived),
      'time_to_final_ms': _diffMs(sessionStart, finalTranscriptReceived),
      'audio_packets_sent': audioPacketsSent,
      'partial_transcripts_received': partialTranscriptsReceived,
    };
  }
  
  int? _diffMs(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    return end.difference(start).inMilliseconds;
  }
}

/// Transcript chunk from Wispr
class WisprTranscript {
  final String text;
  final bool isFinal;
  final double? confidence;
  final DateTime timestamp;
  
  const WisprTranscript({
    required this.text,
    required this.isFinal,
    this.confidence,
    required this.timestamp,
  });
  
  factory WisprTranscript.fromJson(Map<String, dynamic> json) {
    return WisprTranscript(
      text: json['text'] as String? ?? '',
      isFinal: json['is_final'] as bool? ?? false,
      confidence: json['confidence'] as double?,
      timestamp: DateTime.now(),
    );
  }
}

/// Callback types
typedef OnWisprConnected = void Function();
typedef OnWisprTranscript = void Function(WisprTranscript transcript);
typedef OnWisprError = void Function(String error);
typedef OnWisprDisconnected = void Function();

/// Wispr Flow WebSocket Service
/// 
/// Provides real-time streaming transcription via Wispr Flow API
class WisprFlowService {
  final WisprFlowConfig _config;
  final WisprFlowMetrics _metrics = WisprFlowMetrics();
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  bool _sessionActive = false;
  int _reconnectAttempts = 0;
  int _audioPacketIndex = 0;
  
  // Callbacks
  OnWisprConnected? onConnected;
  OnWisprTranscript? onTranscript;
  OnWisprError? onError;
  OnWisprDisconnected? onDisconnected;
  
  // Stream controller for audio chunks
  final _audioController = StreamController<Uint8List>.broadcast();
  
  WisprFlowService({required WisprFlowConfig config}) : _config = config;
  
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get sessionActive => _sessionActive;
  WisprFlowMetrics get metrics => _metrics;
  
  /// Connect to Wispr Flow WebSocket
  Future<bool> connect() async {
    if (_isConnected) {
      debugPrint('WisprFlow: Already connected');
      return true;
    }
    
    try {
      _metrics.sessionStart = DateTime.now();
      
      // Wispr Flow API requires Bearer prefix in URL per documentation:
      // wss://platform-api.wisprflow.ai/api/v1/dash/ws?api_key=Bearer%20<API_KEY>
      // Use Uri constructor with queryParameters to ensure proper URL encoding
      final uri = Uri(
        scheme: 'wss',
        host: 'platform-api.wisprflow.ai',
        path: '/api/v1/dash/ws',
        queryParameters: {
          'api_key': 'Bearer ${_config.apiKey}',
        },
      );
      
      debugPrint('WisprFlow: Connecting to ${uri.toString().replaceAll(_config.apiKey, '***')}');
      
      _channel = WebSocketChannel.connect(uri);
      
      // Wait for connection with timeout
      await _channel!.ready.timeout(
        _config.connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );
      
      _isConnected = true;
      _metrics.connectionEstablished = DateTime.now();
      
      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );
      
      // Authenticate
      await _authenticate();
      
      debugPrint('WisprFlow: Connected successfully');
      onConnected?.call();
      
      _reconnectAttempts = 0;
      return true;
      
    } catch (e, stackTrace) {
      debugPrint('WisprFlow: Connection failed: $e');
      debugPrint('WisprFlow: Stack trace: $stackTrace');
      
      // Provide specific error diagnostics
      String errorDetail = 'Connection failed';
      if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        errorDetail = 'Connection timeout - check network connectivity';
      } else if (e.toString().contains('401') || e.toString().contains('unauthorized')) {
        errorDetail = 'Authentication failed - check your Wispr Flow API key';
      } else if (e.toString().contains('403') || e.toString().contains('forbidden')) {
        errorDetail = 'Access denied - your API key may be invalid or expired';
      } else if (e.toString().contains('WebSocket') || e.toString().contains('socket')) {
        errorDetail = 'WebSocket connection failed - check network/firewall settings';
      }
      
      debugPrint('WisprFlow: Error diagnosis: $errorDetail');
      _isConnected = false;
      onError?.call('$errorDetail: $e');
      
      // Attempt reconnect
      if (_reconnectAttempts < _config.maxReconnectAttempts) {
        _reconnectAttempts++;
        debugPrint('WisprFlow: Reconnecting (attempt $_reconnectAttempts/${_config.maxReconnectAttempts})');
        await Future.delayed(_config.reconnectDelay);
        return await connect();
      }
      
      debugPrint('WisprFlow: Max reconnect attempts reached, giving up');
      return false;
    }
  }
  
  /// Authenticate with Wispr
  /// Per Wispr Flow API docs: https://api-docs.wisprflow.ai/websocket_api
  /// Auth message: { "type": "auth", "access_token": "<TOKEN>", "language": ["en"] }
  Future<void> _authenticate() async {
    // Per Wispr Flow API documentation:
    // The auth message starts the session and includes language preference
    final authMessage = {
      'type': 'auth',
      'access_token': _config.apiKey,
      'language': ['en'],  // ISO 639-1 language codes
    };
    
    _sendMessage(authMessage);
    debugPrint('WisprFlow: Auth message sent: ${authMessage.toString().replaceAll(_config.apiKey, '***')}');
    
    // Wait a moment for any auth response
    // The _handleMessage will set _isAuthenticated if it receives an auth confirmation
    await Future.delayed(const Duration(milliseconds: 800));
    
    // If connection is still alive, assume we're authenticated
    // (some APIs don't send explicit auth confirmation)
    if (_isConnected) {
      if (!_isAuthenticated) {
        debugPrint('WisprFlow: No explicit auth response, assuming authenticated via URL parameter');
        _isAuthenticated = true;
      }
    } else {
      debugPrint('WisprFlow: Connection lost during auth - likely auth failure');
      throw StateError('Authentication failed - connection closed');
    }
  }
  
  /// Start a new transcription session
  /// Per Wispr Flow API docs: https://api-docs.wisprflow.ai/websocket_api
  /// There's no explicit "start" message - the auth message initiates the session
  /// Just reset state and mark session as active
  Future<void> startSession({Map<String, dynamic>? context}) async {
    if (!_isAuthenticated) {
      throw StateError('Not authenticated. Call connect() first.');
    }
    
    // If session is still active from previous turn, reset it first
    // This can happen if final transcript wasn't received yet
    if (_sessionActive) {
      debugPrint('WisprFlow: Previous session still active, resetting for new turn');
      _sessionActive = false;
      _audioPacketIndex = 0;
    }
    
    _audioPacketIndex = 0;
    _sessionActive = true;
    
    // Per Wispr Flow API, there's no explicit "start" message
    // The session begins with the auth message (already sent during connect)
    // Audio is sent via "append" messages, session ends with "commit"
    debugPrint('WisprFlow: Session started (ready for audio packets, index: $_audioPacketIndex)');
    
    // Send a small silence packet so the server receives at least one append and doesn't
    // close the connection (first-tap empty transcript fix: server may timeout if no audio).
    _sendKeepaliveSilence();
  }
  
  /// Send ~100ms of silence (16 kHz, mono, s16) so server gets at least one append and doesn't disconnect.
  void _sendKeepaliveSilence() {
    if (!_sessionActive || _channel == null || !_isConnected) return;
    // 100ms at 16kHz * 2 bytes/sample * 1 channel = 3200 bytes
    const int silenceSamples = 1600; // 100ms at 16kHz
    final silence = Uint8List(silenceSamples * 2); // s16 = 2 bytes per sample, already zeroed
    sendAudio(silence);
    debugPrint('WisprFlow: Sent keepalive silence packet (${silence.length} bytes)');
  }
  
  /// Send audio chunk (16 kHz PCM audio)
  /// Per Wispr Flow API docs: https://api-docs.wisprflow.ai/websocket_api
  /// Append message format:
  /// {
  ///   "type": "append",
  ///   "position": 0,
  ///   "audio_packets": {
  ///     "packets": ["<base64Chunk>"],
  ///     "volumes": [<volume>],  // Must match packets count!
  ///     "packet_duration": <seconds>,
  ///     "audio_encoding": "pcm_s16le",
  ///     "byte_encoding": "base64"
  ///   }
  /// }
  void sendAudio(Uint8List audioData) {
    if (!_sessionActive) {
      debugPrint('WisprFlow: Cannot send audio - session not active');
      return;
    }
    
    if (_metrics.firstAudioSent == null) {
      _metrics.firstAudioSent = DateTime.now();
    }
    
    // Encode audio as base64
    final encodedAudio = base64Encode(audioData);
    
    // Calculate packet duration: bytes / (sample_rate * bytes_per_sample * channels)
    // 16000 Hz * 2 bytes/sample * 1 channel = 32000 bytes/second
    final packetDuration = audioData.length / 32000.0;
    
    // Calculate volume (RMS of audio samples) - normalized 0.0 to 1.0
    final volume = _calculateVolume(audioData);
    
    // Per Wispr Flow API documentation
    // 'volumes' field MUST have same number of items as 'packets'
    // 'audio_encoding' must be 'wav' (not 'pcm_s16le')
    final appendMessage = {
      'type': 'append',
      'position': _audioPacketIndex,
      'audio_packets': {
        'packets': [encodedAudio],
        'volumes': [volume],  // Must match packets array length!
        'packet_duration': packetDuration,
        'audio_encoding': 'wav',  // Wispr expects 'wav' encoding
        'byte_encoding': 'base64',
      },
    };
    
    _sendMessage(appendMessage);
    _audioPacketIndex++;
    _metrics.audioPacketsSent++;
    
    // Log every 10th packet to avoid spam
    if (_audioPacketIndex % 10 == 0) {
      debugPrint('WisprFlow: Sent ${_audioPacketIndex} audio packets (volume: ${volume.toStringAsFixed(3)})');
    }
  }
  
  /// Calculate volume (RMS) from PCM audio data
  /// Returns normalized value 0.0 to 1.0
  double _calculateVolume(Uint8List audioData) {
    if (audioData.isEmpty) return 0.0;
    
    // Convert bytes to 16-bit samples (little-endian)
    final samples = <int>[];
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Little-endian 16-bit signed integer
      int sample = audioData[i] | (audioData[i + 1] << 8);
      // Convert to signed
      if (sample > 32767) sample -= 65536;
      samples.add(sample);
    }
    
    if (samples.isEmpty) return 0.0;
    
    // Calculate RMS (Root Mean Square)
    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    final rms = sqrt(sumSquares / samples.length);
    
    // Normalize to 0.0 - 1.0 (max 16-bit value is 32768)
    return (rms / 32768.0).clamp(0.0, 1.0);
  }
  
  /// Commit the session (finalize transcription)
  /// This tells Wispr we're done sending audio and to finalize the transcript
  Future<void> commitSession() async {
    if (!_sessionActive) {
      debugPrint('WisprFlow: No active session to commit');
      return;
    }
    
    final commitMessage = {
      'type': 'commit',
      'total_packets': _audioPacketIndex,
    };
    
    debugPrint('WisprFlow: Committing session with ${_audioPacketIndex} packets...');
    _sendMessage(commitMessage);
    debugPrint('WisprFlow: Commit message sent, waiting for final transcript...');
    
    // Don't immediately mark session as inactive - wait for transcript response
    // The session will be reset on disconnect or when we start a new session
    // _sessionActive = false;  // Commented out to allow receiving final transcript
  }
  
  /// Handle incoming messages
  /// Per Wispr Flow API docs: https://api-docs.wisprflow.ai/websocket_api
  /// Responses use 'status' field (not 'type'):
  /// - status: "auth" - authentication confirmed
  /// - status: "info" - informational events
  /// - status: "text" - transcription results (with final: true/false)
  /// - status: "error" - errors
  void _handleMessage(dynamic message) {
    try {
      // Log raw message for debugging
      final msgStr = message?.toString() ?? '';
      debugPrint('WisprFlow: Raw message: ${msgStr.substring(0, msgStr.length.clamp(0, 500))}');
      
      final Map<String, dynamic> data = message is String 
          ? jsonDecode(message) 
          : message;
      
      // Wispr Flow uses 'status' field for responses
      final status = data['status'] as String?;
      
      switch (status) {
        case 'auth':
          debugPrint('WisprFlow: Auth confirmed');
          _isAuthenticated = true;
          break;
          
        case 'info':
          final msgInfo = data['message'];
          debugPrint('WisprFlow: Info received: $msgInfo');
          debugPrint('WisprFlow: Full info data: $data');
          // Check for commit_received event
          if (msgInfo is Map && msgInfo['event'] == 'commit_received') {
            debugPrint('WisprFlow: Commit acknowledged, waiting for transcript...');
          }
          break;
          
        case 'text':
          // Transcription result
          final isFinal = data['final'] as bool? ?? false;
          final body = data['body'] as Map<String, dynamic>?;
          final text = body?['text'] as String? ?? data['text'] as String? ?? '';
          final detectedLang = body?['detected_language'] as String?;
          final position = data['position'];
          
          debugPrint('WisprFlow: ======== TEXT RESPONSE ========');
          debugPrint('WisprFlow: Text received - final=$isFinal, position=$position, lang=$detectedLang');
          debugPrint('WisprFlow: Content: "$text"');
          debugPrint('WisprFlow: Full data: $data');
          debugPrint('WisprFlow: ================================');
          
          _handleTranscript({
            'text': text,
            'detected_language': detectedLang,
          }, isFinal: isFinal);
          break;
          
        case 'error':
          final errorMsg = data['error'] as String? ?? data['message'] as String? ?? 'Unknown error';
          debugPrint('WisprFlow: Server error: $errorMsg');
          debugPrint('WisprFlow: Full error data: $data');
          onError?.call(errorMsg);
          break;
          
        default:
          // Log full message when status is unknown/null
          debugPrint('WisprFlow: Unknown status: $status');
          debugPrint('WisprFlow: Full message data: $data');
          
          // Check if it's using old 'type' field format
          final type = data['type'] as String?;
          if (type != null) {
            debugPrint('WisprFlow: Found type field instead: $type');
          }
          
          // Check if it's an error in disguise
          if (data.containsKey('error')) {
            final errorMsg = data['error'] as String? ?? 'Unknown error';
            debugPrint('WisprFlow: Error detected: $errorMsg');
            onError?.call(errorMsg);
          }
      }
      
    } catch (e) {
      debugPrint('WisprFlow: Error handling message: $e');
      debugPrint('WisprFlow: Original message: $message');
      onError?.call('Message handling error: $e');
    }
  }
  
  /// Handle transcript messages
  void _handleTranscript(Map<String, dynamic> data, {required bool isFinal}) {
    if (isFinal && _metrics.finalTranscriptReceived == null) {
      _metrics.finalTranscriptReceived = DateTime.now();
    } else if (!isFinal && _metrics.firstPartialReceived == null) {
      _metrics.firstPartialReceived = DateTime.now();
    }
    
    if (!isFinal) {
      _metrics.partialTranscriptsReceived++;
    }
    
    final text = data['text'] as String? ?? '';
    // Note: detected_language is available in data['detected_language'] if needed
    
    final transcript = WisprTranscript(
      text: text,
      isFinal: isFinal,
      confidence: data['confidence'] as double?,
      timestamp: DateTime.now(),
    );
    
    debugPrint('WisprFlow: Transcript callback - isFinal=$isFinal, text="${text.substring(0, text.length.clamp(0, 100))}"');
    onTranscript?.call(transcript);
    
    // IMPORTANT: Reset session state after final transcript is received
    // This allows the next turn to start properly
    if (isFinal) {
      debugPrint('WisprFlow: Final transcript received, resetting session state for next turn');
      _sessionActive = false;
      _audioPacketIndex = 0;
    }
  }
  
  /// Handle connection errors
  void _handleError(dynamic error) {
    debugPrint('WisprFlow: WebSocket error: $error');
    onError?.call('WebSocket error: $error');
  }
  
  /// Handle disconnection
  void _handleDisconnect() {
    debugPrint('WisprFlow: Disconnected');
    _isConnected = false;
    _isAuthenticated = false;
    _sessionActive = false;
    onDisconnected?.call();
  }
  
  /// Send message to WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      debugPrint('WisprFlow: Cannot send message - not connected');
      return;
    }
    
    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
    } catch (e) {
      debugPrint('WisprFlow: Error sending message: $e');
      onError?.call('Send error: $e');
    }
  }
  
  /// Disconnect from Wispr
  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    debugPrint('WisprFlow: Disconnecting');
    
    try {
      await _channel?.sink.close(status.normalClosure);
    } catch (e) {
      debugPrint('WisprFlow: Error during disconnect: $e');
    }
    
    _isConnected = false;
    _isAuthenticated = false;
    _sessionActive = false;
    _channel = null;
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _audioController.close();
    _metrics.reset();
  }
}
