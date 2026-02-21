// l../mira/memory/lumara_attribution_explainer.dart
// LUMARA attribution explanation prompt system for transparent AI responses

import 'enhanced_attribution_schema.dart';

/// LUMARA attribution explanation service for transparent AI
class LumaraAttributionExplainer {

  /// Generate natural language explanation of attribution sources
  static String generateAttributionExplanation({
    required EnhancedResponseTrace responseTrace,
    bool includeDetailedBreakdown = false,
    bool includeConfidenceScores = false,
    bool includeCrossReferences = true,
  }) {
    final summary = responseTrace.summary;
    final traces = responseTrace.traces;

    if (traces.isEmpty) {
      return '''
I generated this response using my general knowledge and reasoning abilities, without drawing from specific memories in your journal, chats, or media. This response reflects general insights rather than personal context from your stored experiences.
''';
    }

    final explanationParts = <String>[];

    // Opening statement
    explanationParts.add(_generateOpeningStatement(summary));

    // Source type breakdown
    explanationParts.add(_generateSourceBreakdown(summary, includeDetailedBreakdown));

    // Confidence explanation
    if (includeConfidenceScores) {
      explanationParts.add(_generateConfidenceExplanation(summary, traces));
    }

    // Cross-references
    if (includeCrossReferences && summary.crossReferences.isNotEmpty) {
      explanationParts.add(_generateCrossReferenceExplanation(summary.crossReferences));
    }

    // Transparency footer
    explanationParts.add(_generateTransparencyFooter());

    return explanationParts.join('\n\n');
  }

  /// Generate opening statement based on attribution summary
  static String _generateOpeningStatement(AttributionSummary summary) {
    final sourceCount = summary.sourceTypeBreakdown.values.fold(0, (a, b) => a + b);
    final sourceTypes = summary.sourceTypeBreakdown.keys.toList();

    if (sourceCount == 1) {
      final singleType = sourceTypes.first;
      return 'I drew this response from 1 ${_getSourceTypeDescription(singleType).toLowerCase()} in your memory.';
    } else if (sourceTypes.length == 1) {
      final singleType = sourceTypes.first;
      return 'I drew this response from $sourceCount ${_getSourceTypeDescription(singleType).toLowerCase()}s in your memory.';
    } else {
      return 'I drew this response from $sourceCount different sources across ${sourceTypes.length} types of content in your memory.';
    }
  }

  /// Generate source type breakdown explanation
  static String _generateSourceBreakdown(AttributionSummary summary, bool includeDetailedBreakdown) {
    final breakdown = <String>[];
    breakdown.add('**Source Breakdown:**');

    for (final entry in summary.sourceTypeBreakdown.entries) {
      final sourceType = entry.key;
      final count = entry.value;
      final icon = _getSourceTypeIcon(sourceType);
      final description = _getSourceTypeDescription(sourceType);

      if (count == 1) {
        breakdown.add('${icon} 1 $description');
      } else {
        breakdown.add('${icon} $count ${description}s');
      }

      if (includeDetailedBreakdown) {
        breakdown.add('   ${_getSourceTypeDetailedDescription(sourceType)}');
      }
    }

    return breakdown.join('\n');
  }

  /// Generate confidence score explanation
  static String _generateConfidenceExplanation(AttributionSummary summary, List<EnhancedAttributionTrace> traces) {
    final confidence = summary.overallConfidence;
    final level = ConfidenceLevel.fromScore(confidence);

    final explanation = StringBuffer();
    explanation.writeln('**Confidence Analysis:**');
    explanation.writeln('Overall confidence: ${level.label} (${(confidence * 100).toStringAsFixed(1)}%)');
    explanation.writeln(level.description);

    // Add confidence distribution
    final highConfidenceTraces = traces.where((t) => t.confidence >= 0.7).length;
    final mediumConfidenceTraces = traces.where((t) => t.confidence >= 0.4 && t.confidence < 0.7).length;
    final lowConfidenceTraces = traces.where((t) => t.confidence < 0.4).length;

    if (highConfidenceTraces > 0) {
      explanation.writeln('• $highConfidenceTraces highly relevant sources');
    }
    if (mediumConfidenceTraces > 0) {
      explanation.writeln('• $mediumConfidenceTraces moderately relevant sources');
    }
    if (lowConfidenceTraces > 0) {
      explanation.writeln('• $lowConfidenceTraces contextually relevant sources');
    }

    return explanation.toString();
  }

  /// Generate cross-reference explanation
  static String _generateCrossReferenceExplanation(List<CrossReference> crossRefs) {
    if (crossRefs.isEmpty) return '';

    final explanation = StringBuffer();
    explanation.writeln('**Related Content Found:**');

    final groupedRefs = <SourceType, List<CrossReference>>{};
    for (final ref in crossRefs) {
      groupedRefs.putIfAbsent(ref.targetType, () => []);
      groupedRefs[ref.targetType]!.add(ref);
    }

    for (final entry in groupedRefs.entries) {
      final targetType = entry.key;
      final refs = entry.value;
      final icon = _getSourceTypeIcon(targetType);
      final description = _getSourceTypeDescription(targetType);

      if (refs.length == 1) {
        explanation.writeln('${icon} 1 related $description');
      } else {
        explanation.writeln('${icon} ${refs.length} related ${description}s');
      }

      // Add specific cross-reference descriptions
      for (final ref in refs.take(3)) { // Show up to 3 examples
        if (ref.description != null) {
          explanation.writeln('   • ${ref.description}');
        }
      }

      if (refs.length > 3) {
        explanation.writeln('   • ... and ${refs.length - 3} more');
      }
    }

    return explanation.toString();
  }

  /// Generate transparency footer
  static String _generateTransparencyFooter() {
    return '''
**About This Attribution:**
This breakdown shows exactly which of your personal content informed my response. Your memory usage is tracked for complete transparency and you maintain full control over your data. You can explore, edit, or export these source references anytime.''';
  }

  /// Generate detailed prompt for user about attribution system
  static String generateAttributionSystemPrompt() {
    return '''
## Memory Attribution & Transparency

When I respond to your messages, I draw from various types of content in your personal memory system:

### Source Types:
📝 **Journal Entries** - Your written reflections and daily entries
💬 **Chat History** - Our previous conversations and your questions
📷 **Media Content** - Text extracted from photos, audio transcripts
📊 **Phase Tracking** - ARCFORM data about your emotional and phase states
💡 **Generated Insights** - Previous summaries and patterns I've identified
🔗 **Cross-References** - Related content that connects to current topics

### How Attribution Works:
1. **Source Selection**: I identify relevant content from your memory that relates to your current question or conversation
2. **Confidence Scoring**: Each source gets a confidence score based on relevance, recency, and quality
3. **Relationship Mapping**: I determine how each source supports, contradicts, or contextualizes my response
4. **Cross-Referencing**: I find connections between different pieces of your content

### Confidence Levels:
- **Very High (90-100%)**: Directly relevant, recent, or explicitly requested content
- **High (70-89%)**: Clearly relevant with strong thematic connections
- **Medium (50-69%)**: Moderately relevant, provides useful context
- **Low (30-49%)**: Weak but meaningful connections
- **Very Low (0-29%)**: Minimal relevance, background context only

### Your Control:
- View detailed breakdowns of what informed each response
- Adjust weights or exclude specific memories from future responses
- Export your complete attribution history
- Understand exactly how your data influences my responses

This transparency ensures you maintain sovereignty over your personal data while benefiting from personalized, contextually-aware assistance.
''';
  }

  /// Generate contextual explanation prompt for specific attribution
  static String generateContextualExplanationPrompt({
    required EnhancedAttributionTrace trace,
    required String responseContent,
  }) {
    final sourceDesc = _getSourceTypeDescription(trace.sourceType);
    final icon = _getSourceTypeIcon(trace.sourceType);

    return '''
## Why This ${sourceDesc} Was Selected

${icon} **Source**: ${sourceDesc}
🎯 **Relevance**: ${_getRelationDescription(trace.relation)}
📊 **Confidence**: ${trace.confidenceLevel.label} (${(trace.confidence * 100).toStringAsFixed(1)}%)
${trace.reasoning != null ? '💭 **Reasoning**: ${trace.reasoning}' : ''}

### Content Used:
${trace.excerpt ?? 'Content was referenced for context but not directly quoted.'}

### How This Influenced My Response:
${_generateInfluenceExplanation(trace, responseContent)}

### About This Attribution:
- **When Created**: ${_formatTimestamp(trace.timestamp)}
${trace.phaseContext != null ? '- **Phase Context**: ${trace.phaseContext}' : ''}
${trace.sourceMetadata.isNotEmpty ? '- **Additional Context**: ${_formatMetadata(trace.sourceMetadata)}' : ''}

This specific piece of content was selected because it ${_getRelationDescription(trace.relation).toLowerCase()} and provides ${trace.confidenceLevel.description.toLowerCase()} to your current inquiry.
''';
  }

  /// Generate explanation of how a trace influenced the response
  static String _generateInfluenceExplanation(EnhancedAttributionTrace trace, String responseContent) {
    switch (trace.relation) {
      case 'supports':
        return 'This source provided supporting evidence and context that reinforced key points in my response.';
      case 'contradicts':
        return 'This source highlighted different perspectives or potential tensions that I addressed in my response.';
      case 'derives':
        return 'My response built upon insights and conclusions from this source.';
      case 'references':
        return 'This source provided relevant background information and context.';
      case 'contextualizes':
        return 'This source helped situate your current situation within broader patterns and contexts.';
      default:
        return 'This source provided relevant information that informed my understanding and response.';
    }
  }

  /// Generate attribution learning prompt
  static String generateAttributionLearningPrompt({
    required int totalResponses,
    required Map<SourceType, int> sourceUsage,
    required double avgConfidence,
  }) {
    return '''
## Your Memory Attribution Summary

Over $totalResponses responses, here's how I've used your personal content:

### Source Usage Patterns:
${sourceUsage.entries.map((e) =>
  '${_getSourceTypeIcon(e.key)} ${_getSourceTypeDescription(e.key)}: ${e.value} times'
).join('\n')}

### Overall Patterns:
- **Average Confidence**: ${(avgConfidence * 100).toStringAsFixed(1)}% - ${ConfidenceLevel.fromScore(avgConfidence).description}
- **Most Used Source**: ${_getMostUsedSourceDescription(sourceUsage)}
- **Memory Diversity**: ${sourceUsage.length} different types of content regularly referenced

### What This Tells Us:
${_generateUsageInsights(sourceUsage, avgConfidence)}

### Improving Attribution:
- Continue journaling to build richer context
- Engage in varied conversations to create diverse chat history
- Add media with descriptive text for visual context
- Use ARCFORM tracking for emotional and phase awareness

Your memory system is becoming more comprehensive, allowing for increasingly personalized and contextually-aware responses.
''';
  }

  /// Helper methods for generating descriptions and insights
  static String _getSourceTypeDescription(SourceType sourceType) {
    switch (sourceType) {
      case SourceType.journalEntry: return 'Conversation';
      case SourceType.chatMessage: return 'Chat Message';
      case SourceType.chatSession: return 'Chat Conversation';
      case SourceType.photo: return 'Photo';
      case SourceType.photoOcr: return 'Text from Photo';
      case SourceType.audio: return 'Audio Recording';
      case SourceType.audioTranscript: return 'Audio Transcript';
      case SourceType.video: return 'Video';
      case SourceType.videoTranscript: return 'Video Transcript';
      case SourceType.phaseRegime: return 'Phase Tracking';
      case SourceType.emotionTracking: return 'Emotion Data';
      case SourceType.keywordSubmission: return 'Keywords';
      case SourceType.lumaraResponse: return 'Previous LUMARA Response';
      case SourceType.insight: return 'Generated Insight';
      case SourceType.summary: return 'Summary';
      case SourceType.relatedContent: return 'Related Content';
      case SourceType.previousMention: return 'Previous Mention';
      case SourceType.webReference: return 'Web Reference';
      case SourceType.bookReference: return 'Book Reference';
      case SourceType.documentUpload: return 'Uploaded Document';
    }
  }

  static String _getSourceTypeIcon(SourceType sourceType) {
    switch (sourceType) {
      case SourceType.journalEntry: return '📝';
      case SourceType.chatMessage:
      case SourceType.chatSession: return '💬';
      case SourceType.photo:
      case SourceType.photoOcr: return '📷';
      case SourceType.audio:
      case SourceType.audioTranscript: return '🎵';
      case SourceType.video:
      case SourceType.videoTranscript: return '🎥';
      case SourceType.phaseRegime: return '📊';
      case SourceType.emotionTracking: return '😊';
      case SourceType.keywordSubmission: return '🏷️';
      case SourceType.lumaraResponse: return '🤖';
      case SourceType.insight: return '💡';
      case SourceType.summary: return '📋';
      case SourceType.relatedContent: return '🔗';
      case SourceType.previousMention: return '👁️';
      case SourceType.webReference: return '🌐';
      case SourceType.bookReference: return '📚';
      case SourceType.documentUpload: return '📄';
    }
  }

  static String _getSourceTypeDetailedDescription(SourceType sourceType) {
    switch (sourceType) {
      case SourceType.journalEntry:
        return 'Personal reflections, daily entries, and written thoughts from your journal';
      case SourceType.chatMessage:
        return 'Individual messages from our conversations';
      case SourceType.chatSession:
        return 'Complete conversation threads with context';
      case SourceType.photo:
        return 'Visual content and images from your media library';
      case SourceType.photoOcr:
        return 'Text extracted from images using optical character recognition';
      case SourceType.audio:
        return 'Audio recordings from your media collection';
      case SourceType.audioTranscript:
        return 'Text transcriptions of audio content';
      case SourceType.phaseRegime:
        return 'ARCFORM phase tracking data and emotional state information';
      case SourceType.lumaraResponse:
        return 'My previous responses that provide relevant context';
      default:
        return 'Content that provides relevant context and information';
    }
  }

  static String _getRelationDescription(String relation) {
    switch (relation) {
      case 'supports':
        return 'Provides supporting evidence and reinforcement';
      case 'contradicts':
        return 'Presents alternative perspectives or tensions';
      case 'derives':
        return 'Serves as foundation for new insights';
      case 'references':
        return 'Provides relevant background information';
      case 'contextualizes':
        return 'Situates within broader patterns and context';
      default:
        return 'Relates to the current topic';
    }
  }

  static String _getMostUsedSourceDescription(Map<SourceType, int> sourceUsage) {
    if (sourceUsage.isEmpty) return 'No sources used yet';

    final mostUsed = sourceUsage.entries.reduce((a, b) => a.value > b.value ? a : b);
    return '${_getSourceTypeDescription(mostUsed.key)} (${mostUsed.value} times)';
  }

  static String _generateUsageInsights(Map<SourceType, int> sourceUsage, double avgConfidence) {
    final insights = <String>[];

    if (sourceUsage[SourceType.journalEntry] != null && sourceUsage[SourceType.journalEntry]! > 10) {
      insights.add('Your journal entries are providing rich, personal context for responses');
    }

    if (sourceUsage[SourceType.chatMessage] != null && sourceUsage[SourceType.chatMessage]! > 20) {
      insights.add('Our conversation history is helping maintain context across sessions');
    }

    if (sourceUsage.length > 3) {
      insights.add('You\'re building a diverse memory system with multiple content types');
    }

    if (avgConfidence > 0.7) {
      insights.add('High confidence scores indicate strong relevance matching');
    } else if (avgConfidence < 0.4) {
      insights.add('Lower confidence suggests opportunities to add more specific, relevant content');
    }

    return insights.join('\n• ');
  }

  static String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} month${difference.inDays ~/ 30 == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Less than an hour ago';
    }
  }

  static String _formatMetadata(Map<String, dynamic> metadata) {
    final formatted = <String>[];
    for (final entry in metadata.entries) {
      if (entry.value != null && entry.value.toString().isNotEmpty) {
        formatted.add('${_capitalizeFirst(entry.key)}: ${entry.value}');
      }
    }
    return formatted.join(', ');
  }

  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}