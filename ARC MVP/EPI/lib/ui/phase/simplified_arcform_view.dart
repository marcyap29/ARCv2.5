import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../arcform/models/arcform_models.dart';
import '../../arcform/layouts/layouts_3d.dart';
import '../../arcform/render/arcform_renderer_3d.dart';
import 'phase_arcform_3d_screen.dart';

/// Simplified ARCForms view - read-only constellation display
class SimplifiedArcformView extends StatefulWidget {
  const SimplifiedArcformView({super.key});

  @override
  State<SimplifiedArcformView> createState() => _SimplifiedArcformViewState();
}

class _SimplifiedArcformViewState extends State<SimplifiedArcformView> {
  List<Map<String, dynamic>> _snapshots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  /// Public method to refresh snapshots (called from parent)
  void refreshSnapshots() {
    _loadSnapshots();
  }

  /// Load existing Arcform snapshots
  Future<void> _loadSnapshots() async {
    setState(() => _isLoading = true);
    
    try {
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox('arcform_snapshots');
      }
      final box = Hive.box('arcform_snapshots');
      final snapshots = <Map<String, dynamic>>[];
      
      for (final key in box.keys) {
        final snapshot = box.get(key);
        if (snapshot is Map) {
          snapshots.add(Map<String, dynamic>.from(snapshot));
        }
      }
      
      // Sort by creation date (newest first)
      snapshots.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      
      setState(() {
        _snapshots = snapshots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _snapshots = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('ARCForms', style: heading1Style(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kcPrimaryColor),
            onPressed: _loadSnapshots,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                ),
              )
            : _snapshots.isEmpty
                ? _buildEmptyState()
                : _buildSnapshotsList(),
      ),
    );
  }

  /// Build empty state when no snapshots exist
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: kcPrimaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Visualizations Yet',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Your constellation visualizations will appear here after journaling and RIVET analysis.',
              textAlign: TextAlign.center,
              style: bodyStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the scrollable list of Arcform snapshots
  Widget _buildSnapshotsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _snapshots.length,
      itemBuilder: (context, index) {
        final snapshot = _snapshots[index];
        return _buildSnapshotCard(snapshot);
      },
    );
  }

  /// Build a card for a single Arcform snapshot (constellation view)
  Widget _buildSnapshotCard(Map<String, dynamic> snapshot) {
    final keywords = List<String>.from(snapshot['keywords'] ?? []);
    final geometry = snapshot['geometry'] ?? 'constellation';
    final mood = snapshot['mood'] ?? 'neutral';
    final phaseHint = snapshot['phaseHint'] ?? 'Discovery';
    final createdAt = DateTime.tryParse(snapshot['createdAt'] ?? '') ?? DateTime.now();
    final title = snapshot['title'] ?? 'Untitled Constellation';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with constellation icon
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: kcPrimaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: heading3Style(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Constellation visualization placeholder
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: kcBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kcSecondaryColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star,
                      color: kcPrimaryColor.withOpacity(0.7),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Constellation View',
                      style: TextStyle(
                        color: kcPrimaryColor.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${keywords.length} stars',
                      style: TextStyle(
                        color: kcSecondaryTextColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Keywords as constellation points
            if (keywords.isNotEmpty) ...[
              Text(
                'Constellation Points:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: kcSecondaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: keywords.take(8).map((keyword) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kcPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kcPrimaryColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    keyword,
                    style: TextStyle(
                      color: kcPrimaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
              if (keywords.length > 8) ...[
                const SizedBox(height: 4),
                Text(
                  '+${keywords.length - 8} more points',
                  style: TextStyle(
                    color: kcSecondaryTextColor,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            
            const SizedBox(height: 16),
            
            // Metadata row
            Row(
              children: [
                _buildMetadataChip('Pattern', geometry, kcSecondaryColor),
                const SizedBox(width: 8),
                _buildMetadataChip('Mood', mood, kcAccentColor),
                const SizedBox(width: 8),
                _buildMetadataChip('Phase', phaseHint, kcSuccessColor),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              'Created: ${_formatDate(createdAt)}',
              style: captionStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a metadata chip
  Widget _buildMetadataChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$label: $value',
        style: captionStyle(context).copyWith(
          color: color,
          fontSize: 10,
        ),
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
