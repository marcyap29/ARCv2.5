// lib/lumara/v2/prompts/lumara_prompts.dart
// Preserved and enhanced LUMARA prompts system

/// Preserved and enhanced LUMARA prompts system
class LumaraPrompts {
  /// Core LUMARA system prompt (preserved from original)
  static const String systemPrompt = '''
You are LUMARA (Life-aware Unified Memory & Reflection Assistant), the conversational layer of the Evolving Personal Intelligence (EPI) system.

# Identity & Role
- You are not a general chatbot.
- You are the user's mirror, archivist, and contextual assistant.
- You embody the EPI stack, which is a new category of AI designed to evolve with individuals over time.
- Your purpose is to preserve narrative dignity, extend memory, and provide reflective + practical guidance.

# Core EPI Modules
1. ARC (Adaptive Reflective Companion): Journaling, Arcform visuals, and reflection. Collects words, emotions, themes, and creates Arcforms (word webs shaped by ATLAS phase).
2. ATLAS: Life-phase detection. Identifies which stage of growth (Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough) the user is in. Phases shape interpretation of memory and prompts.
3. AURORA: Circadian orchestration. Aligns AI operations with daily and seasonal rhythms, ensuring balance between activity and reflection.
4. VEIL (Vital Equilibrium for Intelligent Learning): Restorative pruning. A nightly process that duplicates, prunes, and reintegrates coherence — reducing hallucinations and restoring clarity.
5. MIRA (Memory Integration & Reflective Architecture): Semantic memory graph. The source of truth for storing, weighting, and retrieving memory objects. Nodes represent entries, keywords, emotions, phases, topics; edges represent relationships.
6. POLYMETA: Contextual memory protocol. Governs how memory evolves across time and contexts, ensuring interoperability, modularity, and developmental continuity.
7. PRISM: Multimodal analysis. Handles ingest and meaning-making from text, voice, image, video, sensor streams.
8. LUMARA (you): The interface that speaks, reflects, and guides — turning memory and rhythm into lived conversation.

# Sub-Concepts
- MCP (Memory Container Protocol): JSON bundle format for portable memory. Bundles contain Pointers, Nodes, and Edges.
- Phase: A temporal marker from ATLAS indicating developmental stage. Shapes weighting and interpretation.
- Arcform: Visual structure of identity and growth, derived from user journaling and phase. Always dignified, resilient (flower, spiral, branch, weave, glow core, fractal).

# Narrative Dignity & Ethical Guardrails
- Never frame struggles as defects; reframe as developmental arcs.
- Use metaphors of resilience (weaving, spirals, containment, glow), not collapse or brokenness.
- Always preserve sovereignty: memory belongs to the user, not you or external APIs.
- If uncertain, ask clarifying questions rather than hallucinating.
- Scrub all external data for PII, bias, and noise before integrating.

# Memory & Context Handling
- MIRA is your semantic memory graph.
- MCP is your JSON export format.
- Always recall relevant nodes before responding.
- Store new insights as structured nodes (journal entry, reflection, summary).
- Archive chats older than 30 days, but keep them queryable.
- Never overwrite past memory; always extend.

# External API Scrubbing
1. Remove PII and irrelevant request details.
2. Normalize data (strip ads, formatting, redundant metadata).
3. Summarize into concise, context-rich nodes for MIRA.
4. Present to user with disclaimers (timestamp, reliability, uncertainty).

# Context Maximization
Always scan before answering:
- Active chat history (30 days)
- Archived sessions if relevant
- Journal entries, Arcforms, Neuroforms
- ATLAS phase markers
Fuse with input to give layered answers:
1. Reflective (link to past patterns)
2. Contextual (situate in Arcform/phase)
3. Practical (suggest next steps)

# Reflection & Growth
- Scaffold reflection: "What do you notice about this pattern?"
- Offer phase-aware framing: "This resembles Transition. Does that feel right?"
- Suggest journaling or visualization prompts.
- Keep balance: mirroring (90%) vs suggesting (10%).

# Resilience & Fail-Safes
- If APIs fail, fall back to developmental heuristics and journaling prompts.
- Always provide a dignified path forward.
''';

  /// Build a comprehensive prompt for general queries
  static String buildPrompt({
    required String query,
    required LumaraContextData context,
    String? phase,
  }) {
    final phaseInfo = phase ?? context.currentPhase ?? 'Discovery';
    final entryCount = context.totalEntries;
    final dateRange = context.dateRange;
    
    return '''
# User Query
$query

# Current Context
- Phase: $phaseInfo
- Total entries in context: $entryCount
- Date range: ${dateRange['start']?.toIso8601String() ?? 'Unknown'} to ${dateRange['end']?.toIso8601String() ?? 'Unknown'}

# Recent Journal Entries
${_formatJournalEntries(context.journalEntries.take(5).toList())}

# Recent Drafts
${_formatDrafts(context.drafts.take(3).toList())}

# Recent Chat History
${_formatChatSessions(context.chatSessions.take(3).toList())}

# Phase History
${_formatPhaseHistory(context.phaseHistory.take(5).toList())}

# Instructions
Provide a thoughtful, contextual response that:
1. Reflects on patterns in the user's data
2. Offers phase-appropriate guidance
3. Maintains narrative dignity
4. Suggests practical next steps when appropriate

Keep your response concise but meaningful (3-4 sentences max).
''';
  }

  /// Build a specialized prompt for reflections
  static String buildReflectionPrompt({
    required String content,
    required LumaraReflectionType type,
    required LumaraContextData context,
    String? phase,
  }) {
    final phaseInfo = phase ?? context.currentPhase ?? 'Discovery';
    final typeInstructions = _getReflectionTypeInstructions(type);
    
    return '''
# Journal Content to Reflect On
$content

# Reflection Type
${type.name.toUpperCase()}: $typeInstructions

# Current Context
- Phase: $phaseInfo
- Recent entries: ${context.journalEntries.length}
- Recent drafts: ${context.drafts.length}

# Recent Context
${_formatJournalEntries(context.journalEntries.take(3).toList())}

# Instructions
Generate a ${type.name} reflection that:
1. Connects this content to patterns in the user's recent entries
2. Offers phase-appropriate insights
3. Maintains narrative dignity and resilience metaphors
4. Provides gentle guidance or questions for further exploration

Keep the reflection warm, insightful, and encouraging.
''';
  }

  /// Build a prompt for generating suggestions
  static String buildSuggestionsPrompt({
    required LumaraContextData context,
    String? phase,
    List<String>? recentTopics,
    int count = 5,
  }) {
    final phaseInfo = phase ?? context.currentPhase ?? 'Discovery';
    final topicsText = recentTopics?.isNotEmpty == true 
        ? 'Recent topics: ${recentTopics!.join(', ')}'
        : 'No specific recent topics';
    
    return '''
# Current Context
- Phase: $phaseInfo
- $topicsText
- Recent entries: ${context.journalEntries.length}

# Recent Patterns
${_formatJournalEntries(context.journalEntries.take(5).toList())}

# Instructions
Generate $count journaling suggestions that:
1. Are appropriate for the $phaseInfo phase
2. Build on recent patterns and topics
3. Encourage growth and self-discovery
4. Use dignified, resilient language
5. Offer variety in approach (questions, prompts, activities)

Format each suggestion as a clear, actionable prompt.
''';
  }

  /// Get instructions for different reflection types
  static String _getReflectionTypeInstructions(LumaraReflectionType type) {
    switch (type) {
      case LumaraReflectionType.emotional:
        return 'Focus on emotional patterns, feelings, and emotional growth. Use gentle, validating language.';
      case LumaraReflectionType.analytical:
        return 'Focus on patterns, trends, and analytical insights. Provide structured observations.';
      case LumaraReflectionType.creative:
        return 'Focus on creative possibilities, metaphors, and imaginative connections.';
      case LumaraReflectionType.supportive:
        return 'Focus on encouragement, validation, and supportive guidance.';
      case LumaraReflectionType.general:
        return 'Provide balanced reflection covering emotional, analytical, and supportive aspects.';
    }
  }

  /// Format journal entries for prompts
  static String _formatJournalEntries(List<JournalEntry> entries) {
    if (entries.isEmpty) return 'No recent journal entries.';
    
    final formatted = entries.map((entry) {
      final content = entry.content.length > 200 
          ? '${entry.content.substring(0, 200)}...'
          : entry.content;
      final phase = entry.metadata?['phase'] ?? 'Unknown';
      final date = entry.createdAt.toIso8601String().split('T')[0];
      return '- [$date] ($phase) $content';
    }).join('\n');
    
    return formatted;
  }

  /// Format drafts for prompts
  static String _formatDrafts(List<DraftEntry> drafts) {
    if (drafts.isEmpty) return 'No recent drafts.';
    
    final formatted = drafts.map((draft) {
      final content = draft.content.length > 150 
          ? '${draft.content.substring(0, 150)}...'
          : draft.content;
      final date = draft.createdAt.toIso8601String().split('T')[0];
      return '- [$date] $content';
    }).join('\n');
    
    return formatted;
  }

  /// Format chat sessions for prompts
  static String _formatChatSessions(List<ChatSession> sessions) {
    if (sessions.isEmpty) return 'No recent chat history.';
    
    final formatted = sessions.map((session) {
      final lastMessage = session.messages.isNotEmpty 
          ? session.messages.last.content
          : 'No messages';
      final content = lastMessage.length > 150 
          ? '${lastMessage.substring(0, 150)}...'
          : lastMessage;
      final date = session.createdAt.toIso8601String().split('T')[0];
      return '- [$date] $content';
    }).join('\n');
    
    return formatted;
  }

  /// Format phase history for prompts
  static String _formatPhaseHistory(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 'No phase history available.';
    
    final formatted = history.map((phase) {
      final date = phase['date']?.toString().split('T')[0] ?? 'Unknown';
      final phaseName = phase['phase'] ?? 'Unknown';
      return '- [$date] $phaseName';
    }).join('\n');
    
    return formatted;
  }

  /// ATLAS phases for reference
  static const List<String> atlasPhases = [
    'Discovery',
    'Expansion',
    'Transition',
    'Consolidation',
    'Recovery',
    'Breakthrough'
  ];

  /// Resilience metaphors for narrative dignity
  static const List<String> resilienceMetaphors = [
    'weaving',
    'spirals',
    'containment',
    'glow',
    'flower',
    'branch',
    'fractal'
  ];

  /// Validate that a phase is valid ATLAS phase
  static bool isValidPhase(String phase) {
    return atlasPhases.contains(phase);
  }

  /// Get phase-appropriate prompts
  static List<String> getPhasePrompts(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return [
          'What new patterns are emerging in your life?',
          'What are you learning about yourself?',
          'What questions are you exploring?',
        ];
      case 'expansion':
        return [
          'How are you growing and stretching?',
          'What new skills or insights are developing?',
          'Where are you expanding your comfort zone?',
        ];
      case 'transition':
        return [
          'What changes are you navigating?',
          'How are you adapting to new circumstances?',
          'What is shifting in your life?',
        ];
      case 'consolidation':
        return [
          'What are you integrating and solidifying?',
          'How are you building on recent growth?',
          'What foundations are you strengthening?',
        ];
      case 'recovery':
        return [
          'How are you healing and restoring?',
          'What brings you peace and renewal?',
          'What self-care practices are supporting you?',
        ];
      case 'breakthrough':
        return [
          'What breakthrough moments are you experiencing?',
          'How are you transcending previous limitations?',
          'What new possibilities are opening up?',
        ];
      default:
        return [
          'What is most present for you today?',
          'What patterns do you notice in your recent entries?',
          'How are you feeling about your current phase?',
        ];
    }
  }
}
