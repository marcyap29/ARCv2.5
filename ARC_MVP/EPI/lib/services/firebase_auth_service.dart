// Firebase Auth service with Google Sign-In, Apple Sign-In, and account linking
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' show
    AppleIDAuthorizationScopes,
    AuthorizationErrorCode,
    SignInWithApple,
    SignInWithAppleAuthorizationException,
    SignInWithAppleException,
    generateNonce;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';
import 'subscription_service.dart';
import 'revenuecat_service.dart';
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
      if (kDebugMode) debugPrint('🔐 FirebaseAuthService: Starting initialization...');
      
      // Ensure Firebase is ready first
      final firebaseService = FirebaseService.instance;
      await firebaseService.ensureReady();

      // Get Firebase Auth instance from the initialized app
      _auth = firebaseService.getAuth();
      if (kDebugMode) debugPrint('🔐 FirebaseAuthService: Auth instance obtained');

      // Initialize Google Sign-In (7.x API - singleton pattern)
      _googleSignIn = GoogleSignIn.instance;
      
      // Initialize with configuration (required in 7.x)
      // Note: scopes are passed to authenticate(), not initialize()
      await _googleSignIn!.initialize(
        // Configure for web platform
        clientId: kIsWeb ? const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID') : null,
      );
      if (kDebugMode) debugPrint('🔐 FirebaseAuthService: Google Sign-In configured');

      // Check current auth state with detailed debugging
      final currentUser = _auth!.currentUser;
      if (kDebugMode) debugPrint('🔐 FirebaseAuthService: Current user before check: ${currentUser?.uid ?? "NULL"}');

      if (currentUser != null) {
        if (kDebugMode) debugPrint('🔐 FirebaseAuthService: 📊 USER AUTH STATE:');
        if (kDebugMode) debugPrint('  UID: ${currentUser.uid}');
        if (kDebugMode) debugPrint('  Email: ${currentUser.email ?? "No email"}');
        if (kDebugMode) debugPrint('  isAnonymous: ${currentUser.isAnonymous}');
        if (kDebugMode) debugPrint('  emailVerified: ${currentUser.emailVerified}');
        if (kDebugMode) debugPrint('  providerData: ${currentUser.providerData.map((p) => p.providerId).toList()}');

        // If user is anonymous but we want real authentication for premium features
        if (currentUser.isAnonymous) {
          if (kDebugMode) debugPrint('🔐 FirebaseAuthService: ⚠️ USER IS ANONYMOUS - Premium features unavailable');
          if (kDebugMode) debugPrint('🔐 FirebaseAuthService: 💡 Use Google Sign-In for full access');
        } else {
          if (kDebugMode) debugPrint('🔐 FirebaseAuthService: ✅ Real authenticated user detected');
          // Force refresh auth state for auto-restored sessions
          await _refreshAuthState(currentUser);
        }
      } else {
        if (kDebugMode) debugPrint('🔐 FirebaseAuthService: ⚠️ No user signed in');
        if (kDebugMode) debugPrint('🔐 FirebaseAuthService: 💡 Anonymous sign-in disabled - use Google Sign-In for premium features');
        if (kDebugMode) debugPrint('🔐 FirebaseAuthService: 💡 Some features may be limited without authentication');

        // REMOVED: Automatic anonymous sign-in for better premium account handling
        // Users should explicitly sign in with Google for premium features
      }

      // Set up automatic token refresh listener
      _setupTokenRefreshListener();

      if (kDebugMode) debugPrint('🔐 FirebaseAuthService: ✅ Initialized successfully');

      // Show detailed auth state after initialization
      debugAuthState();
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('🔐 FirebaseAuthService: ❌ Failed to initialize: $e');
      if (kDebugMode) debugPrint('🔐 FirebaseAuthService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Current authenticated user
  User? get currentUser => _auth?.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? const Stream.empty();

  /// Check if Google Sign-In is available (Firebase Auth must be initialized).
  bool get isGoogleSignInConfigured => _auth != null;

  /// OAuth params so Google always shows the account picker (otherwise Safari / WebView
  /// cookies often re-use the last Google session and you cannot switch accounts).
  GoogleAuthProvider _googleAuthProviderForInteractiveSignIn() {
    return GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters(const <String, String>{
        'prompt': 'select_account',
      });
  }

  /// Sign in with Google
  /// If user is currently anonymous, this will link the accounts
  ///
  /// On iOS and Android we use [FirebaseAuth.signInWithProvider] / [User.linkWithProvider],
  /// which runs Google's OAuth flow through the Firebase iOS/Android SDK (Safari view /
  /// custom tabs). This avoids `google_sign_in` 7.x issues (missing SERVER_CLIENT_ID,
  /// stale GID state after email sign-out, UnimplementedError on signOut).
  ///
  /// On web, [FirebaseAuth.signInWithPopup] is used.
  Future<UserCredential?> signInWithGoogle() async {
    if (_auth == null) {
      throw Exception('Firebase Auth not initialized. Call initialize() first.');
    }

    if (kDebugMode) debugPrint('FirebaseAuthService: Starting Google Sign-In...');

    try {
      // Clear any cached GoogleSignIn user so the native layer does not short-circuit.
      if (!kIsWeb && _googleSignIn != null) {
        try {
          await _googleSignIn!.signOut();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FirebaseAuthService: Pre-Google plugin signOut (non-fatal): $e');
          }
        }
      }

      final GoogleAuthProvider provider = _googleAuthProviderForInteractiveSignIn();

      late final UserCredential userCredential;

      if (kIsWeb) {
        userCredential = await auth.signInWithPopup(provider);
      } else if (isAnonymous) {
        final u = currentUser;
        if (u == null) {
          throw Exception('No user session to link.');
        }
        userCredential = await u.linkWithProvider(provider);
      } else {
        userCredential = await auth.signInWithProvider(provider);
      }

      if (kDebugMode) {
        debugPrint(
            'FirebaseAuthService: Google sign-in OK: ${userCredential.user?.email}');
      }

      if (userCredential.user != null) {
        try {
          await userCredential.user!.reload();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FirebaseAuthService: User reload (non-critical): $e');
          }
        }
      }

      await _refreshAuthState(userCredential.user);
      await Future.delayed(const Duration(milliseconds: 300));

      return userCredential;
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();
      final msg = (e.message ?? '').toLowerCase();
      if (code.contains('cancel') ||
          msg.contains('cancel') ||
          code == 'web-context-canceled') {
        if (kDebugMode) {
          debugPrint('FirebaseAuthService: Google Sign-In canceled');
        }
        return null;
      }
      if (kDebugMode) {
        debugPrint(
            'FirebaseAuthService: Google FirebaseAuthException: ${e.code} ${e.message}');
      }
      rethrow;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FirebaseAuthService: Google Sign-In failed: $e\n$st');
      }
      throw Exception(
        'Google Sign-In is not available. Please use Email sign-in instead. ($e)',
      );
    }
  }

  /// SHA256 hash of string for Sign in with Apple nonce (Apple expects hashed nonce).
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes);
  }

  /// Sign in with Apple (iOS 13+, macOS 10.15+).
  /// If user is currently anonymous, links the Apple credential to preserve data.
  Future<UserCredential?> signInWithApple() async {
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('Sign in with Apple is not available on this device.');
      }

      if (kDebugMode) debugPrint('FirebaseAuthService: Starting Sign in with Apple...');

      final rawNonce = generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to get Apple identity token. Please try again or use another sign-in method.');
      }

      final fullName = AppleFullPersonName(
        givenName: appleCredential.givenName,
        familyName: appleCredential.familyName,
      );
      final credential = AppleAuthProvider.credentialWithIDToken(
        idToken,
        rawNonce,
        fullName,
      );

      if (isAnonymous) {
        return await linkAnonymousWithCredential(credential);
      }

      final userCredential = await auth.signInWithCredential(credential);

      if (kDebugMode) debugPrint('FirebaseAuthService: Successfully signed in with Apple: ${userCredential.user?.email}');

      if (userCredential.user != null) {
        try {
          await userCredential.user!.reload();
        } catch (e) {
          if (kDebugMode) debugPrint('FirebaseAuthService: ⚠️ User reload failed (non-critical): $e');
        }
      }

      await _refreshAuthState(userCredential.user);
      await Future.delayed(const Duration(milliseconds: 300));

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        if (kDebugMode) debugPrint('FirebaseAuthService: User canceled Sign in with Apple');
        return null;
      }
      if (kDebugMode) debugPrint('FirebaseAuthService: Apple Sign-In authorization error: ${e.code} - ${e.message}');
      throw _userFacingAppleSignInError(e.message);
    } on SignInWithAppleException catch (e) {
      if (kDebugMode) debugPrint('FirebaseAuthService: Apple Sign-In exception: $e');
      final msg = e.toString().replaceFirst('Exception:', '').trim();
      throw _userFacingAppleSignInError(msg.isEmpty ? null : msg);
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (kDebugMode) debugPrint('FirebaseAuthService: Apple Sign-In Firebase error: ${e.code} - ${e.message}');
        throw _userFacingAppleSignInError(e.message ?? e.code);
      }
      if (kDebugMode) debugPrint('FirebaseAuthService: Apple Sign-In failed: $e');
      final detail = e is Exception ? e.toString().replaceFirst('Exception:', '').trim() : e.toString();
      throw _userFacingAppleSignInError(detail.isEmpty ? null : detail);
    }
  }

  static Exception _userFacingAppleSignInError([String? detail]) {
    final msg = detail != null && detail.isNotEmpty
        ? 'Sign in with Apple failed. $detail'
        : 'Sign in with Apple failed. Please try again or use another sign-in method.';
    return Exception(msg);
  }

  /// Check if Sign in with Apple is available (e.g. iOS 13+, macOS 10.15+).
  Future<bool> get isAppleSignInAvailable => SignInWithApple.isAvailable();

  /// Link anonymous account with a credential (Google, Email, etc.)
  /// This preserves all user data from the anonymous session
  Future<UserCredential?> linkAnonymousWithCredential(AuthCredential credential) async {
    try {
      final user = currentUser;
      if (user == null || !user.isAnonymous) {
        if (kDebugMode) debugPrint('FirebaseAuthService: Cannot link - no anonymous user');
        return null;
      }

      if (kDebugMode) debugPrint('FirebaseAuthService: Linking anonymous account ${user.uid} with credential...');

      final UserCredential userCredential = await user.linkWithCredential(credential);

      if (kDebugMode) debugPrint('FirebaseAuthService: ✅ Successfully linked anonymous account to ${userCredential.user?.email}');
      if (kDebugMode) debugPrint('FirebaseAuthService: User UID preserved: ${userCredential.user?.uid}');

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        // The credential is already associated with a different account
        // Sign in with the existing account instead
        if (kDebugMode) debugPrint('FirebaseAuthService: Credential already in use, signing in to existing account');
        return await auth.signInWithCredential(credential);
      }
      if (kDebugMode) debugPrint('FirebaseAuthService: Link failed: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('FirebaseAuthService: Link failed: $e');
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
        if (kDebugMode) debugPrint('FirebaseAuthService: Cannot link - no anonymous user');
        return null;
      }

      if (kDebugMode) debugPrint('FirebaseAuthService: Linking anonymous account with email: $email');

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      final UserCredential userCredential = await user.linkWithCredential(credential);

      if (kDebugMode) debugPrint('FirebaseAuthService: ✅ Successfully linked anonymous account to email');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        if (kDebugMode) debugPrint('FirebaseAuthService: Email already in use');
        // User should sign in with existing account instead
      }
      if (kDebugMode) debugPrint('FirebaseAuthService: Email link failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) debugPrint('FirebaseAuthService: Signing in with email: $email');
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      if (kDebugMode) debugPrint('FirebaseAuthService: Email sign-in successful');
      return userCredential;
    } catch (e) {
      if (kDebugMode) debugPrint('FirebaseAuthService: Email sign-in failed: $e');
      rethrow;
    }
  }

  /// Create account with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) debugPrint('FirebaseAuthService: Creating account for: $email');
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      if (kDebugMode) debugPrint('FirebaseAuthService: Account creation successful');
      return userCredential;
    } catch (e) {
      if (kDebugMode) debugPrint('FirebaseAuthService: Account creation failed: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      final user = currentUser;
      if (kDebugMode) debugPrint('FirebaseAuthService: 🚪 Signing out...');
      if (kDebugMode) debugPrint('  Current user: ${user?.email ?? user?.uid ?? "NULL"}');
      if (kDebugMode) debugPrint('  Was anonymous: ${user?.isAnonymous ?? false}');

      // google_sign_in: sign out + disconnect so the next OAuth flow can pick another
      // Google account (signOut alone often leaves enough state to re-bind the same user).
      if (_googleSignIn != null) {
        try {
          if (kDebugMode) debugPrint('FirebaseAuthService: 🔄 Signing out from Google...');
          await _googleSignIn!.signOut();
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'FirebaseAuthService: Google Sign-In signOut skipped (non-fatal): $e');
          }
        }
        try {
          if (kDebugMode) {
            debugPrint('FirebaseAuthService: 🔄 Disconnecting Google Sign-In (revoke app session)...');
          }
          await _googleSignIn!.disconnect();
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'FirebaseAuthService: Google disconnect skipped (non-fatal): $e');
          }
        }
      }

      // Sign out from Firebase
      if (kDebugMode) debugPrint('FirebaseAuthService: 🔄 Signing out from Firebase...');
      await auth.signOut();

      try {
        await RevenueCatService.instance.logOut();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('FirebaseAuthService: RevenueCat logOut (non-fatal): $e');
        }
      }

      // Clear subscription cache to ensure fresh data on next login
      if (kDebugMode) debugPrint('FirebaseAuthService: 🧹 Clearing subscription cache...');
      SubscriptionService.instance.clearCache();

      // Clear AssemblyAI cache
      AssemblyAIService.instance.clearCache();

      if (kDebugMode) debugPrint('FirebaseAuthService: ✅ Sign out successful - use Google Sign-In for premium features');
    } catch (e) {
      if (kDebugMode) debugPrint('FirebaseAuthService: ❌ Sign out failed: $e');
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
      if (kDebugMode) debugPrint('FirebaseAuthService: Failed to get ID token: $e');
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
      if (kDebugMode) debugPrint('🔄 FirebaseAuthService: Refreshing auth state for user: ${user.email}');

      // Force refresh the ID token
      await user.getIdToken(true);
      if (kDebugMode) debugPrint('✅ FirebaseAuthService: Auth token refreshed successfully');

      // RevenueCat: sync user ID for cross-device entitlement (in-app purchases)
      try {
        await RevenueCatService.instance.logIn(user.uid);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ FirebaseAuthService: RevenueCat logIn (non-fatal): $e');
      }

      // Clear any cached subscription data so it re-fetches with new auth
      try {
        // Import is done at top of file, safely call the method
        final subscriptionService = SubscriptionService.instance;
        subscriptionService.clearCache();
        if (kDebugMode) debugPrint('🗑️ FirebaseAuthService: Cleared subscription cache');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ FirebaseAuthService: Could not clear subscription cache: $e');
      }

      // Clear AssemblyAI cache to remove old user tokens
      try {
        AssemblyAIService().clearCache();
        if (kDebugMode) debugPrint('🗑️ FirebaseAuthService: Cleared AssemblyAI cache');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ FirebaseAuthService: Could not clear AssemblyAI cache: $e');
      }

    } catch (e) {
      if (kDebugMode) debugPrint('❌ FirebaseAuthService: Failed to refresh auth state: $e');
    }
  }

  /// Get user photo URL
  String? get userPhotoURL => currentUser?.photoURL;

  /// Force check current authentication state and print detailed debug info
  void debugAuthState() {
    final user = currentUser;
    if (kDebugMode) debugPrint('🔍 FIREBASE AUTH DEBUG STATE:');
    if (kDebugMode) debugPrint('================================');
    if (user != null) {
      if (kDebugMode) debugPrint('✅ User is signed in');
      if (kDebugMode) debugPrint('  UID: ${user.uid}');
      if (kDebugMode) debugPrint('  Email: ${user.email ?? "No email"}');
      if (kDebugMode) debugPrint('  Display Name: ${user.displayName ?? "No display name"}');
      if (kDebugMode) debugPrint('  isAnonymous: ${user.isAnonymous}');
      if (kDebugMode) debugPrint('  emailVerified: ${user.emailVerified}');
      if (kDebugMode) debugPrint('  Provider Data: ${user.providerData.map((p) => '${p.providerId}:${p.email}').toList()}');
      if (kDebugMode) debugPrint('  isSignedIn: $isSignedIn');
      if (kDebugMode) debugPrint('  hasRealAccount: $hasRealAccount');

      if (user.isAnonymous) {
        if (kDebugMode) debugPrint('⚠️ PROBLEM: User is anonymous - premium features unavailable');
        if (kDebugMode) debugPrint('💡 SOLUTION: Use Google Sign-In for premium access');
      } else {
        if (kDebugMode) debugPrint('✅ Real authenticated user - premium features should work');
      }
    } else {
      if (kDebugMode) debugPrint('❌ No user signed in');
      if (kDebugMode) debugPrint('💡 SOLUTION: Sign in with Google for premium features');
    }
    if (kDebugMode) debugPrint('================================');
  }

  /// Delete the current user account (Guideline 5.1.1(v)).
  /// Permanently removes the Firebase Auth account. Backend/Firestore data should be cleaned by a Cloud Function or scheduled job.
  /// Throws if not signed in or if deletion fails (e.g. requires recent login).
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No account to delete. You are not signed in.');
    }
    if (user.isAnonymous) {
      await signOut();
      return;
    }
    try {
      if (kDebugMode) debugPrint('FirebaseAuthService: 🗑️ Deleting user account...');
      await user.delete();
      if (kDebugMode) debugPrint('FirebaseAuthService: ✅ Account deleted');
      await signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (kDebugMode) debugPrint('FirebaseAuthService: Re-authentication required for account deletion');
        throw Exception('For your security, please sign out and sign in again, then try deleting your account.');
      }
      rethrow;
    }
  }

  /// Force sign out completely and clear all cached data
  Future<void> forceSignOutAndClear() async {
    try {
      if (kDebugMode) debugPrint('🧹 FORCE SIGN OUT: Starting complete cleanup...');

      await signOut();

      // Clear subscription cache
      SubscriptionService.instance.clearCache();

      // Clear AssemblyAI cache
      AssemblyAIService().clearCache();

      if (kDebugMode) debugPrint('🧹 FORCE SIGN OUT: Complete cleanup finished');
      if (kDebugMode) debugPrint('💡 Now sign in with Google for premium access');

    } catch (e) {
      if (kDebugMode) debugPrint('❌ FORCE SIGN OUT failed: $e');
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
          if (kDebugMode) debugPrint('🔄 FirebaseAuthService: ID token changed - auto-refreshing for user: ${user.email}');
          // Token was automatically refreshed by Firebase
          // No need to force refresh - Firebase handles this automatically
        }
      },
      onError: (error) {
        if (kDebugMode) debugPrint('⚠️ FirebaseAuthService: Token refresh listener error: $error');
      },
    );

    if (kDebugMode) debugPrint('✅ FirebaseAuthService: Automatic token refresh listener set up');
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
      if (kDebugMode) debugPrint('✅ FirebaseAuthService: Token refreshed (if needed)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ FirebaseAuthService: Token refresh failed: $e');
      // If token refresh fails, try forcing a refresh
      try {
        final user = currentUser;
        if (user != null && !user.isAnonymous) {
          await user.getIdToken(true);
          if (kDebugMode) debugPrint('✅ FirebaseAuthService: Token force-refreshed successfully');
        }
      } catch (forceError) {
        if (kDebugMode) debugPrint('❌ FirebaseAuthService: Force token refresh also failed: $forceError');
      }
    }
  }

  /// Dispose of resources
  void dispose() {
    _idTokenSubscription?.cancel();
    _idTokenSubscription = null;
  }
}
