import 'package:flutter/material.dart';
import '../../services/keyword_analysis_service.dart';

class KeywordsDiscoveredWidget extends StatefulWidget {
  final String text;
  final List<String> manualKeywords;
  final Function(List<String>) onKeywordsChanged;
  final VoidCallback? onAddKeywords;

  const KeywordsDiscoveredWidget({
    super.key,
    required this.text,
    required this.manualKeywords,
    required this.onKeywordsChanged,
    this.onAddKeywords,
  });

  @override
  State<KeywordsDiscoveredWidget> createState() => _KeywordsDiscoveredWidgetState();
}

class _KeywordsDiscoveredWidgetState extends State<KeywordsDiscoveredWidget> {
  final KeywordAnalysisService _keywordService = KeywordAnalysisService();
  late Map<String, List<String>> _categorizedKeywords;
  final TextEditingController _keywordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _analyzeKeywords();
  }

  @override
  void didUpdateWidget(KeywordsDiscoveredWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _analyzeKeywords();
    }
  }

  void _analyzeKeywords() {
    _categorizedKeywords = _keywordService.analyzeKeywords(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add Keywords button
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Keywords Discovered',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onAddKeywords,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Keywords',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Show categorized keywords if any
          if (_categorizedKeywords.isNotEmpty) ...[
            ..._categorizedKeywords.entries.map((entry) {
              return _buildCategorySection(entry.key, entry.value, theme);
            }),
            const SizedBox(height: 12),
          ],
          
          // Manual keyword input section
          _buildManualKeywordInput(theme),
          
          // Show manual keywords if any
          if (widget.manualKeywords.isNotEmpty) ...[
            _buildManualKeywordsSection(theme),
            const SizedBox(height: 12),
          ],
          
          // Show suggestions if no keywords found
          if (_categorizedKeywords.isEmpty && widget.manualKeywords.isEmpty) ...[
            _buildNoKeywordsMessage(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySection(String category, List<String> keywords, ThemeData theme) {
    final categoryColors = {
      'Places': Colors.blue,
      'Time': Colors.indigo,
      'Energy Levels': Colors.amber,
      'Emotions': Colors.red,
      'Feelings': Colors.purple,
      'States of Being': Colors.green,
      'Adjectives': Colors.orange,
      'Slang': Colors.teal,
    };
    
    final categoryIcons = {
      'Places': Icons.location_on,
      'Time': Icons.access_time,
      'Energy Levels': Icons.battery_charging_full,
      'Emotions': Icons.mood,
      'Feelings': Icons.favorite,
      'States of Being': Icons.self_improvement,
      'Adjectives': Icons.description,
      'Slang': Icons.chat_bubble_outline,
    };
    
    final color = categoryColors[category] ?? theme.colorScheme.secondary;
    final icon = categoryIcons[category] ?? Icons.label;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                category,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: keywords.take(8).map((keyword) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                keyword,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildManualKeywordsSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Manual Keywords',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.manualKeywords.map((keyword) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.secondary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    keyword,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _removeManualKeyword(keyword),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.secondary.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoKeywordsMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 32,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No keywords discovered yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add some text or use the + button to add keywords manually',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _removeManualKeyword(String keyword) {
    final updatedKeywords = List<String>.from(widget.manualKeywords);
    updatedKeywords.remove(keyword);
    widget.onKeywordsChanged(updatedKeywords);
  }

  Widget _buildManualKeywordInput(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Add Keywords',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: InputDecoration(
                    hintText: 'Type keywords separated by commas',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withOpacity(0.7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: theme.textTheme.bodySmall,
                  onSubmitted: (value) => _addKeywords(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addKeywords,
                icon: const Icon(Icons.add),
                tooltip: 'Add Keywords',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addKeywords() {
    final text = _keywordController.text.trim();
    if (text.isNotEmpty) {
      final keywords = text.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
      final updatedKeywords = List<String>.from(widget.manualKeywords);
      updatedKeywords.addAll(keywords);
      widget.onKeywordsChanged(updatedKeywords.toSet().toList()); // Remove duplicates
      _keywordController.clear();
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }
}
