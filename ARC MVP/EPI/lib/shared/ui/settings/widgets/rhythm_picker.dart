import 'package:flutter/material.dart';

class RhythmPicker extends StatelessWidget {
  final String selectedRhythm;
  final Function(String) onRhythmChanged;

  const RhythmPicker({
    super.key,
    required this.selectedRhythm,
    required this.onRhythmChanged,
  });

  static const List<Map<String, dynamic>> rhythms = [
    {
      'value': 'daily',
      'label': 'Daily',
      'description': 'Regular daily journaling routine',
      'icon': Icons.calendar_today,
    },
    {
      'value': 'weekly',
      'label': 'Weekly',
      'description': 'Weekly reflection sessions',
      'icon': Icons.date_range,
    },
    {
      'value': 'free-flow',
      'label': 'Free Flow',
      'description': 'Journal when inspiration strikes',
      'icon': Icons.auto_awesome,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rhythms.map((rhythm) {
        final isSelected = selectedRhythm == rhythm['value'];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () => onRhythmChanged(rhythm['value']),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey[700]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    rhythm['icon'],
                    color: isSelected ? Colors.blue : Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rhythm['label'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        Text(
                          rhythm['description'],
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.blue,
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
