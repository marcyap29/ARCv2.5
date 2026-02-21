import 'package:flutter/material.dart';

class HealthChip extends StatelessWidget {
  final String summary; // short text (e.g., "Sleep eff 88%, HRV 48ms")
  final VoidCallback? onTap;
  const HealthChip({super.key, required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


