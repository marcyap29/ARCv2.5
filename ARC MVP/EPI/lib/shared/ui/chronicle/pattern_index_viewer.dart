import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/chronicle/storage/chronicle_index_storage.dart';
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

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _index = null;
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final storage = ChronicleIndexStorage();
      final json = await storage.read(userId);

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
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
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
                            '${_index!.themeClusters.length} theme cluster(s) · Last updated ${_formatDate(_index!.lastUpdated)}',
                            style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
                          ),
                          const SizedBox(height: 16),
                          ..._index!.themeClusters.values.map(_buildClusterCard),
                        ],
                      ),
                    ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
                Icon(Icons.psychology, color: kcPrimaryColor, size: 24),
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
