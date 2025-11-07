import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/core/keyword_extraction_cubit.dart';
import 'package:my_app/arc/core/keyword_extraction_state.dart';
import 'package:my_app/arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class KeywordAnalysisView extends StatefulWidget {
  final String content;
  final String mood;
  final String? initialEmotion;
  final String? initialReason;
  final List<String>? manualKeywords;
  final Map<String, List<String>>? discoveredKeywords; // Real-time discovered keywords
  final List<String>? selectedKeywords; // Pre-selected keywords
  final JournalEntry? existingEntry; // For editing existing entries
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final String? selectedLocation;
  final List<MediaItem>? mediaItems; // Media items from journal screen
  final List<Map<String, dynamic>>? lumaraBlocks; // LUMARA inline blocks
  
  const KeywordAnalysisView({
    super.key,
    required this.content,
    required this.mood,
    this.initialEmotion,
    this.initialReason,
    this.manualKeywords,
    this.discoveredKeywords,
    this.selectedKeywords,
    this.existingEntry,
    this.selectedDate,
    this.selectedTime,
    this.selectedLocation,
    this.mediaItems,
    this.lumaraBlocks,
  });

  @override
  State<KeywordAnalysisView> createState() => _KeywordAnalysisViewState();
}

class _KeywordAnalysisViewState extends State<KeywordAnalysisView>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final JournalRepository _journalRepository = JournalRepository();
  List<String> _pastKeywords = [];
  List<String> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize title controller with existing entry title if available
    if (widget.existingEntry != null && widget.existingEntry!.title.isNotEmpty) {
      _titleController.text = widget.existingEntry!.title;
    }
    
    // Load past keywords for autocomplete
    _loadPastKeywords();
    
    // Listen to keyword controller changes for autocomplete
    _keywordController.addListener(_onKeywordTextChanged);
    
    // Initialize progress animation
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // Start keyword extraction and animation
    context.read<KeywordExtractionCubit>().extractKeywords(widget.content);
    _progressController.forward();
  }

  Future<void> _loadPastKeywords() async {
    try {
      final entries = _journalRepository.getAllJournalEntries();
      final allKeywords = <String>{};
      
      for (final entry in entries) {
        allKeywords.addAll(entry.keywords);
      }
      
      setState(() {
        _pastKeywords = allKeywords.toList()..sort();
      });
    } catch (e) {
      debugPrint('Error loading past keywords: $e');
    }
  }

  void _onKeywordTextChanged() {
    final text = _keywordController.text.toLowerCase();
    if (text.isEmpty) {
      setState(() {
        _filteredSuggestions = [];
      });
      return;
    }

    // Find the last word being typed (after comma or at start)
    final parts = text.split(',');
    final currentWord = parts.last.trim();
    
    if (currentWord.isEmpty) {
      setState(() {
        _filteredSuggestions = [];
      });
      return;
    }

    // Filter past keywords that start with current word
    final suggestions = _pastKeywords
        .where((keyword) => keyword.toLowerCase().startsWith(currentWord))
        .take(5)
        .toList();

    setState(() {
      _filteredSuggestions = suggestions;
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _keywordController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onSaveEntry() async {
    // Use discovered keywords instead of old extraction method
    final allKeywords = <String>[];
    
    // Add discovered keywords (pre-selected from real-time analysis)
    if (widget.selectedKeywords != null) {
      allKeywords.addAll(widget.selectedKeywords!);
    }
    
    // Add manual keywords
    if (widget.manualKeywords != null) {
      allKeywords.addAll(widget.manualKeywords!);
    }
    
    // Remove duplicates
    final uniqueKeywords = allKeywords.toSet().toList();
    
    // DEBUG: Log keyword saving for confirmation
    debugPrint('🔍 KeywordAnalysisView: Saving entry with ${uniqueKeywords.length} total keywords');
    debugPrint('🔍 - Discovered keywords: ${widget.selectedKeywords?.length ?? 0}');
    debugPrint('🔍 - Manual keywords: ${widget.manualKeywords?.length ?? 0}');
    debugPrint('🔍 - Final unique keywords: $uniqueKeywords');
    
    if (widget.existingEntry != null) {
      // For existing entries, ask for confirmation before overwriting (3e requirement)
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overwrite Entry?'),
          content: Text(
            'This will overwrite the original entry from ${_formatEntryDate(widget.existingEntry!.createdAt)}. '
            'This action cannot be undone. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: kcPrimaryColor),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        // User cancelled, don't save
        return;
      }
      
      // Update existing entry - check if mounted before using context
      if (!mounted) return;
      final journalCaptureCubit = context.read<JournalCaptureCubit>();
      final timelineCubit = context.read<TimelineCubit>();
      
      journalCaptureCubit.updateEntryWithKeywords(
        existingEntry: widget.existingEntry!,
        content: widget.content,
        mood: widget.mood,
        selectedKeywords: uniqueKeywords,
        emotion: widget.initialEmotion,
        emotionReason: widget.initialReason,
        selectedDate: widget.selectedDate,
        selectedTime: widget.selectedTime,
        selectedLocation: widget.selectedLocation,
        context: context,
        media: widget.mediaItems, // Pass media items
        blocks: widget.lumaraBlocks, // Pass LUMARA blocks
        title: _titleController.text.trim(),
      );
      
      // Show success message with keyword count
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Entry updated successfully with ${uniqueKeywords.length} keywords'
            ),
            backgroundColor: kcSuccessColor,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Reload all entries to handle date changes properly
        timelineCubit.reloadAllEntries();
        
        // Return result to previous screen instead of navigating directly to home
        Navigator.of(context).pop({'save': true});
      }
    } else {
      // Save new entry - check if mounted before using context
      if (!mounted) return;
      final journalCaptureCubit = context.read<JournalCaptureCubit>();
      final timelineCubit = context.read<TimelineCubit>();
      
      journalCaptureCubit.saveEntryWithKeywords(
        content: widget.content,
        mood: widget.mood,
        selectedKeywords: uniqueKeywords,
        emotion: widget.initialEmotion,
        emotionReason: widget.initialReason,
        context: context,
        media: widget.mediaItems, // Pass media items
        blocks: widget.lumaraBlocks, // Pass LUMARA blocks
        title: _titleController.text.trim(),
      );
    
    // Show success message with keyword count
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Entry saved successfully with ${uniqueKeywords.length} keywords'
          ),
          backgroundColor: kcSuccessColor,
          duration: const Duration(seconds: 3),
        ),
      );
      
        timelineCubit.refreshEntries();
      
      // Return result to previous screen instead of navigating directly to home
      Navigator.of(context).pop({'save': true});
      }
    }
  }

  String _formatEntryDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('Keywords Discovered', style: heading1Style(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _onSaveEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text('Save Entry', style: buttonStyle(context)),
            ),
          ),
        ],
      ),
      body: _buildKeywordAnalysis(context),
    );
  }

  Widget _buildAnalysisProgress() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Sacred geometry animation/icon
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              gradient: kcPrimaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_graph,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            'ARC is analyzing your entry',
            style: heading1Style(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          Text(
            'Discovering the keywords that matter most...',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: kcSurfaceColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          kcPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_progressAnimation.value * 100).round()}%',
                    style: captionStyle(context).copyWith(
                      color: kcPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildKeywordSelection(KeywordExtractionLoaded state) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: kcPrimaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keywords Discovered',
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose keywords that best represent your reflection',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Title input field
          Text(
            'Entry Title (Optional)',
            style: heading2Style(context),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Give your entry a title...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: bodyStyle(context),
          ),
          const SizedBox(height: 24),
          
          // Context reminder
          if (widget.initialEmotion != null || widget.initialReason != null) ...[
            Text(
              'Your reflection context:',
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.initialEmotion != null) ...[
                  _buildContextTag(widget.initialEmotion!),
                  const SizedBox(width: 8),
                ],
                if (widget.initialReason != null)
                  _buildContextTag(widget.initialReason!),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // Selection count
          Text(
            'Selected: ${state.selectedKeywords.length}',
            style: heading2Style(context).copyWith(
              color: state.selectedKeywords.isNotEmpty ? kcPrimaryColor : kcSecondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Keywords grid
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: state.suggestedKeywords
                    .map((keyword) => _buildKeywordChip(keyword, state.selectedKeywords))
                    .toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Selection guidance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcSurfaceAltColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.selectedKeywords.isEmpty)
                  Text(
                    'Select at least 1 keyword to save your entry',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  )
                else
                  Text(
                    'Great selection! Tap "Save Entry" when ready.',
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcSecondaryColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: captionStyle(context).copyWith(
          color: kcSecondaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildKeywordChip(String keyword, List<String> selectedKeywords) {
    final isSelected = selectedKeywords.contains(keyword);
    
    return GestureDetector(
      onTap: () {
        context.read<KeywordExtractionCubit>().toggleKeyword(keyword);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? kcPrimaryColor : kcSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected 
                ? kcPrimaryColor 
                : kcSecondaryColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          keyword,
          style: bodyStyle(context).copyWith(
            color: isSelected 
                ? Colors.white 
                : kcSecondaryColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: kcDangerColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Analysis Failed',
              style: heading1Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<KeywordExtractionCubit>().extractKeywords(widget.content);
                _progressController.reset();
                _progressController.forward();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
              ),
              child: Text('Try Again', style: buttonStyle(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordAnalysis(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content preview
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entry Content:', 
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  widget.content,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24.0),
          
          // Discovered keywords
          if (widget.discoveredKeywords != null && widget.discoveredKeywords!.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Discovered Keywords:', 
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            ...widget.discoveredKeywords!.entries.map((entry) {
              return _buildKeywordCategory(entry.key, entry.value, context, theme);
            }),
            const SizedBox(height: 24.0),
          ],
          
          // Manual keyword input
          _buildManualKeywordInput(context, theme),
          
          const SizedBox(height: 24.0),
          
          // Keywords summary (shows what will be saved)
          _buildKeywordsSummary(context, theme),
          
          const SizedBox(height: 24.0),
          
          // Selected keywords summary
          if (widget.selectedKeywords != null && widget.selectedKeywords!.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selected Keywords:', 
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: widget.selectedKeywords!.map((keyword) {
                return Chip(
                  label: Text(
                    keyword,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeywordCategory(String category, List<String> keywords, BuildContext context, ThemeData theme) {
    // Category colors matching the original KeywordsDiscoveredWidget
    final categoryColors = {
      'Places': theme.colorScheme.primary,
      'Time': theme.colorScheme.secondary,
      'Energy Levels': theme.colorScheme.tertiary,
      'Emotions': Colors.pink,
      'Feelings': Colors.purple,
      'Activities': Colors.orange,
      'Objects': Colors.brown,
      'People': Colors.blue,
      'Health': Colors.green,
      'Work': Colors.indigo,
      'Relationships': Colors.red,
      'Personal': Colors.teal,
    };
    
    final color = categoryColors[category] ?? theme.colorScheme.secondary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: keywords.map((keyword) {
              final isSelected = widget.selectedKeywords?.contains(keyword) ?? false;
              return FilterChip(
                label: Text(
                  keyword,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      widget.selectedKeywords?.add(keyword);
                    } else {
                      widget.selectedKeywords?.remove(keyword);
                    }
                  });
                },
                selectedColor: color.withOpacity(0.3),
                checkmarkColor: Colors.white,
                backgroundColor: color.withOpacity(0.1),
                side: BorderSide(
                  color: color.withOpacity(0.3),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildManualKeywordInput(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Manual Keywords:', 
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Enter keywords separated by commas',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.outline.withOpacity(0.7),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _addManualKeywords(),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  ElevatedButton(
                    onPressed: _addManualKeywords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
              // Autocomplete suggestions
              if (_filteredSuggestions.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _filteredSuggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          suggestion,
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () {
                          _selectSuggestion(suggestion);
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _selectSuggestion(String suggestion) {
    final text = _keywordController.text;
    final parts = text.split(',');
    if (parts.length > 1) {
      // Replace the last part with the suggestion
      parts[parts.length - 1] = suggestion;
      _keywordController.text = parts.join(', ') + ', ';
    } else {
      // Replace entire text with suggestion
      _keywordController.text = '$suggestion, ';
    }
    _keywordController.selection = TextSelection.fromPosition(
      TextPosition(offset: _keywordController.text.length),
    );
    setState(() {
      _filteredSuggestions = [];
    });
  }

  void _addManualKeywords() {
    final text = _keywordController.text.trim();
    if (text.isNotEmpty) {
      final keywords = text.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
      setState(() {
        widget.selectedKeywords?.addAll(keywords);
        widget.manualKeywords?.addAll(keywords);
      });
      _keywordController.clear();
      _filteredSuggestions = [];
    }
  }

  /// Build keywords summary showing what will be saved
  Widget _buildKeywordsSummary(BuildContext context, ThemeData theme) {
    final allKeywords = <String>[];
    
    // Add discovered keywords
    if (widget.selectedKeywords != null) {
      allKeywords.addAll(widget.selectedKeywords!);
    }
    
    // Add manual keywords
    if (widget.manualKeywords != null) {
      allKeywords.addAll(widget.manualKeywords!);
    }
    
    final uniqueKeywords = allKeywords.toSet().toList();
    
    if (uniqueKeywords.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Keywords to be saved (${uniqueKeywords.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: uniqueKeywords.map((keyword) => Chip(
              label: Text(keyword),
              backgroundColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 12,
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}