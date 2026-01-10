// lib/ui/subscription/subscription_management_view.dart
// Full-screen subscription management view

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_app/services/subscription_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/ui/subscription/lumara_subscription_status.dart';
import 'package:my_app/ui/auth/sign_in_screen.dart';

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

      // Clear subscription cache to ensure fresh data
      debugPrint('SubscriptionManagementView: Clearing subscription cache for fresh data');
      SubscriptionService.instance.clearCache();

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
            // Force refresh if we have connection issues or if subscription state seems wrong
            if (snapshot.hasError) {
              debugPrint('SubscriptionManagementView: Error checking premium access: ${snapshot.error}');
            }

            final isPremium = snapshot.data ?? false;

            debugPrint('SubscriptionManagementView: 🔍 Premium access check result: $isPremium');
            debugPrint('SubscriptionManagementView: 🔍 Snapshot state: ${snapshot.connectionState}');
            debugPrint('SubscriptionManagementView: 🔍 Has error: ${snapshot.hasError}');

            if (!isPremium) {
              // Show pricing selector for free users
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                          ? const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            )
                          : PricingSelector(
                              onIntervalSelected: _initiateUpgrade,
                            ),
                      // Debug: Ensure button is visible
                      if (kDebugMode) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Debug: Premium check = false, showing pricing',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
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

      debugPrint('SubscriptionManagement: 🔐 AUTH STATUS CHECK:');
      debugPrint('  isSignedIn: ${authService.isSignedIn}');
      debugPrint('  isAnonymous: ${authService.isAnonymous}');
      debugPrint('  hasRealAccount: ${authService.hasRealAccount}');
      debugPrint('  currentUser: ${authService.currentUser?.email ?? authService.currentUser?.uid ?? "NULL"}');
      debugPrint('  selectedInterval: ${interval.displayName}');

      // Always clear subscription cache before authentication check
      debugPrint('SubscriptionManagement: 🔄 Clearing cache before proceeding');
      SubscriptionService.instance.clearCache();

      // If not signed in with a real account, navigate to sign-in screen first
      if (!authService.hasRealAccount) {
        debugPrint('SubscriptionManagement: User needs to sign in first - navigating to sign-in screen');
        
        // Show dialog explaining the process
        final shouldContinue = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.account_circle, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Expanded(child: Text('Sign In Required')),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To subscribe to Premium, you need to sign in first.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'After signing in, you\'ll be automatically redirected to complete your subscription.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.login),
                label: const Text('Go to Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          debugPrint('SubscriptionManagement: User cancelled');
          setState(() {
            _upgradeLoading = false;
          });
          return;
        }

        // Navigate to sign-in screen (push, not replacement, so we can return)
        if (mounted) {
          debugPrint('SubscriptionManagement: Navigating to sign-in screen...');
          // Use push with SignInScreen directly to pass returnOnSignIn parameter
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SignInScreen(returnOnSignIn: true),
            ),
          );
          
          // After returning from sign-in screen, check auth state
          debugPrint('SubscriptionManagement: Returned from sign-in screen');
          
          // Wait a moment for auth state to settle
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Check if sign-in was successful
          final updatedAuth = FirebaseAuthService.instance;
          debugPrint('SubscriptionManagement: Post-signin auth check:');
          debugPrint('  isSignedIn: ${updatedAuth.isSignedIn}');
          debugPrint('  hasRealAccount: ${updatedAuth.hasRealAccount}');
          debugPrint('  email: ${updatedAuth.currentUser?.email}');
          
          if (!updatedAuth.hasRealAccount) {
            debugPrint('SubscriptionManagement: Sign-in was not completed');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please sign in to subscribe to Premium.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            setState(() {
              _upgradeLoading = false;
            });
            return;
          }
          
          debugPrint('SubscriptionManagement: ✅ Sign-in successful! Verifying token...');
          
          // CRITICAL: Force refresh the auth token to ensure it's ready for Firebase callable
          try {
            final user = updatedAuth.currentUser;
            if (user != null) {
              // Force refresh token to ensure it's valid and fresh
              final token = await user.getIdToken(true);
              if (token != null) {
                debugPrint('SubscriptionManagement: ✅ Auth token refreshed successfully');
                debugPrint('  Token length: ${token.length}');
                debugPrint('  Token preview: ${token.substring(0, token.length > 30 ? 30 : token.length)}...');
              } else {
                debugPrint('SubscriptionManagement: ⚠️ Token refresh returned null');
              }
            }
          } catch (e) {
            debugPrint('SubscriptionManagement: ⚠️ Token refresh failed: $e');
            // Continue anyway - the subscription service will also try to refresh
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Signed in successfully! Opening checkout...'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          // Give Firebase a moment to fully propagate auth state and token
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Final verification before proceeding
      final finalAuth = FirebaseAuthService.instance;
      final finalUser = finalAuth.currentUser;
      
      if (finalUser == null || finalUser.isAnonymous) {
        debugPrint('SubscriptionManagement: ❌ Final auth check failed');
        throw Exception('Authentication required. Please sign in with Google.');
      }
      
      // One more token refresh right before the checkout call
      debugPrint('SubscriptionManagement: 🔑 Final token verification...');
      try {
        final finalToken = await finalUser.getIdToken(true);
        if (finalToken == null) {
          throw Exception('Could not obtain authentication token.');
        }
        debugPrint('SubscriptionManagement: ✅ Final token obtained (${finalToken.length} chars)');
      } catch (e) {
        debugPrint('SubscriptionManagement: ❌ Final token verification failed: $e');
        throw Exception('Authentication token expired. Please sign in again.');
      }

      // Now proceed with Stripe checkout
      debugPrint('SubscriptionManagement: 🚀 Creating Stripe checkout session...');
      
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


