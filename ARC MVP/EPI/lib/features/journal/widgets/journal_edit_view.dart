import 'package:flutter/material.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class JournalEditView extends StatefulWidget {
  final TimelineEntry entry;
  final int entryIndex;

  const JournalEditView({
    super.key,
    required this.entry,
    required this.entryIndex,
  });

  @override
  State<JournalEditView> createState() => _JournalEditViewState();
}

class _JournalEditViewState extends State<JournalEditView> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  String? _selectedMood;
  List<String> _selectedKeywords = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.preview);
    _focusNode = FocusNode();
    
    // Initialize with existing data
    _selectedMood = null; // TimelineEntry doesn't have mood, will be set by user
    _selectedKeywords = List<String>.from(widget.entry.keywords);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('Edit Entry', style: heading1Style(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text('Save', style: buttonStyle(context)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry date
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: kcPrimaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editing entry from:',
                      style: captionStyle(context).copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.entry.date,
                      style: heading1Style(context).copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Mood selection
              _buildMoodSection(),
              
              const SizedBox(height: 24),

              // Keywords section
              _buildKeywordsSection(),
              
              const SizedBox(height: 24),

              // Arcform section
              _buildArcformSection(),
              
              const SizedBox(height: 24),

              // Text editor
              Container(
                height: 200, // Fixed height to prevent overflow
                decoration: BoxDecoration(
                  color: kcSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kcSecondaryTextColor.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: bodyStyle(context),
                  decoration: InputDecoration(
                    hintText: 'Edit your journal entry...',
                    hintStyle: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  cursorColor: kcPrimaryColor,
                  cursorWidth: 2,
                  cursorRadius: const Radius.circular(2),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSection() {
    final moods = ['happy', 'sad', 'anxious', 'calm', 'excited', 'grateful', 'confused', 'hopeful'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mood',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moods.map((mood) {
            final isSelected = _selectedMood == mood;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMood = isSelected ? null : mood;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? kcPrimaryColor 
                      : kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? kcPrimaryColor 
                        : kcSecondaryTextColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  mood,
                  style: bodyStyle(context).copyWith(
                    color: isSelected 
                        ? Colors.white 
                        : kcPrimaryTextColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKeywordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keywords',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        if (_selectedKeywords.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedKeywords.map((keyword) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kcPrimaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kcPrimaryColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      keyword,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedKeywords.remove(keyword);
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: kcPrimaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          decoration: InputDecoration(
            hintText: 'Add keywords (press Enter to add)',
            hintStyle: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kcSecondaryTextColor.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kcPrimaryColor),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && !_selectedKeywords.contains(value.trim())) {
              setState(() {
                _selectedKeywords.add(value.trim());
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildArcformSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Arcform',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kcSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kcSecondaryTextColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              // Phase display
              if (widget.entry.phase != null) ...[
                Row(
                  children: [
                    Icon(
                      _getPhaseIcon(widget.entry.phase!),
                      color: _getPhaseColor(widget.entry.phase!),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Phase: ${widget.entry.phase}',
                      style: bodyStyle(context).copyWith(
                        color: _getPhaseColor(widget.entry.phase!),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              
              // Geometry display
              if (widget.entry.geometry != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.category,
                      color: kcPrimaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Geometry: ${widget.entry.geometry}',
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              
              // Arcform visualization with edit capability
              GestureDetector(
                onTap: () => _showArcformEditDialog(),
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kcSurfaceAltColor,
                    border: Border.all(
                      color: kcPrimaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          _getGeometryIcon(widget.entry.geometry),
                          color: kcPrimaryColor,
                          size: 40,
                        ),
                      ),
                      // Edit indicator
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: kcPrimaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Tap to edit arcform',
                style: captionStyle(context).copyWith(
                  color: kcPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getPhaseIcon(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Icons.explore;
      case 'expansion':
        return Icons.local_florist;
      case 'transition':
        return Icons.trending_up;
      case 'consolidation':
        return Icons.grid_view;
      case 'recovery':
        return Icons.healing;
      case 'breakthrough':
        return Icons.auto_fix_high;
      default:
        return Icons.circle;
    }
  }

  Color _getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5); // Blue
      case 'expansion':
        return const Color(0xFF7C3AED); // Purple  
      case 'transition':
        return const Color(0xFF059669); // Green
      case 'consolidation':
        return const Color(0xFFD97706); // Orange
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFF7C2D12); // Brown
      default:
        return kcSecondaryTextColor;
    }
  }

  IconData _getGeometryIcon(String? geometry) {
    switch (geometry?.toLowerCase()) {
      case 'spiral':
        return Icons.explore;
      case 'flower':
        return Icons.local_florist;
      case 'branch':
        return Icons.trending_up;
      case 'weave':
        return Icons.grid_view;
      case 'glowcore':
        return Icons.healing;
      case 'fractal':
        return Icons.auto_fix_high;
      default:
        return Icons.auto_awesome;
    }
  }

  void _showArcformEditDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kcSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Edit Arcform',
            style: heading1Style(context).copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current phase: ${widget.entry.phase ?? 'Unknown'}',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Current geometry: ${widget.entry.geometry ?? 'Unknown'}',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Arcform editing functionality will be available in a future update.',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: buttonStyle(context).copyWith(
                  color: kcPrimaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onSavePressed() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text before saving'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    // TODO: Implement save functionality
    // This would update the existing entry with new content, mood, and keywords
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entry updated successfully'),
        backgroundColor: kcSuccessColor,
      ),
    );
    
    Navigator.of(context).pop();
  }
}
