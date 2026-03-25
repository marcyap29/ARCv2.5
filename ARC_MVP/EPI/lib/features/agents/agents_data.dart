import 'package:flutter/material.dart';
import 'package:my_app/features/plugins/jina_reader_plugin.dart';

class Persona {
  const Persona({
    required this.name,
    required this.role,
    required this.tags,
    required this.recentEntries,
    required this.inputPlaceholder,
  });

  final String name;
  final String role;
  final List<String> tags;
  final List<String> recentEntries;
  final String inputPlaceholder;
}

class GoalCard {
  const GoalCard({
    required this.id,
    required this.emoji,
    required this.label,
    required this.fillText,
  });

  final String id;
  final String emoji;
  final String label;
  final String fillText;
}

class WorkflowChain {
  const WorkflowChain({
    required this.label,
    required this.steps,
    required this.reason,
  });

  final String label;
  final List<String> steps;
  final String reason;
}

/// One segment of a multi-part user request (tracked through the run).
class RequestPart {
  const RequestPart({
    required this.id,
    required this.title,
    this.detail = '',
  });

  final String id;
  final String title;
  final String detail;
}

/// User-selected file for additional context (paths are session-local).
class AgentAttachment {
  const AgentAttachment({
    required this.id,
    required this.fileName,
    required this.extension,
    required this.sizeBytes,
    this.path,
  });

  final String id;
  final String fileName;
  final String extension;
  final int sizeBytes;
  final String? path;
}

class AgentItem {
  const AgentItem({
    required this.id,
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.description,
    required this.connected,
    required this.enabledByDefault,
    this.isNav = false,
    required this.workerEndpoint,
    required this.swarmspaceSlug,
    required this.isPlugin,
  });

  final String id;
  final String icon;
  final Color iconBg;
  final String label;
  final String description;
  final bool connected;
  final bool enabledByDefault;
  final bool isNav;

  /// Cloudflare Worker route this agent calls (placeholder until backend wiring).
  final String workerEndpoint;

  /// SwarmSpace plugin manifest slug when applicable.
  final String swarmspaceSlug;

  /// `true` = SwarmSpace catalogue plugin; `false` = built-in LUMARA agent.
  final bool isPlugin;
}

class AgentsData {
  /// Free-tier SwarmSpace plugin / API catalogue (no paid keys required for basic use).
  /// Includes in-app manifest for [JinaReaderPlugin] plus common research plugins.
  static List<Map<String, dynamic>> get freeApis => [
        {
          'slug': 'brave-search',
          'name': 'Brave Search',
          'description':
              'Web search for research runs. Free tier available via SwarmSpace.',
          'access_tier': 'free',
          'trust_tier': 'verified',
        },
        {
          'slug': 'semantic-scholar',
          'name': 'Semantic Scholar',
          'description':
              'Academic paper search and metadata. Free API for non-commercial use.',
          'access_tier': 'free',
          'trust_tier': 'verified',
        },
        {
          'slug': 'tavily-search',
          'name': 'Tavily Search',
          'description':
              'AI-oriented web search. Often used when configured on SwarmSpace.',
          'access_tier': 'free',
          'trust_tier': 'verified',
        },
        JinaReaderPlugin.toManifest(),
      ];

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Combines primary prompt, optional parts, and attachment names for orchestration intent.
  static String composeOrchestrationInput(
    String primary,
    List<RequestPart> parts,
    List<AgentAttachment> attachments,
  ) {
    final buf = StringBuffer(primary.trim());
    final nonEmptyParts = parts
        .where(
          (p) => p.title.trim().isNotEmpty || p.detail.trim().isNotEmpty,
        )
        .toList();
    if (nonEmptyParts.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- Multi-part request ---');
      for (var i = 0; i < nonEmptyParts.length; i++) {
        final p = nonEmptyParts[i];
        buf.writeln('${i + 1}. ${p.title.trim()}');
        if (p.detail.trim().isNotEmpty) {
          buf.writeln(p.detail.trim());
        }
      }
    }
    if (attachments.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- Attached files (for context) ---');
      for (final a in attachments) {
        buf.writeln('- ${a.fileName} (${formatBytes(a.sizeBytes)})');
      }
    }
    return buf.toString().trim();
  }

  static final Map<String, Persona> personas = {
    'founder': const Persona(
      name: 'Marc',
      role: 'Founder, Orbital AI',
      tags: ['AI', 'startups', 'SwarmSpace', 'product'],
      recentEntries: [
        'Investor meeting next Thursday',
        'SwarmSpace Verified tier launch approaching',
        'Firebase migration still open',
      ],
      inputPlaceholder:
          'e.g. I have a VC meeting Thursday, want to walk in sharp...',
    ),
    'student': const Persona(
      name: 'Aisha',
      role: 'Biology student, UC San Diego',
      tags: ['marine biology', 'thesis', 'coral bleaching'],
      recentEntries: [
        'Thesis defence next month',
        'Literature review stalled',
        'Study group Friday',
      ],
      inputPlaceholder:
          'e.g. I need to prep for my thesis defence next month...',
    ),
    'coach': const Persona(
      name: 'Jordan',
      role: 'Lifestyle & wellness coach',
      tags: ['coaching', 'clients', 'wellness', 'LinkedIn'],
      recentEntries: [
        'Launching 6-week programme in March',
        'Want to grow LinkedIn',
        'Spring intake opens soon',
      ],
      inputPlaceholder:
          'e.g. I want to launch my spring programme and get content out...',
    ),
  };

  static final Map<String, List<GoalCard>> goalCards = {
    'founder': const [
      GoalCard(
        id: 'founder_prep_meeting',
        emoji: '🤝',
        label: 'Prep meeting',
        fillText:
            'I have an investor meeting next Thursday and I need a sharp prep brief with likely questions and strong answers.',
      ),
      GoalCard(
        id: 'founder_plan_launch',
        emoji: '🚀',
        label: 'Plan launch',
        fillText:
            'Help me plan and announce the SwarmSpace Verified tier launch with clear milestones and messaging.',
      ),
      GoalCard(
        id: 'founder_create_content',
        emoji: '📝',
        label: 'Create content',
        fillText:
            'Draft a week of founder content for LinkedIn and X about Orbital AI progress and product vision.',
      ),
      GoalCard(
        id: 'founder_watch_competition',
        emoji: '🧭',
        label: 'Watch competition',
        fillText:
            'Track competing startups in our space and summarize what they are launching this month.',
      ),
      GoalCard(
        id: 'founder_reach_developers',
        emoji: '💬',
        label: 'Reach out to developers',
        fillText:
            'Find relevant developer communities and draft outreach messages to recruit early technical partners.',
      ),
    ],
    'student': const [
      GoalCard(
        id: 'student_thesis_prep',
        emoji: '🎓',
        label: 'Thesis prep',
        fillText:
            'I need a practical plan to prepare for my thesis defence next month in marine biology.',
      ),
      GoalCard(
        id: 'student_lit_review',
        emoji: '📚',
        label: 'Literature review',
        fillText:
            'Help me restart my stalled literature review on coral bleaching with a clear structure and key papers.',
      ),
      GoalCard(
        id: 'student_presentation_prep',
        emoji: '📊',
        label: 'Presentation prep',
        fillText:
            'Create an outline and speaking notes for my thesis presentation so I can explain my methods confidently.',
      ),
      GoalCard(
        id: 'student_understand_topic',
        emoji: '🔬',
        label: 'Understand a topic',
        fillText:
            'Break down the latest findings on coral bleaching mechanisms and explain them in simple terms.',
      ),
      GoalCard(
        id: 'student_write_something',
        emoji: '✍️',
        label: 'Write something',
        fillText:
            'Help me draft a clean discussion section paragraph connecting my results to current coral bleaching research.',
      ),
    ],
    'coach': const [
      GoalCard(
        id: 'coach_launch_programme',
        emoji: '🌱',
        label: 'Launch programme',
        fillText:
            'I want to launch my 6-week wellness programme in March with a simple weekly rollout plan.',
      ),
      GoalCard(
        id: 'coach_grow_linkedin',
        emoji: '📣',
        label: 'Grow LinkedIn',
        fillText:
            'Create a LinkedIn content strategy to grow my coaching audience and attract the right clients.',
      ),
      GoalCard(
        id: 'coach_prep_client',
        emoji: '🧘',
        label: 'Prep for client',
        fillText:
            'Prepare a focused session plan for a client who is struggling with stress and consistency.',
      ),
      GoalCard(
        id: 'coach_research_topic',
        emoji: '🔎',
        label: 'Research wellness topic',
        fillText:
            'Research evidence-based habits for better sleep and summarize what I can teach clients this week.',
      ),
      GoalCard(
        id: 'coach_find_clients',
        emoji: '🤝',
        label: 'Find potential clients',
        fillText:
            'Identify likely places to find new wellness coaching clients and draft warm outreach messages.',
      ),
    ],
  };

  static const List<AgentItem> agents = [
    AgentItem(
      id: 'writing',
      icon: '✏️',
      iconBg: Color(0xFF2D2D5E),
      label: 'Writing',
      description: 'Drafts, rewrites, and polished copy.',
      connected: true,
      enabledByDefault: true,
      workerEndpoint: 'https://lumara-workflows.orbitalai.workers.dev/workflows/writing',
      swarmspaceSlug: 'lumara-writing',
      isPlugin: false,
    ),
    AgentItem(
      id: 'research',
      icon: '🔍',
      iconBg: Color(0xFF1E3A5F),
      label: 'Research',
      description: 'Finds facts, sources, and useful context.',
      connected: true,
      enabledByDefault: true,
      workerEndpoint: 'https://lumara-workflows.orbitalai.workers.dev/workflows/research',
      swarmspaceSlug: 'lumara-research',
      isPlugin: false,
    ),
    AgentItem(
      id: 'competitor_intel',
      icon: '🗺️',
      iconBg: Color(0xFF2D1E5F),
      label: 'Competitor Intel',
      description: 'Monitors rivals and market positioning.',
      connected: true,
      enabledByDefault: true,
      workerEndpoint: 'https://lumara-workflows.orbitalai.workers.dev/workflows/competitor',
      swarmspaceSlug: 'lumara-competitor',
      isPlugin: false,
    ),
    AgentItem(
      id: 'plugin_discovery',
      icon: '🔌',
      iconBg: Color(0xFF1E3D2F),
      label: 'Plugin Discovery',
      description: 'Discovers tools and integration options.',
      connected: false,
      enabledByDefault: false,
      workerEndpoint: 'https://lumara-workflows.orbitalai.workers.dev/workflows/plugins',
      swarmspaceSlug: 'lumara-plugins',
      isPlugin: false,
    ),
    AgentItem(
      id: 'image_analysis',
      icon: '🖼️',
      iconBg: Color(0xFF3D2A1E),
      label: 'Image Analysis',
      description: 'Interprets images and visual materials.',
      connected: true,
      enabledByDefault: false,
      workerEndpoint: 'https://lumara-workflows.orbitalai.workers.dev/workflows/image',
      swarmspaceSlug: 'lumara-image',
      isPlugin: false,
    ),
    AgentItem(
      id: 'plugin_activity',
      icon: '🕐',
      iconBg: Color(0xFF252538),
      label: 'Plugin Activity',
      description: 'Shows recent plugin events and history.',
      connected: true,
      enabledByDefault: true,
      isNav: true,
      workerEndpoint: '',
      swarmspaceSlug: '',
      isPlugin: false,
    ),
  ];

  static const List<AgentItem> swarmspacePlugins = [
    AgentItem(
      id: 'jina-reader',
      icon: '🔗',
      iconBg: Color(0xFF1A3A4A),
      label: 'Web Reader',
      description:
          'Fetch and extract clean text from any URL. Free, no key required.',
      connected: true,
      enabledByDefault: true,
      isNav: false,
      workerEndpoint:
          'https://lumara-workflows.orbitalai.workers.dev/plugins/jina-reader',
      swarmspaceSlug: 'jina-reader',
      isPlugin: true,
    ),
    AgentItem(
      id: 'brave-search',
      icon: '🦁',
      iconBg: Color(0xFF3A2A1A),
      label: 'Brave Search',
      description: 'Privacy-first web search on an independent index.',
      connected: true,
      enabledByDefault: true,
      isNav: false,
      workerEndpoint:
          'https://lumara-workflows.orbitalai.workers.dev/plugins/brave-search',
      swarmspaceSlug: 'brave-search',
      isPlugin: true,
    ),
    AgentItem(
      id: 'semantic-scholar',
      icon: '📚',
      iconBg: Color(0xFF1A2A3A),
      label: 'Semantic Scholar',
      description: '200M+ academic papers. Free, no key required.',
      connected: true,
      enabledByDefault: true,
      isNav: false,
      workerEndpoint:
          'https://lumara-workflows.orbitalai.workers.dev/plugins/semantic-scholar',
      swarmspaceSlug: 'semantic-scholar',
      isPlugin: true,
    ),
    AgentItem(
      id: 'news-api',
      icon: '📰',
      iconBg: Color(0xFF2A1A3A),
      label: 'News Headlines',
      description: 'Latest headlines from 70+ sources.',
      connected: true,
      enabledByDefault: false,
      isNav: false,
      workerEndpoint:
          'https://lumara-workflows.orbitalai.workers.dev/plugins/news-api',
      swarmspaceSlug: 'news-api',
      isPlugin: true,
    ),
  ];

  static List<String> defaultEnabledIds() => [
        ...agents,
        ...swarmspacePlugins,
      ]
          .where((a) => a.enabledByDefault)
          .map((a) => a.id)
          .toList();

  /// Resolves a chain step label (e.g. `Research`) to catalogue metadata.
  static AgentItem? findAgentByStepLabel(String stepLabel) {
    for (final a in agents) {
      if (a.label == stepLabel) return a;
    }
    for (final a in swarmspacePlugins) {
      if (a.label == stepLabel) return a;
    }
    return null;
  }

  /// Maps orchestration step names to [AgentItem.id] for enablement checks.
  static String? _agentIdForStep(String step) {
    switch (step) {
      case 'Research':
        return 'research';
      case 'Writing':
        return 'writing';
      case 'Competitor Intel':
        return 'competitor_intel';
      case 'Plugin Discovery':
        return 'plugin_discovery';
      default:
        return null;
    }
  }

  static WorkflowChain _filterEnabledSteps(
    WorkflowChain raw,
    List<String> enabledAgentIds,
  ) {
    final enabled = enabledAgentIds.toSet();
    final filtered = <String>[];
    for (final step in raw.steps) {
      final id = _agentIdForStep(step);
      if (id == null) continue;
      if (enabled.contains(id)) {
        filtered.add(step);
      }
    }
    if (filtered.isEmpty) {
      return const WorkflowChain(
        label: 'No agents available',
        steps: [],
        reason: 'Enable at least one agent to run a workflow.',
      );
    }
    return WorkflowChain(
      label: raw.label,
      steps: filtered,
      reason: raw.reason,
    );
  }

  static WorkflowChain orchestrate(
    String input,
    String personaKey,
    List<String> enabledAgentIds,
  ) {
    final raw = _orchestrateRaw(input, personaKey);
    return _filterEnabledSteps(raw, enabledAgentIds);
  }

  static WorkflowChain _orchestrateRaw(String input, String personaKey) {
    final lower = input.toLowerCase();

    if (_containsAny(lower, [
      'meeting',
      'investor',
      'vc',
      'pitch',
      'client',
      'session',
    ])) {
      return const WorkflowChain(
        label: 'Prep for your meeting',
        steps: ['Research', 'Competitor Intel', 'Writing'],
        reason: 'Detected: preparation for a meeting or presentation',
      );
    }

    if (_containsAny(lower, [
      'launch',
      'announce',
      'programme',
      'program',
      'release',
    ])) {
      return const WorkflowChain(
        label: 'Plan and announce your launch',
        steps: ['Research', 'Competitor Intel', 'Writing'],
        reason: 'Detected: product or programme launch',
      );
    }

    if (_containsAny(lower, [
      'content',
      'post',
      'linkedin',
      'twitter',
      'write',
      'draft',
    ])) {
      return const WorkflowChain(
        label: 'Research and write content',
        steps: ['Research', 'Writing'],
        reason: 'Detected: content creation intent',
      );
    }

    if (_containsAny(lower, [
      'compet',
      'rival',
      'market',
      'monitor',
      'watch',
    ])) {
      return const WorkflowChain(
        label: 'Competitive intelligence run',
        steps: ['Competitor Intel', 'Writing'],
        reason: 'Detected: competitor or market awareness',
      );
    }

    if (_containsAny(lower, [
      'reach out',
      'outreach',
      'contact',
      'partner',
      'developer',
    ])) {
      return const WorkflowChain(
        label: 'Find and reach out',
        steps: ['Plugin Discovery', 'Research', 'Writing'],
        reason: 'Detected: outreach or partnership intent',
      );
    }

    if (_containsAny(lower, [
      'research',
      'understand',
      'learn',
      'find out',
    ])) {
      return const WorkflowChain(
        label: 'Deep research report',
        steps: ['Research'],
        reason: 'Detected: information gathering',
      );
    }

    final _ = personaKey; // Reserved for future persona-specific routing.
    return const WorkflowChain(
      label: 'Research and summarise',
      steps: ['Research', 'Writing'],
      reason: 'General intent — running research and synthesis',
    );
  }

  static Color stepColor(String step) {
    switch (step) {
      case 'Research':
        return const Color(0xFF4A90D9);
      case 'Competitor Intel':
        return const Color(0xFF9B6DFF);
      case 'Writing':
        return const Color(0xFF34D399);
      case 'Plugin Discovery':
        return const Color(0xFFFB923C);
      default:
        return const Color(0xFF5B5BD6);
    }
  }

  static bool _containsAny(String source, List<String> terms) {
    for (final term in terms) {
      if (source.contains(term)) return true;
    }
    return false;
  }
}
