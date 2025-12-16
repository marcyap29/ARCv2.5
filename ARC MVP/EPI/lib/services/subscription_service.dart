// Subscription service for managing user subscription tiers and access control
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_auth_service.dart';

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
      // Force refresh ID token before calling Functions
      final authService = FirebaseAuthService.instance;
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.getIdToken(true); // Force refresh
          debugPrint('SubscriptionService: 🔄 ID token refreshed before Function call');
        } catch (e) {
          debugPrint('SubscriptionService: ⚠️ Failed to refresh ID token: $e');
        }
      }

      final functions = FirebaseFunctions.instance;
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


  /// Initialize Stripe checkout for premium subscription
  Future<String?> createStripeCheckoutSession() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createCheckoutSession');

      final result = await callable.call({
        'priceId': 'price_premium_monthly', // This will be configured in Stripe
        'successUrl': 'https://your-app-url.com/success',
        'cancelUrl': 'https://your-app-url.com/cancel',
      });

      final data = result.data as Map<String, dynamic>;
      return data['checkoutUrl'] as String?;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to create checkout session: $e');
      return null;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('cancelSubscription');

      await callable.call();

      // Clear cache to force refresh
      clearCache();

      return true;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to cancel subscription: $e');
      return false;
    }
  }

  /// Get subscription status details
  Future<Map<String, dynamic>?> getSubscriptionDetails() async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getSubscriptionDetails');

      final result = await callable.call();
      return result.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('SubscriptionService: Failed to get subscription details: $e');
      return null;
    }
  }
}