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
      
      final uri = Uri.parse('wss://platform-api.wisprflow.ai/api/v1/dash/ws?api_key=Bearer ${_config.apiKey}');
      
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
      
    } catch (e) {
      debugPrint('WisprFlow: Connection failed: $e');
      _isConnected = false;
      onError?.call('Connection failed: $e');
      
      // Attempt reconnect
      if (_reconnectAttempts < _config.maxReconnectAttempts) {
        _reconnectAttempts++;
        debugPrint('WisprFlow: Reconnecting (attempt $_reconnectAttempts/${_config.maxReconnectAttempts})');
        await Future.delayed(_config.reconnectDelay);
        return await connect();
      }
      
      return false;
    }
  }
  
  /// Authenticate with Wispr
  Future<void> _authenticate() async {
    final authMessage = {
      'type': 'auth',
      'api_key': _config.apiKey,
    };
    
    _sendMessage(authMessage);
    
    // Wait for auth response (simple implementation)
    await Future.delayed(Duration(milliseconds: 500));
    _isAuthenticated = true;
  }
  
  /// Start a new transcription session
  Future<void> startSession({Map<String, dynamic>? context}) async {
    if (!_isAuthenticated) {
      throw StateError('Not authenticated. Call connect() first.');
    }
    
    if (_sessionActive) {
      debugPrint('WisprFlow: Session already active');
      return;
    }
    
    _audioPacketIndex = 0;
    _sessionActive = true;
    
    final startMessage = {
      'type': 'start',
      'audio_format': {
        'sample_rate': 16000,
        'encoding': 'pcm_s16le',
        'channels': 1,
      },
      'byte_encoding': _config.useBinaryEncoding ? 'binary' : 'base64',
      if (context != null) 'context': context,
    };
    
    _sendMessage(startMessage);
    debugPrint('WisprFlow: Session started');
  }
  
  /// Send audio chunk (16 kHz PCM audio)
  void sendAudio(Uint8List audioData) {
    if (!_sessionActive) {
      debugPrint('WisprFlow: Cannot send audio - session not active');
      return;
    }
    
    if (_metrics.firstAudioSent == null) {
      _metrics.firstAudioSent = DateTime.now();
    }
    
    // Encode audio
    final encodedAudio = _config.useBinaryEncoding 
        ? audioData 
        : base64Encode(audioData);
    
    final appendMessage = {
      'type': 'append',
      'audio': encodedAudio,
      'packet_index': _audioPacketIndex,
    };
    
    _sendMessage(appendMessage);
    _audioPacketIndex++;
    _metrics.audioPacketsSent++;
  }
  
  /// Commit the session (finalize transcription)
  Future<void> commitSession() async {
    if (!_sessionActive) {
      debugPrint('WisprFlow: No active session to commit');
      return;
    }
    
    final commitMessage = {
      'type': 'commit',
      'total_packets': _audioPacketIndex,
    };
    
    _sendMessage(commitMessage);
    debugPrint('WisprFlow: Session committed (${_audioPacketIndex} packets)');
    
    _sessionActive = false;
  }
  
  /// Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = message is String 
          ? jsonDecode(message) 
          : message;
      
      final type = data['type'] as String?;
      
      switch (type) {
        case 'partial':
        case 'interim':
          _handleTranscript(data, isFinal: false);
          break;
          
        case 'final':
        case 'transcription':
          _handleTranscript(data, isFinal: true);
          break;
          
        case 'error':
          final errorMsg = data['message'] as String? ?? 'Unknown error';
          debugPrint('WisprFlow: Server error: $errorMsg');
          onError?.call(errorMsg);
          break;
          
        case 'info':
          debugPrint('WisprFlow: Info: ${data['message']}');
          break;
          
        default:
          debugPrint('WisprFlow: Unknown message type: $type');
      }
      
    } catch (e) {
      debugPrint('WisprFlow: Error handling message: $e');
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
    
    final transcript = WisprTranscript(
      text: data['text'] as String? ?? '',
      isFinal: isFinal,
      confidence: data['confidence'] as double?,
      timestamp: DateTime.now(),
    );
    
    onTranscript?.call(transcript);
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
