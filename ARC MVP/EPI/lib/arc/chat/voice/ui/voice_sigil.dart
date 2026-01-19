/// Voice Sigil Widget
/// 
/// Main interactive voice UI element with sophisticated animations:
/// - IDLE: Gentle pulsing with orbital particles
/// - LISTENING: Breathing animation with inward-flowing particles
/// - COMMITMENT: Inner ring contracting with particles compressing
/// - ACCELERATING: Shimmer intensifies, particles accelerating inward
/// - THINKING: Constellation points appear, particles compressed
/// - SPEAKING: LUMARA speaking with outward-flowing particles
/// 
/// Uses the gold LUMARA sigil image as the center element

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../models/phase_models.dart';
import '../endpoint/smart_endpoint_detector.dart';
import 'commitment_ring_painter.dart';
import 'sigil_effects/sigil_particle_system.dart';
import 'sigil_effects/sigil_shimmer.dart';
import 'sigil_effects/constellation_points.dart';

/// Voice sigil animation state
enum VoiceSigilState {
  idle,
  listening,
  commitment,
  accelerating,
  thinking,
  speaking,
}

/// Voice Sigil Widget
/// 
/// The centerpiece of the voice interaction UI
class VoiceSigil extends StatefulWidget {
  final VoiceSigilState state;
  final PhaseLabel currentPhase;
  final double audioLevel; // 0.0 to 1.0
  final CommitmentLevel? commitmentLevel;
  final VoidCallback? onTap;
  final double size;
  
  const VoiceSigil({
    super.key,
    required this.state,
    required this.currentPhase,
    this.audioLevel = 0.0,
    this.commitmentLevel,
    this.onTap,
    this.size = 200.0,
  });
  
  @override
  State<VoiceSigil> createState() => _VoiceSigilState();
}

class _VoiceSigilState extends State<VoiceSigil> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _breathingController;
  late AnimationController _shimmerController;
  late AnimationController _thinkingController;
  late AnimationController _particleController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _shimmerAnimation;
  
  // Particle system
  final ParticleSystemManager _particleManager = ParticleSystemManager();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize particle system
    _particleManager.initialize(count: 25);
    
    // Idle pulse animation (gentle, slow)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Listening breathing animation (calm, rhythmic)
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    
    // Accelerating shimmer animation (faster, building)
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
    
    // Thinking spinner animation
    _thinkingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Particle system animation (continuous)
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    
    _startAppropriateAnimation();
  }
  
  @override
  void didUpdateWidget(VoiceSigil oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.state != widget.state) {
      _startAppropriateAnimation();
    }
  }
  
  void _startAppropriateAnimation() {
    // Stop all animations first
    _pulseController.stop();
    _breathingController.stop();
    _shimmerController.stop();
    _thinkingController.stop();
    
    // Start appropriate animation for current state
    switch (widget.state) {
      case VoiceSigilState.idle:
        _pulseController.repeat(reverse: true);
        break;
        
      case VoiceSigilState.listening:
        _breathingController.repeat(reverse: true);
        break;
        
      case VoiceSigilState.commitment:
        _breathingController.repeat(reverse: true);
        break;
        
      case VoiceSigilState.accelerating:
        _shimmerController.repeat();
        break;
        
      case VoiceSigilState.thinking:
        _thinkingController.repeat();
        break;
        
      case VoiceSigilState.speaking:
        _pulseController.repeat(reverse: true);
        break;
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _breathingController.dispose();
    _shimmerController.dispose();
    _thinkingController.dispose();
    _particleController.dispose();
    super.dispose();
  }
  
  Color _getPhaseColor() {
    // Return phase-appropriate colors
    switch (widget.currentPhase) {
      case PhaseLabel.recovery:
        return const Color(0xFF7E57C2); // Soft purple
      case PhaseLabel.transition:
        return const Color(0xFFFF9800); // Orange
      case PhaseLabel.discovery:
        return const Color(0xFF4CAF50); // Green
      case PhaseLabel.expansion:
        return const Color(0xFF2196F3); // Blue
      case PhaseLabel.consolidation:
        return const Color(0xFF9C27B0); // Purple
      case PhaseLabel.breakthrough:
        return const Color(0xFFFFD700); // Gold
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final phaseColor = _getPhaseColor();
    final flowDirection = _particleManager.getFlowDirection(widget.state);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Particle system layer (always present, behavior changes with state)
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: SigilParticleSystem(
                    state: widget.state,
                    phaseColor: phaseColor,
                    flowDirection: flowDirection,
                    animationValue: _particleController.value,
                    particles: _particleManager.particles,
                  ),
                );
              },
            ),
            
            // Audio-reactive ripples (listening state)
            if (widget.state == VoiceSigilState.listening)
              AnimatedBuilder(
                animation: _breathingController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: AudioReactiveRipplePainter(
                      audioLevel: widget.audioLevel,
                      animationValue: _breathingAnimation.value,
                      phaseColor: phaseColor,
                      isListening: true,
                    ),
                  );
                },
              ),
            
            // Shimmer effect (always present with varying intensity)
            AnimatedBuilder(
              animation: _shimmerController.isAnimating ? _shimmerController : _particleController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: SigilShimmer(
                    state: widget.state,
                    phaseColor: phaseColor,
                    animationValue: _shimmerController.isAnimating 
                        ? _shimmerAnimation.value 
                        : _particleController.value,
                  ),
                );
              },
            ),
            
            // Commitment ring (commitment & accelerating states)
            if (widget.commitmentLevel != null && 
                (widget.state == VoiceSigilState.commitment || 
                 widget.state == VoiceSigilState.accelerating))
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: CommitmentRingPainter(
                  commitmentLevel: widget.commitmentLevel!.level,
                  isShowingIntent: true,
                  phaseColor: phaseColor,
                ),
              ),
            
            // Main sigil (always present)
            _buildMainSigil(phaseColor),
            
            // Constellation points (thinking state)
            if (widget.state == VoiceSigilState.thinking)
              AnimatedBuilder(
                animation: _thinkingController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: ConstellationPoints(
                      phaseColor: phaseColor,
                      animationValue: _thinkingController.value,
                      intensity: 1.0,
                    ),
                  );
                },
              ),
            
            // Thinking spinner overlay (subtle, over constellation)
            if (widget.state == VoiceSigilState.thinking)
              AnimatedBuilder(
                animation: _thinkingController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _thinkingController.value * 2 * math.pi,
                    child: Icon(
                      Icons.refresh,
                      size: widget.size * 0.2,
                      color: phaseColor.withOpacity(0.3),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainSigil(Color phaseColor) {
    Widget sigilContent;
    
    // Use the gold LUMARA sigil image
    sigilContent = Container(
      width: widget.size * 0.5,
      height: widget.size * 0.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: const DecorationImage(
          image: AssetImage('assets/images/LUMARA_Symbol-Final.png'),
          fit: BoxFit.contain,
        ),
        boxShadow: [
          BoxShadow(
            color: phaseColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
    );
    
    // Wrap with appropriate animation
    switch (widget.state) {
      case VoiceSigilState.idle:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: sigilContent,
        );
        
      case VoiceSigilState.listening:
      case VoiceSigilState.commitment:
      case VoiceSigilState.accelerating:
        return AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            final scale = 1.0 + (_breathingAnimation.value * 0.03);
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: sigilContent,
        );
        
      case VoiceSigilState.speaking:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value * 1.02,
              child: Opacity(
                opacity: 0.7 + (_pulseAnimation.value * 0.3),
                child: child,
              ),
            );
          },
          child: sigilContent,
        );
        
      case VoiceSigilState.thinking:
        return Opacity(
          opacity: 0.6,
          child: sigilContent,
        );
    }
  }
}

/// Helper widget to show state label (for debugging/development)
class VoiceSigilStateLabel extends StatelessWidget {
  final VoiceSigilState state;
  final String? additionalInfo;
  
  const VoiceSigilStateLabel({
    super.key,
    required this.state,
    this.additionalInfo,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getStateLabel(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (additionalInfo != null) ...[
            const SizedBox(height: 2),
            Text(
              additionalInfo!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _getStateLabel() {
    switch (state) {
      case VoiceSigilState.idle:
        return 'Tap to start';
      case VoiceSigilState.listening:
        return 'Listening...';
      case VoiceSigilState.commitment:
        return 'Preparing to process...';
      case VoiceSigilState.accelerating:
        return 'Almost ready...';
      case VoiceSigilState.thinking:
        return 'LUMARA is thinking...';
      case VoiceSigilState.speaking:
        return 'LUMARA is speaking...';
    }
  }
}
