// lib/shared/ui/chronicle/intelligence_summary_view.dart
//
// Intelligence Summary (Layer 3) - Readable synthesis of LUMARA's Chronicle.
// Shows latest summary, metadata, Regenerate now, version history.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import 'package:my_app/arc/chat/services/groq_service.dart';
import 'package:my_app/chronicle/dual/models/intelligence_summary_models.dart';
import 'package:my_app/chronicle/dual/services/dual_chronicle_services.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class IntelligenceSummaryView extends StatefulWidget {
  const IntelligenceSummaryView({super.key});

  @override
  State<IntelligenceSummaryView> createState() => _IntelligenceSummaryViewState();
}

class _IntelligenceSummaryViewState extends State<IntelligenceSummaryView> {
  String get _userId =>
      FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';

  IntelligenceSummary? _summary;
  List<IntelligenceSummaryVersion> _versionHistory = [];
  bool _loading = true;
  bool _regenerating = false;
  String? _error;
  bool _showMetadata = false;

  static bool _llmRegistered = false;

  @override
  void initState() {
    super.initState();
    _load();
    _registerLLMIfNeeded();
  }

  void _registerLLMIfNeeded() {
    if (_llmRegistered) return;
    _llmRegistered = true;
    LumaraAPIConfig.instance.initialize().then((_) {
      final config = LumaraAPIConfig.instance.getConfig(LLMProvider.groq);
      final apiKey = config?.apiKey;
      if (apiKey != null && apiKey.isNotEmpty) {
        DualChronicleServices.registerIntelligenceSummaryLLM(
          (systemPrompt, userPrompt, {maxTokens}) async {
            final groq = GroqService(apiKey: apiKey);
            return groq.generateContent(
              prompt: userPrompt,
              systemPrompt: systemPrompt,
              temperature: 0.3,
              maxTokens: maxTokens ?? 4096,
            );
          },
        );
      }
    }).catchError((_) {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = DualChronicleServices.intelligenceSummaryRepo;
      final latest = await repo.getLatest(_userId);
      final history = await repo.getVersionHistory(_userId);
      if (mounted) {
        setState(() {
          _summary = latest;
          _versionHistory = history;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _regenerateNow() async {
    setState(() {
      _regenerating = true;
      _error = null;
    });
    try {
      final generator = DualChronicleServices.intelligenceSummaryGenerator;
      final summary = await generator.generateSummary(_userId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _regenerating = false;
        });
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Intelligence Summary updated'),
              backgroundColor: kcSuccessColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _regenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Intelligence Summary',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kcAccentColor),
            )
          : _summary == null
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: bodyStyle(context).copyWith(color: kcDangerColor),
            ),
            const SizedBox(height: 16),
          ],
          Icon(
            Icons.psychology,
            size: 64,
            color: kcAccentColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Intelligence Summary',
            style: heading3Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your first summary will be generated when you tap below. '
            'LUMARA synthesizes your timeline and learning into a readable narrative. '
            'Summary is also marked for regeneration when you reflect or chat.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _regenerating ? null : _regenerateNow,
            icon: _regenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_regenerating ? 'Generating…' : 'Generate Summary'),
            style: FilledButton.styleFrom(
              backgroundColor: kcAccentColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final summary = _summary!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last updated: ${DateFormat('MMM d, y • h:mm a').format(summary.generatedAt.toLocal())}',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showMetadata = !_showMetadata),
            child: Text(
              _showMetadata ? 'Hide details' : 'Show details',
              style: bodyStyle(context).copyWith(
                color: kcAccentColor,
                fontSize: 13,
              ),
            ),
          ),
          if (_showMetadata) _buildMetadataCard(summary),
          const SizedBox(height: 16),
          _buildMarkdownContent(summary.content),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_versionHistory.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showVersionHistory(),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Previous versions'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _regenerating ? null : _regenerateNow,
                icon: _regenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_regenerating ? 'Generating…' : 'Regenerate now'),
                style: FilledButton.styleFrom(
                  backgroundColor: kcAccentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(IntelligenceSummary summary) {
    final m = summary.metadata;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metadataRow('Confidence', m.confidenceLevel.toUpperCase()),
          _metadataRow(
            'Based on',
            '${m.totalEntries} entries, ${m.temporalSpan.monthsCovered} months',
          ),
          _metadataRow('Patterns', '${m.totalPatterns}'),
          _metadataRow('Relationships', '${m.totalRelationships}'),
          _metadataRow('Version', '#${summary.version}'),
          _metadataRow('Generation', '${m.generationDurationMs} ms'),
        ],
      ),
    );
  }

  Widget _metadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bodyStyle(context).copyWith(
                color: kcPrimaryTextColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(String content) {
    final lines = content.split('\n');
    final children = <Widget>[];
    for (final line in lines) {
      if (line.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            line.substring(2),
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ));
      } else if (line.startsWith('## ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            line.substring(3),
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ));
      } else if (line.startsWith('### ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            line.substring(4),
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ));
      } else {
        children.add(SelectableText(
          line,
          style: bodyStyle(context).copyWith(
            color: kcPrimaryTextColor,
            height: 1.5,
            fontSize: 15,
          ),
        ));
        children.add(const SizedBox(height: 4));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void _showVersionHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kcBackgroundColor,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Previous versions',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _versionHistory.length,
                itemBuilder: (context, i) {
                  final v = _versionHistory[i];
                  return ListTile(
                    title: Text(
                      'Version ${v.version}',
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('MMM d, y • h:mm a')
                          .format(v.generatedAt.toLocal()),
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showVersionContent(v);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVersionContent(IntelligenceSummaryVersion v) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kcBackgroundColor,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Version ${v.version}',
                    style: heading3Style(context).copyWith(
                      color: kcPrimaryTextColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, y').format(v.generatedAt.toLocal()),
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMarkdownContent(v.content),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
