import 'package:flutter/material.dart';

class ToneSelector extends StatelessWidget {
  final String selectedTone;
  final Function(String) onToneChanged;

  const ToneSelector({
    super.key,
    required this.selectedTone,
    required this.onToneChanged,
  });

  static const List<Map<String, dynamic>> tones = [
    {
      'value': 'calm',
      'label': 'Calm',
      'description': 'Gentle, peaceful journaling experience',
      'color': Colors.blue,
    },
    {
      'value': 'energized',
      'label': 'Energized',
      'description': 'Dynamic, motivating atmosphere',
      'color': Colors.orange,
    },
    {
      'value': 'reflective',
      'label': 'Reflective',
      'description': 'Thoughtful, introspective mood',
      'color': Colors.purple,
    },
    {
      'value': 'focused',
      'label': 'Focused',
      'description': 'Clear, concentrated environment',
      'color': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tones.map((tone) {
        final isSelected = selectedTone == tone['value'];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () => onToneChanged(tone['value']),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? tone['color'] : Colors.grey[700]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? tone['color'].withOpacity(0.1) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tone['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tone['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        Text(
                          tone['description'],
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: tone['color'],
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
