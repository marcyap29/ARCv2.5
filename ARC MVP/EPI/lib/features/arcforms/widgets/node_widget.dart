import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/features/arcforms/services/emotional_valence_service.dart';

class NodeWidget extends StatefulWidget {
  final Node node;
  final Function(String, double, double)? onMoved;
  final Function(String)? onTapped;
  final Color? color;

  const NodeWidget({
    super.key,
    required this.node,
    this.onMoved,
    this.onTapped,
    this.color,
  });

  @override
  State<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isSelected = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isSelected = !_isSelected;
    });
    
    if (_isSelected) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
    
    // Provide haptic feedback for better UX experience
    if (mounted) {
      widget.onTapped?.call(widget.node.label);
    }
  }

  Color _getEmotionalColor() {
    if (widget.color != null) {
      return widget.color!;
    }
    
    // Use comprehensive EmotionalValenceService for full warmth/coolness
    final emotionalService = EmotionalValenceService();
    return emotionalService.getEmotionalColor(widget.node.label);
  }

  Color _getGlowColor() {
    // Get glow color based on emotional temperature
    final emotionalService = EmotionalValenceService();
    return emotionalService.getGlowColor(widget.node.label, opacity: _glowAnimation.value);
  }

  @override
  Widget build(BuildContext context) {
    final nodeColor = _getEmotionalColor();
    final isLongWord = widget.node.label.length > 8;
    
    return Positioned(
      left: widget.node.x - widget.node.size / 2,
      top: widget.node.y - widget.node.size / 2,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: _handleTap,
              onPanUpdate: (details) {
                if (widget.onMoved != null) {
                  final RenderBox renderBox = context.findRenderObject() as RenderBox;
                  final position = renderBox.globalToLocal(details.globalPosition);
                  widget.onMoved!(widget.node.id, position.dx, position.dy);
                }
              },
              child: Container(
                width: widget.node.size,
                height: widget.node.size,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getGlowColor(),
                      blurRadius: 12 * _glowAnimation.value,
                      spreadRadius: 3 * _glowAnimation.value,
                    ),
                  ],
                  border: _isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Text(
                      // Show full word if selected or if it's short enough
                      _isSelected || !isLongWord
                          ? widget.node.label
                          : widget.node.label.substring(0, 1),
                      key: ValueKey(_isSelected), // Key for AnimatedSwitcher
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: _isSelected || !isLongWord
                            ? (isLongWord ? 10.0 : 14.0) // Slightly larger for better readability
                            : 18.0, // Larger single letter
                        shadows: [
                          Shadow(
                            offset: const Offset(1, 1),
                            blurRadius: 2.0,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
