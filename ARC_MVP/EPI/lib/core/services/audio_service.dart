/// Audio service for onboarding / welcome screen background audio.
/// Provides isAvailable, isMuted, pause, and resume for lifecycle handling.
library;

import 'package:audioplayers/audioplayers.dart';

/// Simple audio service for onboarding flow.
/// Handles background audio lifecycle (pause/resume) when app goes to background.
class AudioService {
  final AudioPlayer _player = AudioPlayer();

  bool _muted = false;

  /// Whether audio backend is available.
  bool get isAvailable => true;

  /// Whether audio is muted.
  bool get isMuted => _muted;

  /// Pause playback (e.g. when app goes to background).
  void pause() {
    _player.pause();
  }

  /// Resume playback (e.g. when app returns to foreground).
  Future<void> resume() async {
    if (!_muted) {
      try {
        await _player.resume();
      } catch (_) {
        // Ignore if nothing was playing
      }
    }
  }

  /// Set muted state.
  void setMuted(bool muted) {
    _muted = muted;
  }

  /// Fade out audio (e.g. when transitioning screens).
  Future<void> fadeOut() async {
    try {
      await _player.stop();
    } catch (_) {
      // Ignore if nothing was playing
    }
  }
}
