import 'package:flutter/material.dart';
import 'package:my_app/arc/health/apple_health_service.dart';
import 'package:my_app/ui/health/health_detail_screen.dart';

class HealthDetailView extends StatelessWidget {
  final Map<String, dynamic> pointerJson;
  const HealthDetailView({super.key, required this.pointerJson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Summary')),
      body: HealthSummaryBody(pointerJson: pointerJson),
    );
  }
}

/// Reusable body content of the Health Summary screen so it can be embedded
/// inside other layouts (e.g., the Health tab's Summary subtab).
class HealthSummaryBody extends StatefulWidget {
  final Map<String, dynamic> pointerJson;
  const HealthSummaryBody({super.key, required this.pointerJson});

  @override
  State<HealthSummaryBody> createState() => _HealthSummaryBodyState();
}

class _HealthSummaryBodyState extends State<HealthSummaryBody> {
  String _currentMonthKeyUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // Import functionality moved to HealthSettingsDialog (accessible via Settings icon)

  @override
  Widget build(BuildContext context) {
    final windows = (widget.pointerJson['sampling_manifest']?['windows'] as List?) ?? const [];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: windows.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return FutureBuilder<Map<String, num>>(
            future: AppleHealthService.instance.fetchBasicSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final data = snapshot.data!;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Apple Health (last 7 days)', style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.show_chart),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HealthDetailScreen(monthKey: _currentMonthKeyUtc()),
                              ),
                            );
                          },
                          tooltip: 'View detailed charts',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Steps: ${data['steps7d']?.round() ?? 0}  •  Avg HR: ${data['avgHR']?.toStringAsFixed(0) ?? '—'} bpm'),
                  ],
                ),
              );
            },
          );
        }

        if (index == 1) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap "View detailed charts" to see metrics over time, including workouts, energy, HRV, and more.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue.shade200),
                  ),
                ),
              ],
            ),
          );
        }

        final w = windows[index - 2] as Map<String, dynamic>;
        final start = (w['start'] ?? '').toString();
        final end = (w['end'] ?? '').toString();
        final s = (w['summary'] as Map?) ?? const {};
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$start → $end', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(s.entries.map((e) => '${e.key}: ${e.value}').join('  •  ')),
            ],
          ),
        );
      },
    );
  }
}


