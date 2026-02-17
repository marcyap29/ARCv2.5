import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/ui/research_screen.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/widgets/research_report_card.dart';
import 'package:my_app/lumara/agents/screens/research_report_detail_screen.dart';
import 'package:my_app/shared/app_colors.dart';

class ResearchAgentTab extends StatefulWidget {
  const ResearchAgentTab({super.key});

  @override
  State<ResearchAgentTab> createState() => _ResearchAgentTabState();
}

class _ResearchAgentTabState extends State<ResearchAgentTab> {
  Future<List<ResearchReport>> _loadReports() async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    return AgentsChronicleService.instance.getResearchReports(userId);
  }

  void _refresh() => setState(() {});

  static const List<String> _exampleQueries = [
    'SBIR Phase I requirements and how ARC maps to defense priorities',
    'Evidence-based practices for trauma recovery and resilience',
    'Current research on narrative identity and meaning-making',
  ];

  void _showExampleQueries(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Example research questions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ..._exampleQueries.map((q) => ListTile(
                    title: Text(q, style: const TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => ResearchScreen(initialQuery: q),
                        ),
                      ).then((_) => _refresh());
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<ResearchReport>> _groupReportsByDate(
      List<ResearchReport> reports) {
    final grouped = <DateTime, List<ResearchReport>>{};

    for (final report in reports) {
      final dateKey = DateTime(
        report.generatedAt.year,
        report.generatedAt.month,
        report.generatedAt.day,
      );

      grouped.putIfAbsent(dateKey, () => []).add(report);
    }

    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No research reports yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: kcPrimaryTextColor,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Run research from here or use LUMARA chat for research with sources.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kcSecondaryColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const ResearchScreen(),
                ),
              ).then((_) => _refresh());
            },
            icon: const Icon(Icons.search),
            label: const Text('Run new research'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcPrimaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showExampleQueries(context),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('See Examples'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, List<ResearchReport> reports) {
    if (reports.isEmpty) return const SizedBox.shrink();
    final grouped = _groupReportsByDate(reports);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: kcSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final dateGroup = grouped.keys.elementAt(index);
            final reportsForDate = grouped[dateGroup]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _formatDateHeader(dateGroup),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: kcSecondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ...reportsForDate.map((report) => ResearchReportCard(
                      report: report,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                ResearchReportDetailScreen(report: report),
                          ),
                        ).then((_) => _refresh());
                      },
                      onArchive: () => _archive(report),
                      onUnarchive: () => _unarchive(report),
                      onDelete: () => _delete(report),
                    )),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _archive(ResearchReport report) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.archiveResearchReport(userId, report.id);
    _refresh();
  }

  Future<void> _unarchive(ResearchReport report) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    await AgentsChronicleService.instance.unarchiveResearchReport(userId, report.id);
    _refresh();
  }

  Future<void> _delete(ResearchReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete report?'),
        content: Text(
            'Delete research "${report.query}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
    await AgentsChronicleService.instance.deleteResearchReport(userId, report.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResearchReport>>(
      future: _loadReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? [];
        if (all.isEmpty) return _buildEmptyState(context);

        final active = all.where((r) => !r.archived).toList();
        final archived = all.where((r) => r.archived).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportSection('Active', active),
              _buildReportSection('Archived', archived),
            ],
          ),
        );
      },
    );
  }
}
