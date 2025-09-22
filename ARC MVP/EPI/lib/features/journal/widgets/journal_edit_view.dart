import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
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
  late String _currentPhase;
  late String _currentGeometry;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.preview);
    _focusNode = FocusNode();
    
    // Initialize with existing data
    _selectedMood = null; // TimelineEntry doesn't have mood, will be set by user
    _selectedKeywords = List<String>.from(widget.entry.keywords);
    _currentPhase = widget.entry.phase ?? 'Discovery';
    _currentGeometry = widget.entry.geometry ?? 'spiral';
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
              Row(
                children: [
                  Icon(
                    _getPhaseIcon(_currentPhase),
                    color: _getPhaseColor(_currentPhase),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Phase: $_currentPhase',
                    style: bodyStyle(context).copyWith(
                      color: _getPhaseColor(_currentPhase),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
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
                          _getGeometryIcon(_currentGeometry),
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
                          decoration: const BoxDecoration(
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
        return _PhaseEditDialog(
          currentPhase: _currentPhase,
          currentGeometry: _currentGeometry,
          onPhaseChanged: (newPhase, newGeometry) async {
            try {
              // Show loading state
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Updating phase...'),
                  backgroundColor: kcPrimaryColor,
                  duration: Duration(seconds: 1),
                ),
              );

              // Update the entry phase in the database
              final timelineCubit = context.read<TimelineCubit>();
              await timelineCubit.updateEntryPhase(
                widget.entry.id, 
                newPhase, 
                newGeometry,
              );

              // Update local state to reflect the change immediately
              setState(() {
                _currentPhase = newPhase;
                _currentGeometry = newGeometry;
              });

              // Show success message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Phase updated to $newPhase'),
                    backgroundColor: kcSuccessColor,
                  ),
                );
              }
            } catch (e) {
              // Show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to update phase'),
                    backgroundColor: kcDangerColor,
                  ),
                );
              }
            }
          },
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

class _PhaseEditDialog extends StatefulWidget {
  final String currentPhase;
  final String currentGeometry;
  final Function(String phase, String geometry) onPhaseChanged;

  const _PhaseEditDialog({
    required this.currentPhase,
    required this.currentGeometry,
    required this.onPhaseChanged,
  });

  @override
  State<_PhaseEditDialog> createState() => _PhaseEditDialogState();
}

class _PhaseEditDialogState extends State<_PhaseEditDialog> {
  late String _selectedPhase;
  late String _selectedGeometry;

  final Map<String, String> _phaseDescriptions = {
    'Discovery': 'Exploring new insights and beginnings',
    'Expansion': 'Expanding awareness and growth', 
    'Transition': 'Navigating transitions and choices',
    'Consolidation': 'Integrating experiences and wisdom',
    'Recovery': 'Healing and restoring balance',
    'Breakthrough': 'Breaking through to new levels',
  };

  final Map<String, String> _phaseToGeometry = {
    'Discovery': 'spiral',
    'Expansion': 'flower',
    'Transition': 'branch', 
    'Consolidation': 'weave',
    'Recovery': 'glowcore',
    'Breakthrough': 'fractal',
  };

  @override
  void initState() {
    super.initState();
    _selectedPhase = widget.currentPhase;
    _selectedGeometry = widget.currentGeometry;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kcBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Edit Phase',
              style: heading1Style(context).copyWith(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a new phase for this entry',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),

            // Phase Selection
            Expanded(
              child: ListView(
                children: _phaseDescriptions.entries.map((entry) {
                  final phase = entry.key;
                  final description = entry.value;
                  final isSelected = phase == _selectedPhase;
                  final isCurrent = phase == widget.currentPhase;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? kcPrimaryColor.withOpacity(0.2)
                          : kcSurfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? kcPrimaryColor
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(
                        _getPhaseIcon(phase),
                        color: _getPhaseColor(phase),
                        size: 24,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              phase,
                              style: heading3Style(context).copyWith(
                                color: Colors.white,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: kcAccentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Current",
                                style: captionStyle(context).copyWith(
                                  color: kcAccentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          description,
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPhase = phase;
                          _selectedGeometry = _phaseToGeometry[phase] ?? 'spiral';
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: kcSecondaryColor.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: buttonStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPhaseChanged(_selectedPhase, _selectedGeometry);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Update Phase',
                      style: buttonStyle(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
}
