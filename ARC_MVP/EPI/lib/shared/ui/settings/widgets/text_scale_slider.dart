import 'package:flutter/material.dart';

class TextScaleSlider extends StatelessWidget {
  final double textScaleFactor;
  final Function(double) onScaleChanged;

  const TextScaleSlider({
    super.key,
    required this.textScaleFactor,
    required this.onScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Text Size',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(textScaleFactor * 100).round()}%',
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.grey[700],
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: textScaleFactor,
            min: 0.8,
            max: 2.0,
            divisions: 12,
            onChanged: onScaleChanged,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Small',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            Text(
              'Large',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
