// lib/ui/subscription/lumara_subscription_status.dart
// Widget displaying LUMARA subscription status and rate limits

import 'package:flutter/material.dart';
import 'package:my_app/services/subscription_service.dart';

class LumaraSubscriptionStatus extends StatefulWidget {
  final bool compact;

  const LumaraSubscriptionStatus({
    Key? key,
    this.compact = false,
  }) : super(key: key);

  @override
  State<LumaraSubscriptionStatus> createState() => _LumaraSubscriptionStatusState();
}

class _LumaraSubscriptionStatusState extends State<LumaraSubscriptionStatus> {
  SubscriptionTier? _tier;
  SubscriptionFeatures? _features;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();
      final features = await SubscriptionService.instance.getFeatures();

      if (mounted) {
        setState(() {
          _tier = tier;
          _features = features;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('LumaraSubscriptionStatus: Error loading status: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_tier == null || _features == null) {
      return const SizedBox.shrink();
    }

    if (widget.compact) {
      return _buildCompactView();
    } else {
      return _buildFullView();
    }
  }

  Widget _buildCompactView() {
    final isThrottled = _features!.lumaraThrottled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isThrottled ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isThrottled ? Colors.orange.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isThrottled ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 16,
            color: isThrottled ? Colors.orange.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            _tier!.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isThrottled ? Colors.orange.shade900 : Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView() {
    final isThrottled = _features!.lumaraThrottled;
    final limit = _features!.dailyLumaraLimit;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isThrottled ? Icons.warning_amber_rounded : Icons.workspace_premium,
                  color: isThrottled ? Colors.orange : Colors.purple,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _features!.displayText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isThrottled)
                  TextButton(
                    onPressed: () => _showUpgradeDialog(),
                    child: const Text('Upgrade'),
                  ),
              ],
            ),
            if (isThrottled) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Free tier limitations:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildLimitationRow(Icons.chat_bubble_outline, '4 LUMARA requests per conversation'),
              _buildLimitationRow(Icons.speed, '3 requests per minute'),
              _buildLimitationRow(Icons.chat_bubble_outline, '10 chat messages per day'),
              _buildLimitationRow(Icons.history, 'Limited phase history access'),
            ] else ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Premium benefits:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildBenefitRow(Icons.all_inclusive, 'Unlimited LUMARA requests'),
              _buildBenefitRow(Icons.flash_on, 'No rate limiting'),
              _buildBenefitRow(Icons.history, 'Full phase history access'),
              _buildBenefitRow(Icons.priority_high, 'Priority support'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitationRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Get unlimited LUMARA requests, full phase history access, and priority support.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Monthly', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('\$30/month'),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _initiateUpgrade(BillingInterval.monthly);
                        },
                        child: const Text('Choose'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Annual', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('\$200/year'),
                      const Text('Save \$160!', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _initiateUpgrade(BillingInterval.annual);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Best Value'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateUpgrade(BillingInterval interval) async {
    try {
      final success = await SubscriptionService.instance.createStripeCheckoutSession(
        interval: interval,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening checkout for ${interval.displayName} subscription...'),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to initiate upgrade. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('LumaraSubscriptionStatus: Error initiating upgrade: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting upgrade: ${e.toString()}'),
          ),
        );
      }
    }
  }
}

