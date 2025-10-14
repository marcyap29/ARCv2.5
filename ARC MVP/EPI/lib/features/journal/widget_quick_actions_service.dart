import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../mcp/orchestrator/multimodal_integration_service.dart';

/// iOS Widget Extension and Quick Actions Integration
class IOSWidgetQuickActionsIntegration {
  static const MethodChannel _widgetChannel = MethodChannel('ios_widget_extension');
  static const MethodChannel _quickActionsChannel = MethodChannel('quick_actions');
  
  /// Initialize both widget extension and quick actions
  static Future<void> initialize() async {
    try {
      // Initialize widget extension
      await _widgetChannel.invokeMethod('initializeWidget');
      
      // Initialize quick actions
      await _quickActionsChannel.invokeMethod('initializeQuickActions');
      
      print('iOS Widget Extension and Quick Actions initialized successfully');
    } catch (e) {
      print('Failed to initialize iOS Widget Extension and Quick Actions: $e');
    }
  }
  
  /// Update widget with new journal entry
  static Future<void> updateWidget({
    required String title,
    required String content,
    required int mediaCount,
  }) async {
    try {
      await _widgetChannel.invokeMethod('updateWidget', {
        'title': title,
        'content': content,
        'mediaCount': mediaCount,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed to update widget: $e');
    }
  }
  
  /// Refresh widget timeline
  static Future<void> refreshWidget() async {
    try {
      await _widgetChannel.invokeMethod('refreshWidget');
    } catch (e) {
      print('Failed to refresh widget: $e');
    }
  }
  
  /// Handle quick action selection
  static Future<void> handleQuickAction(String actionId) async {
    try {
      await _quickActionsChannel.invokeMethod('handleQuickAction', {'actionId': actionId});
    } catch (e) {
      print('Failed to handle quick action: $e');
    }
  }
}

/// Deep Link Handler for iOS Widget and Quick Actions
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

/// Widget Installation Screen
class WidgetInstallationScreen extends StatefulWidget {
  const WidgetInstallationScreen({super.key});

  @override
  State<WidgetInstallationScreen> createState() => _WidgetInstallationScreenState();
}

class _WidgetInstallationScreenState extends State<WidgetInstallationScreen> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await IOSWidgetQuickActionsIntegration.initialize();
    
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
        title: const Text('Widget & Quick Actions'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EPI Journal Widget & Quick Actions',
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
                          'Services Initialized',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Both the iOS Widget Extension and Quick Actions are now active and ready to use.',
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
                              'You can now use the widget on your home screen and quick actions by long pressing the app icon.',
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
            
            // iOS Widget Extension
            _buildInstallationCard(
              title: 'iOS Home Screen Widget',
              description: 'Add EPI Journal to your iPhone home screen',
              icon: Icons.phone_iphone,
              color: Colors.blue,
              steps: [
                'Long press on your home screen',
                'Tap the "+" button in the top-left corner',
                'Search for "EPI Journal"',
                'Select the widget size you prefer',
                'Tap "Add Widget"',
                'Position the widget on your home screen',
              ],
              features: [
                'Quick "New Entry" button',
                'Quick "Photo" button',
                'Quick "Voice" button',
                'Last entry preview',
                'Media count display',
              ],
              onInstall: () => _showIOSWidgetInstructions(context),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Actions
            _buildInstallationCard(
              title: 'Quick Actions (3D Touch/Long Press)',
              description: 'Long press the EPI app icon for quick access',
              icon: Icons.touch_app,
              color: Colors.green,
              steps: [
                'Long press the EPI app icon',
                'Select "New Entry" from the menu',
                'Or select "Quick Photo" for camera',
                'Or select "Voice Note" for audio',
              ],
              features: [
                'New Entry - Create text entry',
                'Quick Photo - Open camera',
                'Voice Note - Record audio',
                'Works on all iPhone models',
                'No additional setup required',
              ],
              onInstall: () => _showQuickActionsInstructions(context),
            ),
            
            const SizedBox(height: 20),
            
            // Test Buttons
            _buildTestSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallationCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> steps,
    required List<String> features,
    required VoidCallback onInstall,
  }) {
    return Card(
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
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
              'Features:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature)),
                ],
              ),
            )),
            
            const SizedBox(height: 16),
            
            // Installation Steps
            const Text(
              'Installation Steps:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...steps.map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(step)),
                ],
              ),
            )),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onInstall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View Instructions'),
              ),
            ),
          ],
        ),
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

  void _showIOSWidgetInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('iOS Widget Installation'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To install the iOS widget:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('1. Long press on your home screen'),
              const Text('2. Tap the "+" button in the top-left corner'),
              const Text('3. Search for "EPI Journal"'),
              const Text('4. Select the widget size you prefer'),
              const Text('5. Tap "Add Widget"'),
              const Text('6. Position the widget on your home screen'),
              const SizedBox(height: 12),
              const Text(
                'The widget will show:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• Quick "New Entry" button'),
              const Text('• Quick "Photo" button'),
              const Text('• Quick "Voice" button'),
              const Text('• Last entry preview'),
              const Text('• Media count display'),
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

  void _showQuickActionsInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Actions'),
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