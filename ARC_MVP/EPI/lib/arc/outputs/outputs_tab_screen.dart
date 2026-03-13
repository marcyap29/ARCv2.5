/// Outputs Tab Screen
///
/// Phase 5a: Two-level folder taxonomy (Agent → Category), item cards, sort/filter, tag editing.
/// Writing items with PipelineDraft content open in the draft editor for editing.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/outputs/output_detail_screen.dart';
import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/arc/outputs/outputs_cubit.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/arc/outputs/widgets/output_folder_tile.dart';
import 'package:my_app/lumara/agents/writing/draft_editor_screen.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/shared/app_colors.dart';

/// If [item] is a Writing output with contentJson that parses as PipelineDraft, returns that draft; otherwise null.
PipelineDraft? _tryParseWriterDraft(OutputItem item) {
  if (item.agentKey != 'writing' || item.contentJson == null || item.contentJson!.isEmpty) {
    return null;
  }
  try {
    final map = jsonDecode(item.contentJson!) as Map<String, dynamic>;
    final draft = PipelineDraft.fromJson(map);
    if (draft.body.isEmpty && draft.topic.isEmpty) return null;
    return draft;
  } catch (_) {
    return null;
  }
}

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
  bool _selectionModeEnabled = false;
  final Set<String> _selectedItemIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionModeEnabled = !_selectionModeEnabled;
      if (!_selectionModeEnabled) _selectedItemIds.clear();
    });
  }

  void _toggleItemSelection(OutputItem item) {
    setState(() {
      if (_selectedItemIds.contains(item.id)) {
        _selectedItemIds.remove(item.id);
      } else {
        _selectedItemIds.add(item.id);
      }
    });
  }

  Future<void> _deleteSelectedItems(BuildContext context) async {
    if (_selectedItemIds.isEmpty) return;
    final cubit = context.read<OutputsCubit>();
    final n = _selectedItemIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected outputs?'),
        content: Text(
          '$n ${n == 1 ? 'item' : 'items'} will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final id in _selectedItemIds) {
      await cubit.deleteItem(id);
    }
    setState(() {
      _selectionModeEnabled = false;
      _selectedItemIds.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$n ${n == 1 ? 'item' : 'items'} deleted')),
    );
  }

  Widget _buildSelectionModeBar(BuildContext context) {
    if (!_selectionModeEnabled) return const SizedBox.shrink();
    final n = _selectedItemIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kcBorderColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              _selectionModeEnabled = false;
              _selectedItemIds.clear();
            }),
            icon: const Icon(Icons.close, size: 20),
            label: const Text('Cancel'),
          ),
          const Spacer(),
          if (n > 0)
            TextButton.icon(
              onPressed: () => _deleteSelectedItems(context),
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
              label: Text('Delete ($n)', style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.w600)),
            )
          else
            Text(
              'Tap items to select',
              style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.7), fontSize: 13),
            ),
        ],
      ),
    );
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
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.checklist,
                                color: _selectionModeEnabled ? kcPrimaryColor : kcSecondaryTextColor.withOpacity(0.6),
                                size: 22,
                              ),
                              tooltip: 'Select items',
                              onPressed: _toggleSelectionMode,
                            ),
                          ],
                        ),
                      ),
                      _buildSelectionModeBar(context),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _OutputsFolderList(
                          filteredItems: filtered,
                          sortByTitle: state.sortByTitle,
                          selectionModeEnabled: _selectionModeEnabled,
                          selectedItemIds: _selectedItemIds,
                          onToggleSelect: _toggleItemSelection,
                          onItemTap: (item) {
                            final draft = _tryParseWriterDraft(item);
                            if (draft != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => DraftEditorScreen(draft: draft),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => OutputDetailScreen(item: item),
                                ),
                              );
                            }
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

/// Folder list with Writing subfolders grouped under a non-tappable "Writing" section header.
class _OutputsFolderList extends StatelessWidget {
  final List<OutputItem> filteredItems;
  final bool sortByTitle;
  final bool selectionModeEnabled;
  final Set<String> selectedItemIds;
  final void Function(OutputItem) onToggleSelect;
  final void Function(OutputItem) onItemTap;
  final void Function(OutputItem item, List<String> userTags) onItemTagsChanged;
  final void Function(OutputItem) onItemDelete;

  const _OutputsFolderList({
    required this.filteredItems,
    required this.sortByTitle,
    required this.selectionModeEnabled,
    required this.selectedItemIds,
    required this.onToggleSelect,
    required this.onItemTap,
    required this.onItemTagsChanged,
    required this.onItemDelete,
  });

  static List<OutputFolder> get _nonWritingFolders =>
      kOutputFolders.where((f) => f.agentKey != 'writing').toList();
  static List<OutputFolder> get _writingFolders =>
      kOutputFolders.where((f) => f.agentKey == 'writing').toList();

  Widget _buildTile(BuildContext context, OutputFolder folder) {
    final folderItems = filteredItems
        .where((i) => i.agentKey == folder.agentKey && i.folderKey == folder.folderKey)
        .toList();
    return OutputFolderTile(
      folder: folder,
      items: folderItems,
      sortByTitle: sortByTitle,
      selectionModeEnabled: selectionModeEnabled,
      selectedItemIds: selectedItemIds,
      onToggleSelect: onToggleSelect,
      onItemTap: onItemTap,
      onItemTagsChanged: onItemTagsChanged,
      onItemDelete: onItemDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nonWriting = _nonWritingFolders;
    final writing = _writingFolders;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: nonWriting.length + 1 + writing.length,
      itemBuilder: (context, index) {
        if (index < nonWriting.length) {
          return _buildTile(context, nonWriting[index]);
        }
        if (index == nonWriting.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Writing',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: kcSecondaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          );
        }
        return _buildTile(context, writing[index - nonWriting.length - 1]);
      },
    );
  }
}
