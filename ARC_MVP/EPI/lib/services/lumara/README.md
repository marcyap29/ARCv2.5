# LUMARA Entry Classification System

This system adds intelligent classification to LUMARA responses, preventing over-synthesis on simple questions while preserving sophisticated temporal intelligence for complex entries.

## Overview

```
User Entry → Classifier → Response Mode → LUMARA Pipeline → Tailored Response
```

The classification system determines what type of entry the user wrote and configures LUMARA's behavior accordingly:

- **Factual**: Direct answers to questions (≤100 words)
- **Reflective**: Full LUMARA synthesis for personal growth (≤300 words)
- **Analytical**: Intellectual engagement with ideas (≤250 words)
- **Conversational**: Brief acknowledgment of updates (≤30 words)
- **Meta-Analysis**: Comprehensive pattern recognition (≤600 words)

## Quick Start

### 1. Basic Usage

```dart
import 'package:my_app/services/lumara/entry_classifier.dart';
import 'package:my_app/services/lumara/response_mode.dart';

// Classify an entry
final entryType = EntryClassifier.classify("Does Newton's calculus predict or calculate movement?");
print(entryType); // EntryType.factual

// Get response mode
final responseMode = ResponseMode.forEntryType(entryType, entryText);
print(responseMode.maxWords); // 100
print(responseMode.useReflectionHeader); // false
```

### 2. Integration with Existing LUMARA Service

```dart
// Replace your existing generateResponse method
final response = await LumaraClassifierIntegration.generateResponse(
  userId: userId,
  entryText: entryText,
  currentEntryId: currentEntryId,
  userPreferences: userPrefs, // Optional
  enableLogging: true,
);
```

### 3. User Preferences

```dart
// Allow users to customize behavior
final preferences = ClassificationPreferences(
  alwaysUseFullContext: false,
  preferredResponseLength: 120, // 120% of default lengths
  showClassificationDebug: true,
  customWordLimits: {
    EntryType.factual: 150, // Override default 100
  },
);
```

## Examples

### Factual Entry
```dart
Input: "I learned that derivatives measure rates of change. Is this right?"
Classification: EntryType.factual
Response Mode:
- maxWords: 100
- pullFullContext: false
- useReflectionHeader: false
- personaOverride: null (phase determines tone)

Expected Response: "Yes, that's correct. Derivatives measure instantaneous rates of change at specific points. Think of velocity - it's the derivative of position, showing how fast position changes at each moment."
```

### Reflective Entry
```dart
Input: "204.3 lbs this morning. Heaviest I've been. My goal is to lose 30 pounds."
Classification: EntryType.reflective
Response Mode:
- maxWords: 300
- pullFullContext: true
- useReflectionHeader: true
- runSemanticSearch: true

Expected Response: "✨ Reflection\n\nI see you're facing this moment with clarity rather than avoidance - weighing in takes courage when you know the number might be challenging. [continues with full LUMARA synthesis...]"
```

### Meta-Analysis Entry
```dart
Input: "What patterns do you see in my weight loss attempts over the past year?"
Classification: EntryType.metaAnalysis
Response Mode:
- maxWords: 600
- pullFullContext: true
- contextScope: maximum
- personaOverride: 'strategist'

Expected Response: "✨ Pattern Analysis\n\n**Pattern 1: Cyclical Re-engagement**\nAcross 47 entries mentioning weight... [comprehensive pattern analysis with dates and examples]"
```

## File Structure

```
lib/services/lumara/
├── entry_classifier.dart              # Core classification logic
├── response_mode.dart                  # Response mode configuration
├── classification_logger.dart          # Logging and analytics
├── lumara_classifier_integration.dart  # Integration example
└── README.md                          # This file

test/services/lumara/
└── entry_classifier_test.dart         # Comprehensive test suite
```

## Implementation Steps

### Phase 1: Silent Classification (Week 1-2)
```dart
// Add classification but don't change behavior yet
final entryType = EntryClassifier.classify(entryText);
await ClassificationLogger.logClassification(
  userId: userId,
  entryText: entryText,
  classification: entryType,
  response: null, // Just log classification
);

// Continue with existing LUMARA pipeline
final response = await _existingLUMARAGeneration(userId, entryText);
```

### Phase 2: Factual/Conversational Only (Week 3-4)
```dart
final entryType = EntryClassifier.classify(entryText);

if (entryType == EntryType.factual || entryType == EntryType.conversational) {
  // Use new minimal response mode
  final responseMode = ResponseMode.forEntryType(entryType, entryText);
  return await _generateClassifiedResponse(userId, entryText, responseMode);
} else {
  // Keep existing behavior for other types
  return await _existingLUMARAGeneration(userId, entryText);
}
```

### Phase 3: Gradual Rollout
- Week 5-6: Add analytical mode
- Week 7-8: Add meta-analysis mode
- Week 9+: Full rollout

## Testing

Run the test suite:
```bash
flutter test test/services/lumara/entry_classifier_test.dart
```

The tests cover:
- All entry type classifications
- Boundary cases (word count thresholds)
- Edge cases (empty entries, ambiguous content)
- Real-world examples
- Classification consistency
- Helper method validation

## Monitoring

### Classification Metrics
```dart
// Get metrics for monitoring dashboard
final metrics = await ClassificationLogger.getMetrics(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);

print('Factual entries: ${metrics.entryTypeCounts[EntryType.factual]}');
print('Avg factual response words: ${metrics.avgResponseWords[EntryType.factual]}');
```

### User Feedback
```dart
// Log user feedback for improving classification
await ClassificationLogger.logUserFeedback(
  userId: userId,
  entryText: entryText,
  predictedType: EntryType.factual,
  wasAppropriate: false,
  userCorrectedType: EntryType.reflective,
  feedbackNote: "This was actually about my feelings, not a factual question",
);
```

### Misclassification Analysis
```dart
// Analyze patterns in misclassifications
final errors = await ClassificationLogger.analyzeMisclassifications(limit: 100);
for (final error in errors) {
  print('Predicted: ${error.predictedType}, Should be: ${error.correctedType}');
  print('Entry: ${error.entryPreview}');
  print('---');
}
```

## Configuration

### Tuning Classification Thresholds

If classification accuracy is low, adjust these constants in `EntryClassifier`:

```dart
// Current thresholds (in classify method)
wordCount < 100 && hasQuestionMark  // Factual threshold
emotionalDensity > 0.15             // Reflective threshold
wordCount > 200 && firstPersonDensity < 0.05  // Analytical threshold
wordCount < 150 && emotionalDensity < 0.05    // Conversational threshold
```

### Adding New Keywords

Add domain-specific keywords to the pattern lists:

```dart
// In _countMetaAnalysisIndicators
final metaPatterns = [
  // Add new patterns for your use case
  r'what trends do you see in my',
  r'how has my .+ evolved',
];

// In _extractTopics
if (lowerText.contains('your_domain')) keywords.add('your_topic');
```

## Best Practices

### 1. Start Conservative
- Begin with high confidence classifications only
- Default to `reflective` when uncertain
- Monitor user feedback carefully

### 2. Preserve Phase Awareness
- Phase always affects tone, even in factual mode
- Never completely disable LUMARA's personality
- Maintain warmth and intelligence across all modes

### 3. User Control
- Allow users to override classifications
- Provide preferences for response length
- Show debug info when requested

### 4. Continuous Improvement
- Log all classifications for analysis
- Use feedback to tune thresholds
- Monitor response quality metrics

## Troubleshooting

### Common Issues

**1. Too many factual classifications**
- Increase emotional density threshold
- Add more reflective keywords
- Check for goal/struggle language detection

**2. Analytical entries classified as reflective**
- Increase first-person density threshold for analytical
- Add more analytical indicators
- Check word count requirements

**3. Meta-analysis not detected**
- Add more pattern indicators
- Check regex patterns work with your phrasing
- Test with explicit pattern requests

**4. Response quality issues**
- Check validation rules in `_validateResponse`
- Monitor word count violations
- Verify persona overrides work correctly

### Debug Mode

Enable debug information:
```dart
final debug = EntryClassifier.getClassificationDebugInfo(entryText);
print('Classification details: $debug');

final preferences = ClassificationPreferences(
  showClassificationDebug: true,
);
```

## Integration Checklist

- [ ] Add classification files to your project
- [ ] Replace existing LUMARA service call with classified version
- [ ] Set up logging to Firestore
- [ ] Run test suite and verify accuracy
- [ ] Start with silent classification phase
- [ ] Monitor metrics and user feedback
- [ ] Gradually roll out to all entry types
- [ ] Set up monitoring dashboard
- [ ] Create user preference interface
- [ ] Document any customizations for your domain

## Support

For questions about this classification system:
1. Check the test suite for examples
2. Review the debug output for classification details
3. Analyze misclassification logs to identify patterns
4. Adjust thresholds based on your user data

The system is designed to be conservative and preserve LUMARA's intelligence while preventing over-synthesis. Start with the defaults and tune based on real usage patterns.