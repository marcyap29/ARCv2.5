import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';

class CustomTabBar extends StatefulWidget {
  final List<TabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double? height;
  final VoidCallback? onNewJournalPressed;
  final VoidCallback? onVoiceJournalPressed;
  final bool showCenterButton;

  const CustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.height,
    this.onNewJournalPressed,
    this.onVoiceJournalPressed,
    this.showCenterButton = false,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? 80, // Standard height for 4 buttons in a row
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
      child: Row(
        children: [
          // Dynamic tab buttons
          for (int i = 0; i < widget.tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onTabSelected(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3748), // Gray background
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _buildTabContent(
                      widget.tabs[i],
                      widget.selectedIndex == i,
                      isLumara: i == 0, // First tab is always LUMARA
                    ),
                  ),
                ),
              ),
            ),
          // New Journal button (+) — only shown when showCenterButton is true
          if (widget.showCenterButton)
            Expanded(
              child: GestureDetector(
                onTap: widget.onNewJournalPressed,
                onLongPress: widget.onVoiceJournalPressed,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: kcPrimaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: kcPrimaryColor.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildTabContent(TabItem tab, bool isSelected, {bool isLumara = false}) {
    const textColor = kcPrimaryTextColor; // Always white text, no active highlight

    if (tab.icon != null && tab.text != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Prevent overflow by not expanding
        children: [
          if (isLumara)
            // Use LUMARA_Sigil_White.png for LUMARA tab
            Image.asset(
              'assets/icon/LUMARA_Sigil_White.png',
              width: 24, // Reduced from 28 to fit in 42px height
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.psychology,
                  size: 24,
                  color: textColor,
                );
              },
            )
          else
          Icon(
            tab.icon,
              size: 24, // Reduced from 28 to fit in 42px height
            color: textColor,
          ),
          const SizedBox(height: 2),
          Text(
            tab.text!,
            style: const TextStyle(
              fontSize: 8.0, // Slightly smaller to ensure fit
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (tab.icon != null) {
      if (isLumara) {
        return Image.asset(
          'assets/icon/LUMARA_Sigil_White.png',
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.psychology,
              size: 28,
              color: textColor,
            );
          },
        );
      }
      return Icon(
        tab.icon,
        size: 28,
        color: textColor,
      );
    } else {
      return Text(
        tab.text!,
        style: const TextStyle(
          fontSize: 16,
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
