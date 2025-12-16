/// TTS Client for Voice Journal
/// 
/// Handles text-to-speech for LUMARA responses.
/// Uses flutter_tts for local TTS playback.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_journal_state.dart';

/// TTS configuration
class TtsConfig {
  final String language;
  final double speechRate;
  final double volume;
  final double pitch;

  const TtsConfig({
    this.language = 'en-US',
    this.speechRate = 0.5,  // Slightly slower for journal reflection
    this.volume = 1.0,
    this.pitch = 1.0,
  });
}

/// Callback types for TTS events
typedef OnTtsStart = void Function();
typedef OnTtsComplete = void Function();
typedef OnTtsError = void Function(String error);
typedef OnTtsProgress = void Function(String word, int start, int end);

/// TTS Client for Voice Journal
/// 
/// Features:
/// - Configurable voice settings
/// - Latency tracking
/// - Progress callbacks for word highlighting
class TtsJournalClient {
  final FlutterTts _tts = FlutterTts();
  final TtsConfig _config;
  final VoiceLatencyMetrics _metrics;
  
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  
  // Callbacks
  OnTtsStart? _onStart;
  OnTtsComplete? _onComplete;
  OnTtsError? _onError;
  OnTtsProgress? _onProgress;
  
  // Completer for await-able speak
  Completer<void>? _speakCompleter;

  TtsJournalClient({
    TtsConfig config = const TtsConfig(),
    VoiceLatencyMetrics? metrics,
  })  : _config = config,
        _metrics = metrics ?? VoiceLatencyMetrics();

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;

  /// Initialize TTS engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Set language
      await _tts.setLanguage(_config.language);
      await _tts.setSpeechRate(_config.speechRate);
      await _tts.setVolume(_config.volume);
      await _tts.setPitch(_config.pitch);
      
      // Set up handlers
      _tts.setStartHandler(() {
        _isSpeaking = true;
        _isPaused = false;
        
        // Track first audio timing
        if (_metrics.ttsFirstAudio == null) {
          _metrics.ttsFirstAudio = DateTime.now();
        }
        
        _onStart?.call();
      });
      
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _isPaused = false;
        _onComplete?.call();
        _speakCompleter?.complete();
        _speakCompleter = null;
      });
      
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _isPaused = false;
        _onError?.call(msg);
        _speakCompleter?.completeError(msg);
        _speakCompleter = null;
      });
      
      _tts.setProgressHandler((text, start, end, word) {
        _onProgress?.call(word, start, end);
      });
      
      _isInitialized = true;
      debugPrint('TTS: Initialized');
      return true;
      
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      return false;
    }
  }

  /// Speak text
  /// 
  /// Returns a Future that completes when speaking is done.
  Future<void> speak(
    String text, {
    OnTtsStart? onStart,
    OnTtsComplete? onComplete,
    OnTtsError? onError,
    OnTtsProgress? onProgress,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    if (text.trim().isEmpty) {
      debugPrint('TTS: Empty text, skipping');
      return;
    }
    
    _onStart = onStart;
    _onComplete = onComplete;
    _onError = onError;
    _onProgress = onProgress;
    
    _metrics.ttsStart = DateTime.now();
    _speakCompleter = Completer<void>();
    
    debugPrint('TTS: Speaking ${text.length} chars');
    
    try {
      await _tts.speak(text);
      await _speakCompleter?.future;
    } catch (e) {
      debugPrint('TTS speak error: $e');
      _onError?.call('TTS error: $e');
    }
  }

  /// Speak text with streaming support
  /// 
  /// For long texts, this speaks in chunks to start playback faster.
  /// Good for streaming Gemini responses.
  Future<void> speakStreaming(
    Stream<String> textStream, {
    OnTtsStart? onStart,
    OnTtsComplete? onComplete,
    OnTtsError? onError,
    OnTtsProgress? onProgress,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final buffer = StringBuffer();
    bool firstChunkSpoken = false;
    
    _onStart = onStart;
    _onComplete = onComplete;
    _onError = onError;
    _onProgress = onProgress;
    
    _metrics.ttsStart = DateTime.now();
    
    await for (final chunk in textStream) {
      buffer.write(chunk);
      
      // Check if we have a complete sentence to speak
      final text = buffer.toString();
      final sentenceEnd = _findSentenceEnd(text);
      
      if (sentenceEnd > 0) {
        // Speak complete sentence
        final sentence = text.substring(0, sentenceEnd);
        final remainder = text.substring(sentenceEnd);
        
        buffer.clear();
        buffer.write(remainder);
        
        if (!firstChunkSpoken) {
          firstChunkSpoken = true;
          _onStart?.call();
        }
        
        _speakCompleter = Completer<void>();
        await _tts.speak(sentence);
        await _speakCompleter?.future;
      }
    }
    
    // Speak any remaining text
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      if (!firstChunkSpoken) {
        _onStart?.call();
      }
      
      _speakCompleter = Completer<void>();
      await _tts.speak(remaining);
      await _speakCompleter?.future;
    }
    
    _onComplete?.call();
  }

  /// Find the end of a complete sentence
  int _findSentenceEnd(String text) {
    // Look for sentence-ending punctuation followed by space or end of string
    final sentenceEnders = ['. ', '! ', '? ', '.\n', '!\n', '?\n'];
    
    int lastEnd = -1;
    for (final ender in sentenceEnders) {
      final index = text.lastIndexOf(ender);
      if (index > lastEnd) {
        lastEnd = index + ender.length;
      }
    }
    
    // Also check for end of string with punctuation
    if (text.endsWith('.') || text.endsWith('!') || text.endsWith('?')) {
      if (lastEnd < 0) {
        lastEnd = text.length;
      }
    }
    
    return lastEnd;
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
      _isPaused = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    if (_isSpeaking && !_isPaused) {
      await _tts.pause();
      _isPaused = true;
    }
  }

  /// Resume speaking
  Future<void> resume() async {
    // Note: flutter_tts doesn't have a resume method on all platforms
    // This is a placeholder for future implementation
    _isPaused = false;
  }

  /// Update voice settings
  Future<void> updateSettings({
    double? speechRate,
    double? volume,
    double? pitch,
  }) async {
    if (speechRate != null) await _tts.setSpeechRate(speechRate);
    if (volume != null) await _tts.setVolume(volume);
    if (pitch != null) await _tts.setPitch(pitch);
  }

  /// Get available voices
  Future<List<dynamic>> getVoices() async {
    return await _tts.getVoices;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }
}

