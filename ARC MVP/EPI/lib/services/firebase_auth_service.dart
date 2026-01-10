// Firebase Auth service with Google Sign-In integration and account linking
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'subscription_service.dart';
import 'assemblyai_service.dart';

/// Error codes from the backend auth guard
class AuthErrorCodes {
  static const String unauthenticated = 'UNAUTHENTICATED';
  static const String anonymousTrialExpired = 'ANONYMOUS_TRIAL_EXPIRED';
}

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  static FirebaseAuthService get instance => _instance;

  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  StreamSubscription<User?>? _idTokenSubscription;

  FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase Auth not initialized. Call initialize() first.');
    }
    return _auth!;
  }

  /// Check if current user is anonymous
  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  /// Check if user has a real (non-anonymous) account
  bool get hasRealAccount => currentUser != null && !currentUser!.isAnonymous;

  /// Initialize Firebase Auth with proper Firebase app instance
  Future<void> initialize() async {
    try {
      debugPrint('🔐 FirebaseAuthService: Starting initialization...');
      
      // Ensure Firebase is ready first
      final firebaseService = FirebaseService.instance;
      await firebaseService.ensureReady();

      // Get Firebase Auth instance from the initialized app
      _auth = firebaseService.getAuth();
      debugPrint('🔐 FirebaseAuthService: Auth instance obtained');

      // Initialize Google Sign-In (7.x API - singleton pattern)
      _googleSignIn = GoogleSignIn.instance;
      
      // Initialize with configuration (required in 7.x)
      // Note: scopes are passed to authenticate(), not initialize()
      await _googleSignIn!.initialize(
        // Configure for web platform
        clientId: kIsWeb ? const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID') : null,
      );
      debugPrint('🔐 FirebaseAuthService: Google Sign-In configured');

      // Check current auth state with detailed debugging
      final currentUser = _auth!.currentUser;
      debugPrint('🔐 FirebaseAuthService: Current user before check: ${currentUser?.uid ?? "NULL"}');

      if (currentUser != null) {
        debugPrint('🔐 FirebaseAuthService: 📊 USER AUTH STATE:');
        debugPrint('  UID: ${currentUser.uid}');
        debugPrint('  Email: ${currentUser.email ?? "No email"}');
        debugPrint('  isAnonymous: ${currentUser.isAnonymous}');
        debugPrint('  emailVerified: ${currentUser.emailVerified}');
        debugPrint('  providerData: ${currentUser.providerData.map((p) => p.providerId).toList()}');

        // If user is anonymous but we want real authentication for premium features
        if (currentUser.isAnonymous) {
          debugPrint('🔐 FirebaseAuthService: ⚠️ USER IS ANONYMOUS - Premium features unavailable');
          debugPrint('🔐 FirebaseAuthService: 💡 Use Google Sign-In for full access');
        } else {
          debugPrint('🔐 FirebaseAuthService: ✅ Real authenticated user detected');
          // Force refresh auth state for auto-restored sessions
          await _refreshAuthState(currentUser);
        }
      } else {
        debugPrint('🔐 FirebaseAuthService: ⚠️ No user signed in');
        debugPrint('🔐 FirebaseAuthService: 💡 Anonymous sign-in disabled - use Google Sign-In for premium features');
        debugPrint('🔐 FirebaseAuthService: 💡 Some features may be limited without authentication');

        // REMOVED: Automatic anonymous sign-in for better premium account handling
        // Users should explicitly sign in with Google for premium features
      }

      // Set up automatic token refresh listener
      _setupTokenRefreshListener();

      debugPrint('🔐 FirebaseAuthService: ✅ Initialized successfully');

      // Show detailed auth state after initialization
      debugAuthState();
    } catch (e, stackTrace) {
      debugPrint('🔐 FirebaseAuthService: ❌ Failed to initialize: $e');
      debugPrint('🔐 FirebaseAuthService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Current authenticated user
  User? get currentUser => _auth?.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? const Stream.empty();

  /// Check if Google Sign-In is properly configured
  bool get isGoogleSignInConfigured {
    // Google Sign-In requires CLIENT_ID in GoogleService-Info.plist
    // If not configured, _googleSignIn will fail
    return _googleSignIn != null;
  }

  /// Sign in with Google
  /// If user is currently anonymous, this will link the accounts
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (_googleSignIn == null) {
        throw Exception('Google Sign-In not initialized. Please configure OAuth in Firebase Console.');
      }

      debugPrint('FirebaseAuthService: Starting Google Sign-In...');

      // Trigger the authentication flow (7.x API uses authenticate() with scopeHint)
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn!.authenticate(
          scopeHint: ['email', 'profile'],
        );
      } catch (e) {
        debugPrint('FirebaseAuthService: Google Sign-In trigger failed: $e');
        // Check for common configuration errors
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('client id') || 
            errorString.contains('clientid') ||
            errorString.contains('configuration') ||
            errorString.contains('missing')) {
          throw Exception('Google Sign-In is not configured. Please use Email sign-in instead, or configure OAuth in Firebase Console.');
        }
        if (errorString.contains('canceled') || errorString.contains('cancelled')) {
          return null; // User cancelled, not an error
        }
        throw Exception('Google Sign-In failed. Please try Email sign-in instead.');
      }

      // In 7.x, authenticate() throws on cancellation, doesn't return null
      // If we get here, authentication succeeded

      debugPrint('FirebaseAuthService: Google user signed in: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens. Please try Email sign-in instead.');
      }

      // Get access token via authorization client (7.x API)
      String? accessToken;
      try {
        final authorization = await googleUser.authorizationClient.authorizationForScopes(
          ['email', 'profile'],
        );
        if (authorization != null) {
          accessToken = authorization.accessToken;
        }
      } catch (e) {
        debugPrint('FirebaseAuthService: Could not get access token: $e');
      }
      
      // If authorizationForScopes returned null, try authorizeScopes (requires user interaction)
      if (accessToken == null) {
        try {
          final authorization = await googleUser.authorizationClient.authorizeScopes(
            ['email', 'profile'],
          );
          accessToken = authorization.accessToken;
        } catch (e2) {
          debugPrint('FirebaseAuthService: Could not get access token via authorizeScopes: $e2');
        }
      }

      if (accessToken == null) {
        throw Exception('Failed to get Google access token. Please try Email sign-in instead.');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      // If currently anonymous, link the accounts to preserve data
      if (isAnonymous) {
        return await linkAnonymousWithCredential(credential);
      }

      // Otherwise, sign in normally
      final UserCredential userCredential = await auth.signInWithCredential(credential);

      debugPrint('FirebaseAuthService: Successfully signed in to Firebase: ${userCredential.user?.email}');

      // CRITICAL: Reload user to ensure all claims and tokens are fresh
      if (userCredential.user != null) {
        try {
          await userCredential.user!.reload();
          debugPrint('FirebaseAuthService: ✅ User reloaded successfully');
        } catch (e) {
          debugPrint('FirebaseAuthService: ⚠️ User reload failed (non-critical): $e');
        }
      }

      // Force refresh the auth token to ensure all services have the new user
      await _refreshAuthState(userCredential.user);

      // Wait a moment for auth state to fully propagate
      await Future.delayed(const Duration(milliseconds: 300));

      return userCredential;

    } on Exception {
      rethrow;
    } catch (e) {
      debugPrint('FirebaseAuthService: Google Sign-In failed unexpectedly: $e');
      throw Exception('Google Sign-In is not available. Please use Email sign-in instead.');
    }
  }

  /// Link anonymous account with a credential (Google, Email, etc.)
  /// This preserves all user data from the anonymous session
  Future<UserCredential?> linkAnonymousWithCredential(AuthCredential credential) async {
    try {
      final user = currentUser;
      if (user == null || !user.isAnonymous) {
        debugPrint('FirebaseAuthService: Cannot link - no anonymous user');
        return null;
      }

      debugPrint('FirebaseAuthService: Linking anonymous account ${user.uid} with credential...');

      final UserCredential userCredential = await user.linkWithCredential(credential);

      debugPrint('FirebaseAuthService: ✅ Successfully linked anonymous account to ${userCredential.user?.email}');
      debugPrint('FirebaseAuthService: User UID preserved: ${userCredential.user?.uid}');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // The credential is already associated with a different account
        // Sign in with the existing account instead
        debugPrint('FirebaseAuthService: Credential already in use, signing in to existing account');
        return await auth.signInWithCredential(credential);
      }
      debugPrint('FirebaseAuthService: Link failed: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('FirebaseAuthService: Link failed: $e');
      rethrow;
    }
  }

  /// Upgrade anonymous user to email/password account
  Future<UserCredential?> linkAnonymousWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = currentUser;
      if (user == null || !user.isAnonymous) {
        debugPrint('FirebaseAuthService: Cannot link - no anonymous user');
        return null;
      }

      debugPrint('FirebaseAuthService: Linking anonymous account with email: $email');

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      final UserCredential userCredential = await user.linkWithCredential(credential);

      debugPrint('FirebaseAuthService: ✅ Successfully linked anonymous account to email');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        debugPrint('FirebaseAuthService: Email already in use');
        // User should sign in with existing account instead
      }
      debugPrint('FirebaseAuthService: Email link failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('FirebaseAuthService: Signing in with email: $email');
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      debugPrint('FirebaseAuthService: Email sign-in successful');
      return userCredential;
    } catch (e) {
      debugPrint('FirebaseAuthService: Email sign-in failed: $e');
      rethrow;
    }
  }

  /// Create account with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('FirebaseAuthService: Creating account for: $email');
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      debugPrint('FirebaseAuthService: Account creation successful');
      return userCredential;
    } catch (e) {
      debugPrint('FirebaseAuthService: Account creation failed: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      final user = currentUser;
      debugPrint('FirebaseAuthService: 🚪 Signing out...');
      debugPrint('  Current user: ${user?.email ?? user?.uid ?? "NULL"}');
      debugPrint('  Was anonymous: ${user?.isAnonymous ?? false}');

      // Sign out from Google if signed in
      if (_googleSignIn != null) {
        debugPrint('FirebaseAuthService: 🔄 Signing out from Google...');
        await _googleSignIn!.signOut();
      }

      // Sign out from Firebase
      debugPrint('FirebaseAuthService: 🔄 Signing out from Firebase...');
      await auth.signOut();

      // Clear subscription cache to ensure fresh data on next login
      debugPrint('FirebaseAuthService: 🧹 Clearing subscription cache...');
      SubscriptionService.instance.clearCache();

      // Clear AssemblyAI cache
      AssemblyAIService.instance.clearCache();

      debugPrint('FirebaseAuthService: ✅ Sign out successful - use Google Sign-In for premium features');
    } catch (e) {
      debugPrint('FirebaseAuthService: ❌ Sign out failed: $e');
      rethrow;
    }
  }

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Get current user ID token (for Firebase Functions auth)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = currentUser;
      if (user == null) return null;

      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('FirebaseAuthService: Failed to get ID token: $e');
      return null;
    }
  }

  /// Get user display name
  String? get userDisplayName => currentUser?.displayName;

  /// Get user email
  String? get userEmail => currentUser?.email;

  /// Refresh auth state after sign-in to ensure all services have updated user info
  Future<void> _refreshAuthState(User? user) async {
    if (user == null) return;

    try {
      debugPrint('🔄 FirebaseAuthService: Refreshing auth state for user: ${user.email}');

      // Force refresh the ID token
      await user.getIdToken(true);
      debugPrint('✅ FirebaseAuthService: Auth token refreshed successfully');

      // Clear any cached subscription data so it re-fetches with new auth
      try {
        // Import is done at top of file, safely call the method
        final subscriptionService = SubscriptionService.instance;
        subscriptionService.clearCache();
        debugPrint('🗑️ FirebaseAuthService: Cleared subscription cache');
      } catch (e) {
        debugPrint('⚠️ FirebaseAuthService: Could not clear subscription cache: $e');
      }

      // Clear AssemblyAI cache to remove old user tokens
      try {
        AssemblyAIService().clearCache();
        debugPrint('🗑️ FirebaseAuthService: Cleared AssemblyAI cache');
      } catch (e) {
        debugPrint('⚠️ FirebaseAuthService: Could not clear AssemblyAI cache: $e');
      }

    } catch (e) {
      debugPrint('❌ FirebaseAuthService: Failed to refresh auth state: $e');
    }
  }

  /// Get user photo URL
  String? get userPhotoURL => currentUser?.photoURL;

  /// Force check current authentication state and print detailed debug info
  void debugAuthState() {
    final user = currentUser;
    debugPrint('🔍 FIREBASE AUTH DEBUG STATE:');
    debugPrint('================================');
    if (user != null) {
      debugPrint('✅ User is signed in');
      debugPrint('  UID: ${user.uid}');
      debugPrint('  Email: ${user.email ?? "No email"}');
      debugPrint('  Display Name: ${user.displayName ?? "No display name"}');
      debugPrint('  isAnonymous: ${user.isAnonymous}');
      debugPrint('  emailVerified: ${user.emailVerified}');
      debugPrint('  Provider Data: ${user.providerData.map((p) => '${p.providerId}:${p.email}').toList()}');
      debugPrint('  isSignedIn: $isSignedIn');
      debugPrint('  hasRealAccount: $hasRealAccount');

      if (user.isAnonymous) {
        debugPrint('⚠️ PROBLEM: User is anonymous - premium features unavailable');
        debugPrint('💡 SOLUTION: Use Google Sign-In for premium access');
      } else {
        debugPrint('✅ Real authenticated user - premium features should work');
      }
    } else {
      debugPrint('❌ No user signed in');
      debugPrint('💡 SOLUTION: Sign in with Google for premium features');
    }
    debugPrint('================================');
  }

  /// Force sign out completely and clear all cached data
  Future<void> forceSignOutAndClear() async {
    try {
      debugPrint('🧹 FORCE SIGN OUT: Starting complete cleanup...');

      await signOut();

      // Clear subscription cache
      SubscriptionService.instance.clearCache();

      // Clear AssemblyAI cache
      AssemblyAIService().clearCache();

      debugPrint('🧹 FORCE SIGN OUT: Complete cleanup finished');
      debugPrint('💡 Now sign in with Google for premium access');

    } catch (e) {
      debugPrint('❌ FORCE SIGN OUT failed: $e');
    }
  }

  /// Set up automatic token refresh listener
  /// This ensures tokens are automatically refreshed when they expire
  void _setupTokenRefreshListener() {
    if (_auth == null) return;

    // Cancel existing subscription if any
    _idTokenSubscription?.cancel();

    // Listen to ID token changes (fires when token is refreshed)
    _idTokenSubscription = _auth!.idTokenChanges().listen(
      (User? user) {
        if (user != null && !user.isAnonymous) {
          debugPrint('🔄 FirebaseAuthService: ID token changed - auto-refreshing for user: ${user.email}');
          // Token was automatically refreshed by Firebase
          // No need to force refresh - Firebase handles this automatically
        }
      },
      onError: (error) {
        debugPrint('⚠️ FirebaseAuthService: Token refresh listener error: $error');
      },
    );

    debugPrint('✅ FirebaseAuthService: Automatic token refresh listener set up');
  }

  /// Refresh authentication token (called on app resume or when needed)
  /// This ensures tokens are fresh for Firebase Functions calls
  Future<void> refreshTokenIfNeeded() async {
    try {
      final user = currentUser;
      if (user == null || user.isAnonymous) return;

      // Get token without forcing refresh - Firebase will auto-refresh if expired
      // This is more efficient than forcing refresh every time
      await user.getIdToken(false);
      debugPrint('✅ FirebaseAuthService: Token refreshed (if needed)');
    } catch (e) {
      debugPrint('⚠️ FirebaseAuthService: Token refresh failed: $e');
      // If token refresh fails, try forcing a refresh
      try {
        final user = currentUser;
        if (user != null && !user.isAnonymous) {
          await user.getIdToken(true);
          debugPrint('✅ FirebaseAuthService: Token force-refreshed successfully');
        }
      } catch (forceError) {
        debugPrint('❌ FirebaseAuthService: Force token refresh also failed: $forceError');
      }
    }
  }

  /// Dispose of resources
  void dispose() {
    _idTokenSubscription?.cancel();
    _idTokenSubscription = null;
  }
}
