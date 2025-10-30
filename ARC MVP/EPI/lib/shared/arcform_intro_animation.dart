import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/arcforms/arcform_mvp_implementation.dart';

class ArcformIntroAnimation {
  static OverlayEntry? _currentOverlay;

  static void show({
    required BuildContext context,
    required SimpleArcform arcform,
    required String entryTitle,
    VoidCallback? onComplete,
  }) {
    // Remove any existing animation
    dismiss();

    // Check if context is still mounted before accessing Overlay
    if (!context.mounted) return;

    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => _ArcformIntroWidget(
        arcform: arcform,
        entryTitle: entryTitle,
        onComplete: onComplete,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentOverlay!);
  }

  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _ArcformIntroWidget extends StatefulWidget {
  final SimpleArcform arcform;
  final String entryTitle;
  final VoidCallback? onComplete;
  final VoidCallback onDismiss;

  const _ArcformIntroWidget({
    required this.arcform,
    required this.entryTitle,
    this.onComplete,
    required this.onDismiss,
  });

  @override
  State<_ArcformIntroWidget> createState() => _ArcformIntroWidgetState();
}

class _ArcformIntroWidgetState extends State<_ArcformIntroWidget>
    with TickerProviderStateMixin {
  late AnimationController _backdropController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  
  late Animation<double> _backdropAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();
    
    _backdropController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _backdropAnimation = Tween<double>(
      begin: 0.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _backdropController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    // Staggered animation sequence
    _backdropController.forward();
    
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleController.forward();
    _rotationController.repeat();
    
    await Future.delayed(const Duration(milliseconds: 500));
    _particleController.forward();
    
    // Auto-dismiss after showing
    await Future.delayed(const Duration(milliseconds: 3000));
    _dismiss();
  }

  void _dismiss() async {
    _rotationController.stop();
    if (mounted) {
      await Future.wait([
        _backdropController.reverse(),
        _scaleController.reverse(),
        _particleController.reverse(),
      ]);
    }
    
    widget.onComplete?.call();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _backdropController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  String _getGeometryDisplayName() {
    switch (widget.arcform.geometry) {
      case ArcformGeometry.spiral:
        return 'Spiral';
      case ArcformGeometry.flower:
        return 'Flower';
      case ArcformGeometry.branch:
        return 'Branch';
      case ArcformGeometry.weave:
        return 'Weave';
      case ArcformGeometry.glowCore:
        return 'Glow Core';
      case ArcformGeometry.fractal:
        return 'Fractal';
    }
  }

  IconData _getGeometryIcon() {
    switch (widget.arcform.geometry) {
      case ArcformGeometry.spiral:
        return Icons.settings_ethernet;
      case ArcformGeometry.flower:
        return Icons.local_florist;
      case ArcformGeometry.branch:
        return Icons.account_tree;
      case ArcformGeometry.weave:
        return Icons.grid_view;
      case ArcformGeometry.glowCore:
        return Icons.wb_sunny;
      case ArcformGeometry.fractal:
        return Icons.scatter_plot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _backdropAnimation,
        _scaleAnimation,
        _rotationAnimation,
        _particleAnimation,
      ]),
      builder: (context, child) {
        return GestureDetector(
          onTap: _dismiss,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(_backdropAnimation.value),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Arcform visualization
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * 0.5,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              kcPrimaryColor.withOpacity(0.8),
                              kcSecondaryColor.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kcPrimaryColor.withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _getGeometryIcon(),
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Text content
                  Opacity(
                    opacity: _scaleAnimation.value,
                    child: Column(
                      children: [
                        Text(
                          'Your Arcform is ready!',
                          style: heading1Style(context).copyWith(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '"${widget.entryTitle}" became a ${_getGeometryDisplayName()} pattern',
                          style: bodyStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${widget.arcform.keywords.length} keywords • ${widget.arcform.edges.length} connections',
                            style: captionStyle(context).copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Tap to continue
                  Opacity(
                    opacity: _particleAnimation.value,
                    child: Text(
                      'Tap to continue',
                      style: captionStyle(context).copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}