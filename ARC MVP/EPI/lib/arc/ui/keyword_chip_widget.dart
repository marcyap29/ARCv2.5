import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class KeywordChip extends StatelessWidget {
  final String keyword;
  final bool isSelected;
  final VoidCallback onTap;

  const KeywordChip({
    super.key,
    required this.keyword,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kcPrimaryColor : kcSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kcPrimaryColor : kcSecondaryColor,
          ),
        ),
        child: Text(
          keyword,
          style: bodyStyle(context).copyWith(
            color: isSelected ? Colors.white : kcSecondaryColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
