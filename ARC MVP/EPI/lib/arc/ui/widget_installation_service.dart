import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';

/// iOS Widget Extension - Native iOS widget for home screen
class IOSWidgetExtension {
  static const MethodChannel _channel = MethodChannel('ios_widget_extension');

  /// Initialize the iOS widget extension
  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initializeWidget');
    } catch (e) {
      print('Failed to initialize iOS widget: $e');
    }
  }

  /// Update widget with new journal entry
  static Future<void> updateWidget({
    required String title,
    required String content,
    required List<McpPointer> media,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'content': content,
        'mediaCount': media.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed to update iOS widget: $e');
    }
  }
}

/// App Widget - Flutter widget that can be added to home screen
class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  final List<McpPointer> _recentMedia = [];
  String _lastEntry = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'EPI Journal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // Quick actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickButton(
                          icon: Icons.add,
                          label: 'New',
                          onTap: _handleNewEntry,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildQuickButton(
                          icon: Icons.camera_alt,
                          label: 'Photo',
                          onTap: _handleCamera,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Recent entry preview
                  if (_lastEntry.isNotEmpty) ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Entry:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                _lastEntry,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blue, size: 16),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNewEntry() {
    // TODO: Open journal entry screen
  }

  void _handleCamera() {
    // TODO: Open camera
  }
}

/// Widget Installation Guide
class WidgetInstallationGuide extends StatelessWidget {
  const WidgetInstallationGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Installation'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Install EPI Journal Widget',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // iOS Widget Extension
            _buildInstallationCard(
              title: 'iOS Home Screen Widget',
              description: 'Add EPI Journal to your iPhone home screen',
              icon: Icons.phone_iphone,
              steps: [
                'Long press on your home screen',
                'Tap the "+" button in the top-left corner',
                'Search for "EPI Journal"',
                'Select the widget size you prefer',
                'Tap "Add Widget"',
                'Position the widget on your home screen',
              ],
              onInstall: () => _showIOSWidgetInstructions(context),
            ),
            
            const SizedBox(height: 16),
            
            // App Widget
            _buildInstallationCard(
              title: 'App Widget',
              description: 'Add EPI Journal widget within the app',
              icon: Icons.widgets,
              steps: [
                'Open the EPI app',
                'Go to Settings > Widgets',
                'Tap "Add Widget"',
                'Select your preferred widget size',
                'The widget will appear in your app',
              ],
              onInstall: () => _showAppWidgetInstructions(context),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Actions
            _buildInstallationCard(
              title: 'Quick Actions',
              description: '3D Touch/Long Press actions on app icon',
              icon: Icons.touch_app,
              steps: [
                'Long press the EPI app icon',
                'Select "New Entry" from the menu',
                'Or select "Quick Photo" for camera',
                'Or select "Voice Note" for audio',
              ],
              onInstall: () => _showQuickActionsInstructions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallationCard({
    required String title,
    required String description,
    required IconData icon,
    required List<String> steps,
    required VoidCallback onInstall,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 24),
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
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Install Widget'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIOSWidgetInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('iOS Widget Installation'),
        content: const Text(
          'To install the iOS widget:\n\n'
          '1. Long press on your home screen\n'
          '2. Tap the "+" button\n'
          '3. Search for "EPI Journal"\n'
          '4. Select widget size\n'
          '5. Tap "Add Widget"\n\n'
          'The widget will appear on your home screen and allow quick journal entry creation.',
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

  void _showAppWidgetInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Widget Installation'),
        content: const Text(
          'To install the app widget:\n\n'
          '1. Open EPI app\n'
          '2. Go to Settings > Widgets\n'
          '3. Tap "Add Widget"\n'
          '4. Select your preferred size\n'
          '5. The widget will appear in your app\n\n'
          'You can access quick journal entry from within the app.',
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
        title: const Text('Quick Actions Installation'),
        content: const Text(
          'Quick Actions are automatically enabled:\n\n'
          '1. Long press the EPI app icon\n'
          '2. Select "New Entry" for quick text entry\n'
          '3. Select "Quick Photo" for camera\n'
          '4. Select "Voice Note" for audio\n\n'
          'These actions provide instant access to journal features.',
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

