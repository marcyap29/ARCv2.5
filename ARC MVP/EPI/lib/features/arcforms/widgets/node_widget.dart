import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/shared/app_colors.dart';

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
    
    widget.onTapped?.call(widget.node.label);
  }

  Color _getEmotionalColor() {
    if (widget.color != null) {
      return widget.color!;
    }
    
    // Use emotional valence to determine color
    final valence = _getEmotionalValence(widget.node.label);
    
    if (valence > 0.7) {
      return const Color(0xFFFFD700); // Golden
    } else if (valence > 0.4) {
      return const Color(0xFFFF8C42); // Warm orange
    } else if (valence > 0.1) {
      return const Color(0xFFFF6B6B); // Soft coral
    } else if (valence > -0.1) {
      return kcPrimaryColor; // Neutral purple
    } else if (valence > -0.4) {
      return const Color(0xFF4A90E2); // Cool blue
    } else if (valence > -0.7) {
      return const Color(0xFF2E86AB); // Deeper blue
    } else {
      return const Color(0xFF4ECDC4); // Cool teal
    }
  }

  double _getEmotionalValence(String word) {
    final lowerWord = word.toLowerCase().trim();
    
    // Positive words (warm colors)
    const positiveWords = {
      'love', 'joy', 'happiness', 'peace', 'calm', 'breakthrough', 'discovery',
      'success', 'growth', 'gratitude', 'wisdom', 'connection', 'strength',
      'beauty', 'freedom', 'hope', 'inspiration', 'transformation'
    };
    
    // Negative words (cool colors)
    const negativeWords = {
      'sadness', 'fear', 'anger', 'pain', 'stress', 'anxiety', 'struggle',
      'difficulty', 'loss', 'worry', 'confusion', 'tired', 'darkness'
    };
    
    if (positiveWords.contains(lowerWord)) {
      return 0.7; // Positive
    } else if (negativeWords.contains(lowerWord)) {
      return -0.7; // Negative
    }
    
    return 0.0; // Neutral
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
                      color: nodeColor.withOpacity(_glowAnimation.value),
                      blurRadius: 12 * _glowAnimation.value,
                      spreadRadius: 3 * _glowAnimation.value,
                    ),
                  ],
                  border: _isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    // Show full word if selected or if it's short enough
                    _isSelected || !isLongWord
                        ? widget.node.label
                        : widget.node.label.substring(0, 1),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: _isSelected || !isLongWord
                          ? (isLongWord ? 8.0 : 12.0)
                          : 16.0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
