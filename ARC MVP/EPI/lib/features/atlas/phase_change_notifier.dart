import 'package:flutter/material.dart';

/// Service for showing phase change notifications to users
class PhaseChangeNotifier {
  static const Duration _notificationDuration = Duration(seconds: 4);
  
  /// Show a phase change notification
  static void showPhaseChangeNotification(
    BuildContext context, {
    required String fromPhase,
    required String toPhase,
    required String reason,
  }) {
    if (!context.mounted) return;
    
    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Phase Evolution',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Your journey has evolved from $fromPhase to $toPhase',
            style: TextStyle(fontSize: 14),
          ),
          if (reason.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
      backgroundColor: getPhaseColor(toPhase),
      duration: _notificationDuration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.all(16),
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  /// Show a phase stability notification (when phase doesn't change)
  static void showPhaseStabilityNotification(
    BuildContext context, {
    required String currentPhase,
    required String reason,
  }) {
    if (!context.mounted) return;
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.anchor,
            color: Colors.white,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phase Stability',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Your $currentPhase phase continues to serve you well',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: getPhaseColor(currentPhase).withOpacity(0.8),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.all(16),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  /// Get color associated with each phase
  static Color getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Colors.purple;
      case 'expansion':
        return Colors.green;
      case 'transition':
        return Colors.orange;
      case 'consolidation':
        return Colors.blue;
      case 'recovery':
        return Colors.teal;
      case 'breakthrough':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
  
  /// Show a phase change celebration (for major transitions)
  static void showPhaseChangeCelebration(
    BuildContext context, {
    required String fromPhase,
    required String toPhase,
  }) {
    if (!context.mounted) return;
    
    // Show a more prominent notification for major phase changes
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.celebration,
              color: getPhaseColor(toPhase),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Phase Evolution!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: getPhaseColor(toPhase),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your journey has evolved from $fromPhase to $toPhase',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: getPhaseColor(toPhase).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This new phase represents a significant step in your personal growth journey.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Continue Journey',
              style: TextStyle(
                color: getPhaseColor(toPhase),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
