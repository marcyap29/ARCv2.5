// lib/lumara/ui/lumara_splash_screen.dart
// ARC splash screen shown on app launch

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/shared/ui/home/home_view.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/ui/auth/sign_in_screen.dart';

/// Splash screen with ARC logo
class LumaraSplashScreen extends StatefulWidget {
  const LumaraSplashScreen({super.key});

  @override
  State<LumaraSplashScreen> createState() => _LumaraSplashScreenState();
}

class _LumaraSplashScreenState extends State<LumaraSplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    // Navigate after 3 seconds, checking auth state
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  void _checkAuthAndNavigate() {
    _timer?.cancel();

    // Check if user is authenticated
    final isSignedIn = FirebaseAuthService.instance.isSignedIn;

    if (isSignedIn) {
      // User is signed in, go to home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeView(),
        ),
      );
    } else {
      // User is not signed in, go to sign-in screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SignInScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background for white logo
      body: GestureDetector(
        onTap: _navigateToMainMenu, // Tap anywhere to skip
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate logo size based on screen width (use 60% of screen width, min 200px, max 400px)
              final logoSize = (constraints.maxWidth * 0.6).clamp(200.0, 400.0);
              
              return Center(
                child: Image.asset(
                  'assets/images/ARC-Logo-White.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

