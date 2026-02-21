import '../../models/engagement_discipline.dart' show EngagementMode;
import '../../services/gemini_send.dart';
import '../models/query_plan.dart';
import '../models/chronicle_layer.dart';

/// Query Router for CHRONICLE
/// 
/// Classifies user queries and determines which CHRONICLE layers to access.
/// Routes queries to appropriate aggregation layers or raw entries.
/// When [mode] and/or [isVoice] are set, uses speed-optimized layer selection
/// (instant/fast/normal/deep) to meet latency targets.

class ChronicleQueryRouter {
  /// Route a query and determine the query plan.
  /// [userContext] must contain at least context (e.g. userId, currentPhase).
  /// [mode] when set enables mode-aware layer selection (explore=instant, integrate=fast yearly, reflect=fast monthly/yearly).
  /// [isVoice] when true forces instant speed (mini-context only), skipping intent classification.
  Future<QueryPlan> route({
    required String query,
    required Map<String, dynamic> userContext,
    EngagementMode? mode,
    bool isVoice = false,
  }) async {
    print('🔀 ChronicleQueryRouter: Routing query: "${query.substring(0, query.length > 50 ? 50 : query.length)}..."');

    // Speed-optimized path: explore or voice → instant, no CHRONICLE layers (mini-context only)
    if (isVoice || mode == EngagementMode.explore) {
      final plan = QueryPlan.rawEntry(
        intent: QueryIntent.temporalQuery,
        dateFilter: extractDateFilter(query),
        speedTarget: ResponseSpeed.instant,
      );
      print('🔀 ChronicleQueryRouter: Plan (instant): $plan');
      return plan;
    }

    // Integrate: yearly only, fast, allow drill-down (no LLM intent call)
    if (mode == EngagementMode.integrate) {
      final dateFilter = extractDateFilter(query);
      final strategy = 'Use yearly aggregation(s) for fast integrate; drill-down to monthly if needed';
      final plan = QueryPlan.chronicle(
        intent: QueryIntent.temporalQuery,
        layers: [ChronicleLayer.yearly],
        strategy: strategy,
        drillDown: true,
        dateFilter: dateFilter,
        instructions: 'Connect current situation to broader patterns. Reference yearly themes. Suggest drill-down if user wants specific details.',
        voiceInstructions: 'Connect to yearly themes. Drill-down available.',
        speedTarget: ResponseSpeed.fast,
      );
      print('🔀 ChronicleQueryRouter: Plan (integrate/fast): $plan');
      return plan;
    }

    // Reflect or legacy: classify intent then select layers with speed target
    final intent = await _classifyIntent(query);
    final dateFilter = extractDateFilter(query);
    final explicitPeriods = extractExplicitPeriods(query);

    // Specific recall with date range → Layer 0 retrieval (API will fetch getEntriesInRange)
    if (intent == QueryIntent.specificRecall && dateFilter != null) {
      final plan = QueryPlan.rawEntry(
        intent: intent,
        dateFilter: dateFilter,
        layer0DateRange: dateFilter,
        speedTarget: ResponseSpeed.normal,
      );
      print('🔀 ChronicleQueryRouter: Plan (specific recall + date range): $plan');
      return plan;
    }

    final (layers, speedTarget) = _selectLayersForMode(intent, mode, query);

    if (layers.isEmpty) {
      final plan = QueryPlan.rawEntry(
        intent: intent,
        dateFilter: dateFilter,
        speedTarget: speedTarget,
      );
      print('🔀 ChronicleQueryRouter: Plan: $plan');
      return plan;
    }

    final strategy = _determineStrategy(intent, layers);
    final drillDown = mode == EngagementMode.reflect || mode == EngagementMode.integrate
        ? shouldDrillDown(intent, query)
        : shouldDrillDown(intent, query);
    final instructions = _buildInstructions(intent, layers);
    final voiceInstructions = _buildVoiceInstructions(intent, layers);

    final plan = QueryPlan.chronicle(
      intent: intent,
      layers: layers,
      strategy: strategy,
      drillDown: drillDown,
      dateFilter: dateFilter,
      explicitPeriodsByLayer: explicitPeriods,
      instructions: instructions,
      voiceInstructions: voiceInstructions,
      speedTarget: speedTarget,
    );

    print('🔀 ChronicleQueryRouter: Plan: $plan');
    return plan;
  }

  /// Mode-aware layer selection and speed target.
  /// Returns (layers, speedTarget). For reflect/integrate uses single layer + fast when [mode] is set.
  (List<ChronicleLayer>, ResponseSpeed) _selectLayersForMode(
    QueryIntent intent,
    EngagementMode? mode,
    String query,
  ) {
    if (mode == EngagementMode.reflect) {
      final layer = _inferReflectLayer(query, intent);
      return ([layer], ResponseSpeed.fast);
    }
    // Legacy: no mode, use full selectLayers and normal speed
    final layers = selectLayers(intent, query);
    final speedTarget = layers.length > 2 ? ResponseSpeed.deep : ResponseSpeed.normal;
    return (layers, speedTarget);
  }

  /// Infer single layer for reflect mode from query and intent (monthly vs yearly).
  ChronicleLayer _inferReflectLayer(String query, QueryIntent intent) {
    final lower = query.toLowerCase();
    if (lower.contains(RegExp(r'\b(this\s+)?year\b|20\d{2}'))) {
      return ChronicleLayer.yearly;
    }
    if (lower.contains(RegExp(r'\b(this\s+)?month\b|january|february|march|april|may|june|july|august|september|october|november|december'))) {
      return ChronicleLayer.monthly;
    }
    switch (intent) {
      case QueryIntent.patternIdentification:
      case QueryIntent.developmentalTrajectory:
      case QueryIntent.inflectionPoint:
        return ChronicleLayer.yearly;
      default:
        return ChronicleLayer.monthly;
    }
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
- decision_archaeology: Asking about past decisions (e.g., "What have I decided about my career?", "When did I decide to...", "What decisions did I make about X?")

Respond with ONLY the intent name (e.g., "specific_recall", "temporal_query", "decision_archaeology").''';

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
      } else if (intentStr.contains('decision') || intentStr.contains('archaeology') || intentStr.contains('decided')) {
        return QueryIntent.decisionArchaeology;
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

      case QueryIntent.decisionArchaeology:
        // Layer 0 decision entries + monthly aggregations (decision captures appear in both)
        return [ChronicleLayer.layer0, ChronicleLayer.monthly];
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
      case QueryIntent.decisionArchaeology:
        return 'Use Layer 0 decision entries and monthly aggregations to retrieve decision record';
      default:
        return 'Use $layerNames';
    }
  }

  /// Extract date filter from query if present.
  /// Supports: full month ("February 2024"), year ("2024"), week range ("February 3-9", "Feb 3-9"), "last week".
  // Public for testing
  DateTimeRange? extractDateFilter(String query) {
    final lowerQuery = query.toLowerCase();
    final now = DateTime.now();

    // Week range: "February 3-9", "Feb 3-9", "February 3 to 9", "Feb 3 - 9"
    final weekRangeMatch = RegExp(
      r'(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2})\s*(?:-|to)\s*(\d{1,2})(?:\s+(\d{4}))?',
      caseSensitive: false,
    ).firstMatch(lowerQuery);
    if (weekRangeMatch != null) {
      final monthName = weekRangeMatch.group(1)!;
      final day1 = int.tryParse(weekRangeMatch.group(2)!);
      final day2 = int.tryParse(weekRangeMatch.group(3)!);
      final yearStr = weekRangeMatch.group(4);
      final year = yearStr != null ? int.tryParse(yearStr) : now.year;
      final month = _monthNameToNumber(monthName) ?? _shortMonthToNumber(monthName);
      if (year != null && month != null && day1 != null && day2 != null) {
        final start = DateTime(year, month, day1.clamp(1, 31));
        final end = DateTime(year, month, day2.clamp(1, 31), 23, 59, 59);
        if (end.isBefore(start)) {
          return DateTimeRange(start: end, end: start.add(const Duration(days: 1)));
        }
        return DateTimeRange(start: start, end: end);
      }
    }

    // "last week" -> previous 7 days
    if (RegExp(r'\blast\s+week\b').hasMatch(lowerQuery)) {
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final start = end.subtract(const Duration(days: 7));
      return DateTimeRange(start: start, end: end);
    }

    // "last month" -> previous calendar month
    if (RegExp(r'\blast\s+month\b').hasMatch(lowerQuery)) {
      final prev = DateTime(now.year, now.month - 1, 1);
      final start = prev;
      final end = DateTime(prev.year, prev.month + 1, 0, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }

    // Specific month + year
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

    // Short month + year: "Feb 2024"
    final shortMonthMatch = RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{4})', caseSensitive: false).firstMatch(lowerQuery);
    if (shortMonthMatch != null) {
      final month = _shortMonthToNumber(shortMonthMatch.group(1)!);
      final year = int.tryParse(shortMonthMatch.group(2)!);
      if (year != null && month != null) {
        final start = DateTime(year, month, 1);
        final end = DateTime(year, month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      }
    }

    // Year only
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

  /// Extract multiple periods when user asks to compare (e.g. "January vs February", "compare 2024 and 2023").
  /// Returns map keyed by layer name: 'monthly' -> ['2025-01', '2025-02'], 'yearly' -> ['2024', '2023'].
  Map<String, List<String>>? extractExplicitPeriods(String query) {
    final lowerQuery = query.toLowerCase();
    final months = <String>[];
    final years = <String>[];

    // "January and February", "January vs February", "compare January to February"
    final monthNames = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    final currentYear = DateTime.now().year;
    for (final name in monthNames) {
      if (lowerQuery.contains(name)) {
        final monthNum = monthNames.indexOf(name) + 1;
        final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(lowerQuery);
        final year = yearMatch != null ? int.tryParse(yearMatch.group(1)!) : currentYear;
        if (year != null) {
          months.add('$year-${monthNum.toString().padLeft(2, '0')}');
        }
      }
    }

    // "2024 and 2023", "compare 2024 to 2023"
    final yearMatches = RegExp(r'\b(20\d{2})\b').allMatches(lowerQuery);
    for (final m in yearMatches) {
      final y = m.group(1);
      if (y != null && !years.contains(y)) years.add(y);
    }

    if (months.length >= 2) {
      return {'monthly': months.take(5).toList()};
    }
    if (years.length >= 2) {
      return {'yearly': years.take(5).toList()};
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

  int? _shortMonthToNumber(String short) {
    const shortMonths = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    return shortMonths[short.toLowerCase()];
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

      case QueryIntent.decisionArchaeology:
        return 'Answer using Layer 0 decision entries and monthly aggregations. List what the user decided, when, and (if available) what the outcome was.';
      
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

      case QueryIntent.decisionArchaeology:
        return 'Retrieve decision captures from CHRONICLE.';

      default:
        return null;
    }
  }
}
