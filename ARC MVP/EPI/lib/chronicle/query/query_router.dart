import '../../services/gemini_send.dart';
import '../models/query_plan.dart';
import '../models/chronicle_layer.dart';

/// Query Router for CHRONICLE
/// 
/// Classifies user queries and determines which CHRONICLE layers to access.
/// Routes queries to appropriate aggregation layers or raw entries.

class ChronicleQueryRouter {
  /// Route a query and determine the query plan
  Future<QueryPlan> route({
    required String query,
    required Map<String, dynamic> userContext,
  }) async {
    print('🔀 ChronicleQueryRouter: Routing query: "${query.substring(0, query.length > 50 ? 50 : query.length)}..."');

    // 1. Classify intent
    final intent = await _classifyIntent(query);

    // 2. Determine which layers to access
    final layers = selectLayers(intent, query);

    // 3. Build query strategy
    final strategy = _determineStrategy(intent, layers);

    // 4. Extract date filter if present
    final dateFilter = extractDateFilter(query);

    // 5. Determine if drill-down is needed
    final drillDown = shouldDrillDown(intent, query);

    // 6. Build instructions
    final instructions = _buildInstructions(intent, layers);
    final voiceInstructions = _buildVoiceInstructions(intent, layers);

    final plan = layers.isEmpty
        ? QueryPlan.rawEntry(
            intent: intent,
            dateFilter: dateFilter,
          )
        : QueryPlan.chronicle(
            intent: intent,
            layers: layers,
            strategy: strategy,
            drillDown: drillDown,
            dateFilter: dateFilter,
            instructions: instructions,
            voiceInstructions: voiceInstructions,
          );

    print('🔀 ChronicleQueryRouter: Plan: $plan');
    return plan;
  }

  /// Classify query intent using LLM
  Future<QueryIntent> _classifyIntent(String query) async {
    try {
      final systemPrompt = '''You are a query classifier for a journaling AI system.
Classify user queries into one of these intents:

- specific_recall: Asking about a specific date, event, or entry (e.g., "What did I write last Tuesday?", "Tell me about my entry on January 15")
- pattern_identification: Asking about recurring themes or patterns (e.g., "What themes keep recurring?", "What patterns do you see?")
- developmental_trajectory: Asking about change/evolution over time (e.g., "How have I changed since 2020?", "How has my perspective evolved?")
- historical_parallel: Asking if they've experienced something similar before (e.g., "Have I dealt with this before?", "When did I last feel this way?")
- inflection_point: Asking when a shift or change began (e.g., "When did this shift start?", "When did I start feeling different?")
- temporal_query: Asking about a time period (e.g., "Tell me about my month", "What happened in January?", "Summarize my year")

Respond with ONLY the intent name (e.g., "specific_recall", "temporal_query").''';

      final userPrompt = 'Classify this query: "$query"';

      final response = await geminiSend(
        system: systemPrompt,
        user: userPrompt,
        jsonExpected: false,
      );

      // Parse response
      final intentStr = response.trim().toLowerCase();
      for (final intent in QueryIntent.values) {
        if (intent.name == intentStr) {
          return intent;
        }
      }

      // Fallback: try to match partial strings
      if (intentStr.contains('specific') || intentStr.contains('recall')) {
        return QueryIntent.specificRecall;
      } else if (intentStr.contains('pattern')) {
        return QueryIntent.patternIdentification;
      } else if (intentStr.contains('trajectory') || intentStr.contains('change') || intentStr.contains('evolve')) {
        return QueryIntent.developmentalTrajectory;
      } else if (intentStr.contains('parallel') || intentStr.contains('similar') || intentStr.contains('before')) {
        return QueryIntent.historicalParallel;
      } else if (intentStr.contains('inflection') || intentStr.contains('shift') || intentStr.contains('when did')) {
        return QueryIntent.inflectionPoint;
      } else if (intentStr.contains('temporal') || intentStr.contains('month') || intentStr.contains('year') || intentStr.contains('week')) {
        return QueryIntent.temporalQuery;
      }

      // Default fallback
      print('⚠️ ChronicleQueryRouter: Could not classify intent, defaulting to temporalQuery');
      return QueryIntent.temporalQuery;
    } catch (e) {
      print('⚠️ ChronicleQueryRouter: Intent classification failed: $e, defaulting to temporalQuery');
      return QueryIntent.temporalQuery;
    }
  }

  /// Select which layers to access based on intent
  // Public for testing
  List<ChronicleLayer> selectLayers(QueryIntent intent, String query) {
    switch (intent) {
      case QueryIntent.specificRecall:
        // Use raw entries, not CHRONICLE
        return [];

      case QueryIntent.temporalQuery:
        // Check what period user is asking about
        final lowerQuery = query.toLowerCase();
        if (lowerQuery.contains('week') || lowerQuery.contains('last few days')) {
          return [ChronicleLayer.monthly]; // Current month
        } else if (lowerQuery.contains('month')) {
          return [ChronicleLayer.monthly];
        } else if (lowerQuery.contains('year')) {
          return [ChronicleLayer.yearly];
        } else if (lowerQuery.contains('years') || lowerQuery.contains('multi')) {
          return [ChronicleLayer.multiyear];
        }
        // Default to monthly for temporal queries
        return [ChronicleLayer.monthly];

      case QueryIntent.patternIdentification:
        // Patterns visible across months
        return [ChronicleLayer.monthly, ChronicleLayer.yearly];

      case QueryIntent.developmentalTrajectory:
        // Multi-year for long-term, yearly for drill-down
        return [ChronicleLayer.multiyear, ChronicleLayer.yearly];

      case QueryIntent.historicalParallel:
        // Start with multi-year, drill to specific years/months
        return [ChronicleLayer.multiyear, ChronicleLayer.yearly, ChronicleLayer.monthly];

      case QueryIntent.inflectionPoint:
        // Yearly to find the year, monthly to find the month
        return [ChronicleLayer.yearly, ChronicleLayer.monthly];
    }
  }

  /// Determine query strategy description
  String _determineStrategy(QueryIntent intent, List<ChronicleLayer> layers) {
    if (layers.isEmpty) {
      return 'Use raw journal entries for specific recall';
    }

    final layerNames = layers.map((l) {
      switch (l) {
        case ChronicleLayer.monthly:
          return 'monthly aggregations';
        case ChronicleLayer.yearly:
          return 'yearly aggregations';
        case ChronicleLayer.multiyear:
          return 'multi-year aggregations';
        default:
          return l.name;
      }
    }).join(' and ');

    switch (intent) {
      case QueryIntent.temporalQuery:
        return 'Use $layerNames to answer temporal query';
      case QueryIntent.patternIdentification:
        return 'Use $layerNames to identify recurring patterns';
      case QueryIntent.developmentalTrajectory:
        return 'Use $layerNames to analyze developmental trajectory';
      case QueryIntent.historicalParallel:
        return 'Use $layerNames to find historical parallels';
      case QueryIntent.inflectionPoint:
        return 'Use $layerNames to locate inflection points';
      default:
        return 'Use $layerNames';
    }
  }

  /// Extract date filter from query if present
  // Public for testing
  DateTimeRange? extractDateFilter(String query) {
    // Simple date extraction - can be enhanced
    final lowerQuery = query.toLowerCase();
    
    // Check for specific months/years mentioned
    final monthMatch = RegExp(r'(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{4})', caseSensitive: false).firstMatch(lowerQuery);
    if (monthMatch != null) {
      final monthName = monthMatch.group(1)!;
      final year = int.tryParse(monthMatch.group(2)!);
      if (year != null) {
        final month = _monthNameToNumber(monthName);
        if (month != null) {
          final start = DateTime(year, month, 1);
          final end = DateTime(year, month + 1, 0, 23, 59, 59);
          return DateTimeRange(start: start, end: end);
        }
      }
    }

    // Check for year mentioned
    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(lowerQuery);
    if (yearMatch != null) {
      final year = int.tryParse(yearMatch.group(1)!);
      if (year != null) {
        final start = DateTime(year, 1, 1);
        final end = DateTime(year, 12, 31, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      }
    }

    return null;
  }

  /// Convert month name to number
  int? _monthNameToNumber(String monthName) {
    final months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return months[monthName.toLowerCase()];
  }

  /// Determine if drill-down is needed
  // Public for testing
  bool shouldDrillDown(QueryIntent intent, String query) {
    final lowerQuery = query.toLowerCase();
    
    // Check for evidence requests
    if (lowerQuery.contains('evidence') ||
        lowerQuery.contains('show me') ||
        lowerQuery.contains('which entries') ||
        lowerQuery.contains('what did i write')) {
      return true;
    }

    // Historical parallel and inflection point queries often need drill-down
    return intent == QueryIntent.historicalParallel ||
        intent == QueryIntent.inflectionPoint;
  }

  /// Build instructions for the query plan
  String? _buildInstructions(QueryIntent intent, List<ChronicleLayer> layers) {
    if (layers.isEmpty) return null;

    switch (intent) {
      case QueryIntent.temporalQuery:
        return 'Answer the user\'s question about the specified time period using the CHRONICLE aggregation(s). Reference specific entry IDs when mentioned in the aggregation.';
      
      case QueryIntent.patternIdentification:
        return 'Identify and explain recurring patterns from the CHRONICLE aggregations. Cite specific months/years and entry references when available.';
      
      case QueryIntent.developmentalTrajectory:
        return 'Analyze the developmental trajectory using multi-year and yearly aggregations. Highlight key transitions and evolution over time.';
      
      case QueryIntent.historicalParallel:
        return 'Find historical parallels using CHRONICLE aggregations. If user requests evidence, be prepared to drill down to specific entries.';
      
      case QueryIntent.inflectionPoint:
        return 'Locate inflection points using yearly and monthly aggregations. Identify when shifts began and provide context.';
      
      default:
        return null;
    }
  }

  /// Build voice mode instructions (shorter)
  String? _buildVoiceInstructions(QueryIntent intent, List<ChronicleLayer> layers) {
    if (layers.isEmpty) return null;

    switch (intent) {
      case QueryIntent.temporalQuery:
        return 'Answer briefly using CHRONICLE aggregation.';
      
      case QueryIntent.patternIdentification:
        return 'Identify patterns from CHRONICLE.';
      
      case QueryIntent.developmentalTrajectory:
        return 'Describe trajectory from CHRONICLE.';
      
      case QueryIntent.historicalParallel:
        return 'Find parallels in CHRONICLE.';
      
      case QueryIntent.inflectionPoint:
        return 'Locate inflection point in CHRONICLE.';
      
      default:
        return null;
    }
  }
}
