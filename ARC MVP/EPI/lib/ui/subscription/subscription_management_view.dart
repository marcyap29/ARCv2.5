// lib/ui/subscription/subscription_management_view.dart
// Full-screen subscription management view

import 'package:flutter/material.dart';
import 'package:my_app/services/subscription_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/ui/subscription/lumara_subscription_status.dart';

class PricingSelector extends StatefulWidget {
  final Function(BillingInterval) onIntervalSelected;

  const PricingSelector({required this.onIntervalSelected, super.key});

  @override
  State<PricingSelector> createState() => _PricingSelectorState();
}

class _PricingSelectorState extends State<PricingSelector> {
  BillingInterval _selectedInterval = BillingInterval.annual; // Default to better value

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle switch
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleOption(
                label: 'Monthly',
                interval: BillingInterval.monthly,
              ),
              _buildToggleOption(
                label: 'Annual',
                interval: BillingInterval.annual,
                badge: 'Save \$160',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Pricing display
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectedInterval == BillingInterval.monthly
              ? _buildPriceCard(
                  price: '\$30',
                  period: '/month',
                  description: 'Billed monthly',
                )
              : _buildPriceCard(
                  price: '\$200',
                  period: '/year',
                  description: 'Just \$16.67/month • Save \$160',
                  highlighted: true,
                ),
        ),

        const SizedBox(height: 24),

        // Subscribe button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onIntervalSelected(_selectedInterval),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: Text(
              _selectedInterval == BillingInterval.annual
                  ? 'Subscribe & Save \$160'
                  : 'Subscribe Monthly',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption({
    required String label,
    required BillingInterval interval,
    String? badge,
  }) {
    final isSelected = _selectedInterval == interval;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedInterval = interval);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.grey.shade600,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard({
    required String price,
    required String period,
    required String description,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(
          color: highlighted ? Theme.of(context).primaryColor : Colors.grey.shade300,
          width: highlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  period,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: highlighted ? Colors.green : Colors.grey.shade600,
              fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionManagementView extends StatefulWidget {
  const SubscriptionManagementView({Key? key}) : super(key: key);

  @override
  State<SubscriptionManagementView> createState() => _SubscriptionManagementViewState();
}

class _SubscriptionManagementViewState extends State<SubscriptionManagementView> {
  bool _loading = true;
  bool _upgradeLoading = false;
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
        // Upgrade section (if free) or Manage subscription (if premium)
        FutureBuilder<bool>(
          future: SubscriptionService.instance.hasPremiumAccess(),
          builder: (context, snapshot) {
            final isPremium = snapshot.data ?? false;

            if (!isPremium) {
              // Show pricing selector for free users
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Upgrade to Premium',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Get unlimited LUMARA requests and full phase history access',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _upgradeLoading
                          ? const CircularProgressIndicator()
                          : PricingSelector(
                              onIntervalSelected: _initiateUpgrade,
                            ),
                    ],
                  ),
                ),
              );
            }

            // Manage subscription button (if premium)
            return OutlinedButton.icon(
              onPressed: _openCustomerPortal,
              icon: const Icon(Icons.settings),
              label: const Text('Manage Subscription'),
              style: OutlinedButton.styleFrom(
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

  Future<void> _initiateUpgrade(BillingInterval interval) async {
    setState(() {
      _upgradeLoading = true;
    });

    try {
      // Check if user is properly authenticated first
      final authService = FirebaseAuthService.instance;

      debugPrint('SubscriptionManagement: AUTH STATUS CHECK:');
      debugPrint('  isSignedIn: ${authService.isSignedIn}');
      debugPrint('  isAnonymous: ${authService.isAnonymous}');
      debugPrint('  hasRealAccount: ${authService.hasRealAccount}');
      debugPrint('  currentUser: ${authService.currentUser?.email ?? authService.currentUser?.uid ?? "NULL"}');

      // Force Google sign-in for all subscription access (even if user thinks they're signed in)
      if (!authService.hasRealAccount) {
        // Need to sign in with Google for subscription access
        debugPrint('SubscriptionManagement: User needs real account, prompting for Google sign-in');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signing in with Google for subscription access...'),
              backgroundColor: Colors.blue,
            ),
          );
        }

        final userCredential = await authService.signInWithGoogle();

        if (userCredential == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google sign-in is required for subscription access'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        debugPrint('SubscriptionManagement: User successfully signed in with Google');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed in! Opening subscription checkout...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

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
      debugPrint('SubscriptionManagementView: Error initiating upgrade: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting upgrade process: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _upgradeLoading = false;
        });
      }
    }
  }

  Future<void> _openCustomerPortal() async {
    try {
      final success = await SubscriptionService.instance.openCustomerPortal();

      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open subscription management portal'),
          ),
        );
      }
    } catch (e) {
      debugPrint('SubscriptionManagementView: Error opening portal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening subscription management'),
          ),
        );
      }
    }
  }

}


