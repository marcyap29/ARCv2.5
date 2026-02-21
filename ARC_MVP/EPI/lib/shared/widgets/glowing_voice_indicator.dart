import 'package:flutter/material.dart';

/// Glowing, throbbing voice indicator similar to ChatGPT
/// Supports custom icon/image with pulsing animation and glow effect
class GlowingVoiceIndicator extends StatefulWidget {
  final Widget? child; // Custom icon or image
  final IconData? icon; // Or use a standard icon
  final Color primaryColor;
  final Color glowColor;
  final double size;
  final bool isActive; // Controls whether animation is running
  final Duration pulseDuration;
  final double minScale;
  final double maxScale;
  final double glowRadius;
  final VoidCallback? onTap;
  
  const GlowingVoiceIndicator({
    super.key,
    this.child,
    this.icon,
    this.primaryColor = Colors.purple,
    this.glowColor = Colors.purpleAccent,
    this.size = 60,
    this.isActive = true,
    this.pulseDuration = const Duration(milliseconds: 1500),
    this.minScale = 0.95,
    this.maxScale = 1.05,
    this.glowRadius = 20,
    this.onTap,
  }) : assert(child != null || icon != null, 'Must provide either child or icon');

  @override
  State<GlowingVoiceIndicator> createState() => _GlowingVoiceIndicatorState();
}

class _GlowingVoiceIndicatorState extends State<GlowingVoiceIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Scale animation (throbbing effect)
    _pulseController = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Glow animation (opacity pulsing)
    _glowController = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );
    
    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isActive) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  void _stopAnimation() {
    _pulseController.stop();
    _glowController.stop();
  }

  @override
  void didUpdateWidget(GlowingVoiceIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget indicator = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow layers (multiple for intensity)
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  width: widget.size + (widget.glowRadius * (index + 1) * 0.5),
                  height: widget.size + (widget.glowRadius * (index + 1) * 0.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.glowColor.withOpacity(_opacityAnimation.value * (1 - index * 0.3)),
                        widget.glowColor.withOpacity(0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                );
              },
            );
          }),
          
          // Main icon with scale animation
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: widget.child ?? Icon(
                widget.icon,
                color: Colors.white,
                size: widget.size * 0.5,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: indicator,
      );
    }

    return indicator;
  }
}

/// Variant: ChatGPT-style sound wave indicator
class SoundWaveIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final bool isActive;
  final VoidCallback? onTap;
  
  const SoundWaveIndicator({
    super.key,
    this.color = Colors.purple,
    this.size = 60,
    this.isActive = true,
    this.onTap,
  });

  @override
  State<SoundWaveIndicator> createState() => _SoundWaveIndicatorState();
}

class _SoundWaveIndicatorState extends State<SoundWaveIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  
  @override
  void initState() {
    super.initState();
    
    // Create 5 bars with staggered animations
    _controllers = List.generate(5, (index) {
      return AnimationController(
        duration: Duration(milliseconds: 400 + (index * 100)),
        vsync: this,
      );
    });
    
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
    
    if (widget.isActive) {
      _startAnimation();
    }
  }
  
  void _startAnimation() {
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted && widget.isActive) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }
  
  void _stopAnimation() {
    for (var controller in _controllers) {
      controller.stop();
    }
  }
  
  @override
  void didUpdateWidget(SoundWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }
  
  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    Widget indicator = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: widget.size * 0.12,
                height: widget.size * _animations[index].value,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          );
        }),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: indicator,
      );
    }

    return indicator;
  }
}

