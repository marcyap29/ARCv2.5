// lib/lumara/v2/ui/journal/lumara_journal_integration.dart
// New simplified journal integration for LUMARA v2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lumara_interface.dart';
import '../data/lumara_scope.dart';
import '../core/lumara_core.dart';

/// New simplified journal integration for LUMARA v2.0
class LumaraJournalIntegration extends StatefulWidget {
  final String journalContent;
  final String? phase;
  final List<String>? keywords;
  final Function(String) onReflectionGenerated;
  final Function(String) onSuggestionGenerated;
  
  const LumaraJournalIntegration({
    super.key,
    required this.journalContent,
    this.phase,
    this.keywords,
    required this.onReflectionGenerated,
    required this.onSuggestionGenerated,
  });

  @override
  State<LumaraJournalIntegration> createState() => _LumaraJournalIntegrationState();
}

class _LumaraJournalIntegrationState extends State<LumaraJournalIntegration> {
  bool _isGenerating = false;
  String? _currentReflection;
  List<String> _suggestions = [];
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // LUMARA FAB
        _buildLumaraFab(),
        
        // Current reflection display
        if (_currentReflection != null) ...[
          const SizedBox(height: 16),
          _buildReflectionCard(),
        ],
        
        // Suggestions display
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSuggestionsCard(),
        ],
      ],
    );
  }
  
  Widget _buildLumaraFab() {
    return FloatingActionButton(
      onPressed: _isGenerating ? null : _generateReflection,
      backgroundColor: Theme.of(context).primaryColor,
      child: _isGenerating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.auto_awesome, color: Colors.white),
      tooltip: 'Ask LUMARA for reflection',
    );
  }
  
  Widget _buildReflectionCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'LUMARA Reflection',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isGenerating ? null : _generateReflection,
                  tooltip: 'Generate new reflection',
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(_currentReflection!),
                  tooltip: 'Copy reflection',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _currentReflection!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateSuggestions,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Get Suggestions'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _continueConversation,
                  icon: const Icon(Icons.chat),
                  label: const Text('Continue Chat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSuggestionsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'LUMARA Suggestions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isGenerating ? null : _generateSuggestions,
                  tooltip: 'Generate new suggestions',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._suggestions.asMap().entries.map((entry) {
              final index = entry.key;
              final suggestion = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => _copyToClipboard(suggestion),
                      tooltip: 'Copy suggestion',
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Future<void> _generateReflection() async {
    if (_isGenerating) return;
    
    setState(() {
      _isGenerating = true;
    });
    
    try {
      final lumara = LumaraCore.instance.interface;
      
      final reflection = await lumara.reflect(
        journalContent: widget.journalContent,
        type: LumaraReflectionType.general,
        phase: widget.phase,
        keywords: widget.keywords,
      );
      
      if (reflection.isError) {
        _showError('Failed to generate reflection: ${reflection.content}');
        return;
      }
      
      setState(() {
        _currentReflection = reflection.content;
      });
      
      widget.onReflectionGenerated(reflection.content);
    } catch (e) {
      _showError('Error generating reflection: $e');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }
  
  Future<void> _generateSuggestions() async {
    if (_isGenerating) return;
    
    setState(() {
      _isGenerating = true;
    });
    
    try {
      final lumara = LumaraCore.instance.interface;
      
      final suggestions = await lumara.getSuggestions(
        phase: widget.phase,
        recentTopics: widget.keywords,
        count: 5,
      );
      
      setState(() {
        _suggestions = suggestions.map((s) => s.text).toList();
      });
      
      if (suggestions.isNotEmpty) {
        widget.onSuggestionGenerated(suggestions.first.text);
      }
    } catch (e) {
      _showError('Error generating suggestions: $e');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }
  
  void _continueConversation() {
    // Navigate to main LUMARA chat with context
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LumaraMainInterface(
          initialContext: {
            'journalContent': widget.journalContent,
            'phase': widget.phase,
            'keywords': widget.keywords,
            'reflection': _currentReflection,
          },
        ),
      ),
    );
  }
  
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
