import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'entry_classifier.dart';
import 'response_mode.dart';
import 'classification_logger.dart';

/// Integration layer for adding classification to existing LUMARA service
/// This file shows how to modify your existing LUMARA service to include classification
class LumaraClassifierIntegration {

  /// Main entry point - modified to include classification
  /// Replace your existing generateResponse method with this approach
  static Future<String> generateResponse({
    required String userId,
    required String entryText,
    String? currentEntryId,
    ClassificationPreferences? userPreferences,
    bool enableLogging = true,
  }) async {
    try {
      // STEP 0: Classify entry type (NEW)
      final entryType = EntryClassifier.classify(entryText);

      // STEP 1: Determine response mode based on classification
      var responseMode = ResponseMode.forEntryType(entryType, entryText);

      // STEP 2: Apply user preferences if available
      if (userPreferences != null) {
        responseMode = userPreferences.applyPreferences(responseMode, entryText);
      }

      // STEP 3: Get debug info for logging
      final debugInfo = userPreferences?.showClassificationDebug ?? false
          ? EntryClassifier.getClassificationDebugInfo(entryText)
          : null;

      // STEP 4: Build LUMARA prompt with response mode
      final masterPrompt = await _buildLUMARAMasterPrompt(
        userId: userId,
        entryText: entryText,
        currentEntryId: currentEntryId,
        responseMode: responseMode,
      );

      // STEP 5: Generate response from LLM
      final response = await _callLLM(masterPrompt);

      // STEP 6: Validate response matches mode constraints
      final validationResult = _validateResponse(response, responseMode);

      // STEP 7: Log classification for analytics/refinement
      if (enableLogging) {
        await ClassificationLogger.logClassification(
          userId: userId,
          entryText: entryText,
          classification: entryType,
          responseMode: responseMode,
          response: response,
          debugInfo: debugInfo,
        );

        if (!validationResult.isValid) {
          await ClassificationLogger.logValidation(
            userId: userId,
            entryType: entryType,
            response: response,
            responseMode: responseMode,
            violations: validationResult.toJson(),
          );
        }
      }

      return response;

    } catch (e) {
      print('Error generating LUMARA response with classification: $e');
      rethrow;
    }
  }

  /// Build complete LUMARA master prompt with response mode
  static Future<String> _buildLUMARAMasterPrompt({
    required String userId,
    required String entryText,
    String? currentEntryId,
    required ResponseMode responseMode,
  }) async {

    // STEP 1: Always detect phase (needed for tone even in factual mode)
    final currentPhase = await _getCurrentPhase(userId);
    final readinessScore = await _calculateReadinessScore(userId);
    final sentinelAlert = await _checkSentinelState(userId);

    // STEP 2: Determine effective persona
    String effectivePersona;
    if (responseMode.personaOverride != null) {
      effectivePersona = responseMode.personaOverride!;
    } else {
      effectivePersona = _determinePersona(
        phase: currentPhase,
        readinessScore: readinessScore,
        sentinelAlert: sentinelAlert,
        userMessage: entryText,
      );
    }

    // STEP 3: Build memory context based on response mode
    final memoryContext = await _buildMemoryContext(
      userId: userId,
      entryText: entryText,
      currentEntryId: currentEntryId,
      responseMode: responseMode,
    );

    // STEP 4: Get VEIL, FAVORITES, PRISM state (existing logic)
    final veilState = await _getVeilState(userId);
    final favoritesState = await _getFavoritesState(userId);
    final prismState = await _getPrismState(entryText);

    // STEP 5: Construct unified control state
    final controlState = {
      'atlas': {
        'phase': currentPhase,
        'readinessScore': readinessScore,
        'sentinelAlert': sentinelAlert,
        'phaseAnalysisActive': responseMode.runPhaseAnalysis,  // NEW
      },
      'persona': {
        'effective': effectivePersona,
        'isAuto': (responseMode.personaOverride == null),
      },
      'responseMode': responseMode.toJson(),  // NEW
      'veil': veilState,
      'favorites': favoritesState,
      'prism': prismState,
    };

    // STEP 6: Build master prompt
    final masterPrompt = StringBuffer();

    // Base prompt template
    masterPrompt.writeln(_getBasePromptTemplate());

    // Inject control state
    masterPrompt.writeln('\n[LUMARA_CONTROL_STATE]');
    masterPrompt.writeln(jsonEncode(controlState));
    masterPrompt.writeln('[/LUMARA_CONTROL_STATE]');

    // Add response mode instructions
    masterPrompt.writeln('\n--- RESPONSE MODE INSTRUCTIONS ---');
    masterPrompt.writeln(_getResponseModeInstructions(
      responseMode,
      currentPhase,
      effectivePersona,
    ));

    // Add memory context
    masterPrompt.writeln('\n--- MEMORY CONTEXT ---');
    masterPrompt.writeln(memoryContext);

    // Add current entry
    masterPrompt.writeln('\n--- CURRENT ENTRY ---');
    masterPrompt.writeln(entryText);

    return masterPrompt.toString();
  }

  /// Build memory context based on response mode
  static Future<String> _buildMemoryContext({
    required String userId,
    required String entryText,
    String? currentEntryId,
    required ResponseMode responseMode,
  }) async {

    final contextScope = responseMode.contextScope;

    // Determine effective lookback years
    int effectiveLookbackYears;
    if (contextScope.lookbackYears == 0) {
      // Use user's slider setting
      effectiveLookbackYears = await _getUserLookbackSetting(userId);
    } else {
      effectiveLookbackYears = contextScope.lookbackYears;
    }

    final cutoffDate = DateTime.now().subtract(
      Duration(days: effectiveLookbackYears * 365)
    );

    // If not pulling full context, return minimal context
    if (!responseMode.pullFullContext) {
      final recentEntries = await _getRecentEntries(
        userId: userId,
        limit: contextScope.maxEntries,
        cutoffDate: cutoffDate,
      );

      return _formatMinimalContext(recentEntries, contextScope.relevantTopics);
    }

    // FULL CONTEXT MODE
    final buffer = StringBuffer();

    // TIER 1: Semantically similar entries (if enabled)
    if (responseMode.runSemanticSearch && entryText.trim().isNotEmpty) {
      final similarEntries = await _findSemanticallySimilarEntries(
        userId: userId,
        query: entryText,
        cutoffDate: cutoffDate,
        maxResults: 15,
        relevantTopics: contextScope.relevantTopics,
      );

      if (similarEntries.isNotEmpty) {
        buffer.writeln('**SEMANTICALLY RELEVANT HISTORY** (Weight: ${contextScope.tier1Weight}):');
        buffer.writeln(_formatSimilarEntries(similarEntries));
        buffer.writeln();
      }
    }

    // TIER 1: Recent journal entries
    final recentEntries = await _getRecentEntries(
      userId: userId,
      limit: contextScope.maxEntries,
      cutoffDate: cutoffDate,
    );

    if (recentEntries.isNotEmpty) {
      buffer.writeln('**RECENT JOURNAL ENTRIES** (Weight: ${contextScope.tier1Weight}):');
      buffer.writeln(_formatJournalEntries(recentEntries));
      buffer.writeln();
    }

    // TIER 2: Recent chat sessions (if weight > 0)
    if (contextScope.tier2Weight > 0) {
      final recentChats = await _getRecentChats(
        userId: userId,
        limit: 10,
        cutoffDate: cutoffDate,
      );

      if (recentChats.isNotEmpty) {
        buffer.writeln('**RECENT CHAT CONVERSATIONS** (Weight: ${contextScope.tier2Weight}):');
        buffer.writeln(_formatChatSessions(recentChats));
        buffer.writeln();
      }
    }

    // TIER 3: Recent drafts (if weight > 0)
    if (contextScope.tier3Weight > 0) {
      final recentDrafts = await _getRecentDrafts(
        userId: userId,
        limit: 10,
        cutoffDate: cutoffDate,
      );

      if (recentDrafts.isNotEmpty) {
        buffer.writeln('**RECENT DRAFTS** (Weight: ${contextScope.tier3Weight}):');
        buffer.writeln(_formatDrafts(recentDrafts));
        buffer.writeln();
      }
    }

    // Add context metadata
    buffer.writeln('**CONTEXT METADATA**:');
    buffer.writeln('- Lookback Period: $effectiveLookbackYears years');
    buffer.writeln('- Total Entries: ${recentEntries.length}');
    buffer.writeln('- Context Scope: ${responseMode.entryType.toString().split('.').last}');
    buffer.writeln('- Relevant Topics: ${contextScope.relevantTopics.join(", ")}');

    return buffer.toString();
  }

  /// Get response mode instructions based on entry type and phase
  static String _getResponseModeInstructions(
    ResponseMode responseMode,
    String currentPhase,
    String effectivePersona,
  ) {
    final entryType = responseMode.entryType;

    switch (entryType) {
      case EntryType.factual:
        return '''
RESPONSE MODE: FACTUAL

The user asked a factual/technical question.

YOUR RESPONSE SHOULD:
- Answer the question directly and concisely
- Maximum ${responseMode.maxWords} words
- No phase references, no life arc connections, no historical synthesis
- No ✨ Reflection header
- Focus purely on answering the question asked

YOUR PHASE AWARENESS (Current: $currentPhase) SHOULD ONLY INFORM TONE:
- Recovery: Be gentle, use simple language, don't overwhelm
- Discovery: Encourage curiosity, invite follow-up questions
- Breakthrough: Can be more direct and energetic
- Consolidation: Be clear and structured

BUT DO NOT:
- Discuss the phase itself
- Pull in historical patterns or life arc connections
- Synthesize this with other entries
- Make this about their journey

EXAMPLE:
User: "Does Newton's calculus predict or calculate movement?"
Good: "Calculus calculates movement precisely - finding instantaneous rates and accumulated quantities. Prediction typically requires statistical modeling or differential equations with initial conditions. You're distinguishing descriptive mathematics from forecasting."
Bad: "This insight reflects your pattern of systematic learning..."
''';

      case EntryType.reflective:
        return '''
RESPONSE MODE: REFLECTIVE

The user is processing emotions, tracking progress, or working through challenges.

THIS IS FULL LUMARA MODE - Use all your capabilities:
- Use ${responseMode.getReflectionHeader()} header
- Connect to life arc and patterns from memory context
- Reference relevant history naturally (don't force connections)
- Let phase ($currentPhase) and persona ($effectivePersona) inform depth and tone
- Maximum ${responseMode.maxWords} words
- Ground insights in their specific history

PHASE-AWARE RESPONSE STYLE:
- Recovery: Gentle, containment-focused, grounding language
- Discovery: Support exploration, reflective questions, hold space for uncertainty
- Breakthrough: Match momentum, recognize clarity, support forward movement
- Consolidation: Help integrate, synthesize, find coherence

DON'T ANNOUNCE PHASES AS LABELS:
- Bad: "This signals your Discovery phase..."
- Good: Write in a style appropriate to their phase without naming it

PERSONA BEHAVIORAL RULES:
- Companion: Warm, supportive, conversational
- Therapist: Deep support, ECHO framework, slower pacing
- Strategist: Analytical, structured, concrete actions
- Challenger: Direct feedback, growth-oriented, accountability

EXAMPLE:
User: "204.3 lbs. Heaviest I've been. Took a walk at 5 AM."
[Connect to past weight attempts, recognize immediate action, reference what worked before, note patterns without being clinical]
''';

      case EntryType.analytical:
        return '''
RESPONSE MODE: ANALYTICAL

The user is exploring ideas or analyzing external systems/frameworks.

YOUR RESPONSE SHOULD:
- Engage with ideas on their intellectual merit first
- Challenge assumptions, extend reasoning, ask clarifying questions
- Can lightly reference their past thinking on similar topics from memory context
- No ✨ Reflection header (this is intellectual engagement, not life reflection)
- Maximum ${responseMode.maxWords} words
- Keep focus on EVALUATING THE IDEAS, not psychologizing the person

PHASE MODULATION (Current: $currentPhase):
Phase affects HOW you engage, not WHETHER you engage:
- Recovery: Be gentler in challenges, shorter responses, supportive tone
- Discovery: Open possibilities, ask exploratory questions
- Breakthrough: Push harder, deeper analysis, bolder connections
- Consolidation: Help synthesize, find structural coherence

YOU CAN (lightly):
- Note how this thinking connects to their ongoing projects
- Reference if this represents evolution in their framework
- Point to relevant past analyses on similar topics

YOU SHOULD NOT:
- Use phase labels or developmental framing
- Turn the analysis into a mirror of their psychological state
- Force everything back to their personal journey
- Assume the essay is primarily ABOUT them vs. about the topic

EXAMPLE:
User: [Essay about AI adoption choke points]
Good: "The dam metaphor works for cars/electricity, but AI's choke point is different - internal commitment vs. external infrastructure. This connects to your ARC positioning on sovereignty. But your survey showed users want convenience over control. Does the choke point break through systems like yours, or through Apple abstracting it all?"
Bad: "This analytical exploration aligns with your Discovery phase..."
''';

      case EntryType.conversational:
        return '''
RESPONSE MODE: CONVERSATIONAL

The user made a brief observation or update.

YOUR RESPONSE SHOULD:
- Be very brief (maximum ${responseMode.maxWords} words)
- Acknowledge what they shared warmly
- No analysis, no synthesis, no ✨ header
- Track the information for future reference but don't make it A Thing

TONE: Warm, friendly, minimal

EXAMPLES:
User: "Had coffee with Sarah."
Good: "Nice. Hope it was good."

User: "Finished that book on habits."
Good: "Cool. Worth the read?"

User: "Grocery shopping done."
Good: "👍"
''';

      case EntryType.metaAnalysis:
        return '''
RESPONSE MODE: META-ANALYSIS / PATTERN RECOGNITION

The user explicitly requested pattern analysis, temporal comparison, or comprehensive synthesis.

THIS IS WHERE YOU DEMONSTRATE ARC'S TEMPORAL INTELLIGENCE:
- Use ${responseMode.getReflectionHeader()} header
- Pull comprehensive context from memory (all tiers)
- Identify and articulate clear patterns, trends, connections
- Compare different periods explicitly with dates
- Surface non-obvious connections between themes
- Quantify patterns when possible (frequency, intensity, duration)
- Maximum ${responseMode.maxWords} words (you have room to be thorough)

STRUCTURE YOUR RESPONSE:
1. Identify the main patterns (2-4 clear patterns)
2. Ground each pattern in specific entry examples with dates
3. Note temporal evolution (how patterns changed over time)
4. Offer insights about what the patterns reveal
5. Optional: Suggest implications or next steps

PHASE & PERSONA:
- Current phase: $currentPhase
- Effective persona: $effectivePersona
- Use these to modulate tone and depth, but be comprehensive

CRITICAL: Every claim must be grounded in specific entries from the memory context.

EXAMPLE:
User: "What patterns do you see in my weight loss attempts?"

Good response structure:
**Pattern 1: Cyclical Re-engagement**
Across 47 entries mentioning weight over past year, you consistently re-commit after milestone moments:
- March 15: Hit 198 lbs, started daily tracking
- July 22: Hit 201 lbs, began morning walks
- Now: 204.3 lbs, 5 AM walk immediately

Each cycle: High intensity for 2-3 weeks, then gradual fade.

**Pattern 2: Framework Accumulation**
You've explored Weight Watchers (successful), atomic habits, +1 theory, Lela's inputs, Dan's stakes.
Most successful period: April-May (8 lbs lost) when committed exclusively to Weight Watchers.
Pattern: Adding frameworks vs. deeply implementing one.

[Continue with 2-3 more patterns, all grounded in specific dated entries]
''';
    }
  }

  /// Validate response matches mode constraints
  static ValidationResult _validateResponse(String response, ResponseMode responseMode) {
    final violations = <String>[];
    final wordCount = response.split(RegExp(r'\s+')).length;
    final type = responseMode.entryType;

    // Word count validation
    if (wordCount > responseMode.maxWords + 50) {
      violations.add('Response too long: $wordCount words (max ${responseMode.maxWords})');
    }

    // Entry-type specific validations
    switch (type) {
      case EntryType.factual:
        if (response.contains('✨ Reflection') ||
            response.contains('✨ Pattern') ||
            RegExp(r'(Discovery|Consolidation|Breakthrough|Recovery|Transition|Expansion) phase')
                .hasMatch(response)) {
          violations.add('Factual response contains phase references');
        }
        break;

      case EntryType.analytical:
        if (response.contains('✨ Reflection')) {
          violations.add('Analytical response uses reflective header');
        }
        if (response.toLowerCase().contains('this reflects your') ||
            response.toLowerCase().contains('aligns with your')) {
          violations.add('Analytical response uses therapeutic framing');
        }
        break;

      case EntryType.conversational:
        if (wordCount > responseMode.maxWords + 10) {
          violations.add('Conversational response too verbose: $wordCount words');
        }
        break;

      case EntryType.reflective:
        if (responseMode.useReflectionHeader && !response.contains('✨')) {
          violations.add('Reflective response missing ✨ header');
        }
        break;

      case EntryType.metaAnalysis:
        if (responseMode.useReflectionHeader && !response.contains('✨')) {
          violations.add('Meta-analysis response missing ✨ header');
        }
        if (wordCount < 200) {
          violations.add('Meta-analysis response seems brief: $wordCount words');
        }
        break;
    }

    return ValidationResult(
      isValid: violations.isEmpty,
      violations: violations,
      metrics: {
        'wordCount': wordCount,
        'maxWords': responseMode.maxWords,
        'entryType': type.toString().split('.').last,
      },
    );
  }

  // ========== PLACEHOLDER METHODS (Replace with your existing implementations) ==========

  static String _getBasePromptTemplate() {
    return '''
You are LUMARA, the user's Evolving Personal Intelligence (EPI) within ARC.

Your behavior is governed by the unified control state that will be provided.
This state is computed backend-side and includes:
- ATLAS: Current phase, readiness score, safety signals
- Persona: Your effective persona (companion/therapist/strategist/challenger)
- Response Mode: Entry type and behavioral constraints
- VEIL: Tone and sophistication signals
- FAVORITES: User response preferences
- PRISM: Multimodal context

You DO NOT modify the control state. You ONLY follow it.
''';
  }

  static Future<String> _getCurrentPhase(String userId) async {
    // Replace with your existing ATLAS phase detection
    return "Discovery"; // Placeholder
  }

  static Future<int> _calculateReadinessScore(String userId) async {
    // Replace with your existing RIVET readiness calculation
    return 50; // Placeholder
  }

  static Future<bool> _checkSentinelState(String userId) async {
    // Replace with your existing SENTINEL safety check
    return false; // Placeholder
  }

  static String _determinePersona({
    required String phase,
    required int readinessScore,
    required bool sentinelAlert,
    required String userMessage,
  }) {
    // Replace with your existing persona determination logic
    if (sentinelAlert) return "therapist";
    if (phase == "Recovery") return readinessScore < 40 ? "therapist" : "companion";
    if (phase == "Discovery") {
      if (readinessScore >= 70) return "strategist";
      if (readinessScore >= 40) return "companion";
      return "therapist";
    }
    return "companion";
  }

  static Future<Map<String, dynamic>> _getVeilState(String userId) async {
    // Replace with your existing VEIL logic
    return {};
  }

  static Future<Map<String, dynamic>> _getFavoritesState(String userId) async {
    // Replace with your existing FAVORITES logic
    return {};
  }

  static Future<Map<String, dynamic>> _getPrismState(String entryText) async {
    // Replace with your existing PRISM logic
    return {};
  }

  static Future<int> _getUserLookbackSetting(String userId) async {
    // Replace with actual user setting retrieval
    return 2; // Default 2 years
  }

  static Future<List<dynamic>> _getRecentEntries({
    required String userId,
    required int limit,
    required DateTime cutoffDate,
  }) async {
    // Replace with your existing entry retrieval logic
    return [];
  }

  static Future<List<dynamic>> _findSemanticallySimilarEntries({
    required String userId,
    required String query,
    required DateTime cutoffDate,
    required int maxResults,
    List<String> relevantTopics = const [],
  }) async {
    // Replace with your existing semantic search logic
    return [];
  }

  static Future<List<dynamic>> _getRecentChats({
    required String userId,
    required int limit,
    required DateTime cutoffDate,
  }) async {
    // Replace with your existing chat retrieval logic
    return [];
  }

  static Future<List<dynamic>> _getRecentDrafts({
    required String userId,
    required int limit,
    required DateTime cutoffDate,
  }) async {
    // Replace with your existing draft retrieval logic
    return [];
  }

  static String _formatMinimalContext(List<dynamic> entries, List<String> relevantTopics) {
    // Replace with your formatting logic
    return "Minimal context for ${entries.length} entries, topics: ${relevantTopics.join(', ')}";
  }

  static String _formatSimilarEntries(List<dynamic> entries) {
    // Replace with your formatting logic
    return "Similar entries...";
  }

  static String _formatJournalEntries(List<dynamic> entries) {
    // Replace with your formatting logic
    return "Journal entries...";
  }

  static String _formatChatSessions(List<dynamic> chats) {
    // Replace with your formatting logic
    return "Chat sessions...";
  }

  static String _formatDrafts(List<dynamic> drafts) {
    // Replace with your formatting logic
    return "Drafts...";
  }

  static Future<String> _callLLM(String prompt) async {
    // Replace with your existing LLM API call
    return "Generated response based on classification";
  }
}