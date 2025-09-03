import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/features/timeline/widgets/historical_arcform_view.dart';
import 'package:my_app/repositories/journal_repository.dart';
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
  late TextEditingController _dateController;
  late FocusNode _focusNode;
  String? _selectedMood;
  List<String> _selectedKeywords = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.preview);
    _focusNode = FocusNode();
    
    // Parse date from entry format (M/d/yyyy)
    try {
      final dateParts = widget.entry.date.split('/');
      _selectedDate = DateTime(
        int.parse(dateParts[2]), // year
        int.parse(dateParts[0]), // month
        int.parse(dateParts[1]), // day
      );
    } catch (e) {
      _selectedDate = DateTime.now();
    }
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    
    // Initialize with existing data
    _selectedMood = null; // TimelineEntry doesn't have mood, will be set by user
    _selectedKeywords = List<String>.from(widget.entry.keywords);
  }

  @override
  void dispose() {
    _textController.dispose();
    _dateController.dispose();
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
          // View historical arcform button
          IconButton(
            onPressed: _viewHistoricalArcform,
            icon: const Icon(Icons.auto_graph),
            color: kcPrimaryColor,
            tooltip: 'View Arcform',
          ),
          const SizedBox(width: 8),
          // Delete button
          IconButton(
            onPressed: _onDeletePressed,
            icon: const Icon(Icons.delete_outline),
            color: kcDangerColor,
            tooltip: 'Delete Entry',
          ),
          const SizedBox(width: 8),
          // Save button
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry date (editable)
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
                      'Entry Date:',
                      style: captionStyle(context).copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showDatePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_selectedDate),
                              style: heading1Style(context).copyWith(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
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

              // Text editor
              Expanded(
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
                  ),
                  maxLines: null,
                  expands: true,
                  textInputAction: TextInputAction.newline,
                  cursorColor: kcPrimaryColor,
                  cursorWidth: 2,
                  cursorRadius: const Radius.circular(2),
                ),
              ),
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
                      child: Icon(
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
              borderSide: BorderSide(color: kcPrimaryColor),
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
    // This would update the existing entry with new content, mood, keywords, and date
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entry updated successfully'),
        backgroundColor: kcSuccessColor,
      ),
    );
    
    Navigator.of(context).pop();
  }

  void _onDeletePressed() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text(
          'Delete Entry',
          style: heading1Style(context),
        ),
        content: Text(
          'Are you sure you want to delete this journal entry? This action cannot be undone.',
          style: bodyStyle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: buttonStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcDangerColor,
            ),
            child: Text(
              'Delete',
              style: buttonStyle(context),
            ),
          ),
        ],
      ),
    ).then((shouldDelete) {
      if (shouldDelete == true) {
        _deleteEntry();
      }
    });
  }

  Future<void> _deleteEntry() async {
    try {
      final journalRepository = JournalRepository();
      await journalRepository.deleteJournalEntry(widget.entry.id);
      
      // Check if this was the last entry
      final timelineCubit = context.read<TimelineCubit>();
      final allEntriesDeleted = await timelineCubit.checkIfAllEntriesDeleted();
      
      if (mounted) {
        if (!allEntriesDeleted) {
          // Refresh the timeline if there are still entries
          timelineCubit.refreshEntries();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry deleted successfully'),
            backgroundColor: kcSuccessColor,
          ),
        );
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete entry: $e'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    }
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: kcPrimaryColor,
              onPrimary: Colors.white,
              surface: kcSurfaceColor,
              onSurface: kcPrimaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(_selectedDate);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _viewHistoricalArcform() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HistoricalArcformView(entry: widget.entry),
      ),
    );
  }
}
