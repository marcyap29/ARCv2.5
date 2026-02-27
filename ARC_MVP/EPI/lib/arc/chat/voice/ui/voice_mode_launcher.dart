/// Voice Mode Launcher
/// 
/// Simple button to activate voice mode
/// Can be added as a FloatingActionButton, button, or card
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/voice_system_initializer.dart';
import '../services/voice_session_service.dart';
import '../../../services/enhanced_lumara_api.dart';
import '../../voice_journal/prism_adapter.dart';
import 'voice_mode_screen.dart';
import 'package:my_app/services/firebase_auth_service.dart';

/// Voice Mode Launcher Button
/// 
/// Add this anywhere in your app to launch voice mode
class VoiceModeLauncher extends StatelessWidget {
  final String userId;
  final EnhancedLumaraApi lumaraApi;
  final PrismAdapter prism;
  final Widget? child;
  final VoidCallback? onComplete;
  
  const VoiceModeLauncher({
    super.key,
    required this.userId,
    required this.lumaraApi,
    required this.prism,
    this.child,
    this.onComplete,
  });
  
  /// Launch voice mode
  /// NOTE: Voice mode is currently in beta - restricted to marcyap@orbitalai.net only
  Future<void> _launchVoiceMode(BuildContext context) async {
    // BETA CHECK: Voice mode is in beta testing - only allow for specific tester
    final currentUserEmail = FirebaseAuthService.instance.currentUser?.email?.toLowerCase();
    const betaTesterEmail = 'marcyap@orbitalai.net';
    
    if (currentUserEmail != betaTesterEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice mode is currently in beta testing. Coming soon!'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Check if voice can be initialized
      final canInit = await VoiceSystemInitializer.canInitialize();
      
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      
      if (!canInit) {
        _showError(
          context,
          'Voice mode not configured',
          'Voice mode is not yet set up. Please contact support.',
        );
        return;
      }
      
      // Initialize voice system
      final initializer = VoiceSystemInitializer(
        userId: userId,
        firestore: FirebaseFirestore.instance,
        lumaraApi: lumaraApi,
        prism: prism,
      );
      
      final sessionService = await initializer.initialize();
      
      if (!context.mounted) return;
      
      if (sessionService == null) {
        _showError(
          context,
          'Failed to initialize voice',
          'Could not start voice mode. Please try again.',
        );
        return;
      }
      
      // Navigate to voice screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoiceModeScreen(
            sessionService: sessionService,
            onComplete: () {
              Navigator.pop(context);
              onComplete?.call();
            },
          ),
        ),
      );
      
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      
      _showError(
        context,
        'Error',
        'Failed to start voice mode: $e',
      );
    }
  }
  
  void _showError(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (child != null) {
      // Wrap custom child
      return GestureDetector(
        onTap: () => _launchVoiceMode(context),
        child: child,
      );
    }
    
    // Default button
    return FloatingActionButton.extended(
      onPressed: () => _launchVoiceMode(context),
      icon: const Icon(Icons.mic),
      label: const Text('Voice Mode'),
      backgroundColor: Colors.deepPurple,
    );
  }
}

/// Voice Mode Card (for use in lists/grids)
class VoiceModeCard extends StatelessWidget {
  final String userId;
  final EnhancedLumaraApi lumaraApi;
  final PrismAdapter prism;
  final VoidCallback? onComplete;
  
  const VoiceModeCard({
    super.key,
    required this.userId,
    required this.lumaraApi,
    required this.prism,
    this.onComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return VoiceModeLauncher(
      userId: userId,
      lumaraApi: lumaraApi,
      prism: prism,
      onComplete: onComplete,
      child: Card(
        elevation: 4,
        color: Colors.deepPurple.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mic,
                size: 48,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 8),
              Text(
                'Voice Mode',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Speak with LUMARA',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice Mode Icon Button (compact)
class VoiceModeIconButton extends StatelessWidget {
  final String userId;
  final EnhancedLumaraApi lumaraApi;
  final PrismAdapter prism;
  final VoidCallback? onComplete;
  
  const VoiceModeIconButton({
    super.key,
    required this.userId,
    required this.lumaraApi,
    required this.prism,
    this.onComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    return VoiceModeLauncher(
      userId: userId,
      lumaraApi: lumaraApi,
      prism: prism,
      onComplete: onComplete,
      child: IconButton(
        icon: const Icon(Icons.mic),
        tooltip: 'Voice Mode',
        iconSize: 28,
        color: Colors.deepPurple,
        onPressed: () {}, // Handled by VoiceModeLauncher
      ),
    );
  }
}
