import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/lumara/agents/widgets/research_report_card.dart';
import 'package:my_app/lumara/agents/screens/research_report_detail_screen.dart';
import 'package:my_app/shared/ui/home/home_cubit.dart';
import 'package:my_app/shared/app_colors.dart';

class ResearchAgentTab extends StatelessWidget {
  const ResearchAgentTab({super.key});

  Future<List<ResearchReport>> _loadResearchReports() async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    return AgentsChronicleService.instance.getResearchReports(userId);
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
            'Ask LUMARA to research something in the main tab',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kcSecondaryColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              try {
                context.read<HomeCubit>().changeTab(0);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Go to LUMARA and ask for research'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('See Examples'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcPrimaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(
      BuildContext context, List<ResearchReport> reports) {
    final groupedReports = _groupReportsByDate(reports);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedReports.length,
      itemBuilder: (context, index) {
        final dateGroup = groupedReports.keys.elementAt(index);
        final reportsForDate = groupedReports[dateGroup]!;

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
                    );
                  },
                )),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResearchReport>>(
      future: _loadResearchReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildReportList(context, snapshot.data!);
      },
    );
  }
}
