// lib/lumara/agents/widgets/agent_tip_banner.dart
//
// Shows one agent tip occasionally (every ~2h) on agent screens. Dismissible.

import 'package:flutter/material.dart';
import 'package:my_app/lumara/agents/agent_tips.dart';
import 'package:my_app/shared/app_colors.dart';

/// Banner that shows a single tip from [getNextAgentTip], or nothing if too soon.
/// Place at top of agent screen body. When dismissed, hides until next interval.
class AgentTipBanner extends StatefulWidget {
  const AgentTipBanner({super.key});

  @override
  State<AgentTipBanner> createState() => _AgentTipBannerState();
}

class _AgentTipBannerState extends State<AgentTipBanner> {
  AgentTip? _tip;
  bool _loading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadTip();
  }

  Future<void> _loadTip() async {
    final tip = await getNextAgentTip();
    if (mounted) {
      setState(() {
        _tip = tip;
        _loading = false;
      });
    }
  }

  void _dismiss() {
    if (_tip != null) markAgentTipShown();
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _tip == null || _dismissed) {
      return const SizedBox.shrink();
    }
    return Material(
      color: kcSurfaceAltColor.withOpacity(0.95),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, size: 20, color: kcPrimaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _tip!.text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kcPrimaryTextColor,
                      height: 1.3,
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: _dismiss,
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                foregroundColor: kcSecondaryColor,
              ),
              tooltip: 'Dismiss tip',
            ),
          ],
        ),
      ),
    );
  }
}
