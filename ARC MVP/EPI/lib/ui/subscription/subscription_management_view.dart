// lib/ui/subscription/subscription_management_view.dart
// Full-screen subscription management view

import 'package:flutter/material.dart';
import 'package:my_app/services/subscription_service.dart';
import 'package:my_app/ui/subscription/lumara_subscription_status.dart';

class SubscriptionManagementView extends StatefulWidget {
  const SubscriptionManagementView({Key? key}) : super(key: key);

  @override
  State<SubscriptionManagementView> createState() => _SubscriptionManagementViewState();
}

class _SubscriptionManagementViewState extends State<SubscriptionManagementView> {
  bool _loading = true;
  Map<String, dynamic>? _subscriptionDetails;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  Future<void> _loadSubscriptionDetails() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final details = await SubscriptionService.instance.getSubscriptionDetails();

      if (mounted) {
        setState(() {
          _subscriptionDetails = details;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('SubscriptionManagementView: Error loading details: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load subscription details';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSubscriptionDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current subscription status card
          const LumaraSubscriptionStatus(compact: false),

          const SizedBox(height: 24),

          // Usage statistics (if available)
          if (_subscriptionDetails != null) ...[
            _buildUsageCard(),
            const SizedBox(height: 24),
          ],

          // Billing information
          _buildBillingInfo(),

          const SizedBox(height: 24),

          // Actions
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildUsageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics),
                const SizedBox(width: 12),
                Text(
                  'Usage This Month',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildUsageRow(
              'LUMARA Requests',
              _subscriptionDetails?['usageStats']?['lumaraRequests']?.toString() ?? 'N/A',
              Icons.chat_bubble_outline,
            ),
            const SizedBox(height: 8),
            _buildUsageRow(
              'Phase History Access',
              _subscriptionDetails?['usageStats']?['phaseHistoryDays']?.toString() ?? 'N/A',
              Icons.history,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBillingInfo() {
    final hasBilling = _subscriptionDetails?['stripeSubscriptionId'] != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment),
                const SizedBox(width: 12),
                Text(
                  'Billing Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasBilling) ...[
              _buildInfoRow('Subscription ID', _subscriptionDetails!['stripeSubscriptionId']),
              const SizedBox(height: 8),
              if (_subscriptionDetails?['nextBillingDate'] != null)
                _buildInfoRow('Next Billing', _subscriptionDetails!['nextBillingDate']),
              const SizedBox(height: 8),
              _buildInfoRow('Status', _subscriptionDetails?['status'] ?? 'Active'),
            ] else ...[
              Text(
                'No active subscription',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              const Text('Upgrade to Premium for full access'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upgrade button (if free)
        FutureBuilder<bool>(
          future: SubscriptionService.instance.hasPremiumAccess(),
          builder: (context, snapshot) {
            final isPremium = snapshot.data ?? false;

            if (!isPremium) {
              return ElevatedButton.icon(
                onPressed: _initiateUpgrade,
                icon: const Icon(Icons.upgrade),
                label: const Text('Upgrade to Premium'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              );
            }

            // Cancel subscription button (if premium)
            return OutlinedButton.icon(
              onPressed: _showCancelDialog,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Subscription'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Refresh button
        OutlinedButton.icon(
          onPressed: () {
            SubscriptionService.instance.clearCache();
            _loadSubscriptionDetails();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Status'),
        ),
      ],
    );
  }

  Future<void> _initiateUpgrade() async {
    try {
      final checkoutUrl = await SubscriptionService.instance.createStripeCheckoutSession();

      if (checkoutUrl != null && mounted) {
        // In a real app, you would open the checkout URL in a webview or browser
        // For now, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening checkout: $checkoutUrl'),
            duration: const Duration(seconds: 3),
          ),
        );

        // TODO: Open checkout URL in webview or browser
        // Example: await launchUrl(Uri.parse(checkoutUrl));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to initiate upgrade. Please try again.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('SubscriptionManagementView: Error initiating upgrade: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error starting upgrade process.'),
          ),
        );
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your Premium subscription? '
          'You will lose access to unlimited LUMARA requests and full phase history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Premium'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelSubscription();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSubscription() async {
    try {
      final success = await SubscriptionService.instance.cancelSubscription();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription cancelled successfully'),
            ),
          );
          _loadSubscriptionDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel subscription. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('SubscriptionManagementView: Error cancelling subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error cancelling subscription.'),
          ),
        );
      }
    }
  }
}


