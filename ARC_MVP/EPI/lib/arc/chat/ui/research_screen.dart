import 'package:my_app/lumara/agents/research/swarmspace_web_search_tool.dart';
// lib/arc/chat/ui/research_screen.dart
// Dedicated screen for the LUMARA Research Agent (Agents tab).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../services/lumara_cloud_generate.dart';
import 'package:my_app/lumara/agents/research/research_agent.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/lumara/agents/research/research_models.dart';
import 'package:my_app/lumara/agents/research/web_search_tool.dart';
import 'package:my_app/lumara/agents/screens/research_agent_tab.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Screen for the LUMARA Research Agent: enter a question, get a synthesized report.
class ResearchScreen extends StatefulWidget {
  const ResearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
  }

  ResearchReport? _report;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Enter a research question.';
      });
      return;
    }
    final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final agent = ResearchAgent(
        getAgentOsPrefix: () => LumaraReflectionSettingsService.instance.getAgentOsPrefix(),
        generate: ({required systemPrompt, required userPrompt, maxTokens}) async {
          return generateForAgents(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: maxTokens ?? 1200,
          );
        },
        searchTool: SwarmSpaceWebSearchTool(),
      );
      final result = await agent.conductResearch(
        userId: userId,
        query: query,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _report = result.report;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _copyReport() {
    if (_report == null) return;
    final buf = StringBuffer();
    buf.writeln('# Research: ${_report!.query}');
    buf.writeln();
    buf.writeln('## Summary');
    buf.writeln(_report!.summary);
    buf.writeln();
    buf.writeln('## Key Insights');
    for (final i in _report!.keyInsights) {
      buf.writeln('- ${i.statement}');
    }
    buf.writeln();
    buf.writeln('## Detailed Findings');
    buf.writeln(_report!.detailedFindings);
    buf.writeln();
    buf.writeln('## Sources');
    for (final c in _report!.citations) {
      buf.writeln('[${c.id}] ${c.title} - ${c.url}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Research'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('My Research'),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                    body: const ResearchAgentTab(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.folder_open, size: 20),
            label: const Text('My Research'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Research question',
                hintText: 'e.g. SBIR Phase I requirements and how ARC maps to defense priorities',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const Gap(16),
            FilledButton(
              onPressed: _loading ? null : _runResearch,
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run research'),
            ),
            if (_error != null) ...[
              const Gap(16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Gap(24),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_report != null)
                  TextButton.icon(
                    onPressed: _copyReport,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
              ],
            ),
            if (_report == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Your research report will appear here after you run a query above. Reports are saved automatically to My Research.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else ...[
              const Gap(8),
              Text(
                'Saved to My Research. Open Agents → Research to see all reports.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const Gap(12),
              _Section(
                title: 'Summary',
                child: SelectableText(_report!.summary),
              ),
              if (_report!.keyInsights.isNotEmpty) ...[
                const Gap(16),
                _Section(
                  title: 'Key insights',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _report!.keyInsights
                        .map((i) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(
                                      i.statement,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
              const Gap(16),
              _Section(
                title: 'Detailed findings',
                child: SelectableText(_report!.detailedFindings),
              ),
              if (_report!.citations.isNotEmpty) ...[
                const Gap(16),
                _Section(
                  title: 'Sources',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _report!.citations
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: SelectableText(
                                '[${c.id}] ${c.title}\n${c.url}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Gap(6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ],
    );
  }
}
