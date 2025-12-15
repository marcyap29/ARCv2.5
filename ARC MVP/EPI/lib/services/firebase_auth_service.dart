// Firebase Auth service with Google Sign-In integration and account linking
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

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

      // Check current auth state
      final currentUser = _auth!.currentUser;
      debugPrint('🔐 FirebaseAuthService: Current user before anon check: ${currentUser?.uid ?? "NULL"}');

      // Auto-sign in anonymously if no user is signed in (for MVP testing)
      if (currentUser == null) {
        try {
          debugPrint('🔐 FirebaseAuthService: ⚠️ No user signed in - attempting anonymous sign-in for MVP...');
          final userCredential = await _auth!.signInAnonymously();
          debugPrint('🔐 FirebaseAuthService: ✅ Anonymous sign-in successful!');
          debugPrint('🔐 FirebaseAuthService: Anonymous UID: ${userCredential.user?.uid}');
        } catch (e, stackTrace) {
          debugPrint('🔐 FirebaseAuthService: ❌ Anonymous sign-in FAILED: $e');
          debugPrint('🔐 FirebaseAuthService: Stack trace: $stackTrace');
          // Continue anyway - function calls will fail gracefully
        }
      } else {
        debugPrint('🔐 FirebaseAuthService: Already signed in as: ${currentUser.uid}');
      }

      debugPrint('🔐 FirebaseAuthService: ✅ Initialized successfully');
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
      debugPrint('FirebaseAuthService: Signing out...');

      // Sign out from Google if signed in
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }

      // Sign out from Firebase
      await auth.signOut();

      debugPrint('FirebaseAuthService: Sign out successful');
    } catch (e) {
      debugPrint('FirebaseAuthService: Sign out failed: $e');
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

  /// Get user photo URL
  String? get userPhotoURL => currentUser?.photoURL;
}
