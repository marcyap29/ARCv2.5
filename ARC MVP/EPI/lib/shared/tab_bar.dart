import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';

class CustomTabBar extends StatefulWidget {
  final List<TabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double? height;
  final VoidCallback? onNewJournalPressed;

  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height,
    this.onNewJournalPressed,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  // Find the index of the LUMARA tab
  int? _getLumaraTabIndex() {
    for (int i = 0; i < widget.tabs.length; i++) {
      if (widget.tabs[i].text == 'LUMARA') {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lumaraIndex = _getLumaraTabIndex();
    final hasNewJournalButton = widget.onNewJournalPressed != null && lumaraIndex != null;
    
    return Container(
      height: widget.height ?? (hasNewJournalButton ? 110 : 90),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          // New Journal button above LUMARA tab
          if (hasNewJournalButton)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: widget.tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final isLumaraTab = index == lumaraIndex;
                  
                  return Expanded(
                    child: isLumaraTab
                        ? Center(
                            child: GestureDetector(
                              onTap: widget.onNewJournalPressed,
                              child: Container(
                                width: 32,
                                height: 32,
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
                                  size: 18,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                }).toList(),
              ),
            ),
          // Tab bar row
          Expanded(
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
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
            size: 24,
            color: textColor,
          ),
          const SizedBox(height: 2),
          Text(
            tab.text!,
            style: TextStyle(
              fontSize: 10,
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
        size: 24,
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
