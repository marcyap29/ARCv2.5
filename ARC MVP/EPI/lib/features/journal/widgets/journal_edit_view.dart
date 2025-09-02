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
        child: Padding(
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
