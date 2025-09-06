import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing ethereal intro music playback
/// Handles audio playback, fading, muting, and persistence
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static const String _muteKey = 'intro_audio_muted';
  static const String _assetPath = 'assets/audio/intro_loop.mp3';
  static const String _etherealTrack = 'assets/audio/ES_Smell of Morning Coffee - Franz Gordon.mp3';
  
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isPlaying = false;
  String _currentTrack = _etherealTrack; // Default to ethereal track

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioPlayer = AudioPlayer();
      // Try to set the ethereal track first (P22 - Ethereal Music)
      try {
        await _audioPlayer!.setAsset(_etherealTrack);
        await _audioPlayer!.setLoopMode(LoopMode.one);
        await _audioPlayer!.setVolume(0.5); // Default volume
        _currentTrack = _etherealTrack;
      } catch (e) {
        // Fallback to intro loop if ethereal track not found
        try {
          await _audioPlayer!.setAsset(_assetPath);
          await _audioPlayer!.setLoopMode(LoopMode.one);
          await _audioPlayer!.setVolume(0.5); // Default volume
          _currentTrack = _assetPath;
        } catch (e2) {
          print('WARNING: No audio assets found - Audio service will be disabled');
          _audioPlayer = null;
          _isInitialized = true;
          return;
        }
      }
      
      // Load mute preference
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool(_muteKey) ?? false;
      
      if (_isMuted) {
        await _audioPlayer!.setVolume(0.0);
      }
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('AudioService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AudioService initialization failed: $e');
      }
      _isInitialized = false;
    }
  }

  /// Start playing the intro music
  Future<void> play() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_audioPlayer == null || _isMuted) return;

    try {
      await _audioPlayer!.play();
      _isPlaying = true;
      
      if (kDebugMode) {
        print('Intro music started playing');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to play intro music: $e');
      }
    }
  }

  /// Stop playing the intro music
  Future<void> stop() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.stop();
      _isPlaying = false;
      
      if (kDebugMode) {
        print('Intro music stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to stop intro music: $e');
      }
    }
  }

  /// Pause the intro music
  Future<void> pause() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.pause();
      _isPlaying = false;
      
      if (kDebugMode) {
        print('Intro music paused');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to pause intro music: $e');
      }
    }
  }

  /// Resume the intro music
  Future<void> resume() async {
    if (_audioPlayer == null || _isMuted) return;

    try {
      await _audioPlayer!.play();
      _isPlaying = true;
      
      if (kDebugMode) {
        print('Intro music resumed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to resume intro music: $e');
      }
    }
  }

  /// Fade out the intro music over the specified duration
  Future<void> fadeOut({Duration duration = const Duration(seconds: 2)}) async {
    if (_audioPlayer == null) return;

    try {
      const steps = 20; // Number of fade steps
      final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
      final volumeStep = _audioPlayer!.volume / steps;

      for (int i = 0; i < steps; i++) {
        await Future.delayed(stepDuration);
        if (_audioPlayer != null) {
          final newVolume = (_audioPlayer!.volume - volumeStep).clamp(0.0, 1.0);
          await _audioPlayer!.setVolume(newVolume);
        }
      }

      await stop();
      
      if (kDebugMode) {
        print('Intro music faded out over ${duration.inSeconds} seconds');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to fade out intro music: $e');
      }
    }
  }

  /// Mute audio
  Future<void> mute() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_audioPlayer == null || _isMuted) return;

    try {
      _isMuted = true;
      await _audioPlayer!.setVolume(0.0);
      
      // Save mute preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey, _isMuted);
      
      if (kDebugMode) {
        print('Audio muted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to mute audio: $e');
      }
    }
  }

  /// Unmute audio
  Future<void> unmute() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_audioPlayer == null || !_isMuted) return;

    try {
      _isMuted = false;
      await _audioPlayer!.setVolume(0.5); // Default volume
      
      // Save mute preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey, _isMuted);
      
      if (kDebugMode) {
        print('Audio unmuted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to unmute audio: $e');
      }
    }
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_audioPlayer == null) return;

    try {
      _isMuted = !_isMuted;
      
      if (_isMuted) {
        await _audioPlayer!.setVolume(0.0);
      } else {
        await _audioPlayer!.setVolume(0.5);
      }

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey, _isMuted);
      
      if (kDebugMode) {
        print('Intro music ${_isMuted ? "muted" : "unmuted"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to toggle mute: $e');
      }
    }
  }

  /// Set mute state
  Future<void> setMuted(bool muted) async {
    if (_isMuted == muted) return;
    
    await toggleMute();
  }

  /// Get current mute state
  bool get isMuted => _isMuted;

  /// Get current playing state
  bool get isPlaying => _isPlaying;

  /// Get current volume
  double get volume => _audioPlayer?.volume ?? 0.0;

  /// Check if audio is available
  bool get isAvailable => _isInitialized && _audioPlayer != null;

  /// Switch to ethereal track (P22 - Ethereal Music)
  Future<void> switchToEtherealTrack() async {
    if (!_isInitialized || _audioPlayer == null) return;
    
    try {
      await _audioPlayer!.setAsset(_etherealTrack);
      _currentTrack = _etherealTrack;
      
      if (kDebugMode) {
        print('Switched to ethereal track: $_etherealTrack');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error switching to ethereal track: $e');
      }
    }
  }

  /// Switch to intro loop track
  Future<void> switchToIntroLoop() async {
    if (!_isInitialized || _audioPlayer == null) return;
    
    try {
      await _audioPlayer!.setAsset(_assetPath);
      _currentTrack = _assetPath;
      
      if (kDebugMode) {
        print('Switched to intro loop: $_assetPath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error switching to intro loop: $e');
      }
    }
  }

  /// Get current track name
  String get currentTrackName {
    if (_currentTrack == _etherealTrack) {
      return 'Ethereal Morning Coffee';
    } else if (_currentTrack == _assetPath) {
      return 'Intro Loop';
    }
    return 'Unknown Track';
  }

  /// Check if ethereal track is currently playing
  bool get isEtherealTrackPlaying => _currentTrack == _etherealTrack;

  /// Set ethereal volume (lower for ambient background)
  Future<void> setEtherealVolume(double volume) async {
    if (!_isInitialized || _audioPlayer == null || _isMuted) return;
    
    // Clamp volume between 0.0 and 1.0
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _audioPlayer!.setVolume(clampedVolume);
    
    if (kDebugMode) {
      print('Ethereal volume set to: $clampedVolume');
    }
  }

  /// Fade in ethereal music gradually
  Future<void> fadeInEthereal({Duration duration = const Duration(seconds: 3)}) async {
    if (!_isInitialized || _audioPlayer == null || _isMuted) return;
    
    await switchToEtherealTrack();
    await play();
    
    // Start at 0 volume and fade in
    await _audioPlayer!.setVolume(0.0);
    
    const steps = 30;
    final stepDuration = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    final volumeStep = 0.3 / steps; // Fade to 30% volume
    
    for (int i = 0; i <= steps; i++) {
      await Future.delayed(stepDuration);
      final volume = (i * volumeStep).clamp(0.0, 0.3);
      await _audioPlayer!.setVolume(volume);
    }
    
    if (kDebugMode) {
      print('Ethereal music faded in over ${duration.inSeconds} seconds');
    }
  }

  /// Dispose of the audio service
  Future<void> dispose() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }
    _isInitialized = false;
    _isPlaying = false;
    
    if (kDebugMode) {
      print('AudioService disposed');
    }
  }
}

