/// Base Feed Card
///
/// Shared card wrapper with phase-colored left border indicator.
/// All feed entry cards extend from this base to get consistent styling.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';

class BaseFeedCard extends StatelessWidget {
  final FeedEntry entry;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BaseFeedCard({
    super.key,
    required this.entry,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: entry.phaseColor ?? Colors.grey.withOpacity(0.3),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }
}
