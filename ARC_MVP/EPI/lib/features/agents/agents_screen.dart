import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/screens/plugin_activity_screen.dart';
import 'package:my_app/lumara/agents/widgets/lumara_writing_format_card.dart';
import 'package:my_app/lumara/agents/screens/plugin_catalog_screen.dart';
import 'package:my_app/lumara/profile/user_profile_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'agents_data.dart';
import 'agents_persona_resolver.dart';
import 'run_screen.dart';

/// Emoji hints for [AgentsData.swarmspaceOfficialFreeApiSlugs] (site-style list).
const Map<String, String> _kFreeApiSlugEmoji = {
  'brave-search': '🦁',
  'semantic-scholar': '📚',
  'jina-reader': '🔗',
  'wikipedia': '📖',
  'open-meteo': '🌤️',
  'news-api': '📰',
  'arxiv': '📄',
  'pubmed': '🧬',
  'hacker-news': '🔶',
  'reddit': '🤖',
  'github-public': '🐙',
  'exchange-rates': '💱',
  'rest-countries': '🌍',
  'nominatim': '📍',
  'gemini-flash': '✨',
};

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  static const _prefsAgentTogglesKey = 'lumara_agents_enabled_ids';

  late String _personaKey;
  String _input = '';
  bool _useChronicle = true;
  bool _dismissedGreeting = false;
  late final Map<String, bool> _agentToggles;
  late final TextEditingController _inputController;
  late final TextEditingController _writingFormatSpecsController;
  late final TextEditingController _researchPaperSpecsController;
  late final TextEditingController _capabilitySearchController;
  late final FocusNode _inputFocusNode;
  late final ScrollController _scrollController;
  bool _outputFormatExpanded = false;
  bool _inspirationExpanded = false;
  bool _agentsExpanded = false;
  bool _swarmSpaceStoreExpanded = true;
  final List<_PartEntry> _partEntries = [];
  final List<AgentAttachment> _attachments = [];
  /// See [LumaraWritingFormatIds]; legacy ids still accepted by Run screen defaults.
  String _writingFormatId = LumaraWritingFormatIds.normalizeSelectableId(
      LumaraWritingFormatIds.mediumSocial);

  bool _includeWritingSources = false;
  String _profileContextHint = '';

  bool get _canSubmit {
    final hasText = _input.trim().isNotEmpty;
    final hasParts = _partEntries.any(
      (e) =>
          e.titleController.text.trim().isNotEmpty ||
          e.detailController.text.trim().isNotEmpty,
    );
    return hasText || hasParts || _attachments.isNotEmpty;
  }

  /// Matches [AgentsData.orchestrate] for the current Your run + enabled agents.
  bool get _predictedRunIncludesWriting {
    if (!_canSubmit) return false;
    final parts = _snapshotRequestParts();
    final composed = AgentsData.composeOrchestrationInput(
      _input,
      parts,
      _attachments,
    );
    final enabledIds = _agentToggles.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final chain = AgentsData.orchestrate(composed, _personaKey, enabledIds);
    return chain.steps.any((s) => s.toLowerCase().contains('writing'));
  }

  @override
  void initState() {
    super.initState();
    _personaKey = AgentsPersonaResolver.resolvePersonaKey();
    _inputController = TextEditingController();
    _writingFormatSpecsController = TextEditingController();
    _researchPaperSpecsController = TextEditingController();
    _capabilitySearchController = TextEditingController();
    _inputFocusNode = FocusNode();
    _inputController.addListener(() {
      if (mounted) setState(() {});
    });
    _capabilitySearchController.addListener(() {
      if (mounted) setState(() {});
    });
    _scrollController = ScrollController();
    _agentToggles = {
      for (final a in [...AgentsData.agents, ...AgentsData.swarmspacePlugins])
        a.id: a.enabledByDefault,
    };
    _loadPersistedAgentToggles();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshPersonaKey();
      await _loadProfileContextHint();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPersonaKey());
  }

  Future<void> _refreshPersonaKey() async {
    final k = await AgentsPersonaResolver.resolvePersonaKeyResolved();
    if (mounted && k != _personaKey) {
      setState(() => _personaKey = k);
    }
  }

  Future<void> _loadProfileContextHint() async {
    try {
      final p = await UserProfileService.instance.getProfile();
      final line =
          p[AgentsPersonaResolver.schoolOrProfessionFormKey]?.trim() ?? '';
      if (mounted && line.isNotEmpty) {
        setState(() => _profileContextHint = line);
      }
    } catch (_) {}
  }

  String _specsForRun() {
    if (_writingFormatId == LumaraWritingFormatIds.researchPaper) {
      final rp = _researchPaperSpecsController.text.trim();
      final gen = _writingFormatSpecsController.text.trim();
      if (rp.isNotEmpty) return rp;
      if (gen.isNotEmpty) return gen;
      return '';
    }
    return _writingFormatSpecsController.text.trim();
  }

  Future<void> _loadPersistedAgentToggles() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsAgentTogglesKey);
    if (saved == null || !mounted) return;
    final on = saved.toSet();
    setState(() {
      for (final a in [...AgentsData.agents, ...AgentsData.swarmspacePlugins]) {
        _agentToggles[a.id] = on.contains(a.id);
      }
    });
  }

  Future<void> _persistAgentToggles() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _agentToggles.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await prefs.setStringList(_prefsAgentTogglesKey, ids);
  }

  @override
  void dispose() {
    for (final e in _partEntries) {
      e.titleController.dispose();
      e.detailController.dispose();
    }
    _inputController.dispose();
    _writingFormatSpecsController.dispose();
    _researchPaperSpecsController.dispose();
    _capabilitySearchController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearPartsAndAttachments() {
    for (final e in _partEntries) {
      e.titleController.dispose();
      e.detailController.dispose();
    }
    _partEntries.clear();
    _attachments.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        ),
        child: Scaffold(
          backgroundColor: kcBackgroundColor,
          appBar: AppBar(
            backgroundColor: kcBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              'SwarmSpace',
              style: heading1Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _input = '';
                    _inputController.clear();
                    _capabilitySearchController.clear();
                    _dismissedGreeting = false;
                    _clearPartsAndAttachments();
                  });
                },
                icon: Icon(
                  Icons.refresh_rounded,
                  color: kcSecondaryTextColor.withValues(alpha: 0.7),
                ),
                tooltip: 'Reset',
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LUMARA hosts capabilities on SwarmSpace and chooses what to run from your request, enabled agents, and toggled plugins.',
            style: GoogleFonts.inter(
              color: const Color(0xFF6A6A8A),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionLabel('YOUR RUN'),
          const SizedBox(height: 6),
          Text(
            'This box is for the job you want done. Tap Work it out for me and LUMARA will pick workflows and SwarmSpace tools—it is not the plugin catalogue.',
            style: GoogleFonts.inter(
              color: const Color(0xFF33334A),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _buildFreeformCard(),
          const SizedBox(height: 16),
          if (_predictedRunIncludesWriting) ...[
            _buildChevronSection(
              expanded: _outputFormatExpanded,
              onToggle: () => setState(
                () => _outputFormatExpanded = !_outputFormatExpanded,
              ),
              title: 'Output format',
              subtitle:
                  'Length and specs for this run (shown when Writing is in the chain).',
              child: _buildWritingFormatSection(),
            ),
            const SizedBox(height: 8),
          ],
          _buildChevronSection(
            expanded: _inspirationExpanded,
            onToggle: () => setState(
              () => _inspirationExpanded = !_inspirationExpanded,
            ),
            title: 'Inspiration',
            subtitle: 'Prep meeting, launch plan, content ideas—tap a card to fill Your run.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestions use your profile and what you typed in Your run.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF33334A),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _buildGoalCards(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildChevronSection(
            expanded: _agentsExpanded,
            onToggle: () =>
                setState(() => _agentsExpanded = !_agentsExpanded),
            title: 'Agents',
            subtitle:
                'Enable or open built-in agents. Writing opens its own workspace.',
            child: _buildAgentsList(),
          ),
          const SizedBox(height: 24),
          _buildChevronSection(
            expanded: _swarmSpaceStoreExpanded,
            onToggle: () => setState(
              () => _swarmSpaceStoreExpanded = !_swarmSpaceStoreExpanded,
            ),
            title: 'SwarmSpace store · 15 free APIs',
            subtitle:
                'Official free-tier order (swarmspace.app). Search to narrow; open the catalog for everything.',
            child: _buildSwarmSpaceStoreExpandedBody(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Collapsible block with a leading chevron (Material-style expand affordance).
  Widget _buildChevronSection({
    required bool expanded,
    required VoidCallback onToggle,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF7A7A9A),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE8E8F4),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF44445A),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          child,
        ],
      ],
    );
  }

  Widget _buildSwarmSpaceStoreExpandedBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionLabel('FIND A CAPABILITY'),
        const SizedBox(height: 6),
        Text(
          'Filter the free-tier list by keyword. This search does not start a run—use Your run and Work it out for me for that.',
          style: GoogleFonts.inter(
            color: const Color(0xFF33334A),
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _capabilitySearchController,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFFE0E0F0),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F0F1E),
            hintText: 'Search by name, slug, or keyword…',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFF44445A),
              fontSize: 13,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1C1C30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1C1C30)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5B5BD6)),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: const Color(0xFF5B5BD6).withValues(alpha: 0.85),
              size: 22,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Toggle Include in runs only where LUMARA already routes that plugin.',
          style: GoogleFonts.inter(
            color: const Color(0xFF33334A),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        _buildOfficialFreeApisList(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _openPluginCatalog,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B5BD6),
              side: BorderSide(
                color: const Color(0xFF5B5BD6).withValues(alpha: 0.55),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Browse all SwarmSpace plugins',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredFreeApis() {
    final q = _capabilitySearchController.text.trim().toLowerCase();
    if (q.isEmpty) return AgentsData.freeApis;
    bool matches(Map<String, dynamic> raw) {
      final slug = (raw['slug'] as String? ?? '').toLowerCase();
      final name = (raw['name'] as String? ?? '').toLowerCase();
      final desc = (raw['description'] as String? ?? '').toLowerCase();
      return slug.contains(q) || name.contains(q) || desc.contains(q);
    }
    return AgentsData.freeApis.where(matches).toList();
  }

  Widget _buildWritingFormatSection() {
    return LumaraWritingFormatCard(
      selectedId: _writingFormatId,
      onSelect: (id) => setState(() => _writingFormatId = id),
      specsController: _writingFormatSpecsController,
      researchPaperSpecsController: _researchPaperSpecsController,
      includeSources: _includeWritingSources,
      onIncludeSourcesChanged: (v) =>
          setState(() => _includeWritingSources = v),
    );
  }

  Widget _buildFreeformCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14142A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_dismissedGreeting) ...[
            Row(
              children: [
                Text('👋', style: GoogleFonts.inter(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi there',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Chronicle context is matched to your saved profile — not shown here.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7A7A9A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _dismissedGreeting = true);
                  },
                  icon: Text(
                    '×',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF44445A),
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _inputController,
            focusNode: _inputFocusNode,
            minLines: 3,
            maxLines: 5,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFFE0E0F0),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0C0C1A),
              hintText:
                  'What should we research, compare, or write for you? Be specific.',
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFF44445A),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1C1C30)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1C1C30)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF5B5BD6)),
              ),
            ),
            onChanged: (value) {
              setState(() => _input = value);
            },
            onSubmitted: (_) => _handleSubmit(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('📖', style: GoogleFonts.inter(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use CHRONICLE context',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _useChronicle
                        ? const Color(0xFF7070C0)
                        : const Color(0xFF44445A),
                  ),
                ),
              ),
              _buildToggle(
                _useChronicle,
                () => setState(() => _useChronicle = !_useChronicle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMultiPartSection(),
          const SizedBox(height: 14),
          _buildAttachmentsSection(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B5BD6)
                    .withValues(alpha: _canSubmit ? 1.0 : 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              onPressed: _canSubmit ? _handleSubmit : null,
              child: Text(
                'Work it out for me →',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCards() {
    final cards = AgentsData.goalCardsForFreeText(
      '$_profileContextHint ${_inputController.text}',
    );
    return Column(
      children: [
        ...cards.map((card) {
          return GestureDetector(
            onTap: () => _fillGoal(card.fillText),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1A1A2C)),
              ),
              child: Row(
                children: [
                  Text(card.emoji, style: GoogleFonts.inter(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      card.label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB0B0D0),
                      ),
                    ),
                  ),
                  Text(
                    '↗',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF33334A),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF1E1E30).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Text('⚙️', style: GoogleFonts.inter(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Build a custom chain',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF33334A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A3A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'soon',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF7A7A9A),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  void _openPluginCatalog() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const PluginCatalogScreen(),
      ),
    );
  }

  void _openPluginActivity() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const PluginActivityScreen(),
      ),
    );
  }

  void _onAgentOpenTap(AgentItem agent, bool isEnabled) {
    if (!isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enable ${agent.label} first.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF2A2A3E),
        ),
      );
      return;
    }
    if (agent.id == 'plugin_discovery') {
      _openPluginCatalog();
      return;
    }
    if (agent.id == 'plugin_activity') {
      _openPluginActivity();
      return;
    }
    if (agent.id == 'writing') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const WritingScreen(),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${agent.label} runs when you use Work it out for me above.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2A2A3E),
      ),
    );
  }

  Widget _buildAgentsList() {
    return Column(
      children: AgentsData.agents.map((agent) {
        final isEnabled = _agentToggles[agent.id] ?? false;
        final card = Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14142A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1C1C30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: agent.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      agent.icon,
                      style: GoogleFonts.inter(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.label,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          agent.description,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF7A7A9A),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (agent.isNav)
                    Text(
                      '›',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF44445A),
                        fontSize: 20,
                      ),
                    ),
                ],
              ),
              if (!agent.isNav) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    agent.connected
                        ? _buildConnectedBadge()
                        : _buildDisconnectedBadge(),
                    const Spacer(),
                    _buildToggle(
                      isEnabled,
                      () {
                        setState(() {
                          _agentToggles[agent.id] = !isEnabled;
                        });
                        _persistAgentToggles();
                      },
                    ),
                  ],
                ),
                if (agent.connected && isEnabled) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B5BD6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: () => _onAgentOpenTap(agent, isEnabled),
                      child: Text(
                        agent.id == 'plugin_discovery'
                            ? 'Browse plugins →'
                            : 'Open ${agent.label} →',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                if (!agent.connected) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to your account to use ${agent.label}.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF33334A),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );

        if (agent.isNav) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openPluginActivity,
            child: card,
          );
        }
        return card;
      }).toList(),
    );
  }

  Widget _buildOfficialFreeApisList() {
    final rows = _filteredFreeApis();
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No free-tier APIs match that search. Try another keyword or browse all plugins below.',
          style: GoogleFonts.inter(
            color: const Color(0xFF44445A),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.map(_buildFreeApiRow).toList(),
    );
  }

  Widget _buildFreeApiRow(Map<String, dynamic> raw) {
    final slug = raw['slug'] as String? ?? '';
    final name = raw['name'] as String? ?? slug;
    final desc = raw['description'] as String? ?? '';
    final wired = AgentsData.swarmspacePluginForSlug(slug);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: wired != null
          ? _buildWiredOfficialFreeApiCard(
              plugin: wired,
              displayName: name,
              displayDescription: desc,
            )
          : _buildCatalogOnlyFreeApiCard(
              slug: slug,
              title: name,
              description: desc,
            ),
    );
  }

  Widget _buildWiredOfficialFreeApiCard({
    required AgentItem plugin,
    required String displayName,
    required String displayDescription,
  }) {
    final isEnabled = _agentToggles[plugin.id] ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14142A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: plugin.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  plugin.icon,
                  style: GoogleFonts.inter(fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildFreeTierChip(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plugin.swarmspaceSlug,
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF34D399),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayDescription,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF7A7A9A),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildConnectedBadge(),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Include in runs',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7A7A9A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildToggle(
                    isEnabled,
                    () {
                      setState(() {
                        _agentToggles[plugin.id] = !isEnabled;
                      });
                      _persistAgentToggles();
                    },
                  ),
                ],
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'SwarmSpace · ',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF33334A),
                    fontSize: 10,
                  ),
                ),
                Text(
                  plugin.swarmspaceSlug,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF34D399),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCatalogOnlyFreeApiCard({
    required String slug,
    required String title,
    required String description,
  }) {
    final emoji = _kFreeApiSlugEmoji[slug] ?? '✦';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14142A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: GoogleFonts.inter(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildFreeTierChip(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            slug,
            style: GoogleFonts.robotoMono(
              color: const Color(0xFF34D399),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF7A7A9A),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'On SwarmSpace free tier; LUMARA will add include toggles as workers go live.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF44445A),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTierChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2218),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF183A26)),
      ),
      child: Text(
        'FREE',
        style: GoogleFonts.inter(
          color: const Color(0xFF34D399),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildToggle(bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF5B5BD6) : const Color(0xFF252538),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: value ? 22 : 2,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2218),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF183A26)),
      ),
      child: Text(
        'Connected',
        style: GoogleFonts.inter(
          color: const Color(0xFF34D399),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDisconnectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF181828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222238)),
      ),
      child: Text(
        'Disconnected',
        style: GoogleFonts.inter(
          color: const Color(0xFF44445A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.robotoMono(
        color: const Color(0xFF33334A),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMultiPartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'MULTI-PART REQUEST',
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF33334A),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _addPart,
              child: Text(
                '+ Add part',
                style: GoogleFonts.inter(
                  color: const Color(0xFF5B5BD6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Optional sub-tasks; each part is tracked while the chain runs.',
          style: GoogleFonts.inter(
            color: const Color(0xFF44445A),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_partEntries.length, (index) {
          final e = _partEntries[index];
          return Padding(
            key: ValueKey<String>(e.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1C1C30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: e.titleController,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFFE0E0F0),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Part title (e.g. Research, Draft deck)',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF44445A),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removePartAt(index),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF44445A),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: e.detailController,
                    minLines: 1,
                    maxLines: 4,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFB0B0D0),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Details (optional)',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF44445A),
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF14142A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1C1C30)),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACHMENTS',
          style: GoogleFonts.robotoMono(
            color: const Color(0xFF33334A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PDF, Word, TXT, Markdown, images — for model context on device.',
          style: GoogleFonts.inter(
            color: const Color(0xFF44445A),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickAttachments,
            icon: const Icon(
              Icons.attach_file,
              color: Color(0xFF5B5BD6),
              size: 20,
            ),
            label: Text(
              'Add files',
              style: GoogleFonts.inter(
                color: const Color(0xFF5B5BD6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFF1C1C30)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachments.map((a) {
              return Chip(
                backgroundColor: const Color(0xFF13131F),
                side: const BorderSide(color: Color(0xFF1C1C30)),
                label: Text(
                  '${a.fileName} · ${AgentsData.formatBytes(a.sizeBytes)}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB0B0D0),
                    fontSize: 12,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _attachments.removeWhere((x) => x.id == a.id);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _addPart() {
    setState(() {
      _partEntries.add(
        _PartEntry(
          id: const Uuid().v4(),
          titleController: TextEditingController(),
          detailController: TextEditingController(),
        ),
      );
    });
  }

  void _removePartAt(int index) {
    setState(() {
      final e = _partEntries.removeAt(index);
      e.titleController.dispose();
      e.detailController.dispose();
    });
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'txt',
        'md',
        'rtf',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'heic',
      ],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      for (final p in result.files) {
        if (p.name.isEmpty) continue;
        var ext = (p.extension ?? '').toLowerCase();
        if (ext.isEmpty) {
          final dot = p.name.lastIndexOf('.');
          if (dot != -1) {
            ext = p.name.substring(dot + 1).toLowerCase();
          }
        }
        _attachments.add(
          AgentAttachment(
            id: const Uuid().v4(),
            fileName: p.name,
            extension: ext.isEmpty ? 'file' : ext,
            sizeBytes: p.size,
            path: p.path,
          ),
        );
      }
    });
  }

  List<RequestPart> _snapshotRequestParts() {
    return _partEntries
        .map(
          (e) => RequestPart(
            id: e.id,
            title: e.titleController.text,
            detail: e.detailController.text,
          ),
        )
        .where(
          (p) => p.title.trim().isNotEmpty || p.detail.trim().isNotEmpty,
        )
        .toList();
  }

  void _handleSubmit() {
    if (!_canSubmit) return;
    final parts = _snapshotRequestParts();
    final composed = AgentsData.composeOrchestrationInput(
      _input,
      parts,
      _attachments,
    );
    final enabledIds = _agentToggles.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final chain = AgentsData.orchestrate(composed, _personaKey, enabledIds);
    if (chain.steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable at least one agent to run a workflow.'),
          backgroundColor: Color(0xFF2A2A3E),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RunScreen(
          chain: chain,
          input: _input.trim(),
          requestParts: parts,
          attachments: List<AgentAttachment>.from(_attachments),
          platforms: null,
          personaKey: _personaKey,
          useChronicle: _useChronicle,
          enabledAgentIds: enabledIds,
          writingFormatId: _writingFormatId,
          researchPaperSpecs: _specsForRun(),
          includeWritingSources: _includeWritingSources,
        ),
      ),
    );
  }

  void _fillGoal(String text) {
    setState(() => _input = text);
    _inputController.text = text;
    _inputController.selection =
        TextSelection.collapsed(offset: text.length);
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }
}

class _PartEntry {
  _PartEntry({
    required this.id,
    required this.titleController,
    required this.detailController,
  });

  final String id;
  final TextEditingController titleController;
  final TextEditingController detailController;
}
