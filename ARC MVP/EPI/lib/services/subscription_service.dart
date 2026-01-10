// Subscription service for managing user subscription tiers and access control
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_auth_service.dart';
import 'firebase_service.dart';

// Enum for billing interval
enum BillingInterval {
  monthly,
  annual;

  String get displayName {
    switch (this) {
      case BillingInterval.monthly:
        return 'Monthly';
      case BillingInterval.annual:
        return 'Annual';
    }
  }

  String get apiValue {
    switch (this) {
      case BillingInterval.monthly:
        return 'monthly';
      case BillingInterval.annual:
        return 'annual';
    }
  }
}

enum SubscriptionTier {
  free,
  premium;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  bool get hasFullAccess => this == SubscriptionTier.premium;
  bool get isThrottled => this == SubscriptionTier.free;
}

class SubscriptionFeatures {
  final bool lumaraThrottled;
  final bool phaseHistoryRestricted;
  final int dailyLumaraLimit;
  final String displayText;

  const SubscriptionFeatures({
    required this.lumaraThrottled,
    required this.phaseHistoryRestricted,
    required this.dailyLumaraLimit,
    required this.displayText,
  });

  static const free = SubscriptionFeatures(
    lumaraThrottled: true,
    phaseHistoryRestricted: true,
    dailyLumaraLimit: 50,
    displayText: 'Free - Limited Access',
  );

  static const premium = SubscriptionFeatures(
    lumaraThrottled: false,
    phaseHistoryRestricted: false,
    dailyLumaraLimit: -1, // Unlimited
    displayText: 'Premium - Full Access',
  );
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static SubscriptionService get instance => _instance;

  SubscriptionTier? _cachedTier;
  DateTime? _cacheExpiry;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Clear cached subscription data (call after authentication changes)
  void clearCache() {
    debugPrint('SubscriptionService: 🗑️ Clearing subscription cache');
    _cachedTier = null;
    _cacheExpiry = null;
  }

  /// Get current user's subscription tier
  Future<SubscriptionTier> getSubscriptionTier({bool forceRefresh = false}) async {
    // Check cache first (unless forcing refresh)
    if (!forceRefresh && _cachedTier != null && _cacheExpiry != null && DateTime.now().isBefore(_cacheExpiry!)) {
      debugPrint('SubscriptionService: Using cached tier: $_cachedTier');
      return _cachedTier!;
    }

    if (forceRefresh) {
      debugPrint('SubscriptionService: Force refresh requested - clearing cache');
      _cachedTier = null;
      _cacheExpiry = null;
    }

    try {
      // Check if user is signed in with detailed debugging
      final authService = FirebaseAuthService.instance;
      debugPrint('SubscriptionService: 📊 AUTH STATE CHECK:');
      debugPrint('  isSignedIn: ${authService.isSignedIn}');
      debugPrint('  hasRealAccount: ${authService.hasRealAccount}');
      debugPrint('  isAnonymous: ${authService.isAnonymous}');
      debugPrint('  currentUser: ${authService.currentUser?.email ?? authService.currentUser?.uid ?? "NULL"}');

      if (!authService.isSignedIn) {
        debugPrint('SubscriptionService: ❌ User not signed in, defaulting to free tier');
        return SubscriptionTier.free;
      }

      if (authService.isAnonymous) {
        debugPrint('SubscriptionService: ⚠️ User is anonymous, cannot access premium features');
        debugPrint('SubscriptionService: 💡 Sign in with Google for premium subscription access');
        return SubscriptionTier.free;
      }

      debugPrint('SubscriptionService: ✅ Real user authenticated, fetching subscription from Firebase...');

      // Try to get from Firebase Functions first
      final tier = await _fetchFromFirebase();

      // Cache the result
      _cachedTier = tier;
      _cacheExpiry = DateTime.now().add(_cacheTimeout);

      // Also cache in local storage for offline access
      await _cacheLocally(tier);

      return tier;
    } catch (e) {
      debugPrint('SubscriptionService: Error fetching subscription tier: $e');

      // Fallback to local cache
      final localTier = await _getFromLocalCache();
      if (localTier != null) {
        debugPrint('SubscriptionService: Using local cache');
        return localTier;
      }

      // Ultimate fallback
      debugPrint('SubscriptionService: Defaulting to free tier');
      return SubscriptionTier.free;
    }
  }

  /// Fetch subscription tier from Firebase Functions
  Future<SubscriptionTier> _fetchFromFirebase() async {
    try {
      // Ensure token is fresh (Firebase will auto-refresh if expired)
      final authService = FirebaseAuthService.instance;
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        try {
          // Don't force refresh - Firebase automatically refreshes expired tokens
          await currentUser.getIdToken(false);
          debugPrint('SubscriptionService: ✅ Token ready for Function call');
        } catch (e) {
          debugPrint('SubscriptionService: ⚠️ Token check failed: $e');
          // Continue anyway - Firebase Functions will handle auth errors
        }
      }

      final functions = FirebaseService.instance.getFunctions();
      final callable = functions.httpsCallable('getUserSubscription');

      debugPrint('SubscriptionService: 🔗 Calling Firebase Function: getUserSubscription');

      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;

      debugPrint('SubscriptionService: 📦 Firebase Function response: $data');

      final tierString = data['tier'] as String?;
      debugPrint('SubscriptionService: 🎯 Tier from Firebase: $tierString');

      switch (tierString?.toLowerCase()) {
        case 'premium':
          debugPrint('SubscriptionService: ✅ Premium tier confirmed!');
          return SubscriptionTier.premium;
        case 'free':
          debugPrint('SubscriptionService: ℹ️ Free tier confirmed');
          return SubscriptionTier.free;
        default:
          debugPrint('SubscriptionService: ⚠️ Unknown tier "$tierString", defaulting to free');
          return SubscriptionTier.free;
      }
    } catch (e) {
      debugPrint('SubscriptionService: ❌ Firebase Functions call failed: $e');
      debugPrint('SubscriptionService: 🔍 Error type: ${e.runtimeType}');
      if (e.toString().contains('UNAUTHENTICATED')) {
        debugPrint('SubscriptionService: 🚫 Authentication error - user may need to sign in again');
      }
      rethrow;
    }
  }

  /// Cache subscription tier locally
  Future<void> _cacheLocally(SubscriptionTier tier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_tier', tier.name);
      await prefs.setInt('subscription_cache_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('SubscriptionService: Failed to cache locally: $e');
    }
  }

  /// Get subscription tier from local cache
  Future<SubscriptionTier?> _getFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tierString = prefs.getString('subscription_tier');
      final cacheTime = prefs.getInt('subscription_cache_time');

      if (tierString == null || cacheTime == null) {
        return null;
      }

      // Check if cache is expired (max 24 hours for offline fallback)
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTime);
      if (DateTime.now().difference(cacheDate).inHours > 24) {
        return null;
      }

      return SubscriptionTier.values.firstWhere(
        (tier) => tier.name == tierString,
        orElse: () => SubscriptionTier.free,
      );
    } catch (e) {
      debugPrint('SubscriptionService: Failed to get from local cache: $e');
      return null;
    }
  }

  /// Get subscription features for current tier
  Future<SubscriptionFeatures> getFeatures() async {
    final tier = await getSubscriptionTier();
    switch (tier) {
      case SubscriptionTier.free:
        return SubscriptionFeatures.free;
      case SubscriptionTier.premium:
        return SubscriptionFeatures.premium;
    }
  }

  /// Check if user has premium access
  Future<bool> hasPremiumAccess() async {
    final tier = await getSubscriptionTier();
    return tier == SubscriptionTier.premium;
  }


  /// Initialize Stripe checkout for premium subscription with URL launcher
  Future<bool> createStripeCheckoutSession({
    BillingInterval interval = BillingInterval.monthly,
  }) async {
    try {
      // Check authentication first
      final authService = FirebaseAuthService.instance;
      debugPrint('SubscriptionService: 🔐 AUTH CHECK for checkout:');
      debugPrint('  isSignedIn: ${authService.isSignedIn}');
      debugPrint('  hasRealAccount: ${authService.hasRealAccount}');
      debugPrint('  isAnonymous: ${authService.isAnonymous}');

      if (!authService.isSignedIn) {
        debugPrint('SubscriptionService: ❌ User not signed in, cannot create checkout session');
        throw Exception('Please sign in to subscribe to premium');
      }

      if (authService.isAnonymous) {
        debugPrint('SubscriptionService: ❌ Anonymous user cannot subscribe');
        throw Exception('Please sign in with Google to subscribe to premium');
      }

      // Ensure token is fresh (Firebase will auto-refresh if expired)
      // Verify user is authenticated before proceeding
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('User authentication is required. Please sign in and try again.');
      }
      
      if (currentUser.isAnonymous) {
        throw Exception('Anonymous users cannot subscribe. Please sign in with Google.');
      }
      
      debugPrint('SubscriptionService: ✅ User authenticated: ${currentUser.uid}');

      // Verify auth state one more time before making the call
      final finalAuthCheck = FirebaseAuthService.instance;
      if (!finalAuthCheck.hasRealAccount) {
        debugPrint('SubscriptionService: ❌ Final auth check failed - user still anonymous');
        throw Exception('Please sign in with Google to subscribe. Authentication is required.');
      }

      // Get fresh token right before the call
      final freshUser = finalAuthCheck.currentUser;
      if (freshUser == null) {
        throw Exception('User authentication is required. Please sign in and try again.');
      }
      
      // Verify user is not anonymous
      if (freshUser.isAnonymous) {
        throw Exception('Anonymous users cannot subscribe. Please sign in with Google.');
      }
      
      String? freshToken;
      try {
        freshToken = await freshUser.getIdToken(true); // Force refresh
        if (freshToken == null) {
          throw Exception('Could not obtain authentication token. Please sign in again.');
        }
        debugPrint('SubscriptionService: ✅ Fresh token obtained (${freshToken.substring(0, freshToken.length > 20 ? 20 : freshToken.length)}...)');
      } catch (e) {
        debugPrint('SubscriptionService: ⚠️ Could not get fresh token: $e');
        throw Exception('Authentication token is required. Please sign in again.');
      }
      
      // CRITICAL: Ensure Functions instance uses the same Firebase app as Auth
      // This ensures the callable has access to the authenticated user context
      final authApp = FirebaseAuthService.instance.auth.app;
      final functionsRegion = const String.fromEnvironment(
        'FIREBASE_FUNCTIONS_REGION',
        defaultValue: 'us-central1',
      );
      final functions = FirebaseFunctions.instanceFor(app: authApp, region: functionsRegion);
      
      debugPrint('SubscriptionService: 🔗 Functions instance created with auth app: ${authApp.name}');

      // CRITICAL: Create callable AFTER ensuring auth state is ready
      // Firebase callables automatically include auth token from current user
      // The Functions instance is now using the same app as Auth, so it has access to the user
      final callable = functions.httpsCallable('createCheckoutSession');

      debugPrint('SubscriptionService: 💳 Creating Stripe checkout session (${interval.apiValue})');
      debugPrint('SubscriptionService: 🔐 Auth context:');
      debugPrint('  User ID: ${freshUser.uid}');
      debugPrint('  Email: ${freshUser.email ?? "No email"}');
      debugPrint('  isAnonymous: ${freshUser.isAnonymous}');
      debugPrint('  Has token: true'); // freshToken is guaranteed non-null after the check above
      final preview = freshToken.length > 30 ? freshToken.substring(0, 30) : freshToken;
      debugPrint('  Token preview: $preview...');

      // CRITICAL: Wait a moment to ensure auth state is fully propagated to Firebase
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verify auth state one final time right before the call
      final preCallAuth = FirebaseAuthService.instance;
      if (preCallAuth.currentUser == null || preCallAuth.currentUser!.isAnonymous) {
        debugPrint('SubscriptionService: ❌ PRE-CALL AUTH CHECK FAILED');
        debugPrint('  currentUser: ${preCallAuth.currentUser?.uid ?? "NULL"}');
        debugPrint('  isAnonymous: ${preCallAuth.currentUser?.isAnonymous ?? true}');
        throw Exception('Authentication required. Please sign in with Google and try again.');
      }

      // Make the callable request
      // Firebase automatically includes the auth token in the request headers
      debugPrint('SubscriptionService: 📞 Calling Firebase Function createCheckoutSession...');
      debugPrint('SubscriptionService: 🔐 Pre-call auth state:');
      debugPrint('  User ID: ${preCallAuth.currentUser!.uid}');
      debugPrint('  Email: ${preCallAuth.currentUser!.email ?? "No email"}');
      debugPrint('  isAnonymous: ${preCallAuth.currentUser!.isAnonymous}');
      
      final result = await callable.call({
        'billingInterval': interval.apiValue,
        'successUrl': 'arc://subscription/success',
        'cancelUrl': 'arc://subscription/cancel',
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('SubscriptionService: ❌ Function call timed out after 30 seconds');
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );
      
      debugPrint('SubscriptionService: ✅ Function call succeeded');

      final data = result.data as Map<String, dynamic>;
      final checkoutUrl = (data['url'] ?? data['checkoutUrl']) as String?;

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        debugPrint('SubscriptionService: 🚀 Launching checkout URL: $checkoutUrl');

        final uri = Uri.parse(checkoutUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Opens in browser
          );

          // Clear cache to force refresh after potential subscription change
          clearCache();

          return true;
        } else {
          debugPrint('SubscriptionService: ❌ Could not launch checkout URL');
          throw Exception('Could not launch checkout URL');
        }
      }

      debugPrint('SubscriptionService: ❌ No checkout URL received');
      return false;
    } catch (e) {
      debugPrint('SubscriptionService: ❌ Failed to create checkout session: $e');
      rethrow;
    }
  }

  /// Open Stripe Customer Portal for subscription management
  Future<bool> openCustomerPortal() async {
    try {
      final functions = FirebaseService.instance.getFunctions();
      final callable = functions.httpsCallable('createPortalSession');

      debugPrint('SubscriptionService: 🏢 Creating customer portal session');

      final result = await callable.call({
        'returnUrl': 'arc://settings',
      });

      final data = result.data as Map<String, dynamic>;
      final portalUrl = data['url'] as String?;

      if (portalUrl != null && portalUrl.isNotEmpty) {
        debugPrint('SubscriptionService: 🚀 Launching portal URL: $portalUrl');

        final uri = Uri.parse(portalUrl);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          // Clear cache to force refresh after potential subscription changes
          clearCache();

          return true;
        } else {
          debugPrint('SubscriptionService: ❌ Could not launch portal URL');
        }
      }

      debugPrint('SubscriptionService: ❌ No portal URL received');
      return false;
    } catch (e) {
      debugPrint('SubscriptionService: ❌ Failed to create portal session: $e');
      return false;
    }
  }

  /// Cancel subscription (deprecated - use Customer Portal instead)
  @deprecated
  Future<bool> cancelSubscription() async {
    debugPrint('SubscriptionService: ⚠️ cancelSubscription is deprecated, use openCustomerPortal() instead');
    return await openCustomerPortal();
  }

  /// Get subscription status details
  Future<Map<String, dynamic>?> getSubscriptionDetails() async {
    try {
      final functions = FirebaseService.instance.getFunctions();
      final callable = functions.httpsCallable('getSubscriptionDetails');

      final result = await callable.call();
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to get subscription details: $e');
      return null;
    }
  }
}
