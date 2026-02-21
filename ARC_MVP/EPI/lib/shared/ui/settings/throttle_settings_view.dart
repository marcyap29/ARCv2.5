// throttle_settings_view.dart - Throttle unlock settings with password protection

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class ThrottleSettingsView extends StatefulWidget {
  const ThrottleSettingsView({super.key});

  @override
  State<ThrottleSettingsView> createState() => _ThrottleSettingsViewState();
}

class _ThrottleSettingsViewState extends State<ThrottleSettingsView> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isUnlocked = false;
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkThrottleStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkThrottleStatus() async {
    try {
      setState(() {
        _isCheckingStatus = true;
        _errorMessage = null;
      });

      // Ensure Firebase is properly initialized before accessing Functions
      FirebaseApp app;
      try {
        // Try to get existing app first
        app = Firebase.app();
      } catch (e) {
        // If no app exists, initialize it
        app = await Firebase.initializeApp();
      }

      final callable = FirebaseFunctions.instanceFor(app: app).httpsCallable('checkThrottleStatus');
      final result = await callable.call();

      if (mounted) {
        setState(() {
          _isUnlocked = result.data['unlocked'] == true;
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _errorMessage = 'Error checking throttle status: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _unlockThrottle() async {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Ensure Firebase is properly initialized before accessing Functions
      FirebaseApp app;
      try {
        // Try to get existing app first
        app = Firebase.app();
      } catch (e) {
        // If no app exists, initialize it
        app = await Firebase.initializeApp();
      }

      final callable = FirebaseFunctions.instanceFor(app: app).httpsCallable('unlockThrottle');
      final result = await callable.call({'password': password});

      if (result.data['success'] == true) {
        if (mounted) {
          setState(() {
            _isUnlocked = true;
            _isLoading = false;
            _passwordController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Throttle unlocked successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid password';
          _passwordController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _lockThrottle() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Ensure Firebase is properly initialized before accessing Functions
      FirebaseApp app;
      try {
        // Try to get existing app first
        app = Firebase.app();
      } catch (e) {
        // If no app exists, initialize it
        app = await Firebase.initializeApp();
      }

      final callable = FirebaseFunctions.instanceFor(app: app).httpsCallable('lockThrottle');
      final result = await callable.call();

      if (result.data['success'] == true) {
        if (mounted) {
          setState(() {
            _isUnlocked = false;
            _isLoading = false;
            _passwordController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Throttle locked'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error locking throttle: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Throttle'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isCheckingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isUnlocked
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isUnlocked
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isUnlocked ? Icons.lock_open : Icons.lock,
                          color: _isUnlocked ? Colors.green : Colors.orange,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isUnlocked ? 'Throttle Unlocked' : 'Throttle Locked',
                                style: heading3Style(context).copyWith(
                                  color: kcPrimaryTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isUnlocked
                                    ? 'Rate limits are disabled for your account'
                                    : 'Rate limits are active (20/day, 3/min)',
                                style: bodyStyle(context).copyWith(
                                  color: kcSecondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Password Input Section
                  if (!_isUnlocked) ...[
                    Text(
                      'Enter password to unlock throttle',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor,
                        letterSpacing: 2.0, // Makes password harder to count
                      ),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: kcAccentColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: kcSecondaryTextColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        // No character counter
                        counterText: '',
                      ),
                      // Hide character count
                      maxLength: null,
                      onSubmitted: (_) => _unlockThrottle(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _unlockThrottle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kcAccentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Unlock Throttle',
                                style: bodyStyle(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    // Lock Button (when unlocked)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _lockThrottle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Lock Throttle',
                                style: bodyStyle(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: bodyStyle(context).copyWith(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'About Throttle',
                              style: bodyStyle(context).copyWith(
                                color: kcPrimaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Free tier users are limited to 20 requests per day and 3 requests per minute. '
                          'Unlocking the throttle removes these limits. This is a developer/admin feature.',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

