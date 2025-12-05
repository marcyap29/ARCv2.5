// Firebase Auth service with Google Sign-In integration
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

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

  /// Initialize Firebase Auth with proper Firebase app instance
  Future<void> initialize() async {
    try {
      // Ensure Firebase is ready first
      final firebaseService = FirebaseService.instance;
      await firebaseService.ensureReady();

      // Get Firebase Auth instance from the initialized app
      _auth = firebaseService.getAuth();

      // Initialize Google Sign-In
      _googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
        // Configure for web platform
        clientId: kIsWeb ? const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID') : null,
      );

      debugPrint('FirebaseAuthService: Initialized successfully');
    } catch (e) {
      debugPrint('FirebaseAuthService: Failed to initialize: $e');
      rethrow;
    }
  }

  /// Current authenticated user
  User? get currentUser => _auth?.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? const Stream.empty();

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (_googleSignIn == null) {
        throw Exception('Google Sign-In not initialized');
      }

      debugPrint('FirebaseAuthService: Starting Google Sign-In...');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        debugPrint('FirebaseAuthService: Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('FirebaseAuthService: Google user signed in: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await auth.signInWithCredential(credential);

      debugPrint('FirebaseAuthService: Successfully signed in to Firebase: ${userCredential.user?.email}');
      return userCredential;

    } catch (e) {
      debugPrint('FirebaseAuthService: Google Sign-In failed: $e');
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
