import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../core/services/audio_service.dart';

class MusicControlSection extends StatefulWidget {
  const MusicControlSection({super.key});

  @override
  State<MusicControlSection> createState() => _MusicControlSectionState();
}

class _MusicControlSectionState extends State<MusicControlSection> {
  final AudioService _audioService = AudioService();
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  String _currentTrack = 'Intro Loop';

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioService.initialize();
      setState(() {
        _isInitialized = true;
        _isPlaying = _audioService.isPlaying;
        _isMuted = _audioService.isMuted;
        _currentTrack = _audioService.currentTrackName;
      });
    } catch (e) {
      print('ERROR: Failed to initialize audio service: $e');
      setState(() {
        _isInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Ethereal Music',
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Music Control Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              // Track Info
              Row(
                children: [
                  Icon(
                    Icons.music_note,
                    color: kcAccentColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isInitialized ? _currentTrack : 'Loading...',
                          style: heading3Style(context).copyWith(
                            color: kcPrimaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sacred ambient background music',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Control Buttons
              Row(
                children: [
                  // Play/Pause Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isInitialized ? _togglePlayback : null,
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isPlaying ? 'Pause' : 'Play',
                        style: bodyStyle(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kcAccentColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Mute/Unmute Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isInitialized ? _toggleMute : null,
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: _isMuted ? Colors.red : kcSecondaryTextColor,
                      ),
                      label: Text(
                        _isMuted ? 'Unmute' : 'Mute',
                        style: bodyStyle(context).copyWith(
                          color: _isMuted ? Colors.red : kcSecondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: _isMuted 
                              ? Colors.red.withOpacity(0.5)
                              : kcSecondaryTextColor.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Track Selection
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isInitialized ? _switchToEthereal : null,
                      icon: Icon(
                        Icons.spa,
                        color: _currentTrack == 'Ethereal Morning Coffee'
                            ? kcAccentColor 
                            : kcSecondaryTextColor,
                        size: 20,
                      ),
                      label: Text(
                        'Ethereal Track',
                        style: captionStyle(context).copyWith(
                          color: _currentTrack == 'Ethereal Morning Coffee'
                              ? kcAccentColor 
                              : kcSecondaryTextColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(
                          color: _currentTrack == 'Ethereal Morning Coffee'
                              ? kcAccentColor.withOpacity(0.5)
                              : kcSecondaryTextColor.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isInitialized ? _switchToIntro : null,
                      icon: Icon(
                        Icons.loop,
                        color: _currentTrack == 'Intro Loop'
                            ? kcAccentColor 
                            : kcSecondaryTextColor,
                        size: 20,
                      ),
                      label: Text(
                        'Intro Loop',
                        style: captionStyle(context).copyWith(
                          color: _currentTrack == 'Intro Loop'
                              ? kcAccentColor 
                              : kcSecondaryTextColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(
                          color: _currentTrack == 'Intro Loop'
                              ? kcAccentColor.withOpacity(0.5)
                              : kcSecondaryTextColor.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Fade In Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isInitialized ? _fadeInEthereal : null,
                  icon: const Icon(Icons.volume_up, size: 20),
                  label: const Text('Fade In Ethereal'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                      color: kcAccentColor.withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioService.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioService.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('ERROR: Failed to toggle playback: $e');
    }
  }

  Future<void> _toggleMute() async {
    try {
      if (_isMuted) {
        await _audioService.unmute();
        setState(() {
          _isMuted = false;
        });
      } else {
        await _audioService.mute();
        setState(() {
          _isMuted = true;
        });
      }
    } catch (e) {
      print('ERROR: Failed to toggle mute: $e');
    }
  }

  Future<void> _switchToEthereal() async {
    try {
      await _audioService.switchToEtherealTrack();
      setState(() {
        _currentTrack = 'Ethereal Morning Coffee';
      });
    } catch (e) {
      print('ERROR: Failed to switch to ethereal track: $e');
    }
  }

  Future<void> _switchToIntro() async {
    try {
      await _audioService.switchToIntroLoop();
      setState(() {
        _currentTrack = 'Intro Loop';
      });
    } catch (e) {
      print('ERROR: Failed to switch to intro loop: $e');
    }
  }

  Future<void> _fadeInEthereal() async {
    try {
      await _audioService.fadeInEthereal();
      setState(() {
        _currentTrack = 'Ethereal Morning Coffee';
        _isPlaying = true;
      });
    } catch (e) {
      print('ERROR: Failed to fade in ethereal: $e');
    }
  }
}
