import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';

class CustomTabBar extends StatefulWidget {
  final List<TabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double? height;
  final VoidCallback? onNewJournalPressed;
  final bool showCenterButton;

  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height,
    this.onNewJournalPressed,
    this.showCenterButton = false,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: widget.height ?? 65,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            top: 2,
            bottom: 12, // Increased bottom padding for better spacing
          ),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // First tab (Journal)
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTabSelected(0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: widget.selectedIndex == 0 ? kcPrimaryGradient : null,
                      color: widget.selectedIndex == 0 ? null : kcSurfaceAltColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _buildTabContent(widget.tabs[0], widget.selectedIndex == 0),
                    ),
                  ),
                ),
              ),
              // Spacer for center button (if enabled)
              if (widget.showCenterButton && widget.onNewJournalPressed != null)
                const SizedBox(width: 40),
              // Second tab (LUMARA)
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTabSelected(1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: widget.selectedIndex == 1 ? kcPrimaryGradient : null,
                      color: widget.selectedIndex == 1 ? null : kcSurfaceAltColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _buildTabContent(widget.tabs[1], widget.selectedIndex == 1),
                    ),
                  ),
                ),
              ),
              // Third tab (Insights)
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTabSelected(2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: widget.selectedIndex == 2 ? kcPrimaryGradient : null,
                      color: widget.selectedIndex == 2 ? null : kcSurfaceAltColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _buildTabContent(widget.tabs[2], widget.selectedIndex == 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Center button positioned above the bar
        if (widget.showCenterButton && widget.onNewJournalPressed != null)
          Positioned(
            top: -20, // Position above the bar
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: widget.onNewJournalPressed,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: kcPrimaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 13, // Reduced by 1/3 (from 20 to ~13)
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildTabContent(TabItem tab, bool isSelected) {
    final textColor = isSelected ? Colors.white : kcPrimaryTextColor;

    if (tab.icon != null && tab.text != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tab.icon,
            size: 20,
            color: textColor,
          ),
          const SizedBox(height: 1),
          Text(
            tab.text!,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (tab.icon != null) {
      return Icon(
        tab.icon,
        size: 20,
        color: textColor,
      );
    } else {
      return Text(
        tab.text!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
  }
}

class TabItem {
  final IconData? icon;
  final String? text;

  const TabItem({
    this.icon,
    this.text,
  }) : assert(
            icon != null || text != null, 'Tab must have either icon or text');
}
