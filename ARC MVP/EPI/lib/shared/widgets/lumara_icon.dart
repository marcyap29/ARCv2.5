import 'package:flutter/material.dart';

/// Reusable LUMARA icon widget that displays the custom LUMARA logo
/// Falls back to Icons.psychology if the image asset is not found
class LumaraIcon extends StatelessWidget {
  final double? size;
  final Color? color;
  final BoxFit fit;

  const LumaraIcon({
    super.key,
    this.size,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 24.0;
    
    // Try to load the custom LUMARA logo image
    // If the image is not found, fall back to the psychology icon
    return Image.asset(
      'assets/icon/LUMARA_Sigil_White.png',
      width: iconSize,
      height: iconSize,
      fit: fit,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to psychology icon if image not found
        return Icon(
          Icons.psychology,
          size: iconSize,
          color: color,
        );
      },
    );
  }
}

/// Helper function to get LUMARA icon for use in IconButton and similar widgets
/// Returns the custom image if available, otherwise returns Icons.psychology
Widget buildLumaraIcon({
  double? size,
  Color? color,
}) {
  return LumaraIcon(
    size: size,
    color: color,
  );
}

