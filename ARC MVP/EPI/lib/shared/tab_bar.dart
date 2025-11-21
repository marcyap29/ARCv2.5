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
    return Container(
      height: widget.height ?? 100, // Increased to 100 to accommodate the + button
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.only(
        left: 8,
        right: 8,
        top: 4,
        bottom: 18,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // + button above tabs
          Center(
            child: Container(
              width: 37.5, // Reduced by 1/4 from 50
              height: 37.5, // Reduced by 1/4 from 50
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kcPrimaryColor,
                border: Border.all(
                  color: kcPrimaryColor.withOpacity(0.3),
                  width: 0.75, // Reduced by 1/4 from 1
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 3, // Reduced by 1/4 from 4
                    offset: const Offset(0, 1.5), // Reduced by 1/4 from 2
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onNewJournalPressed,
                  borderRadius: BorderRadius.circular(18.75), // Reduced by 1/4 from 25
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 18, // Reduced by 1/4 from 24
                  ),
                ),
              ),
            ),
          ),
          // Tabs row
          Expanded(
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
        ],
      ),
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
            size: 31.25, // Increased by 1/4 from 25 to 31.25
            color: textColor,
          ),
          const SizedBox(height: 2), // Increased spacing between icon and text
          Text(
            tab.text!,
            style: TextStyle(
              fontSize: 14.0625, // Increased by 1/4 from 11.25 to 14.0625
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
        size: 31.25, // Increased by 1/4 from 25 to 31.25
        color: textColor,
      );
    } else {
      return Text(
        tab.text!,
        style: TextStyle(
          fontSize: 18.75, // Increased by 1/4 from 15 to 18.75
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
