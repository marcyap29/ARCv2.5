import 'package:flutter/material.dart';
import 'package:my_app/lumara/services/enhanced_lumara_api.dart';
import '../../../telemetry/analytics.dart';

enum LumaraIntent {
  suggestIdeas,
  thinkThrough,
  differentPerspective,
  nextSteps,
  analyzeFurther,
}

class EnhancedLumaraSuggestionSheet extends StatefulWidget {
  final Function(LumaraIntent) onSelect;
  final String? entryText;
  final String? phase;

  const EnhancedLumaraSuggestionSheet({
    super.key,
    required this.onSelect,
    this.entryText,
    this.phase,
  });

  @override
  State<EnhancedLumaraSuggestionSheet> createState() => _EnhancedLumaraSuggestionSheetState();
}

class _EnhancedLumaraSuggestionSheetState extends State<EnhancedLumaraSuggestionSheet> {
  final EnhancedLumaraApi _lumaraApi = EnhancedLumaraApi(Analytics());
  final Analytics _analytics = Analytics();
  
  bool _isLoading = false;
  String? _cloudAnalysis;
  List<String> _aiSuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadCloudAnalysis();
  }

  Future<void> _loadCloudAnalysis() async {
    if (widget.entryText == null || widget.entryText!.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: generateCloudAnalysis and generateAISuggestions not yet implemented
      // Using generatePromptedReflection as fallback
      final analysis = await _lumaraApi.generatePromptedReflection(
        entryText: widget.entryText!,
        intent: 'suggest',
        phase: widget.phase ?? 'Discovery',
      );
      
      // Generate suggestions from the analysis
      final suggestions = _extractSuggestionsFromAnalysis(analysis);

      setState(() {
        _cloudAnalysis = analysis;
        _aiSuggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      _analytics.log('lumara_cloud_analysis_error', {'error': e.toString()});
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _extractSuggestionsFromAnalysis(String analysis) {
    // Extract suggestions from the analysis text
    final suggestions = <String>[];
    final lines = analysis.split('\n');
    
    for (final line in lines) {
      if (line.trim().startsWith('•') || line.trim().startsWith('-')) {
        suggestions.add(line.trim().substring(1).trim());
      } else if (line.trim().isNotEmpty && line.length < 150) {
        suggestions.add(line.trim());
      }
    }
    
    return suggestions.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reflect with LUMARA',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Cloud Analysis Section
            if (_cloudAnalysis != null) ...[
              _buildCloudAnalysisSection(theme),
              const SizedBox(height: 16),
            ],
            
            // AI Suggestions Section
            if (_aiSuggestions.isNotEmpty) ...[
              _buildAISuggestionsSection(theme),
              const SizedBox(height: 16),
            ],
            
            // Traditional LUMARA intents
            _buildTraditionalIntents(theme),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudAnalysisSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
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
                Icons.cloud_done,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Cloud Analysis',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _cloudAnalysis!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestionsSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'AI Suggestions',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._aiSuggestions.map((suggestion) => _buildClickableSuggestion(suggestion, theme)),
        ],
      ),
    );
  }

  Widget _buildClickableSuggestion(String suggestion, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _analytics.logLumaraEvent('ai_suggestion_clicked', data: {
            'suggestion': suggestion,
          });
          // Insert the suggestion into the journal entry
          _insertSuggestionIntoEntry(suggestion);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  suggestion,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.touch_app,
                size: 16,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTraditionalIntents(ThemeData theme) {
    final items = [
      (LumaraIntent.suggestIdeas, 'Suggest some ideas', Icons.lightbulb),
      (LumaraIntent.thinkThrough, 'Help me think through this', Icons.psychology),
      (LumaraIntent.differentPerspective, 'Offer different perspective', Icons.flip),
      (LumaraIntent.nextSteps, 'Suggest next steps', Icons.navigation),
      (LumaraIntent.analyzeFurther, 'Analyze further', Icons.analytics),
    ];

    return Column(
      children: items.map((item) => _SuggestionTile(
        intent: item.$1,
        title: item.$2,
        icon: item.$3,
        onTap: () {
          Navigator.of(context).maybePop();
          widget.onSelect(item.$1);
        },
      )).toList(),
    );
  }

  void _insertSuggestionIntoEntry(String suggestion) {
    // Navigate back and pass the suggestion to the parent
    Navigator.of(context).pop(suggestion);
  }
}

/// Individual suggestion tile
class _SuggestionTile extends StatelessWidget {
  final LumaraIntent intent;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.intent,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
