// Firebase Auth helper (template)
// Uncomment and adapt if authentication is required.

// import 'package:firebase_auth/firebase_auth.dart';

// class FirebaseAuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   User? get currentUser => _auth.currentUser;
//   Stream<User?> get authStateChanges => _auth.authStateChanges();
//
//   Future<UserCredential> signInWithEmailAndPassword({
//     required String email,
//     required String password,
//   }) {
//     return _auth.signInWithEmailAndPassword(email: email, password: password);
//   }
//
//   Future<void> signOut() => _auth.signOut();
// }
