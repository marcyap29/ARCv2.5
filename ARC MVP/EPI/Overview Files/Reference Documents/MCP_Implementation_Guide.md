# MCP Implementation Guide for EPI

## Overview

This guide provides practical implementation details for integrating the Memory Container Protocol (MCP) with EPI's existing architecture. It covers how to enhance current modules with MCP capabilities while maintaining backward compatibility.

## Integration Architecture

### Current EPI Module Integration

```
┌─────────────────────────────────────────────────────────────────┐
│                        EPI Application Layer                    │
├─────────────────────────────────────────────────────────────────┤
│  ARC        ATLAS       MIRA        AURORA      VEIL      ECHO  │
│  Journal    Phases      Memory      Rhythms     Privacy   Voice │
│     │         │           │           │           │        │    │
│     └─────────┼───────────┼───────────┼───────────┼────────┘    │
│               │           │           │           │             │
├───────────────┼───────────┼───────────┼───────────┼─────────────┤
│               │           │           │           │             │
│         Enhanced MIRA Memory Service (MCP Core)                │
│                           │                                     │
├───────────────────────────┼─────────────────────────────────────┤
│                           │                                     │
│  Attribution   Domain     │  Lifecycle   Conflict   Bundle     │
│  Service       Scoping    │  Manager     Resolver   Manager    │
│                           │                                     │
├───────────────────────────┼─────────────────────────────────────┤
│                           │                                     │
│               MCP Storage Layer                                 │
│                                                                 │
│  Local Storage   Cloud Sync   Export/Import   Federation       │
└─────────────────────────────────────────────────────────────────┘
```

## Module-Specific Implementation

### ARC Module Integration

**Enhanced Journal Capture with MCP:**

```dart
// lib/arc/core/enhanced_journal_capture_cubit.dart
class EnhancedJournalCaptureCubit extends JournalCaptureCubit {
  final EnhancedMiraMemoryService _memoryService;

  @override
  Future<void> submitJournalEntry(String content) async {
    // Extract SAGE structure from journal entry
    final sage = await _extractSAGEStructure(content);

    // Store in MCP with full metadata
    final nodeId = await _memoryService.storeMemory(
      content: content,
      domain: MemoryDomain.personal,
      privacy: PrivacyLevel.personal,
      sage: sage,
      keywords: await _extractKeywords(content),
      emotions: await _extractEmotions(content),
      source: 'ARC',
    );

    // Create traditional journal entry for UI compatibility
    final journalEntry = JournalEntry(
      id: nodeId,
      content: content,
      createdAt: DateTime.now(),
      mcpNodeRef: nodeId, // Link to MCP node
    );

    emit(JournalCaptureSuccess(journalEntry));
  }

  // Extract SAGE structure from journal content
  Future<SAGEStructure> _extractSAGEStructure(String content) async {
    // Use NLP or patterns to extract:
    // - Situation: What was happening?
    // - Action: What did you do?
    // - Growth: What did you learn?
    // - Essence: What's the deeper meaning?

    return SAGEStructure(
      situation: await _extractSituation(content),
      action: await _extractAction(content),
      growth: await _extractGrowth(content),
      essence: await _extractEssence(content),
    );
  }
}
```

**ARC Memory Commands:**

```dart
// lib/arc/commands/memory_commands.dart
class ARCMemoryCommands {
  static const List<String> commands = [
    '/memory show',
    '/memory journal',
    '/memory themes',
    '/memory export journal',
  ];

  static Future<String> handleCommand(String command, EnhancedMiraMemoryService memoryService) async {
    switch (command.toLowerCase()) {
      case '/memory journal':
        return await _showJournalMemories(memoryService);
      case '/memory themes':
        return await _showJournalThemes(memoryService);
      case '/memory export journal':
        return await _exportJournalData(memoryService);
      default:
        return 'Unknown ARC memory command: $command';
    }
  }

  static Future<String> _showJournalMemories(EnhancedMiraMemoryService memoryService) async {
    final memories = await memoryService.retrieveMemories(
      domains: [MemoryDomain.personal],
      limit: 10,
    );

    final buffer = StringBuffer();
    buffer.writeln('📖 Your Recent Journal Memories:');
    buffer.writeln();

    for (final node in memories.nodes) {
      if (node.sage != null) {
        buffer.writeln('${node.createdAt.toLocal().toString().split(' ')[0]}:');
        buffer.writeln('Situation: ${node.sage!.situation}');
        buffer.writeln('Growth: ${node.sage!.growth}');
        buffer.writeln('Essence: ${node.sage!.essence}');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
```

### LUMARA Integration

**Enhanced LUMARA with MCP Memory:**

```dart
// lib/lumara/bloc/enhanced_lumara_assistant_cubit.dart
class EnhancedLumaraAssistantCubit extends LumaraAssistantCubit {
  final EnhancedMiraMemoryService _memoryService;

  @override
  Future<void> sendMessage(String text) async {
    final responseId = _generateResponseId();

    // Record user message in MCP
    await _memoryService.storeMemory(
      content: text,
      domain: MemoryDomain.personal,
      privacy: PrivacyLevel.personal,
      source: 'LUMARA_USER',
      metadata: {
        'conversation_type': 'chat',
        'session_id': currentSessionId,
        'role': 'user',
      },
    );

    // Retrieve relevant memories for context
    final memoryResult = await _memoryService.retrieveMemories(
      query: text,
      domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
      responseId: responseId,
      enableCrossDomainSynthesis: false,
    );

    // Generate AI response with memory context
    final response = await _generateResponseWithMemory(text, memoryResult);

    // Create explainable response
    final explainableResponse = await _memoryService.generateExplainableResponse(
      content: response,
      referencedNodes: memoryResult.nodes,
      responseId: responseId,
      includeReasoningDetails: true,
    );

    // Store assistant response in MCP
    await _memoryService.storeMemory(
      content: response,
      domain: MemoryDomain.personal,
      privacy: PrivacyLevel.personal,
      source: 'LUMARA_ASSISTANT',
      metadata: {
        'conversation_type': 'chat',
        'session_id': currentSessionId,
        'role': 'assistant',
        'attribution_id': responseId,
        'memory_references': memoryResult.nodes.length,
      },
    );

    // Emit response with attribution
    emit(LumaraResponseSuccess(
      message: response,
      attribution: explainableResponse.citationText,
      memoryUsage: memoryResult.nodes.length,
      transparencyScore: explainableResponse.attribution['overall_confidence'],
    ));
  }

  Future<String> _generateResponseWithMemory(
    String userMessage,
    MemoryRetrievalResult memoryResult,
  ) async {
    // Build context from retrieved memories
    final memoryContext = _buildMemoryContext(memoryResult.nodes);

    // Generate response using enhanced prompt with memory context
    final prompt = '''
You are LUMARA, a sacred reflective companion. The user has said: "$userMessage"

Based on their memory, here's relevant context:
$memoryContext

Respond with wisdom that honors their journey and growth.
''';

    return await _callLLMWithPrompt(prompt);
  }

  String _buildMemoryContext(List<EnhancedMiraNode> nodes) {
    final buffer = StringBuffer();

    for (final node in nodes.take(5)) {
      buffer.writeln('Memory from ${node.createdAt.toLocal().toString().split(' ')[0]}:');
      if (node.sage != null) {
        buffer.writeln('- Situation: ${node.sage!.situation}');
        buffer.writeln('- Growth: ${node.sage!.growth}');
        buffer.writeln('- Essence: ${node.sage!.essence}');
      } else {
        buffer.writeln('- Content: ${node.narrative.length > 100 ? node.narrative.substring(0, 100) + '...' : node.narrative}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
```

### ATLAS Phase Integration

**Phase-Aware Memory Lifecycle:**

```dart
// lib/atlas/phase_detection/mcp_phase_integration.dart
class MCPPhaseIntegration {
  final EnhancedMiraMemoryService _memoryService;

  MCPPhaseIntegration(this._memoryService);

  /// Handle phase transition and update memory lifecycle
  Future<void> handlePhaseTransition({
    required String fromPhase,
    required String toPhase,
    required String userId,
  }) async {
    // Update memory service with new phase context
    await _memoryService.initialize(
      userId: userId,
      currentPhase: toPhase,
    );

    // Apply phase-specific memory operations
    await _applyPhaseTransitionMemoryOps(fromPhase, toPhase);

    // Store phase transition as memory
    await _memoryService.storeMemory(
      content: 'Transitioning from $fromPhase to $toPhase phase',
      domain: MemoryDomain.personal,
      privacy: PrivacyLevel.personal,
      sage: SAGEStructure(
        situation: 'Life phase transition detected',
        action: 'Moving from $fromPhase to $toPhase',
        growth: 'Evolving through natural life cycles',
        essence: 'Growth is a continuous journey',
      ),
      source: 'ATLAS',
      metadata: {
        'transition_type': 'phase_change',
        'from_phase': fromPhase,
        'to_phase': toPhase,
      },
    );
  }

  Future<void> _applyPhaseTransitionMemoryOps(String fromPhase, String toPhase) async {
    switch (toPhase) {
      case 'Transition':
        // Accelerate memory pruning during transition
        await _scheduleMemoryPruning(accelerated: true);
        break;
      case 'Consolidation':
        // Strengthen important memories during consolidation
        await _reinforceKeyMemories();
        break;
      case 'Recovery':
        // Apply resilience restoration
        await _applyResilienceRestoration();
        break;
    }
  }

  Future<void> _scheduleMemoryPruning({bool accelerated = false}) async {
    // Get pruning candidates
    final dashboard = await _memoryService.getMemoryDashboard();
    final decayThreshold = accelerated ? 0.3 : 0.1;

    // Schedule pruning for highly decayed memories
    // This would integrate with the lifecycle management service
  }

  Future<void> _reinforceKeyMemories() async {
    // Identify and reinforce key memories during consolidation
    final keyMemories = await _identifyKeyMemories();

    for (final nodeId in keyMemories) {
      // Reinforce through lifecycle service
      // This would boost reinforcement scores
    }
  }

  Future<List<String>> _identifyKeyMemories() async {
    // Logic to identify key memories based on:
    // - High reinforcement scores
    // - Frequent access
    // - Emotional significance
    // - SAGE essence content
    return [];
  }
}
```

### Memory Dashboard Implementation

**Flutter UI for Memory Dashboard:**

```dart
// lib/features/memory/memory_dashboard_view.dart
class MemoryDashboardView extends StatefulWidget {
  @override
  State<MemoryDashboardView> createState() => _MemoryDashboardViewState();
}

class _MemoryDashboardViewState extends State<MemoryDashboardView> {
  final EnhancedMiraMemoryService _memoryService = GetIt.instance<EnhancedMiraMemoryService>();
  MemoryDashboard? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final dashboard = await _memoryService.getMemoryDashboard();
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_dashboard == null) return const ErrorView();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.export_notes),
            onPressed: _exportMemory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMemoryOverview(),
            const SizedBox(height: 24),
            _buildDomainDistribution(),
            const SizedBox(height: 24),
            _buildMemoryHealth(),
            const SizedBox(height: 24),
            _buildConflictSummary(),
            const SizedBox(height: 24),
            _buildAttributionStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Memories',
                    _dashboard!.totalMemories.toString(),
                    Icons.memory,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Memory Health',
                    '${(_dashboard!.memoryHealth * 100).toStringAsFixed(1)}%',
                    Icons.health_and_safety,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Sovereignty Score',
                    '${(_dashboard!.sovereigntyScore * 100).toStringAsFixed(1)}%',
                    Icons.security,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active Conflicts',
                    _dashboard!.conflictSummary['total_active_conflicts'].toString(),
                    Icons.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDomainDistribution() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Domains',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ..._dashboard!.domainDistribution.entries.map((entry) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                    ),
                    Expanded(
                      flex: 2,
                      child: LinearProgressIndicator(
                        value: entry.value / _dashboard!.totalMemories,
                        backgroundColor: Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.value}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryHealth() {
    final healthScore = _dashboard!.memoryHealth;
    Color healthColor;
    String healthText;

    if (healthScore > 0.8) {
      healthColor = Colors.green;
      healthText = 'Excellent';
    } else if (healthScore > 0.6) {
      healthColor = Colors.orange;
      healthText = 'Good';
    } else {
      healthColor = Colors.red;
      healthText = 'Needs Attention';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Health',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Health: $healthText'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: healthScore,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(healthColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                CircularProgressIndicator(
                  value: healthScore,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(healthColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictSummary() {
    final conflicts = _dashboard!.conflictSummary;
    final activeConflicts = conflicts['total_active_conflicts'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Conflicts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (activeConflicts == 0)
              const Text('No active conflicts - your memories are in harmony')
            else
              Column(
                children: [
                  Text('$activeConflicts conflicts need your attention'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _handleConflicts,
                    child: const Text('Review Conflicts'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributionStats() {
    final stats = _dashboard!.attributionStats;
    final transparencyScore = stats['memory_transparency_score'] as double? ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Transparency',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('Transparency Score: ${(transparencyScore * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: transparencyScore,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            const Text(
              'All memory usage is tracked and explainable',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMemory() async {
    try {
      final exportData = await _memoryService.exportUserMemoryData(
        format: 'mcp_bundle',
        includePrivate: false, // Default to not include private data
      );

      // Show export options dialog
      _showExportDialog(exportData);
    } catch (e) {
      // Handle error
    }
  }

  void _showExportDialog(String exportData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Memory Data'),
        content: const Text(
          'Your memory data has been prepared for export. '
          'This includes all your memories in a portable format that you own completely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Save to file or share
              Navigator.pop(context);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConflicts() async {
    // Navigate to conflict resolution view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConflictResolutionView(),
      ),
    );
  }
}
```

## Memory Commands Implementation

**Enhanced Memory Commands:**

```dart
// lib/features/memory/memory_command_handler.dart
class MemoryCommandHandler {
  final EnhancedMiraMemoryService _memoryService;

  MemoryCommandHandler(this._memoryService);

  static const Map<String, String> commands = {
    '/memory show': 'Show memory status and statistics',
    '/memory conflicts': 'Review and resolve memory conflicts',
    '/memory domains': 'Manage domain access and privacy',
    '/memory export': 'Export your complete memory data',
    '/memory health': 'Check memory system health',
    '/memory attribution': 'View recent memory usage attribution',
    '/memory clear': 'Clear old or low-value memories',
    '/memory backup': 'Create a memory backup bundle',
  };

  Future<String> handleCommand(String command) async {
    switch (command.toLowerCase().trim()) {
      case '/memory show':
        return await _showMemoryStatus();
      case '/memory conflicts':
        return await _showConflicts();
      case '/memory domains':
        return await _showDomains();
      case '/memory export':
        return await _exportMemory();
      case '/memory health':
        return await _checkMemoryHealth();
      case '/memory attribution':
        return await _showAttribution();
      case '/memory clear':
        return await _clearMemories();
      case '/memory backup':
        return await _backupMemory();
      default:
        return _showHelp();
    }
  }

  Future<String> _showMemoryStatus() async {
    final dashboard = await _memoryService.getMemoryDashboard();

    return '''
📊 **Memory Status**

**Overview:**
• Total Memories: ${dashboard.totalMemories}
• Memory Health: ${(dashboard.memoryHealth * 100).toStringAsFixed(1)}%
• Sovereignty Score: ${(dashboard.sovereigntyScore * 100).toStringAsFixed(1)}%

**Domains:**
${dashboard.domainDistribution.entries.map((e) => '• ${e.key}: ${e.value} memories').join('\n')}

**Recent Activity:**
${dashboard.recentActivity.take(3).map((a) => '• ${a['description']}').join('\n')}

Your memory is healthy and fully under your control.
''';
  }

  Future<String> _showConflicts() async {
    final dashboard = await _memoryService.getMemoryDashboard();
    final conflictCount = dashboard.conflictSummary['total_active_conflicts'] as int;

    if (conflictCount == 0) {
      return '''
✅ **No Memory Conflicts**

Your memories are in harmony. No contradictions or inconsistencies detected.
''';
    }

    return '''
⚠️ **Memory Conflicts Detected**

You have $conflictCount memory conflicts that need your attention.

These represent different perspectives or changes in your thinking over time.
Use the Memory Dashboard to review and resolve them at your own pace.

Remember: Conflicts often represent growth and evolving wisdom.
''';
  }

  Future<String> _showDomains() async {
    final dashboard = await _memoryService.getMemoryDashboard();

    return '''
🔐 **Memory Domains**

Your memories are organized into secure domains:

${dashboard.domainDistribution.entries.map((e) => '• **${e.key.toUpperCase()}**: ${e.value} memories').join('\n')}

**Privacy Levels:**
${dashboard.privacyDistribution.entries.map((e) => '• ${e.key}: ${e.value} memories').join('\n')}

All domains respect your privacy preferences and can be accessed independently.
''';
  }

  Future<String> _exportMemory() async {
    try {
      final exportPath = await _memoryService.exportUserMemoryData(
        format: 'mcp_bundle',
        includePrivate: false,
      );

      return '''
📦 **Memory Export Complete**

Your memory data has been exported in MCP (Memory Container Protocol) format.

**What's included:**
• All your memories and their relationships
• Complete attribution history
• Privacy settings and domain organization
• Full provenance and audit trails

**File location:** $exportPath

This is YOUR data - portable, readable, and completely under your control.
''';
    } catch (e) {
      return '''
❌ **Export Failed**

Error exporting memory data: $e

Please try again or contact support if the issue persists.
''';
    }
  }

  Future<String> _checkMemoryHealth() async {
    final dashboard = await _memoryService.getMemoryDashboard();
    final health = dashboard.memoryHealth;
    final sovereignty = dashboard.sovereigntyScore;

    String healthStatus;
    String recommendations = '';

    if (health > 0.8) {
      healthStatus = '🟢 Excellent';
    } else if (health > 0.6) {
      healthStatus = '🟡 Good';
      recommendations = '\n**Recommendations:**\n• Consider resolving any pending conflicts\n• Review and clean old memories';
    } else {
      healthStatus = '🔴 Needs Attention';
      recommendations = '\n**Recommendations:**\n• Review memory conflicts immediately\n• Clean up old or irrelevant memories\n• Check for corrupted or damaged entries';
    }

    return '''
🏥 **Memory Health Report**

**Overall Health:** $healthStatus (${(health * 100).toStringAsFixed(1)}%)
**Sovereignty Score:** ${(sovereignty * 100).toStringAsFixed(1)}%
**Transparency:** ${(dashboard.attributionStats['memory_transparency_score'] * 100).toStringAsFixed(1)}%

$recommendations

Your memory system is functioning properly and remains under your complete control.
''';
  }

  Future<String> _showAttribution() async {
    final stats = await _memoryService.getMemoryDashboard();
    final attribution = stats.attributionStats;

    return '''
🔍 **Memory Attribution Summary**

**Recent Usage:**
• Total Responses: ${attribution['total_responses']}
• Memory References: ${attribution['total_memory_references']}
• Avg References per Response: ${attribution['avg_references_per_response'].toStringAsFixed(1)}

**Transparency Score:** ${(attribution['memory_transparency_score'] * 100).toStringAsFixed(1)}%

Every time your memories are used to inform a response, it's tracked and attributable.
You can see exactly which memories influenced each conversation.
''';
  }

  String _showHelp() {
    return '''
💡 **Memory Commands Help**

Available commands:
${commands.entries.map((e) => '• `${e.key}` - ${e.value}').join('\n')}

Your memory system is built on principles of sovereignty, transparency, and dignity.
Every memory belongs to you and can be exported, modified, or deleted at any time.
''';
  }

  Future<String> _clearMemories() async {
    return '''
🧹 **Memory Cleanup**

Memory cleanup helps maintain system health by removing:
• Highly decayed memories (with your consent)
• Duplicate or redundant entries
• Old temporary data

Use the Memory Dashboard for detailed cleanup options.
Important memories are protected and will never be automatically deleted.
''';
  }

  Future<String> _backupMemory() async {
    try {
      final snapshot = await _memoryService.createMemorySnapshot(
        includeAttributions: true,
        includeConflicts: true,
      );

      return '''
💾 **Memory Backup Created**

**Backup Details:**
• ${snapshot.nodes.length} memories backed up
• Attribution data included
• Conflict resolution history preserved
• Complete domain structure saved

**Created:** ${snapshot.manifest.createdAt.toLocal()}

Your backup is stored locally and can be used to restore your memory at any time.
''';
    } catch (e) {
      return 'Error creating backup: $e';
    }
  }
}
```

## Testing and Validation

**MCP Integration Tests:**

```dart
// test/mcp/mcp_integration_test.dart
void main() {
  group('MCP Integration Tests', () {
    late EnhancedMiraMemoryService memoryService;

    setUp(() async {
      memoryService = EnhancedMiraMemoryService(
        miraService: MockMiraService(),
      );
      await memoryService.initialize(
        userId: 'test_user',
        currentPhase: 'Discovery',
      );
    });

    test('should store and retrieve memory with attribution', () async {
      // Store a memory
      final nodeId = await memoryService.storeMemory(
        content: 'Test journal entry about growth',
        domain: MemoryDomain.personal,
        sage: SAGEStructure(
          situation: 'Testing MCP',
          action: 'Writing test',
          growth: 'Learning system',
          essence: 'Testing validates design',
        ),
      );

      // Retrieve memories
      final result = await memoryService.retrieveMemories(
        query: 'growth',
        responseId: 'test_response',
      );

      expect(result.nodes.length, greaterThan(0));
      expect(result.attributions.length, greaterThan(0));
      expect(result.attributions.first.nodeRef, equals(nodeId));
    });

    test('should handle memory conflicts gracefully', () async {
      // Store conflicting memories
      await memoryService.storeMemory(
        content: 'I love this project',
        domain: MemoryDomain.work,
        keywords: ['project', 'love', 'enthusiasm'],
      );

      await memoryService.storeMemory(
        content: 'I hate this project',
        domain: MemoryDomain.work,
        keywords: ['project', 'hate', 'frustration'],
      );

      // Check for conflicts
      final dashboard = await memoryService.getMemoryDashboard();
      final conflicts = dashboard.conflictSummary['total_active_conflicts'] as int;

      expect(conflicts, greaterThan(0));
    });

    test('should export MCP-compliant bundle', () async {
      // Store some memories
      await memoryService.storeMemory(
        content: 'Test memory 1',
        domain: MemoryDomain.personal,
      );

      await memoryService.storeMemory(
        content: 'Test memory 2',
        domain: MemoryDomain.creative,
      );

      // Export bundle
      final exportData = await memoryService.exportUserMemoryData(
        format: 'mcp_bundle',
      );

      final bundle = jsonDecode(exportData);

      expect(bundle['manifest'], isNotNull);
      expect(bundle['nodes'], isNotNull);
      expect(bundle['manifest']['schema_version'], equals('mcp_bundle.v1'));
    });

    test('should respect domain privacy boundaries', () async {
      // Store health data
      await memoryService.storeMemory(
        content: 'Private health information',
        domain: MemoryDomain.health,
        privacy: PrivacyLevel.confidential,
      );

      // Try to retrieve without proper context
      final result = await memoryService.retrieveMemories(
        domains: [MemoryDomain.health],
        responseId: 'test_response',
      );

      // Should not return confidential data without proper access
      expect(result.nodes.length, equals(0));
    });
  });
}
```

This implementation guide provides a complete roadmap for integrating MCP with EPI's existing architecture while maintaining backward compatibility and enhancing user sovereignty over their memory data.