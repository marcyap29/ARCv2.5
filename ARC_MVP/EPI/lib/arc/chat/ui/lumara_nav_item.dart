import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';

/// LUMARA navigation item for the bottom navigation
class LumaraNavItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const LumaraNavItem({
    super.key,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LumaraIcon(
              size: 24,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const Gap(4),
            Text(
              'LUMARA',
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}