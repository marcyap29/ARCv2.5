/// Outputs Tab Screen
///
/// Browse and search LUMARA agent outputs: research reports and writing drafts.
/// Search filters by keywords in titles, subjects, and content.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';
import 'package:my_app/lumara/agents/models/content_draft.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/screens/research_report_detail_screen.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/widgets/content_draft_card.dart';
import 'package:my_app/shared/app_colors.dart';

class OutputsTabScreen extends StatefulWidget {
  const OutputsTabScreen({super.key});

  @override
  State<OutputsTabScreen> createState() => _OutputsTabScreenState();
}

class _OutputsTabScreenState extends State<OutputsTabScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<ResearchReport> _reports = [];
  List<ContentDraft> _drafts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOutputs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOutputs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await AgentsChronicleService.instance.getCurrentUserId();
      final reports = await AgentsChronicleService.instance.getResearchReports(userId);
      final drafts = await AgentsChronicleService.instance.getContentDrafts(userId);
      if (mounted) {
        setState(() {
          _reports = reports;
          _drafts = drafts;
          _loading = false;
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

  List<ResearchReport> get _filteredReports {
    if (_searchQuery.isEmpty) return _reports;
    final q = _searchQuery.toLowerCase();
    return _reports.where((r) {
      return (r.query.toLowerCase().contains(q)) ||
          (r.summary.toLowerCase().contains(q));
    }).toList();
  }

  List<ContentDraft> get _filteredDrafts {
    if (_searchQuery.isEmpty) return _drafts;
    final q = _searchQuery.toLowerCase();
    return _drafts.where((d) {
      return (d.title.toLowerCase().contains(q)) ||
          (d.preview.toLowerCase().contains(q)) ||
          ((d.contentType ?? '').toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: kcPrimaryTextColor),
                decoration: InputDecoration(
                  hintText: 'Search reports and writings by title, subject...',
                  hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: kcSecondaryTextColor.withOpacity(0.5)),
                  filled: true,
                  fillColor: kcSurfaceAltColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Could not load outputs',
                                  style: TextStyle(color: kcSecondaryTextColor, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.7), fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _loadOutputs,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final reports = _filteredReports;
    final drafts = _filteredDrafts;
    final isEmpty = reports.isEmpty && drafts.isEmpty;

    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: kcSecondaryTextColor.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No outputs yet' : 'No matching outputs',
              style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.8), fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try different keywords',
                style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.5), fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOutputs,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (reports.isNotEmpty) _buildReportsSection(reports),
          if (drafts.isNotEmpty) _buildDraftsSection(drafts),
        ],
      ),
    );
  }

  Widget _buildReportsSection(List<ResearchReport> reports) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Reports',
            style: TextStyle(
              color: kcSecondaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        ...reports.map((r) => _ReportTile(
              report: r,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => ResearchReportDetailScreen(report: r),
                  ),
                ).then((_) => _loadOutputs());
              },
            )),
      ],
    );
  }

  Widget _buildDraftsSection(List<ContentDraft> drafts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Writing',
            style: TextStyle(
              color: kcSecondaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final d = drafts[index];
              return ContentDraftCard(
                draft: d,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const WritingScreen(),
                    ),
                  ).then((_) => _loadOutputs());
                },
                onMarkFinished: () => _markFinished(d),
                onArchive: () => _archive(d),
                onUnarchive: () => _unarchive(d),
                onDelete: () => _delete(d),
                onChanged: _loadOutputs,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _markFinished(ContentDraft draft) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.markDraftFinished(userId, draft.id);
    _loadOutputs();
  }

  Future<void> _archive(ContentDraft draft) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.archiveDraft(userId, draft.id);
    _loadOutputs();
  }

  Future<void> _unarchive(ContentDraft draft) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.unarchiveDraft(userId, draft.id);
    _loadOutputs();
  }

  Future<void> _delete(ContentDraft draft) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete draft?'),
        content: Text('Delete "${draft.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.deleteDraft(userId, draft.id);
    _loadOutputs();
  }
}

class _ReportTile extends StatelessWidget {
  final ResearchReport report;
  final VoidCallback onTap;

  const _ReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMd().format(report.generatedAt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment, size: 20, color: kcPrimaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      report.query,
                      style: const TextStyle(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (report.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  report.summary,
                  style: TextStyle(
                    color: kcSecondaryTextColor.withOpacity(0.9),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
