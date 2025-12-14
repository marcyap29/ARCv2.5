import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../voice/push_to_talk_controller.dart';

/// Animated voice orb widget inspired by ChatGPT
/// Shows small button with equalizer bars when idle, expands to animated orb when active
class AnimatedVoiceOrb extends StatefulWidget {
  final VCState state;
  final double? audioLevel; // 0.0 to 1.0 for real-time audio visualization
  final VoidCallback? onTap;
  final bool isEnabled;

  const AnimatedVoiceOrb({
    super.key,
    required this.state,
    this.audioLevel,
    this.onTap,
    this.isEnabled = true,
  });

  @override
  State<AnimatedVoiceOrb> createState() => _AnimatedVoiceOrbState();
}

enum _OrbState { idle, recording, processing, speaking }

class _AnimatedVoiceOrbState extends State<AnimatedVoiceOrb>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  _OrbState _currentOrbState = _OrbState.idle;
  double _currentAudioLevel = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Expansion animation (idle -> expanded)
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0, // Small button size
      end: 2.5, // Expanded orb size
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ));
    
    // Pulse animation for active states
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _updateOrbState();
  }

  @override
  void didUpdateWidget(AnimatedVoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state || widget.audioLevel != oldWidget.audioLevel) {
      _updateOrbState();
      if (widget.audioLevel != null) {
        _currentAudioLevel = widget.audioLevel!;
      }
    }
  }

  void _updateOrbState() {
    _OrbState newState;
    
    switch (widget.state) {
      case VCState.idle:
        newState = _OrbState.idle;
        break;
      case VCState.listening:
        newState = _OrbState.recording;
        break;
      case VCState.thinking:
        newState = _OrbState.processing;
        break;
      case VCState.speaking:
        newState = _OrbState.speaking;
        break;
      case VCState.error:
        newState = _OrbState.idle;
        break;
    }
    
    if (newState != _currentOrbState) {
      setState(() {
        _currentOrbState = newState;
      });
      
      // Animate expansion/contraction
      if (newState == _OrbState.idle) {
        _expandController.reverse();
      } else {
        _expandController.forward();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color _getOrbColor() {
    switch (_currentOrbState) {
      case _OrbState.idle:
        return const Color(0xFF2196F3); // Blue like ChatGPT
      case _OrbState.recording:
        return Colors.red;
      case _OrbState.processing:
        return Colors.amber;
      case _OrbState.speaking:
        return Colors.grey;
    }
  }

  Color _getGlowColor() {
    switch (_currentOrbState) {
      case _OrbState.idle:
        return const Color(0xFF42A5F5);
      case _OrbState.recording:
        return Colors.redAccent;
      case _OrbState.processing:
        return Colors.orangeAccent;
      case _OrbState.speaking:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseSize = 60.0;
    final orbColor = _getOrbColor();
    final glowColor = _getGlowColor();
    final isExpanded = _expandController.value > 0.1;
    
    return GestureDetector(
      onTap: widget.isEnabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _expandController,
          _pulseController,
          _glowController,
        ]),
        builder: (context, child) {
          final scale = _scaleAnimation.value;
          final currentSize = baseSize * scale;
          
          if (!isExpanded) {
            // Idle state: Small button with equalizer bars
            return _buildIdleButton(baseSize, orbColor);
          } else {
            // Expanded state: Animated orb
            return _buildExpandedOrb(currentSize, orbColor, glowColor);
          }
        },
      ),
    );
  }

  /// Build idle state: Small circular button with equalizer bars
  Widget _buildIdleButton(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: _buildEqualizerBars(size * 0.4, Colors.white),
      ),
    );
  }

  /// Build equalizer bars (3 vertical bars of varying heights)
  Widget _buildEqualizerBars(double width, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(3, (index) {
        final heights = [0.6, 1.0, 0.7]; // Different heights for visual interest
        return Container(
          width: width * 0.2,
          height: width * heights[index],
          margin: EdgeInsets.symmetric(horizontal: width * 0.05),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// Build expanded orb with audio visualization
  Widget _buildExpandedOrb(double size, Color orbColor, Color glowColor) {
    // Calculate pulse based on audio level or default pulse
    double pulseScale = 1.0;
    if (_currentOrbState == _OrbState.recording && _currentAudioLevel > 0) {
      // Use real audio level for responsive pulsing
      pulseScale = 1.0 + (_currentAudioLevel * 0.3); // Scale from 1.0 to 1.3
    } else if (_currentOrbState == _OrbState.processing) {
      // Processing: gentle pulse
      pulseScale = 1.0 + (_pulseController.value * 0.15);
    } else if (_currentOrbState == _OrbState.speaking) {
      // Speaking: dimmed, minimal pulse
      pulseScale = 0.9 + (_pulseController.value * 0.05);
    } else {
      // Default: gentle pulse
      pulseScale = 1.0 + (_pulseController.value * 0.1);
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow layers
        ...List.generate(3, (index) {
          return Container(
            width: size + (20 * (index + 1)),
            height: size + (20 * (index + 1)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  glowColor.withOpacity(_glowAnimation.value * (1 - index * 0.3)),
                  glowColor.withOpacity(0),
                ],
                stops: const [0.5, 1.0],
              ),
            ),
          );
        }),
        
        // Main orb with pulse
        Transform.scale(
          scale: pulseScale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  orbColor,
                  orbColor.withOpacity(0.8),
                ],
                stops: const [0.0, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(_glowAnimation.value * 0.6),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: _currentOrbState == _OrbState.recording
                ? _buildAudioVisualization(size, orbColor)
                : _currentOrbState == _OrbState.processing
                    ? _buildProcessingIndicator(size)
                    : null,
          ),
        ),
      ],
    );
  }

  /// Build audio visualization inside orb (oscilloscope-like)
  Widget _buildAudioVisualization(double size, Color color) {
    // Create animated bars based on audio level
    final barCount = 8;
    final barWidth = size / (barCount * 2);
    
    return CustomPaint(
      size: Size(size, size),
      painter: _AudioVisualizationPainter(
        audioLevel: _currentAudioLevel,
        color: Colors.white.withOpacity(0.9),
        barCount: barCount,
        barWidth: barWidth,
      ),
    );
  }

  /// Build processing indicator (spinning or pulsing)
  Widget _buildProcessingIndicator(double size) {
    return Center(
      child: SizedBox(
        width: size * 0.4,
        height: size * 0.4,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

/// Custom painter for audio visualization (oscilloscope effect)
class _AudioVisualizationPainter extends CustomPainter {
  final double audioLevel;
  final Color color;
  final int barCount;
  final double barWidth;

  _AudioVisualizationPainter({
    required this.audioLevel,
    required this.color,
    required this.barCount,
    required this.barWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final centerY = size.height / 2;
    final spacing = size.width / (barCount + 1);
    
    // Create bars with varying heights based on audio level
    for (int i = 0; i < barCount; i++) {
      // Simulate oscilloscope effect with sine wave pattern
      final phase = (i / barCount) * 2 * math.pi;
      final heightFactor = (math.sin(phase + audioLevel * 10) + 1) / 2;
      final barHeight = (size.height * 0.3) * (0.3 + heightFactor * audioLevel);
      
      final x = spacing * (i + 1) - barWidth / 2;
      final y = centerY - barHeight / 2;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AudioVisualizationPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel;
  }
}
