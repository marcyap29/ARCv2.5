import 'package:flutter/material.dart';
import 'package:my_app/insights/analytics_page.dart';
import 'package:my_app/arc/health/apple_health_service.dart';
import 'package:my_app/arc/ui/health/health_detail_view.dart';

class HealthView extends StatefulWidget {
  const HealthView({super.key});

  @override
  State<HealthView> createState() => _HealthViewState();
}

class _HealthViewState extends State<HealthView> {
  int _selected = 0; // 0: Summary, 1: Connect, 2: Analytics

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: _selected,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Health'),
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            onTap: (i) => setState(() => _selected = i),
            tabs: const [
              Tab(icon: Icon(Icons.favorite_outline, size: 20), text: 'Summary'),
              Tab(icon: Icon(Icons.health_and_safety, size: 20), text: 'Connect'),
              Tab(icon: Icon(Icons.stacked_line_chart, size: 20), text: 'Analytics'),
            ],
          ),
        ),
        body: Container(
          color: Colors.black.withOpacity(0.04),
          child: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildScrollable([_summaryCard(context)]),
              _buildScrollable([_connectAppleHealthCard(context)]),
              _buildScrollable([_analyticsEntryCard(context)]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollable(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(20),
        children: children,
      );

  Widget _summaryCard(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const HealthDetailView(pointerJson: {}),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: const [
            Icon(Icons.favorite_outline),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Health Summary',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _connectAppleHealthCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        final granted = await AppleHealthService.instance.requestPermissions();
        if (context.mounted) {
          final summary = granted
              ? await AppleHealthService.instance.fetchBasicSummary()
              : <String, num>{};
          final msg = granted
              ? (summary.isEmpty
                  ? 'Apple Health connected. No recent data found.'
                  : 'Apple Health connected. Steps 7d: ${summary['steps7d']?.round() ?? 0}')
              : 'Apple Health permission denied';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: const [
            Icon(Icons.health_and_safety),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connect Apple Health',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _analyticsEntryCard(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AnalyticsPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: const [
            Icon(Icons.stacked_line_chart),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Analytics',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}


