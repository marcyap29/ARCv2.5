import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool listening;
  final bool speaking;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  const MicButton({
    super.key,
    required this.listening,
    required this.speaking,
    required this.onTap,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = speaking ? Icons.volume_up : Icons.mic;
    final label = speaking
        ? 'Speaking...'
        : (listening ? 'Listening...' : 'Tap to Speak');
    
    Color backgroundColor;
    Color foregroundColor;
    
    if (listening) {
      backgroundColor = Colors.red;
      foregroundColor = Colors.white;
    } else if (speaking) {
      backgroundColor = theme.colorScheme.primary;
      foregroundColor = Colors.white;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      foregroundColor = theme.colorScheme.onSurface;
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(icon, size: 24),
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: listening || speaking ? 4 : 1,
            ),
          ),
        ),
        if (listening || speaking) ...[
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onEnd,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              side: BorderSide(
                color: theme.colorScheme.outline,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'End',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

