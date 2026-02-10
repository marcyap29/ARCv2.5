import 'package:flutter/material.dart';

/// Custom LUMARA icon widget using the app icon image
class LumaraIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final BoxFit fit;

  const LumaraIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // Use the LUMARA sigil image asset
    return Image.asset(
      'assets/icon/LUMARA_Sigil.png',
      width: size,
      height: size,
      fit: fit,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to psychology icon if image not found
        return Icon(
          Icons.psychology,
          size: size,
          color: color,
        );
      },
    );
  }
}