// lib/shared/ui/chronicle/intelligence_summary_view.dart
//
// Intelligence Summary (Layer 3) - Readable synthesis of LUMARA's Chronicle.
// Shows latest summary, metadata, Regenerate now, version history.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/chronicle/dual/models/intelligence_summary_models.dart';
import 'package:my_app/chronicle/dual/services/dual_chronicle_services.dart';
import 'package:my_app/chronicle/dual/services/lumara_connection_fade_preferences.dart';
import 'package:my_app/chronicle/dual/services/intelligence_summary_schedule_preferences.dart';
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
  String _scheduleLabel = 'Daily at 10:00 PM';
  String? _nextRefreshLabel;
  bool _scheduleLoaded = false;
  int _fadeDays = defaultFadeDays;

  @override
  void initState() {
    super.initState();
    _load();
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
      final cadence = await IntelligenceSummarySchedulePreferences.getCadence();
      final hour = await IntelligenceSummarySchedulePreferences.getHour();
      final minute = await IntelligenceSummarySchedulePreferences.getMinute();
      final lastGen = await IntelligenceSummarySchedulePreferences.getLastGeneratedAt();
      final next = await IntelligenceSummarySchedulePreferences.getNextScheduledTime(
        lastGenerated: lastGen,
      );
      final due = await IntelligenceSummarySchedulePreferences.isRunDue();
      final fadeDays = await LumaraConnectionFadePreferences.getFadeDays();
      if (mounted) {
        setState(() {
          _summary = latest;
          _versionHistory = history;
          _scheduleLabel = '${cadence.label} at ${_formatTime(hour, minute)}';
          _nextRefreshLabel = DateFormat('MMM d, y • h:mm a').format(next.toLocal());
          _scheduleLoaded = true;
          _fadeDays = fadeDays;
          _loading = false;
        });
        if (due && latest != null && !_regenerating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _regenerateNow();
          });
        }
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

  String _formatTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final am = hour < 12;
    return '$h:${minute.toString().padLeft(2, '0')} ${am ? 'AM' : 'PM'}';
  }

  Future<void> _showScheduleDialog() async {
    var cadence = await IntelligenceSummarySchedulePreferences.getCadence();
    var hour = await IntelligenceSummarySchedulePreferences.getHour();
    var minute = await IntelligenceSummarySchedulePreferences.getMinute();
    if (!mounted) return;
    final picked = await showDialog<({IntelligenceSummaryCadence c, int h, int m})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Refresh schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-refresh Intelligence Summary (only you see it).',
                      style: bodyStyle(ctx).copyWith(color: kcSecondaryTextColor),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<IntelligenceSummaryCadence>(
                      value: cadence,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: IntelligenceSummaryCadence.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          cadence = v;
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text('Time: ${_formatTime(hour, minute)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay(hour: hour, minute: minute),
                        );
                        if (t != null) {
                          hour = t.hour;
                          minute = t.minute;
                          setDialogState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop((c: cadence, h: hour, m: minute)),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked != null && mounted) {
      await IntelligenceSummarySchedulePreferences.setCadence(picked.c);
      await IntelligenceSummarySchedulePreferences.setHour(picked.h);
      await IntelligenceSummarySchedulePreferences.setMinute(picked.m);
      await _load();
    }
  }

  Future<void> _regenerateNow() async {
    setState(() {
      _regenerating = true;
      _error = null;
    });
    try {
      final summary = await DualChronicleServices.generateIntelligenceSummaryWithGapAnalysis(_userId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _regenerating = false;
        });
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Intelligence Summary updated; gap analysis ran.'),
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
          const SizedBox(height: 12),
          Text(
            'Requires: Groq API key (Settings → LUMARA → API & providers). '
            'Uses Layer 0 (chats, reflections, voice), CHRONICLE Layers 1–3 (monthly, yearly, multi-year) when available, and LUMARA\'s learned patterns.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              height: 1.35,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (_scheduleLoaded) ...[
            const SizedBox(height: 16),
            _buildScheduleCard(),
          ],
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
          if (_scheduleLoaded) ...[
            const SizedBox(height: 12),
            _buildScheduleCard(),
          ],
          const SizedBox(height: 12),
          Text(
            'Connections (causal chains, learning moments, patterns) from the last $_fadeDays days are used; older ones fade from context.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 12,
            ),
          ),
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

  Widget _buildScheduleCard() {
    return InkWell(
      onTap: _showScheduleDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, color: kcAccentColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refresh: $_scheduleLabel',
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (_nextRefreshLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Next: $_nextRefreshLabel',
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.edit, size: 18, color: kcSecondaryTextColor),
          ],
        ),
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
          _metadataRow('Causal chains', '${m.totalCausalChains}'),
          _metadataRow('Learning moments', '${m.totalLearningMoments}'),
          _metadataRow('Patterns', '${m.totalPatterns}'),
          _metadataRow('Relationships', '${m.totalRelationships}'),
          _metadataRow(
            'Active memory window',
            '$_fadeDays days (older connections fade from context)',
          ),
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
