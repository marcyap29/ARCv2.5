/// Outputs Tab Screen
///
/// Phase 5a: Two-level folder taxonomy (Agent → Category), item cards, sort/filter, tag editing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/outputs/output_detail_screen.dart';
import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/arc/outputs/outputs_cubit.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/arc/outputs/widgets/output_folder_tile.dart';
import 'package:my_app/shared/app_colors.dart';

class OutputsTabScreen extends StatelessWidget {
  const OutputsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutputsCubit(),
      child: const _OutputsTabBody(),
    );
  }
}

class _OutputsTabBody extends StatefulWidget {
  const _OutputsTabBody();

  @override
  State<_OutputsTabBody> createState() => _OutputsTabBodyState();
}

class _OutputsTabBodyState extends State<_OutputsTabBody> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OutputItem> _filterBySearch(List<OutputItem> items, String query) {
    if (query.isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((i) {
      if (i.title.toLowerCase().contains(q)) return true;
      for (final t in [...i.autoTags, ...i.userTags]) {
        if (t.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => context.read<OutputsCubit>().setSearchQuery(_searchController.text),
                style: const TextStyle(color: kcPrimaryTextColor),
                decoration: InputDecoration(
                  hintText: 'Search by title or tag...',
                  hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: kcSecondaryTextColor.withOpacity(0.5)),
                  filled: true,
                  fillColor: kcSurfaceAltColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<OutputsCubit, OutputsState>(
                builder: (context, state) {
                  final filtered = _filterBySearch(state.items, state.searchQuery);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Sort:',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: kcSecondaryTextColor,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('Date')),
                                ButtonSegment(value: true, label: Text('A–Z')),
                              ],
                              selected: {state.sortByTitle},
                              onSelectionChanged: (s) {
                                context.read<OutputsCubit>().setSortByTitle(s.first);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _OutputsFolderList(
                          filteredItems: filtered,
                          sortByTitle: state.sortByTitle,
                          onItemTap: (item) {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => OutputDetailScreen(item: item),
                              ),
                            );
                          },
                          onItemTagsChanged: (item, userTags) async {
                            final updated = item.copyWith(userTags: userTags);
                            await OutputsRepository.instance.updateUserTags(item.id, userTags);
                            OutputsChronicleService.instance.onOutputSaved(
                              type: 'output_tagged',
                              item: updated,
                            );
                          },
                          onItemDelete: (item) async {
                            await context.read<OutputsCubit>().deleteItem(item.id);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folder list with Writer subfolders grouped under a non-tappable "Writer" section header.
class _OutputsFolderList extends StatelessWidget {
  final List<OutputItem> filteredItems;
  final bool sortByTitle;
  final void Function(OutputItem) onItemTap;
  final void Function(OutputItem item, List<String> userTags) onItemTagsChanged;
  final void Function(OutputItem) onItemDelete;

  const _OutputsFolderList({
    required this.filteredItems,
    required this.sortByTitle,
    required this.onItemTap,
    required this.onItemTagsChanged,
    required this.onItemDelete,
  });

  static List<OutputFolder> get _nonWriterFolders =>
      kOutputFolders.where((f) => f.agentKey != 'writer').toList();
  static List<OutputFolder> get _writerFolders =>
      kOutputFolders.where((f) => f.agentKey == 'writer').toList();

  Widget _buildTile(BuildContext context, OutputFolder folder) {
    final folderItems = filteredItems
        .where((i) => i.agentKey == folder.agentKey && i.folderKey == folder.folderKey)
        .toList();
    return OutputFolderTile(
      folder: folder,
      items: folderItems,
      sortByTitle: sortByTitle,
      onItemTap: onItemTap,
      onItemTagsChanged: onItemTagsChanged,
      onItemDelete: onItemDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nonWriter = _nonWriterFolders;
    final writer = _writerFolders;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: nonWriter.length + 1 + writer.length,
      itemBuilder: (context, index) {
        if (index < nonWriter.length) {
          return _buildTile(context, nonWriter[index]);
        }
        if (index == nonWriter.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Writer',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: kcSecondaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          );
        }
        return _buildTile(context, writer[index - nonWriter.length - 1]);
      },
    );
  }
}
