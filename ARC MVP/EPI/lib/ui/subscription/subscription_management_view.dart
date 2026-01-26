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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Free - Limited Access'),
        const SizedBox(height: 8),
        _buildBulletRow(Icons.chat_bubble_outline, '4 LUMARA requests per conversation'),
        _buildBulletRow(Icons.speed, '3 requests per minute'),
        _buildBulletRow(Icons.chat_bubble_outline, '10 chat messages per day'),
        _buildBulletRow(Icons.history, 'Limited phase history access'),
        const SizedBox(height: 8),
        _buildParagraph('Good for exploring. Not enough to build narrative intelligence.'),
        const SizedBox(height: 24),

        _buildSectionTitle('Premium'),
        const SizedBox(height: 8),
        _buildParagraph('Monthly: \$20/month\nFull access. Cancel anytime.\n\nAnnual: \$200/year\n\$16.67/month. Save \$40.'),
        const SizedBox(height: 16),

        // Toggle switch
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          width: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: _buildToggleOption(
                  label: 'Monthly\n\$20/mo',
                  interval: BillingInterval.monthly,
                  badge: 'Save \$40',
                ),
              ),
              Expanded(
                child: _buildToggleOption(
                  label: 'Annual\n\$200/yr',
                  interval: BillingInterval.annual,
                  badge: 'Save \$160',
                ),
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
                  price: '\$20',
                  period: '/month',
                  description: 'Full access. Cancel anytime.',
                )
              : _buildPriceCard(
                  price: '\$200',
                  period: '/year',
                  description: '\$16.67/month • Save \$40',
                  highlighted: true,
                ),
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('What you get'),
        const SizedBox(height: 8),
        _buildBulletRow(Icons.all_inclusive, 'Unlimited LUMARA reflections', isPositive: true),
        _buildBulletRow(Icons.history, 'Full phase detection and history', isPositive: true),
        _buildBulletRow(Icons.auto_awesome, 'Personalized phase visuals that evolve with your entries', isPositive: true),
        _buildBulletRow(Icons.memory, 'Complete narrative memory across all time', isPositive: true),
        _buildBulletRow(Icons.tune, 'Persona adaptation (4 modes)', isPositive: true),
        _buildBulletRow(Icons.hub, 'Knowledge graph visualization', isPositive: true),
        const SizedBox(height: 12),
        _buildParagraph(
          'By month 6, LUMARA connects patterns you can\'t see. By month 12, you have a developmental map no other AI can build.',
        ),
        const SizedBox(height: 8),
        _buildParagraph(
          'The annual commit makes sense because continuity matters - stopping/starting breaks the temporal thread.',
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
                  ? 'Continue with Annual (\$200/year)'
                  : 'Continue with Monthly (\$20/month)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 24),

        _buildFoundersCard(),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildBulletRow(IconData icon, String text, {bool isPositive = false}) {
    final color = isPositive ? Colors.green.shade700 : Colors.grey.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundersCard() {
    return Card(
      elevation: 1,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.stars, color: Colors.purple),
        title: const Text(
          'Founders Commit: \$1,500 (3 years)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Not a subscription. A partnership.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _buildParagraph(
            'Help shape the future of Narrative Intelligence. Limited to 150 members.',
          ),
          const SizedBox(height: 12),
          _buildParagraph(
            'Premium costs \$200/year and you can cancel anytime.\nFounders costs \$1,500 for 3 years and you help build this.',
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('What you get beyond Premium'),
          const SizedBox(height: 8),
          _buildBulletRow(Icons.schedule, 'Early access to new features (4-8 weeks, or +2 months if paid upfront)', isPositive: true),
          _buildBulletRow(Icons.people_alt, 'Monthly calls with the team - your requests get priority', isPositive: true),
          _buildBulletRow(Icons.lock, 'Private founding community (150 max)', isPositive: true),
          _buildBulletRow(Icons.price_change, 'Price locked at \$500/year for 3 years', isPositive: true),
          _buildBulletRow(Icons.verified, 'Permanent founding badge', isPositive: true),
          const SizedBox(height: 12),
          _buildSectionTitle('This is for'),
          const SizedBox(height: 8),
          _buildBulletRow(Icons.check_circle, 'Consistent journalers ready to commit 3 years', isPositive: true),
          _buildBulletRow(Icons.check_circle, 'People who want to shape where Narrative Intelligence goes', isPositive: true),
          _buildBulletRow(Icons.check_circle, 'Those who see the long game', isPositive: true),
          const SizedBox(height: 12),
          _buildSectionTitle('Not for'),
          const SizedBox(height: 8),
          _buildBulletRow(Icons.cancel, '"Trying it out" (use Free)'),
          _buildBulletRow(Icons.cancel, 'Looking for a discount (Premium is cheaper)'),
          const SizedBox(height: 12),
          _buildParagraph('Limited to 150 members. When full, closes forever.'),
          const SizedBox(height: 8),
          _buildParagraph(
            'By Year 3 you\'ll have 36+ months of narrative memory the system learned from your story. That\'s irreplaceable.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => widget.onIntervalSelected(BillingInterval.foundersUpfront),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue with Founders Commit'),
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.black : Colors.grey.shade700,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
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
              const Text('Upgrade to Premium or Founders for full access'),
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
                        'Choose Your Plan',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Premium is the standard subscription. Founders is a 3-year commitment for builders.',
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

  String _checkoutLabel(BillingInterval interval) {
    switch (interval) {
      case BillingInterval.monthly:
        return 'Premium Monthly';
      case BillingInterval.annual:
        return 'Premium Annual';
      case BillingInterval.foundersUpfront:
        return 'Founders Commit';
    }
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

      // ALWAYS check authentication status - be very explicit
      final isSignedIn = authService.isSignedIn;
      final isAnonymous = authService.isAnonymous;
      final hasRealAccount = authService.hasRealAccount;
      final currentUser = authService.currentUser;
      
      debugPrint('SubscriptionManagement: 🔍 DETAILED AUTH CHECK:');
      debugPrint('  isSignedIn: $isSignedIn');
      debugPrint('  isAnonymous: $isAnonymous');
      debugPrint('  hasRealAccount: $hasRealAccount');
      debugPrint('  currentUser: ${currentUser?.uid ?? "NULL"}');
      debugPrint('  email: ${currentUser?.email ?? "NULL"}');
      debugPrint('  providerData: ${currentUser?.providerData.map((p) => p.providerId).toList() ?? []}');
      
      // If not signed in with a real account, navigate to sign-in screen first
      // Check multiple conditions to be absolutely sure
      if (!hasRealAccount || isAnonymous || currentUser == null || currentUser.isAnonymous) {
        debugPrint('SubscriptionManagement: ⚠️ User needs to sign in first - navigating to sign-in screen');
        debugPrint('  Reason: hasRealAccount=$hasRealAccount, isAnonymous=$isAnonymous, currentUser=${currentUser != null}');
        
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
                  'To continue, you need to sign in first.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'After signing in, you\'ll be automatically redirected to complete your checkout.',
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
                  content: Text('Please sign in to continue.'),
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

      // Final verification before proceeding - be VERY strict
      final finalAuth = FirebaseAuthService.instance;
      final finalUser = finalAuth.currentUser;
      
      debugPrint('SubscriptionManagement: 🔍 FINAL AUTH CHECK:');
      debugPrint('  finalUser: ${finalUser?.uid ?? "NULL"}');
      debugPrint('  isAnonymous: ${finalUser?.isAnonymous ?? true}');
      debugPrint('  email: ${finalUser?.email ?? "NULL"}');
      debugPrint('  hasRealAccount: ${finalAuth.hasRealAccount}');
      
      if (finalUser == null) {
        debugPrint('SubscriptionManagement: ❌ Final auth check failed - user is NULL');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to continue. Tap to sign in.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }
        throw Exception('Authentication required. Please sign in with Google.');
      }
      
      if (finalUser.isAnonymous) {
        debugPrint('SubscriptionManagement: ❌ Final auth check failed - user is ANONYMOUS');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in with Google to continue. Anonymous accounts cannot subscribe.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }
        throw Exception('Authentication required. Please sign in with Google.');
      }
      
      if (!finalAuth.hasRealAccount) {
        debugPrint('SubscriptionManagement: ❌ Final auth check failed - hasRealAccount is FALSE');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in with Google to continue.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
              content: Text('Opening checkout for ${_checkoutLabel(interval)}...'),
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


