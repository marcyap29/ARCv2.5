import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/models/chronicle_aggregation.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/ui/timeline/timeline_with_ideas_view.dart';

/// CHRONICLE Layers Viewer
/// 
/// Visual UI/UX for displaying CHRONICLE layers (monthly, yearly, multi-year)
/// to ensure transparency with users about what has been synthesized.
class ChronicleLayersViewer extends StatefulWidget {
  /// Which tab to show first: 0 = Monthly, 1 = Yearly, 2 = Multi-Year.
  final int initialTabIndex;

  const ChronicleLayersViewer({super.key, this.initialTabIndex = 0});

  @override
  State<ChronicleLayersViewer> createState() => _ChronicleLayersViewerState();
}

class _ChronicleLayersViewerState extends State<ChronicleLayersViewer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  // Aggregations by layer
  List<ChronicleAggregation> _monthlyAggs = [];
  List<ChronicleAggregation> _yearlyAggs = [];
  List<ChronicleAggregation> _multiyearAggs = [];

  @override
  void initState() {
    super.initState();
    final index = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: index);
    _loadAggregations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAggregations() async {
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final aggregationRepo = ChronicleRepos.aggregation;

      final monthly = await aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.monthly,
      );
      final yearly = await aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.yearly,
      );
      final multiyear = await aggregationRepo.getAllForLayer(
        userId: userId,
        layer: ChronicleLayer.multiyear,
      );

      if (mounted) {
        setState(() {
          _monthlyAggs = monthly..sort((a, b) => b.period.compareTo(a.period));
          _yearlyAggs = yearly..sort((a, b) => b.period.compareTo(a.period));
          _multiyearAggs = multiyear..sort((a, b) => b.period.compareTo(a.period));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading CHRONICLE aggregations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'CHRONICLE Layers',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: kcPrimaryTextColor,
          unselectedLabelColor: kcSecondaryTextColor,
          indicatorColor: kcAccentColor,
          tabs: const [
            Tab(
              icon: Icon(Icons.calendar_month),
              text: 'Monthly',
            ),
            Tab(
              icon: Icon(Icons.calendar_today),
              text: 'Yearly',
            ),
            Tab(
              icon: Icon(Icons.calendar_view_month),
              text: 'Multi-Year',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLayerView(
                  ChronicleLayer.monthly,
                  _monthlyAggs,
                  Icons.calendar_month,
                ),
                _buildLayerView(
                  ChronicleLayer.yearly,
                  _yearlyAggs,
                  Icons.calendar_today,
                ),
                _buildLayerView(
                  ChronicleLayer.multiyear,
                  _multiyearAggs,
                  Icons.calendar_view_month,
                ),
              ],
            ),
    );
  }

  Widget _buildLayerView(
    ChronicleLayer layer,
    List<ChronicleAggregation> aggregations,
    IconData icon,
  ) {
    if (aggregations.isEmpty) {
      return _buildEmptyState(layer);
    }

    return Column(
      children: [
        // Layer info header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kcBackgroundColor.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: kcPrimaryTextColor.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: kcAccentColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layer.displayName,
                      style: heading2Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${aggregations.length} ${aggregations.length == 1 ? 'aggregation' : 'aggregations'}',
                      style: captionStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getLayerColor(layer).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getLayerColor(layer).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getLayerBadge(layer),
                  style: captionStyle(context).copyWith(
                    color: _getLayerColor(layer),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Aggregations list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: aggregations.length,
            itemBuilder: (context, index) {
              return _buildAggregationCard(aggregations[index], layer);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ChronicleLayer layer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getLayerIcon(layer),
              size: 64,
              color: kcSecondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No ${layer.displayName.toLowerCase()} aggregations yet',
              style: heading2Style(context).copyWith(
                color: kcSecondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _getEmptyStateMessage(layer),
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAggregationCard(ChronicleAggregation aggregation, ChronicleLayer layer) {
    String formattedPeriod;
    try {
      if (layer == ChronicleLayer.multiyear) {
        final parts = aggregation.period.split('-');
        if (parts.length == 2) {
          formattedPeriod = '${parts[0]} - ${parts[1]}';
        } else {
          formattedPeriod = aggregation.period;
        }
      } else if (layer == ChronicleLayer.monthly) {
        final parts = aggregation.period.split('-');
        if (parts.length == 2) {
          final year = parts[0];
          final month = int.parse(parts[1]);
          final monthNames = [
            '', 'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
          ];
          formattedPeriod = '${monthNames[month]} $year';
        } else {
          formattedPeriod = aggregation.period;
        }
      } else {
        formattedPeriod = aggregation.period;
      }
    } catch (e) {
      formattedPeriod = aggregation.period;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kcBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getLayerColor(layer).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: const EdgeInsets.all(20),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getLayerColor(layer).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getLayerIcon(layer),
            color: _getLayerColor(layer),
            size: 24,
          ),
        ),
        title: Text(
          formattedPeriod,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              _buildMetadataChip(
                Icons.article,
                '${aggregation.entryCount} ${aggregation.entryCount == 1 ? 'entry' : 'entries'}',
              ),
              const SizedBox(width: 8),
              _buildMetadataChip(
                Icons.compress,
                '${(aggregation.compressionRatio * 100).toStringAsFixed(1)}% size',
              ),
              if (aggregation.userEdited) ...[
                const SizedBox(width: 8),
                _buildMetadataChip(
                  Icons.edit,
                  'Edited',
                  color: Colors.orange,
                ),
              ],
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDateShort(aggregation.synthesisDate),
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              aggregation.synthesisDate.year.toString(),
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
        children: [
          // Metadata section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcBackgroundColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetadataRow('Synthesized', _formatDateLong(aggregation.synthesisDate)),
                _buildMetadataRow('Version', 'v${aggregation.version}'),
                _buildMetadataRow('Compression', '${(aggregation.compressionRatio * 100).toStringAsFixed(2)}%'),
                if (aggregation.userEdited)
                  _buildMetadataRow('Status', 'User Edited', valueColor: Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Source entries: titles for monthly (clickable → timeline), count for others
          _SourceEntriesSection(
            aggregation: aggregation,
            layer: layer,
            layerColor: _getLayerColor(layer),
          ),
          const SizedBox(height: 16),
          // Content preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcBackgroundColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description,
                      size: 18,
                      color: kcSecondaryTextColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Content Preview',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Show first 500 characters of content
                Text(
                  aggregation.content.length > 500
                      ? '${aggregation.content.substring(0, 500)}...'
                      : aggregation.content,
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryTextColor.withOpacity(0.8),
                    height: 1.6,
                  ),
                ),
                if (aggregation.content.length > 500) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _showFullContent(aggregation, formattedPeriod),
                    icon: const Icon(Icons.open_in_full, size: 18),
                    label: const Text('View Full Content'),
                    style: TextButton.styleFrom(
                      foregroundColor: _getLayerColor(layer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? kcAccentColor).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (color ?? kcAccentColor).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? kcAccentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: captionStyle(context).copyWith(
              color: color ?? kcAccentColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bodyStyle(context).copyWith(
                color: valueColor ?? kcPrimaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullContent(ChronicleAggregation aggregation, String period) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kcBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ChronicleContentSheet(
        aggregation: aggregation,
        period: period,
        onSaved: () {
          Navigator.pop(context);
          _loadAggregations();
        },
      ),
    );
  }

  Color _getLayerColor(ChronicleLayer layer) {
    switch (layer) {
      case ChronicleLayer.monthly:
        return Colors.blue;
      case ChronicleLayer.yearly:
        return Colors.purple;
      case ChronicleLayer.multiyear:
        return Colors.orange;
      case ChronicleLayer.layer0:
        return Colors.grey;
    }
  }

  IconData _getLayerIcon(ChronicleLayer layer) {
    switch (layer) {
      case ChronicleLayer.monthly:
        return Icons.calendar_month;
      case ChronicleLayer.yearly:
        return Icons.calendar_today;
      case ChronicleLayer.multiyear:
        return Icons.calendar_view_month;
      case ChronicleLayer.layer0:
        return Icons.description;
    }
  }

  String _getLayerBadge(ChronicleLayer layer) {
    switch (layer) {
      case ChronicleLayer.monthly:
        return 'EXAMINE';
      case ChronicleLayer.yearly:
        return 'INTEGRATE';
      case ChronicleLayer.multiyear:
        return 'LINK';
      case ChronicleLayer.layer0:
        return 'VERBALIZE';
    }
  }

  String _getEmptyStateMessage(ChronicleLayer layer) {
    switch (layer) {
      case ChronicleLayer.monthly:
        return 'Monthly aggregations will appear here once you have entries and synthesis runs.';
      case ChronicleLayer.yearly:
        return 'Yearly aggregations will appear here once you have at least 3 months of data.';
      case ChronicleLayer.multiyear:
        return 'Multi-year aggregations will appear here once you have multiple years of data.';
      case ChronicleLayer.layer0:
        return 'Raw entries are stored separately.';
    }
  }

  String _formatDateShort(DateTime date) {
    final monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${monthNames[date.month]} ${date.day}';
  }

  String _formatDateLong(DateTime date) {
    final monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${monthNames[date.month]} ${date.day}, ${date.year}';
  }
}

/// Shows source entry titles (monthly) or count (yearly/multiyear). Monthly titles are tappable → timeline.
class _SourceEntriesSection extends StatelessWidget {
  final ChronicleAggregation aggregation;
  final ChronicleLayer layer;
  final Color layerColor;

  const _SourceEntriesSection({
    required this.aggregation,
    required this.layer,
    required this.layerColor,
  });

  Future<List<({String id, String title})>> _loadTitlesForMonthly(BuildContext context) async {
    if (aggregation.sourceEntryIds.isEmpty) return [];
    final repo = JournalRepository();
    final results = <({String id, String title})>[];
    for (final id in aggregation.sourceEntryIds) {
      final entry = await repo.getJournalEntryById(id);
      final title = entry?.title.trim().isNotEmpty == true
          ? entry!.title
          : (entry?.content.trim().isNotEmpty == true
              ? '${entry!.content.substring(0, entry.content.length.clamp(0, 50))}${entry.content.length > 50 ? '…' : ''}'
              : 'Entry');
      results.add((id: id, title: title));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    if (layer != ChronicleLayer.monthly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kcBackgroundColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.article_outlined, size: 18, color: kcSecondaryTextColor),
            const SizedBox(width: 8),
            Text(
              '${aggregation.sourceEntryIds.length} source ${aggregation.sourceEntryIds.length == 1 ? 'period' : 'periods'}',
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcBackgroundColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 18, color: layerColor),
              const SizedBox(width: 8),
              Text(
                'Source entries (${aggregation.sourceEntryIds.length})',
                style: captionStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<({String id, String title})>>(
            future: _loadTitlesForMonthly(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: layerColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading titles…',
                        style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                      ),
                    ],
                  ),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Text(
                  'No source entries',
                  style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => TimelineWithIdeasView(
                              initialScrollToEntryId: item.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new, size: 16, color: layerColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.title,
                                style: bodyStyle(context).copyWith(
                                  color: kcPrimaryTextColor,
                                  fontSize: 14,
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Full-content sheet with view/edit and save for CHRONICLE aggregations.
class _ChronicleContentSheet extends StatefulWidget {
  final ChronicleAggregation aggregation;
  final String period;
  final VoidCallback onSaved;

  const _ChronicleContentSheet({
    required this.aggregation,
    required this.period,
    required this.onSaved,
  });

  @override
  State<_ChronicleContentSheet> createState() => _ChronicleContentSheetState();
}

class _ChronicleContentSheetState extends State<_ChronicleContentSheet> {
  late TextEditingController _controller;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.aggregation.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim() == widget.aggregation.content) {
      setState(() => _isEditing = false);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final repo = ChronicleRepos.aggregation;
      final updated = widget.aggregation.copyWith(
        content: _controller.text.trim(),
        userEdited: true,
        version: widget.aggregation.version + 1,
      );
      switch (updated.layer) {
        case ChronicleLayer.monthly:
          await repo.saveMonthly(userId, updated);
          break;
        case ChronicleLayer.yearly:
          await repo.saveYearly(userId, updated);
          break;
        case ChronicleLayer.multiyear:
          await repo.saveMultiYear(userId, updated);
          break;
        default:
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CHRONICLE summary saved. Your edits will be used in future synthesis.')),
        );
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: kcPrimaryTextColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.period,
                        style: heading2Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.aggregation.layer.displayName,
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isEditing) ...[
                  TextButton(
                    onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                    child: Text('Cancel', style: TextStyle(color: kcSecondaryTextColor)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    color: kcPrimaryTextColor,
                    tooltip: 'Edit summary',
                    onPressed: () => setState(() => _isEditing = true),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: kcPrimaryTextColor,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isEditing
                ? SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        height: 1.8,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Edit your CHRONICLE summary...',
                        border: InputBorder.none,
                        alignLabelWithHint: true,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      widget.aggregation.content,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        height: 1.8,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
