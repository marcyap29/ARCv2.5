import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick Actions Service for iOS
class QuickActionsService {
  static const MethodChannel _channel = MethodChannel('quick_actions');
  
  /// Initialize quick actions
  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initializeQuickActions');
      print('Quick Actions initialized successfully');
    } catch (e) {
      print('Failed to initialize Quick Actions: $e');
    }
  }
  
  /// Handle quick action selection
  static Future<void> handleQuickAction(String actionId) async {
    try {
      await _channel.invokeMethod('handleQuickAction', {'actionId': actionId});
    } catch (e) {
      print('Failed to handle quick action: $e');
    }
  }
}

/// Deep Link Handler for Quick Actions
class DeepLinkHandler {
  static final Map<String, VoidCallback> _handlers = {};
  
  /// Register a handler for a specific deep link
  static void registerHandler(String path, VoidCallback handler) {
    _handlers[path] = handler;
  }
  
  /// Handle incoming deep link
  static void handleDeepLink(String path) {
    final handler = _handlers[path];
    if (handler != null) {
      handler();
    } else {
      print('No handler registered for path: $path');
    }
  }
}

/// iOS Notification Handler
class IOSNotificationHandler {
  static final Map<String, VoidCallback> _notificationHandlers = {};
  
  /// Register a handler for iOS notifications
  static void registerNotificationHandler(String notificationName, VoidCallback handler) {
    _notificationHandlers[notificationName] = handler;
  }
  
  /// Handle iOS notification
  static void handleNotification(String notificationName) {
    final handler = _notificationHandlers[notificationName];
    if (handler != null) {
      handler();
    } else {
      print('No handler registered for notification: $notificationName');
    }
  }
}

/// Quick Actions Installation Screen
class QuickActionsInstallationScreen extends StatefulWidget {
  const QuickActionsInstallationScreen({super.key});

  @override
  State<QuickActionsInstallationScreen> createState() => _QuickActionsInstallationScreenState();
}

class _QuickActionsInstallationScreenState extends State<QuickActionsInstallationScreen> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await QuickActionsService.initialize();
    
    // Register deep link handlers
    DeepLinkHandler.registerHandler('new-entry', () {
      _navigateToNewEntry();
    });
    
    DeepLinkHandler.registerHandler('camera', () {
      _navigateToCamera();
    });
    
    DeepLinkHandler.registerHandler('voice', () {
      _navigateToVoiceRecorder();
    });
    
    // Register notification handlers
    IOSNotificationHandler.registerNotificationHandler('OpenNewEntry', () {
      _navigateToNewEntry();
    });
    
    IOSNotificationHandler.registerNotificationHandler('OpenCamera', () {
      _navigateToCamera();
    });
    
    IOSNotificationHandler.registerNotificationHandler('OpenVoiceRecorder', () {
      _navigateToVoiceRecorder();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Actions'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EPI Journal Quick Actions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Quick Actions Active',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quick Actions are now active and ready to use. Long press the EPI app icon to access them.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Quick Actions work on all iPhone models, including those without 3D Touch.',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Quick Actions Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.touch_app, color: Colors.green, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Actions (3D Touch/Long Press)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Long press the EPI app icon for quick access',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Features
                    const Text(
                      'Available Actions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildActionItem('New Entry', 'Create text entry', Icons.create),
                    _buildActionItem('Quick Photo', 'Open camera', Icons.camera_alt),
                    _buildActionItem('Voice Note', 'Record audio', Icons.mic),
                    
                    const SizedBox(height: 16),
                    
                    // Installation Steps
                    const Text(
                      'How to Use:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Long press the EPI app icon'),
                    const Text('2. Select "New Entry" for quick text entry'),
                    const Text('3. Select "Quick Photo" for camera'),
                    const Text('4. Select "Voice Note" for audio'),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showQuickActionsInstructions(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('View Instructions'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test Buttons
            _buildTestSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Integration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Test the deep link functionality:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToNewEntry(),
                    icon: const Icon(Icons.create),
                    label: const Text('New Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToCamera(),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToVoiceRecorder(),
                    icon: const Icon(Icons.mic),
                    label: const Text('Voice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToNewEntry() {
    // TODO: Navigate to new entry screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening New Entry...')),
    );
  }

  void _navigateToCamera() {
    // TODO: Navigate to camera screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Camera...')),
    );
  }

  void _navigateToVoiceRecorder() {
    // TODO: Navigate to voice recorder screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening Voice Recorder...')),
    );
  }

  void _showQuickActionsInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Actions Instructions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick Actions are automatically enabled:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('1. Long press the EPI app icon'),
              const Text('2. Select "New Entry" for quick text entry'),
              const Text('3. Select "Quick Photo" for camera'),
              const Text('4. Select "Voice Note" for audio'),
              const SizedBox(height: 12),
              const Text(
                'Available actions:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• New Entry - Create text entry'),
              const Text('• Quick Photo - Open camera'),
              const Text('• Voice Note - Record audio'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Note: Quick Actions work on all iPhone models, including those without 3D Touch.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
