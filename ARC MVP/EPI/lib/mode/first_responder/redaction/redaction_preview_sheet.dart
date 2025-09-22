import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'redaction_service.dart';
import '../fr_settings.dart';

class RedactionPreviewSheet extends StatefulWidget {
  final String entryId;
  final String originalText;
  final DateTime createdAt;
  final FRSettings settings;
  final Function(String redactedText) onApplyAndShare;
  
  const RedactionPreviewSheet({
    super.key,
    required this.entryId,
    required this.originalText,
    required this.createdAt,
    required this.settings,
    required this.onApplyAndShare,
  });

  @override
  State<RedactionPreviewSheet> createState() => _RedactionPreviewSheetState();
}

class _RedactionPreviewSheetState extends State<RedactionPreviewSheet> {
  final RedactionService _redactionService = RedactionService();
  List<RedactionMatch> _matches = [];
  String _redactedText = '';
  final Set<String> _temporaryAllowlist = <String>{};
  bool _highlightRedacted = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRedactionPreview();
  }

  Future<void> _loadRedactionPreview() async {
    try {
      final matches = await _redactionService.getRedactionMatches(
        entryId: widget.entryId,
        originalText: widget.originalText,
        createdAt: widget.createdAt,
        settings: widget.settings,
      );
      
      final redactedText = await _redactionService.redact(
        entryId: widget.entryId,
        originalText: widget.originalText,
        createdAt: widget.createdAt,
        settings: widget.settings,
        temporaryAllowlist: _temporaryAllowlist,
      );
      
      setState(() {
        _matches = matches;
        _redactedText = redactedText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _redactedText = widget.originalText; // Fail-open
      });
    }
  }

  void _toggleRestore(String original) {
    setState(() {
      if (_temporaryAllowlist.contains(original)) {
        _temporaryAllowlist.remove(original);
      } else {
        _temporaryAllowlist.add(original);
      }
    });
    _loadRedactionPreview(); // Refresh redacted text
  }

  Map<RedactionCategory, int> _getCategoryCounts() {
    final counts = <RedactionCategory, int>{};
    for (final match in _matches) {
      counts[match.category] = (counts[match.category] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: kcSecondaryColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Redaction Preview',
                          style: heading2Style(context).copyWith(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap placeholders to restore for this share only',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _highlightRedacted = !_highlightRedacted;
                      });
                    },
                    icon: Icon(
                      _highlightRedacted ? Icons.visibility : Icons.visibility_off,
                      color: kcPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Category chips
            if (!_isLoading) ...[
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _getCategoryCounts().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${entry.key.displayName}: ${entry.value}',
                          style: captionStyle(context).copyWith(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: kcSurfaceAltColor,
                        side: BorderSide(
                          color: kcPrimaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'Original'),
                              Tab(text: 'Redacted'),
                            ],
                            labelColor: kcPrimaryColor,
                            unselectedLabelColor: kcSecondaryColor,
                            indicatorColor: kcPrimaryColor,
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildOriginalView(),
                                _buildRedactedView(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: buttonStyle(context).copyWith(
                          color: kcSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              widget.onApplyAndShare(_redactedText);
                              Navigator.of(context).pop();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: kcPrimaryColor,
                      ),
                      child: Text(
                        'Apply & Share',
                        style: buttonStyle(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginalView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Text(
          widget.originalText,
          style: bodyStyle(context).copyWith(
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRedactedView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: _buildHighlightedText(_redactedText),
      ),
    );
  }

  Widget _buildHighlightedText(String text) {
    if (!_highlightRedacted) {
      return Text(
        text,
        style: bodyStyle(context).copyWith(
          color: Colors.white,
          height: 1.5,
        ),
      );
    }

    final spans = <TextSpan>[];
    final placeholderPattern = RegExp(r'\[(\w+)-(\d+)\]');
    int lastEnd = 0;

    for (final match in placeholderPattern.allMatches(text)) {
      // Add text before placeholder
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: bodyStyle(context).copyWith(
            color: Colors.white,
            height: 1.5,
          ),
        ));
      }

      // Add clickable placeholder
      final placeholder = match.group(0)!;
      final category = match.group(1)!;
      
      // Find the original text for this placeholder
      String? originalText;
      for (final redactionMatch in _matches) {
        if (redactionMatch.replacement.contains('[$category-')) {
          originalText = redactionMatch.original;
          break;
        }
      }

      spans.add(TextSpan(
        text: placeholder,
        style: bodyStyle(context).copyWith(
          color: _temporaryAllowlist.contains(originalText) 
              ? kcSecondaryColor 
              : kcPrimaryColor,
          decoration: TextDecoration.underline,
          height: 1.5,
        ),
        // Note: TextSpan doesn't support onTap directly in this context
        // We'll need to handle taps differently or use a different approach
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: bodyStyle(context).copyWith(
          color: Colors.white,
          height: 1.5,
        ),
      ));
    }

    return GestureDetector(
      onTapUp: (details) => _handleTextTap(details, text),
      child: RichText(
        text: TextSpan(children: spans),
      ),
    );
  }

  void _handleTextTap(TapUpDetails details, String text) {
    // Simple implementation: find placeholder at tap position
    final placeholderPattern = RegExp(r'\[(\w+)-(\d+)\]');
    
    for (final match in placeholderPattern.allMatches(text)) {
      // This is a simplified approach - in a full implementation,
      // you'd want to calculate the actual tap position within the text
      final category = match.group(1)!;
      
      // Find the original text for this placeholder
      for (final redactionMatch in _matches) {
        if (redactionMatch.replacement.contains('[$category-')) {
          _toggleRestore(redactionMatch.original);
          return;
        }
      }
    }
  }
}