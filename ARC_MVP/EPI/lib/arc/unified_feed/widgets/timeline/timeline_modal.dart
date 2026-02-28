/// Timeline Modal
///
/// Full-screen modal bottom sheet for navigating the user's history.
/// Three tabs: Timeline (year/month browser), Phase (phase-grouped view),
/// Search (text search across all entries, including #attachment, #report, #writing).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/repositories/feed_repository.dart';
import 'timeline_view.dart';

class TimelineModal extends StatefulWidget {
  final DateTime currentDate;
  final void Function(DateTime) onDateSelected;
  final FeedRepository? feedRepo;
  final void Function(FeedEntry)? onEntrySelected;

  const TimelineModal({
    super.key,
    required this.currentDate,
    required this.onDateSelected,
    this.feedRepo,
    this.onEntrySelected,
  });

  @override
  State<TimelineModal> createState() => _TimelineModalState();
}

class _TimelineModalState extends State<TimelineModal> {
  int _selectedTabIndex = 0; // 0: Timeline, 1: Phase, 2: Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<FeedEntry> _searchResults = [];
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _runSearch(String query) {
    setState(() {
      _searchQuery = query;
      if (widget.feedRepo == null) {
        _searchResults = [];
      } else if (query.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults = widget.feedRepo!.search(query);
      }
    });
  }

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
    if (widget.feedRepo == null) {
      return Center(
        child: Text(
          'Search unavailable',
          style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.6), fontSize: 14),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            style: const TextStyle(color: kcPrimaryTextColor),
            decoration: InputDecoration(
              hintText: 'Search entries, #attachment, #report, #writing...',
              hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: kcSecondaryTextColor.withOpacity(0.5)),
              filled: true,
              fillColor: kcSurfaceAltColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _runSearch,
          ),
          const SizedBox(height: 8),
          Text(
            'Use #attachment, #report, #writing to filter by output type',
            style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.5), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _searchQuery.isEmpty
                ? Center(
                    child: Text(
                      'Type to search your journal and outputs',
                      style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4), fontSize: 14),
                    ),
                  )
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          'No matching entries',
                          style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4), fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final e = _searchResults[index];
                          return _SearchResultTile(
                            entry: e,
                            onTap: () {
                              widget.onEntrySelected?.call(e);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback onTap;

  const _SearchResultTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().format(entry.timestamp);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconForType(entry.type),
                    size: 18,
                    color: entry.phaseColor ?? kcSecondaryTextColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.title ?? entry.typeLabel,
                      style: const TextStyle(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.preview,
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.9),
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(FeedEntryType type) {
    switch (type) {
      case FeedEntryType.researchReport:
        return Icons.assignment;
      case FeedEntryType.voiceMemo:
        return Icons.mic;
      case FeedEntryType.savedConversation:
      case FeedEntryType.activeConversation:
        return Icons.chat_bubble_outline;
      case FeedEntryType.reflection:
        return Icons.edit_note;
      case FeedEntryType.lumaraInitiative:
        return Icons.auto_awesome;
    }
  }
}
