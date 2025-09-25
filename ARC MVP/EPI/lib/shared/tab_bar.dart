import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';

class CustomTabBar extends StatefulWidget {
  final List<TabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double? height;
  final int? elevatedTabIndex; // Index of tab to elevate (e.g., + button)

  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height,
    this.elevatedTabIndex,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  @override
  Widget build(BuildContext context) {
    // Check if we have an elevated tab (roman numeral 1 shape)
    final hasElevatedTab = widget.elevatedTabIndex != null && 
                          widget.elevatedTabIndex! < widget.tabs.length;
    
    if (hasElevatedTab) {
      return _buildRomanNumeralOneShape();
    }
    
    // Default flat tab bar
    return Container(
      height: widget.height ?? 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
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
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == widget.selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => widget.onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: isSelected ? kcPrimaryGradient : null,
                  color: isSelected ? null : kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _buildTabContent(tab, isSelected),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRomanNumeralOneShape() {
    final elevatedIndex = widget.elevatedTabIndex!;
    final elevatedTab = widget.tabs[elevatedIndex];
    final otherTabs = widget.tabs.where((tab) => tab != elevatedTab).toList();
    
    return Container(
      height: (widget.height ?? 80) + 30, // Slightly more height for elevated button
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          // Main tab bar container
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: (widget.height ?? 80) - 15, // Reduce height by 15px
              padding: const EdgeInsets.all(6), // Reduce padding from 8 to 6
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
                children: otherTabs.asMap().entries.map((entry) {
                  final originalIndex = widget.tabs.indexOf(otherTabs[entry.key]);
                  final isSelected = originalIndex == widget.selectedIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTabSelected(originalIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.all(2), // Reduce margin from 4 to 2
                        decoration: BoxDecoration(
                          gradient: isSelected ? kcPrimaryGradient : null,
                          color: isSelected ? null : kcSurfaceAltColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _buildTabContent(otherTabs[entry.key], isSelected),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Elevated + button
          Positioned(
            top: 0, // Lower the + button slightly
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => widget.onTabSelected(elevatedIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 45, // Smaller purple border to prevent cropping
                  height: 45,
                  decoration: BoxDecoration(
                    gradient: elevatedIndex == widget.selectedIndex ? kcPrimaryGradient : kcPrimaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kcPrimaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      elevatedTab.icon,
                      size: 28, // Keep icon size the same
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
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
            size: 20, // Reduce icon size from 24 to 20
            color: textColor,
          ),
          const SizedBox(height: 2), // Reduce spacing from 4 to 2
          Text(
            tab.text!,
            style: TextStyle(
              fontSize: 10, // Reduce text size from 12 to 10
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
        size: 20, // Reduce icon size from 24 to 20
        color: textColor,
      );
    } else {
      return Text(
        tab.text!,
        style: TextStyle(
          fontSize: 12, // Reduce text size from 14 to 12
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
