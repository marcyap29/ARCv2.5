import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/chronicle/storage/chronicle_index_storage.dart';
import 'package:my_app/chronicle/storage/chronicle_theme_ignore_list_storage.dart';
import 'package:my_app/chronicle/models/chronicle_index.dart';
import 'package:my_app/chronicle/models/theme_cluster.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Viewer for the CHRONICLE pattern index (vectorized themes).
///
/// Shows which themes have been embedded and clustered across time,
/// with appearance counts and periods.
class PatternIndexViewer extends StatefulWidget {
  const PatternIndexViewer({super.key});

  @override
  State<PatternIndexViewer> createState() => _PatternIndexViewerState();
}

class _PatternIndexViewerState extends State<PatternIndexViewer> {
  bool _isLoading = true;
  String? _error;
  ChronicleIndex? _index;
  List<String> _ignoredLabels = [];
  bool _showIgnored = false;

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  String get _userId =>
      FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';

  Future<void> _loadIgnoreList() async {
    final list = await ChronicleThemeIgnoreListStorage.getIgnored(_userId);
    if (mounted) setState(() => _ignoredLabels = list);
  }

  Future<void> _loadIndex() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _index = null;
    });

    try {
      final userId = _userId;
      final storage = ChronicleIndexStorage();
      final json = await storage.read(userId);
      await _loadIgnoreList();

      if (json.isEmpty || !json.containsKey('theme_clusters')) {
        if (mounted) {
          setState(() {
            _index = ChronicleIndex.empty();
            _isLoading = false;
          });
        }
        return;
      }

      final index = ChronicleIndex.fromJson(json);
      if (mounted) {
        setState(() {
          _index = index;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Visible clusters (not in ignore list).
  List<ThemeCluster> get _visibleClusters {
    if (_index == null) return [];
    final ignored = _ignoredLabels.toSet();
    return _index!.themeClusters.values
        .where((c) => !ignored.contains(c.canonicalLabel))
        .toList();
  }

  /// Clusters that are in the ignore list (for "Ignored themes" section).
  List<ThemeCluster> get _ignoredClusters {
    if (_index == null) return [];
    final ignored = _ignoredLabels.toSet();
    return _index!.themeClusters.values
        .where((c) => ignored.contains(c.canonicalLabel))
        .toList();
  }

  Future<void> _addToIgnoreList(String canonicalLabel) async {
    await ChronicleThemeIgnoreListStorage.addIgnored(_userId, canonicalLabel);
    await _loadIgnoreList();
    if (mounted) setState(() {});
  }

  Future<void> _removeFromIgnoreList(String canonicalLabel) async {
    await ChronicleThemeIgnoreListStorage.removeIgnored(_userId, canonicalLabel);
    await _loadIgnoreList();
    if (mounted) setState(() {});
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
          'Vectorized patterns',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kcPrimaryTextColor),
            onPressed: _isLoading ? null : _loadIndex,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load pattern index',
                        style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _index == null || _index!.themeClusters.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 64,
                              color: kcPrimaryTextColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No vectorized patterns yet',
                              style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Run monthly synthesis and update the pattern index in CHRONICLE Management to see themes here.',
                              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadIndex,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            '${_visibleClusters.length} theme cluster(s)${_ignoredLabels.isEmpty ? "" : " · ${_ignoredLabels.length} ignored"} · Last updated ${_formatDate(_index!.lastUpdated)}',
                            style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Swipe left on a theme to add it to the ignore list (won\'t appear in pattern queries).',
                            style: captionStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_visibleClusters.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  _index!.themeClusters.isEmpty
                                      ? 'No themes yet.'
                                      : 'All themes are ignored. Restore some below.',
                                  style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                                ),
                              ),
                            )
                          else
                            ..._visibleClusters.map((c) => _buildDismissibleClusterCard(c)),
                          if (_ignoredClusters.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            InkWell(
                              onTap: () => setState(() => _showIgnored = !_showIgnored),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showIgnored ? Icons.expand_less : Icons.expand_more,
                                      color: kcSecondaryTextColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ignored themes (${_ignoredClusters.length}) — tap to restore',
                                      style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showIgnored) ...[
                              const SizedBox(height: 8),
                              ..._ignoredClusters.map((c) => _buildIgnoredClusterTile(c)),
                            ],
                          ],
                        ],
                      ),
                    ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Swipe left to add theme to ignore list (delete-like motion).
  Widget _buildDismissibleClusterCard(ThemeCluster cluster) {
    return Dismissible(
      key: ValueKey<String>(cluster.clusterId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kcSecondaryTextColor.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.block, color: kcPrimaryTextColor.withOpacity(0.8), size: 24),
            const SizedBox(width: 8),
            Text(
              'Ignore',
              style: heading3Style(context).copyWith(
                color: kcPrimaryTextColor.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        await _addToIgnoreList(cluster.canonicalLabel);
        return true;
      },
      child: _buildClusterCard(cluster),
    );
  }

  Widget _buildIgnoredClusterTile(ThemeCluster cluster) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: kcSurfaceColor.withOpacity(0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.block, color: kcSecondaryTextColor, size: 20),
        title: Text(
          cluster.canonicalLabel,
          style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
        ),
        trailing: TextButton(
          onPressed: () async {
            await _removeFromIgnoreList(cluster.canonicalLabel);
          },
          child: Text('Restore', style: captionStyle(context).copyWith(color: kcPrimaryColor)),
        ),
      ),
    );
  }

  Widget _buildClusterCard(ThemeCluster cluster) {
    final periods = cluster.appearances
        .map((a) => a.period)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kcSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: kcPrimaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cluster.canonicalLabel,
                    style: heading3Style(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${cluster.totalAppearances} appearance(s)',
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
            if (cluster.aliases.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: cluster.aliases
                    .take(5)
                    .map((a) => Chip(
                          label: Text(a, style: captionStyle(context)),
                          backgroundColor: kcBackgroundColor,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            if (periods.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Periods: ${periods.take(10).join(", ")}${periods.length > 10 ? "…" : ""}',
                style: captionStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
