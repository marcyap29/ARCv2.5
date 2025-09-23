import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class DebriefBreathWidget extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback? onSkipped;
  
  const DebriefBreathWidget({
    super.key,
    required this.onCompleted,
    this.onSkipped,
  });

  @override
  State<DebriefBreathWidget> createState() => _DebriefBreathWidgetState();
}

class _DebriefBreathWidgetState extends State<DebriefBreathWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  
  int _completedCycles = 0;
  bool _isInhaling = true;
  bool _hasStarted = false;
  
  // Breathing pattern: 4-4 box breathing (inhale 4s, hold 2s, exhale 4s, hold 2s)
  static const int _inhaleDuration = 4;
  static const int _holdAfterInhaleDuration = 1;
  static const int _exhaleDuration = 4;
  static const int _holdAfterExhaleDuration = 1;
  static const int _totalCycleDuration = _inhaleDuration + _holdAfterInhaleDuration + _exhaleDuration + _holdAfterExhaleDuration;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: _totalCycleDuration),
      vsync: this,
    );
    
    // Scale animation for breathing circle
    _scaleAnimation = TweenSequence<double>([
      // Inhale - grow
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _inhaleDuration / _totalCycleDuration,
      ),
      // Hold after inhale
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: _holdAfterInhaleDuration / _totalCycleDuration,
      ),
      // Exhale - shrink
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _exhaleDuration / _totalCycleDuration,
      ),
      // Hold after exhale
      TweenSequenceItem(
        tween: ConstantTween<double>(0.7),
        weight: _holdAfterExhaleDuration / _totalCycleDuration,
      ),
    ]).animate(_controller);
    
    // Color animation for breathing states
    _colorAnimation = TweenSequence<Color?>([
      // Inhale - blue
      TweenSequenceItem(
        tween: ColorTween(begin: kcPrimaryColor.withOpacity(0.3), end: kcPrimaryColor.withOpacity(0.8)),
        weight: _inhaleDuration / _totalCycleDuration,
      ),
      // Hold after inhale - hold blue
      TweenSequenceItem(
        tween: ConstantTween<Color?>(kcPrimaryColor.withOpacity(0.8)),
        weight: _holdAfterInhaleDuration / _totalCycleDuration,
      ),
      // Exhale - green
      TweenSequenceItem(
        tween: ColorTween(begin: kcPrimaryColor.withOpacity(0.8), end: const Color(0xFF6BE3A0).withOpacity(0.3)),
        weight: _exhaleDuration / _totalCycleDuration,
      ),
      // Hold after exhale - hold green
      TweenSequenceItem(
        tween: ConstantTween<Color?>(const Color(0xFF6BE3A0).withOpacity(0.3)),
        weight: _holdAfterExhaleDuration / _totalCycleDuration,
      ),
    ]).animate(_controller);
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _completedCycles++;
        });
        
        if (_completedCycles >= 2) {
          widget.onCompleted();
        } else {
          _controller.reset();
          _controller.forward();
        }
      }
    });
    
    // Listen to animation progress for breathing instructions
    _controller.addListener(() {
      final progress = _controller.value;
      const inhaleEnd = _inhaleDuration / _totalCycleDuration;
      const holdAfterInhaleEnd = inhaleEnd + (_holdAfterInhaleDuration / _totalCycleDuration);
      const exhaleEnd = holdAfterInhaleEnd + (_exhaleDuration / _totalCycleDuration);
      
      bool newIsInhaling;
      if (progress <= inhaleEnd) {
        newIsInhaling = true; // Inhaling
      } else if (progress <= holdAfterInhaleEnd) {
        newIsInhaling = true; // Hold after inhale (still showing inhale)
      } else if (progress <= exhaleEnd) {
        newIsInhaling = false; // Exhaling
      } else {
        newIsInhaling = false; // Hold after exhale (still showing exhale)
      }
      
      if (newIsInhaling != _isInhaling) {
        setState(() {
          _isInhaling = newIsInhaling;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startBreathing() {
    setState(() {
      _hasStarted = true;
    });
    _controller.forward();
  }

  String get _instructionText {
    if (!_hasStarted) return 'Ready to breathe?';
    
    final progress = _controller.value;
    const inhaleEnd = _inhaleDuration / _totalCycleDuration;
    const holdAfterInhaleEnd = inhaleEnd + (_holdAfterInhaleDuration / _totalCycleDuration);
    const exhaleEnd = holdAfterInhaleEnd + (_exhaleDuration / _totalCycleDuration);
    
    if (progress <= inhaleEnd) {
      return 'Breathe in...';
    } else if (progress <= holdAfterInhaleEnd) {
      return 'Hold...';
    } else if (progress <= exhaleEnd) {
      return 'Breathe out...';
    } else {
      return 'Hold...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        
        // Progress indicator
        Text(
          'Breath ${_completedCycles + 1} of 2',
          style: captionStyle(context).copyWith(
            color: kcSecondaryColor,
            fontSize: 14,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Breathing circle
        GestureDetector(
          onTap: _hasStarted ? null : _startBreathing,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring (static)
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kcSecondaryColor.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    
                    // Breathing circle (animated)
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _colorAnimation.value,
                          boxShadow: [
                            BoxShadow(
                              color: (_colorAnimation.value ?? kcPrimaryColor).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Start tap area (when not started)
                    if (!_hasStarted)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white.withOpacity(0.8),
                          size: 40,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Instruction text
        Text(
          _instructionText,
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Microcopy
        Text(
          _hasStarted ? 'Follow the circle' : 'Tap to begin',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryColor,
            fontSize: 14,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Skip button
        TextButton(
          onPressed: widget.onSkipped,
          child: Text(
            'Skip breathing',
            style: captionStyle(context).copyWith(
              color: kcSecondaryColor,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}