/// Timeline Modal
///
/// Full-screen modal bottom sheet for navigating the user's history.
/// Three tabs: Timeline (year/month browser), Phase (phase-grouped view),
/// Search (text search across all entries).

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'timeline_view.dart';

class TimelineModal extends StatefulWidget {
  final DateTime currentDate;
  final void Function(DateTime) onDateSelected;

  const TimelineModal({
    super.key,
    required this.currentDate,
    required this.onDateSelected,
  });

  @override
  State<TimelineModal> createState() => _TimelineModalState();
}

class _TimelineModalState extends State<TimelineModal> {
  int _selectedTabIndex = 0; // 0: Timeline, 1: Phase, 2: Search

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: kcBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: kcSecondaryTextColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: kcPrimaryTextColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Timeline',
                    style: TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance for close button
              ],
            ),
          ),

          // Tab selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildTab('Timeline', 0),
                _buildTab('Phase', 1),
                _buildTab('Search', 2),
              ],
            ),
          ),

          Divider(color: kcBorderColor.withOpacity(0.3), height: 1),

          // Content based on selected tab
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? kcPrimaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
              color: isSelected ? kcPrimaryColor : kcSecondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return TimelineView(
          currentDate: widget.currentDate,
          onDateSelected: widget.onDateSelected,
        );
      case 1:
        return _buildPhaseView();
      case 2:
        return _buildSearchView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPhaseView() {
    // Phase 3 implementation - placeholder for now
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 48, color: kcSecondaryTextColor.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'Phase view coming soon',
            style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse entries grouped by ATLAS phases',
            style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchView() {
    // Phase 3 implementation - placeholder for now
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            style: const TextStyle(color: kcPrimaryTextColor),
            decoration: InputDecoration(
              hintText: 'Search entries, conversations, themes...',
              hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: kcSecondaryTextColor.withOpacity(0.5)),
              filled: true,
              fillColor: kcSurfaceAltColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (query) {
              // TODO: Implement search
            },
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Text(
                'Type to search your journal',
                style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
