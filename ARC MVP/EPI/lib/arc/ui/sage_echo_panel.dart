import 'package:flutter/material.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class SAGEEchoPanel extends StatelessWidget {
  final SAGEAnnotation annotation;
  final VoidCallback onEditPressed;

  const SAGEEchoPanel({
    super.key,
    required this.annotation,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SAGE Echo',
                style: heading3Style(context),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(annotation.confidence * 100).round()}% confident',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kcPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnnotationItem(
            context,
            'Situation',
            annotation.situation,
          ),
          const SizedBox(height: 12),
          _buildAnnotationItem(
            context,
            'Action',
            annotation.action,
          ),
          const SizedBox(height: 12),
          _buildAnnotationItem(
            context,
            'Growth',
            annotation.growth,
          ),
          const SizedBox(height: 12),
          _buildAnnotationItem(
            context,
            'Essence',
            annotation.essence,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Adjust if something feels off.',
                style: captionStyle(context),
              ),
              TextButton(
                onPressed: onEditPressed,
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: kcSecondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnotationItem(
      BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: kcSecondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: bodyStyle(context),
        ),
      ],
    );
  }
}
