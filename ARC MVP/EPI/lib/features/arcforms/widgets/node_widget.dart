import 'package:flutter/material.dart';
import 'package:my_app/features/arcforms/arcform_renderer_state.dart';
import 'package:my_app/shared/app_colors.dart';

class NodeWidget extends StatelessWidget {
  final Node node;
  final Function(String, double, double)? onMoved;

  const NodeWidget({
    super.key,
    required this.node,
    this.onMoved,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: node.x - node.size / 2,
      top: node.y - node.size / 2,
      child: GestureDetector(
        onPanUpdate: (details) {
          if (onMoved != null) {
            final RenderBox renderBox = context.findRenderObject() as RenderBox;
            final position = renderBox.globalToLocal(details.globalPosition);
            onMoved!(node.id, position.dx, position.dy);
          }
        },
        child: Container(
          width: node.size,
          height: node.size,
          decoration: BoxDecoration(
            color: kcPrimaryGradient.colors.first,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kcPrimaryGradient.colors.first.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              node.label.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
