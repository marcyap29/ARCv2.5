import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// ARC MVP View - The core interface for creating and viewing Arcforms
/// This view demonstrates the journal entry → keywords → Arcform pipeline
class ArcformMVPView extends StatefulWidget {
  const ArcformMVPView({super.key});

  @override
  State<ArcformMVPView> createState() => _ArcformMVPViewState();
}

class _ArcformMVPViewState extends State<ArcformMVPView> {
  List<Map<String, dynamic>> _snapshots = [];
  bool _isLoading = true;
  String _selectedGeometry = 'spiral';

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  /// Load existing Arcform snapshots
  Future<void> _loadSnapshots() async {
    setState(() => _isLoading = true);
    
    try {
      final box = await Hive.openBox('arcform_snapshots');
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

  /// Create a demo Arcform from sample data
  Future<void> _createDemoArcform() async {
    try {
      final demoData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'entryId': 'demo_${DateTime.now().millisecondsSinceEpoch}',
        'title': 'Demo Reflection',
        'content': 'This is a sample journal entry to demonstrate the ARC MVP functionality. It shows how keywords are extracted and visualized.',
        'mood': 'reflective',
        'keywords': ['reflection', 'growth', 'awareness', 'insight', 'journey'],
        'geometry': _selectedGeometry,
        'colorMap': {
          'reflection': '#4F46E5',
          'growth': '#7C3AED',
          'awareness': '#D1B3FF',
          'insight': '#6BE3A0',
          'journey': '#F7D774',
        },
        'edges': [
          [0, 1, 0.8],
          [1, 2, 0.8],
          [2, 3, 0.8],
          [3, 4, 0.8],
          [4, 0, 0.6],
        ],
        'phaseHint': 'Discovery',
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      final box = await Hive.openBox('arcform_snapshots');
      await box.put(demoData['id'], demoData);
      
      await _loadSnapshots();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo Arcform created successfully!'),
            backgroundColor: kcSuccessColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create demo Arcform: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }

  /// Delete an Arcform snapshot
  Future<void> _deleteSnapshot(String id) async {
    try {
      final box = await Hive.openBox('arcform_snapshots');
      await box.delete(id);
      await _loadSnapshots();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arcform deleted successfully'),
            backgroundColor: kcSuccessColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete Arcform: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('ARC MVP', style: heading1Style(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kcPrimaryColor),
            onPressed: _loadSnapshots,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Demo creation section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kcSecondaryColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Demo Arcform',
                  style: heading2Style(context),
                ),
                const SizedBox(height: 12),
                Text(
                  'Generate a sample Arcform to see the visualization in action.',
                  style: bodyStyle(context),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGeometry,
                        decoration: InputDecoration(
                          labelText: 'Geometry Pattern',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: ['spiral', 'flower', 'branch', 'weave', 'glowCore', 'fractal']
                            .map((geometry) => DropdownMenuItem(
                                  value: geometry,
                                  child: Text(geometry),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedGeometry = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _createDemoArcform,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kcPrimaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: Text('Create Demo', style: buttonStyle(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Snapshots list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _snapshots.isEmpty
                    ? _buildEmptyState()
                    : _buildSnapshotsList(),
          ),
        ],
        ),
      ),
    );
  }

  /// Build empty state when no snapshots exist
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: kcSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No Arcforms Yet',
            style: heading2Style(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first Arcform by writing a journal entry\nor use the demo button above.',
            style: bodyStyle(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build the list of Arcform snapshots
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

  /// Build a card for a single Arcform snapshot
  Widget _buildSnapshotCard(Map<String, dynamic> snapshot) {
    final keywords = List<String>.from(snapshot['keywords'] ?? []);
    final geometry = snapshot['geometry'] ?? 'spiral';
    final mood = snapshot['mood'] ?? 'neutral';
    final phaseHint = snapshot['phaseHint'] ?? 'Discovery';
    final createdAt = DateTime.tryParse(snapshot['createdAt'] ?? '') ?? DateTime.now();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: kcSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    snapshot['title'] ?? 'Untitled',
                    style: heading3Style(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteSnapshot(snapshot['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  child: const Icon(Icons.more_vert, color: kcSecondaryColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              snapshot['content'] ?? '',
              style: bodyStyle(context),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            
            // Keywords visualization
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((keyword) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kcPrimaryColor.withOpacity(0.5)),
                ),
                child: Text(
                  keyword,
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryColor,
                    fontSize: 12,
                  ),
                ),
              )).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Metadata row
            Row(
              children: [
                _buildMetadataChip('Geometry', geometry, kcSecondaryColor),
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
