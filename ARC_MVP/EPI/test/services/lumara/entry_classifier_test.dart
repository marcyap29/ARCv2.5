import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/lumara/entry_classifier.dart';

void main() {
  group('EntryClassifier Tests', () {

    group('Factual Classification', () {
      test('Classifies simple factual question', () {
        const entry = "I thought Newton's calculus was for prediction, "
                     "but it's actually for calculation. Does this make sense?";
        expect(EntryClassifier.classify(entry), EntryType.factual);
      });

      test('Classifies learning clarification', () {
        const entry = "I learned that derivatives measure rates of change. Is this right?";
        expect(EntryClassifier.classify(entry), EntryType.factual);
      });

      test('Classifies technical question', () {
        const entry = "Does the Kalman filter require matrix inversion?";
        expect(EntryClassifier.classify(entry), EntryType.factual);
      });

      test('Classifies understanding check', () {
        const entry = "Am I understanding this correctly? The integral is the area under the curve?";
        expect(EntryClassifier.classify(entry), EntryType.factual);
      });

      test('Classifies short learning note', () {
        const entry = "I thought X but it's actually Y. Did I get this right?";
        expect(EntryClassifier.classify(entry), EntryType.factual);
      });
    });

    group('Reflective Classification', () {
      test('Classifies weight tracking entry', () {
        const entry = "I weighed myself yesterday. 204.3 lbs. "
                     "Heaviest I've ever been. My goal is to lose 30 pounds.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Classifies emotional entry', () {
        const entry = "Feeling really anxious about the presentation tomorrow. "
                     "Can't stop thinking about what might go wrong.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Classifies goal-setting entry', () {
        const entry = "My goal is to finish the first draft by Friday. "
                     "I'm committed to writing 1000 words per day.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Classifies struggle entry', () {
        const entry = "I'm stuck on this problem and can't figure out the solution. "
                     "Feeling really frustrated with my progress.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Classifies personal metrics', () {
        const entry = "Ran 3 miles today. Took me 28 minutes. "
                     "Getting faster but still tired.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Classifies emotional state with goals', () {
        const entry = "I want to be better at handling stress. "
                     "Today was overwhelming but I'm trying to learn.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });
    });

    group('Analytical Classification', () {
      test('Classifies analytical essay', () {
        const entry = "A theory on AI adoption and its choke point. "
                     "Looking back with hindsight, the adoption of cars and electricity "
                     "followed a similar pattern. Both resembled a dam holding back enormous "
                     "potential, constrained by choke points that delayed mass impact. "
                     "In both cases, the choke point was not invention but distribution. "
                     "The key breakthrough came when someone solved the distribution problem. "
                     "This pattern suggests that AI adoption will follow similar dynamics. "
                     "The current constraint is not capability but accessibility. "
                     "Therefore, the breakthrough will come from whoever solves "
                     "the distribution of AI capabilities to end users.";
        expect(EntryClassifier.classify(entry), EntryType.analytical);
      });

      test('Classifies theoretical framework', () {
        const entry = "The key distinction between prediction and calculation lies in "
                     "the nature of the mathematical operation. Prediction attempts to forecast "
                     "future states based on incomplete data, while calculation determines precise "
                     "values from complete information. This has implications for how we approach "
                     "uncertainty in complex systems. Prediction models must account for variance "
                     "and confidence intervals, while calculations provide deterministic results. "
                     "Understanding this difference is crucial for proper application of "
                     "mathematical tools in engineering and science.";
        expect(EntryClassifier.classify(entry), EntryType.analytical);
      });

      test('Classifies third-person analysis', () {
        const entry = "The adoption of new technologies follows predictable patterns. "
                     "Researchers have identified that early adopters typically represent "
                     "2.5% of the population, followed by early majority adoption. "
                     "This pattern holds across various technological innovations. "
                     "The implications for product strategy are significant, suggesting "
                     "that companies should focus on crossing the chasm between "
                     "early adopters and early majority.";
        expect(EntryClassifier.classify(entry), EntryType.analytical);
      });
    });

    group('Conversational Classification', () {
      test('Classifies brief update', () {
        const entry = "Had coffee with Sarah this morning.";
        expect(EntryClassifier.classify(entry), EntryType.conversational);
      });

      test('Classifies mundane observation', () {
        const entry = "Traffic was terrible today.";
        expect(EntryClassifier.classify(entry), EntryType.conversational);
      });

      test('Classifies simple completion note', () {
        const entry = "Finished the grocery shopping.";
        expect(EntryClassifier.classify(entry), EntryType.conversational);
      });

      test('Classifies brief factual note', () {
        const entry = "Meeting moved to 3pm.";
        expect(EntryClassifier.classify(entry), EntryType.conversational);
      });

      test('Classifies weather observation', () {
        const entry = "It's raining again.";
        expect(EntryClassifier.classify(entry), EntryType.conversational);
      });
    });

    group('Meta-Analysis Classification', () {
      test('Classifies pattern request', () {
        const entry = "What patterns do you see in my weight loss attempts over the past year?";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });

      test('Classifies temporal comparison', () {
        const entry = "How has my thinking about ARC evolved since I started this project?";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });

      test('Classifies theme inquiry', () {
        const entry = "Looking back at my entries about Eiffel, what themes keep emerging?";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });

      test('Classifies connection request', () {
        const entry = "What connections exist between my sleep quality and work productivity?";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });

      test('Classifies change tracking', () {
        const entry = "Compare my energy levels from last month versus this month.";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });

      test('Classifies explicit ARC request', () {
        const entry = "Based on everything you know about my journey, what insights can you provide?";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });

      test('Classifies pattern analysis request', () {
        const entry = "Analyze my entries and tell me what patterns you notice in my behavior.";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });
    });

    group('Edge Cases', () {
      test('Empty entry defaults to conversational', () {
        expect(EntryClassifier.classify(""), EntryType.conversational);
      });

      test('Whitespace-only entry defaults to conversational', () {
        expect(EntryClassifier.classify("   \n\t  "), EntryType.conversational);
      });

      test('Ambiguous short entry defaults to reflective', () {
        const entry = "Today was hard.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Emotional analytical essay stays analytical', () {
        const entry = "An analysis of grief in modern society reveals complex patterns. "
                     "Grief manifests differently across cultures, yet certain patterns emerge. "
                     "The five stages proposed by Kübler-Ross have been widely adopted, though "
                     "research suggests grief is more cyclical than linear. Cross-cultural "
                     "studies demonstrate that while the emotions are universal, the expression "
                     "and duration vary significantly. This has implications for therapeutic "
                     "approaches in multicultural societies.";
        // Should be analytical despite emotional topic
        expect(EntryClassifier.classify(entry), EntryType.analytical);
      });

      test('Personal essay with high first-person density stays reflective', () {
        const entry = "I have been thinking about my relationship with failure. "
                     "I've noticed that I tend to avoid challenges when I'm not confident. "
                     "My pattern is to procrastinate rather than risk failing. "
                     "I want to change this about myself. I think it comes from childhood. "
                     "My parents always praised success but didn't teach me how to handle failure.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Long factual question becomes analytical', () {
        const entry = "I've been studying calculus and I understand that derivatives measure "
                     "instantaneous rates of change. The concept makes sense mathematically, "
                     "but I'm struggling to understand the practical applications. "
                     "How does this apply to real-world engineering problems? "
                     "What are some examples where knowing the instantaneous rate of change "
                     "is more useful than knowing the average rate of change? "
                     "I can see how it might be useful in physics for velocity and acceleration, "
                     "but what about in other fields? Are there business applications? "
                     "How do economists use calculus in their models?";
        // Long and technical, should become analytical not factual
        expect(EntryClassifier.classify(entry), EntryType.analytical);
      });
    });

    group('Boundary Cases', () {
      test('99 words factual question is factual', () {
        final words = '${List.filled(95, 'word').join(' ')} does this make sense?';
        expect(EntryClassifier.classify(words), EntryType.factual);
      });

      test('101 words factual question is not factual', () {
        final words = '${List.filled(97, 'word').join(' ')} does this make sense?';
        expect(EntryClassifier.classify(words), isNot(EntryType.factual));
      });

      test('149 words low emotion is conversational', () {
        final words = List.filled(149, 'word').join(' ');
        expect(EntryClassifier.classify(words), EntryType.conversational);
      });

      test('151 words low emotion is not conversational', () {
        final words = List.filled(151, 'word').join(' ');
        expect(EntryClassifier.classify(words), isNot(EntryType.conversational));
      });
    });

    group('Debug Information', () {
      test('Provides detailed debug info', () {
        const entry = "I'm feeling anxious about the meeting tomorrow. "
                     "My goal is to present confidently.";
        final debug = EntryClassifier.getClassificationDebugInfo(entry);

        expect(debug, containsPair('wordCount', greaterThan(0)));
        expect(debug, containsPair('emotionalDensity', greaterThan(0.0)));
        expect(debug, containsPair('hasGoalLanguage', true));
        expect(debug, containsPair('finalClassification', EntryType.reflective));
      });

      test('Debug info includes all metrics', () {
        const entry = "What patterns do you see in my progress?";
        final debug = EntryClassifier.getClassificationDebugInfo(entry);

        expect(debug.keys, contains('wordCount'));
        expect(debug.keys, contains('hasQuestionMark'));
        expect(debug.keys, contains('metaIndicatorCount'));
        expect(debug.keys, contains('emotionalDensity'));
        expect(debug.keys, contains('firstPersonDensity'));
        expect(debug.keys, contains('technicalIndicators'));
        expect(debug.keys, contains('analyticalIndicators'));
        expect(debug.keys, contains('hasPersonalMetrics'));
        expect(debug.keys, contains('hasGoalLanguage'));
        expect(debug.keys, contains('hasStruggleLanguage'));
        expect(debug.keys, contains('finalClassification'));
      });
    });

    group('Classification Consistency', () {
      test('Same entry always gets same classification', () {
        const entry = "I'm trying to understand calculus better. It's challenging.";
        final classification1 = EntryClassifier.classify(entry);
        final classification2 = EntryClassifier.classify(entry);
        final classification3 = EntryClassifier.classify(entry);

        expect(classification1, equals(classification2));
        expect(classification2, equals(classification3));
      });

      test('Minor variations produce same classification', () {
        const entry1 = "I'm feeling anxious about tomorrow.";
        const entry2 = "I am feeling anxious about tomorrow.";
        const entry3 = "I'm feeling anxious about tomorrow!";

        final classification1 = EntryClassifier.classify(entry1);
        final classification2 = EntryClassifier.classify(entry2);
        final classification3 = EntryClassifier.classify(entry3);

        expect(classification1, equals(classification2));
        expect(classification2, equals(classification3));
      });
    });

    group('Real-world Examples', () {
      test('Weight loss entry', () {
        const entry = "204.3 lbs this morning. Heaviest I've been. "
                     "Need to get back on track with my eating.";
        expect(EntryClassifier.classify(entry), EntryType.reflective);
      });

      test('Technical learning question', () {
        const entry = "I learned that Kalman filters use matrix operations. "
                     "Is matrix inversion required for every update?";
        expect(EntryClassifier.classify(entry), EntryType.factual);
      });

      test('Project analysis', () {
        const entry = "The key insight about ARC's positioning is that it sits between "
                     "raw AI capabilities and user interfaces. This creates unique value "
                     "by providing temporal intelligence that other systems lack. "
                     "The competitive advantage comes from memory architecture, not just "
                     "the LLM interface. This positioning allows for deeper personalization "
                     "than chatbots while remaining more accessible than full AI agents.";
        expect(EntryClassifier.classify(entry), EntryType.analytical);
      });

      test('Quick update', () {
        const entry = "Finished the gym. Good workout today.";
        expect(EntryClassifier.classify(entry), EntryType.conversational);
      });

      test('Pattern analysis request', () {
        const entry = "Looking back at my entries about work stress, "
                     "what patterns emerge across different projects?";
        expect(EntryClassifier.classify(entry), EntryType.metaAnalysis);
      });
    });
  });

  group('EntryClassifier Helper Methods', () {
    group('Emotional Density', () {
      test('Calculates high emotional density', () {
        const text = "I feel anxious and scared about this";
        final density = EntryClassifier._calculateEmotionalDensity(text);
        expect(density, greaterThan(0.2));
      });

      test('Calculates low emotional density', () {
        const text = "The meeting is scheduled for tomorrow";
        final density = EntryClassifier._calculateEmotionalDensity(text);
        expect(density, equals(0.0));
      });
    });

    group('First Person Density', () {
      test('Calculates high first-person density', () {
        const text = "I think my approach is working for me";
        final density = EntryClassifier._calculateFirstPersonDensity(text);
        expect(density, greaterThan(0.3));
      });

      test('Calculates low first-person density', () {
        const text = "The system works well in most cases";
        final density = EntryClassifier._calculateFirstPersonDensity(text);
        expect(density, equals(0.0));
      });
    });

    group('Pattern Detection', () {
      test('Detects meta-analysis patterns', () {
        const text = "what patterns do you see in my behavior";
        final count = EntryClassifier._countMetaAnalysisIndicators(text);
        expect(count, greaterThan(0));
      });

      test('Detects goal language', () {
        expect(EntryClassifier._containsGoalLanguage("my goal is to improve"), true);
        expect(EntryClassifier._containsGoalLanguage("i want to be better"), true);
        expect(EntryClassifier._containsGoalLanguage("just a regular sentence"), false);
      });

      test('Detects struggle language', () {
        expect(EntryClassifier._containsStruggleLanguage("i'm struggling with this"), true);
        expect(EntryClassifier._containsStruggleLanguage("this is difficult for me"), true);
        expect(EntryClassifier._containsStruggleLanguage("everything is fine"), false);
      });

      test('Detects personal metrics', () {
        expect(EntryClassifier._containsPersonalMetrics("ran 3 miles today"), true);
        expect(EntryClassifier._containsPersonalMetrics("weighed 150 lbs"), true);
        expect(EntryClassifier._containsPersonalMetrics("\$50 spent on groceries"), true);
        expect(EntryClassifier._containsPersonalMetrics("went to the store"), false);
      });
    });
  });
}