// lib/lumara/ui/lumara_splash_screen.dart
// LUMARA splash screen shown on app launch

import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/lumara_icon.dart';
import 'package:my_app/shared/ui/home/home_view.dart';

/// Splash screen with LUMARA symbol and ARC label
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
    // Navigate to main menu (HomeView) after 3 seconds
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToMainMenu();
      }
    });
  }

  void _navigateToMainMenu() {
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeView(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: _navigateToMainMenu, // Tap anywhere to skip
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate icon size based on screen width (use 40% of screen width, min 200px)
              final iconSize = (constraints.maxWidth * 0.4).clamp(200.0, 600.0);
              
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large LUMARA symbol (responsive - 40% of screen width)
                    LumaraIcon(
                      size: iconSize,
                      color: theme.colorScheme.primary,
                      strokeWidth: (iconSize / 100).clamp(2.0, 6.0),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // ARC label
                    Text(
                      'ARC',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 4.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

