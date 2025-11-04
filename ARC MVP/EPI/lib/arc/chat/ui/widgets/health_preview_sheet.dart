import 'package:flutter/material.dart';
import 'package:my_app/prism/models/health_summary.dart';
import 'package:my_app/prism/providers/health_preview_provider.dart';

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class HealthPreviewSheet extends StatefulWidget {
  const HealthPreviewSheet({super.key});
  @override
  State<HealthPreviewSheet> createState() => _HealthPreviewSheetState();
}

class _HealthPreviewSheetState extends State<HealthPreviewSheet> {
  HealthSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await HealthPreviewProvider.instance.getTodaySummary();
    if (mounted) {
      setState(() {
        _summary = s;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _summary == null
                ? const Text('Health not available or not authorized.')
                : _buildContent(context, _summary!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, HealthSummary s) {
    final m = s.metrics;
    final showValues = s.visibility.canShowValuesInChat;
    final badges = <Widget>[];
    if (m.steps != null) {
      badges.add(_Badge(showValues ? 'Steps: ${m.steps}' : 'Steps: trend', Colors.blue));
    }
    if (m.exerciseMinutes != null) {
      badges.add(_Badge(showValues ? 'Exercise: ${m.exerciseMinutes}m' : 'Exercise: trend', Colors.green));
    }
    if (m.sleep?.totalMinutes != null) {
      badges.add(_Badge(showValues ? 'Sleep: ${m.sleep!.totalMinutes}m' : 'Sleep: trend', Colors.purple));
    }
    if (m.restingHrBpm != null) {
      badges.add(_Badge(showValues ? 'RHR: ${m.restingHrBpm!.round()} bpm' : 'RHR: trend', Colors.red));
    }
    if (m.hrvRmssdMs != null) {
      badges.add(_Badge(showValues ? 'HRV: ${m.hrvRmssdMs!.round()} ms' : 'HRV: trend', Colors.teal));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, color: Colors.pink),
            const SizedBox(width: 8),
            const Text('Today\'s Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Switch(
              value: showValues,
              onChanged: (_) {
                // Values are controlled by consent; show hint only
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Toggle numeric visibility in Settings > Health')),
                );
              },
            )
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: badges),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach Health'),
            onPressed: () {
              Navigator.of(context).pop('attach_health');
            },
          ),
        )
      ],
    );
  }
}


