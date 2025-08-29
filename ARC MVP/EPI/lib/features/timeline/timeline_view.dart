import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/features/timeline/timeline_state.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return const TimelineViewContent();
  }
}

class TimelineViewContent extends StatefulWidget {
  const TimelineViewContent({super.key});

  @override
  State<TimelineViewContent> createState() => _TimelineViewContentState();
}

class _TimelineViewContentState extends State<TimelineViewContent> {
  final ScrollController _scrollController = ScrollController();
  late TimelineCubit _timelineCubit;

  @override
  void initState() {
    super.initState();
    _timelineCubit = context.read<TimelineCubit>();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _timelineCubit.loadMoreEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineCubit, TimelineState>(
      builder: (context, state) {
        return Column(
          children: [
            _buildFilterButtons(state),
            Expanded(
              child: _buildTimelineContent(state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterButtons(TimelineState state) {
    // Get the current filter from the state if it's loaded
    TimelineFilter currentFilter = TimelineFilter.all;
    if (state is TimelineLoaded) {
      currentFilter = state.filter;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: currentFilter == TimelineFilter.all,
            onSelected: (_) =>
                context.read<TimelineCubit>().setFilter(TimelineFilter.all),
            selectedColor: kcPrimaryColor.withOpacity(0.3),
            backgroundColor: kcSurfaceAltColor,
            labelStyle: const TextStyle(color: kcPrimaryTextColor),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Text only'),
            selected: currentFilter == TimelineFilter.textOnly,
            onSelected: (_) => context
                .read<TimelineCubit>()
                .setFilter(TimelineFilter.textOnly),
            selectedColor: kcPrimaryColor.withOpacity(0.3),
            backgroundColor: kcSurfaceAltColor,
            labelStyle: const TextStyle(color: kcPrimaryTextColor),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('With Arcform'),
            selected: currentFilter == TimelineFilter.withArcform,
            onSelected: (_) => context
                .read<TimelineCubit>()
                .setFilter(TimelineFilter.withArcform),
            selectedColor: kcPrimaryColor.withOpacity(0.3),
            backgroundColor: kcSurfaceAltColor,
            labelStyle: const TextStyle(color: kcPrimaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContent(TimelineState state) {
    if (state is TimelineLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is TimelineError) {
      return Center(
        child: Text(
          state.message,
          style: bodyStyle(context),
        ),
      );
    }

    if (state is TimelineLoaded) {
      if (state.groupedEntries.isEmpty) {
        return Center(
          child: Text(
            'No entries yet',
            style: bodyStyle(context),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<TimelineCubit>().refreshEntries();
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: state.groupedEntries.length +
              (state.hasMore ? 1 : 0), // Add loading indicator if hasMore
          itemBuilder: (context, index) {
            if (index == state.groupedEntries.length) {
              // This is the loading indicator at the end
              return state.hasMore
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }

            final monthGroup = state.groupedEntries[index];
            return _buildMonthGroup(monthGroup);
          },
        ),
      );
    }

    return Container();
  }

  Widget _buildMonthGroup(TimelineMonthGroup monthGroup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: kcPrimaryGradient,
          ),
          child: Text(
            monthGroup.month,
            style: heading1Style(context).copyWith(
              color: kcPrimaryTextColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...monthGroup.entries
            .map((entry) => _buildTimelineCard(entry))
            .toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimelineCard(TimelineEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: () {
          // TODO: Open detail view
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.date,
                    style: captionStyle(context),
                  ),
                  if (entry.hasArcform)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kcSecondaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Arcform',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kcSecondaryTextColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                entry.preview,
                style: bodyStyle(context),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.hasArcform) ...[
                const SizedBox(height: 12),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: kcSurfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: kcSecondaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
