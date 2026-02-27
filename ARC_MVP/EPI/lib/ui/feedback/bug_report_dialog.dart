import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/lumara/pii_scrub.dart';
import 'package:my_app/shared/app_colors.dart';

/// Google Apps Script URL for bug report submissions
/// This endpoint appends bug reports to a Google Sheet
const String kBugReportWebhookUrl = 'https://script.google.com/macros/s/AKfycbxtmqvVyqqK0sm6SkavZmr9RhbsaF_CzLc4KuyZM3JeqPLKsSbWXGVPRtAtoC_RVoZW/exec';

/// Dialog for reporting bugs, triggered by shaking the device
class BugReportDialog extends StatefulWidget {
  const BugReportDialog({super.key});
  
  // Static flag to prevent multiple dialogs
  static bool _isDialogOpen = false;
  
  static Future<void> show(BuildContext context) async {
    if (kDebugMode) print('DEBUG: BugReportDialog.show() called');

    // Prevent multiple dialogs from opening
    if (_isDialogOpen) {
      if (kDebugMode) print('DEBUG: Bug report dialog already open, ignoring shake');
      return;
    }
    
    // Check if shake-to-report is enabled
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('shake_to_report_enabled') ?? true;
    
    if (kDebugMode) print('DEBUG: shake_to_report_enabled = $isEnabled');

    if (!isEnabled) {
      if (kDebugMode) print('DEBUG: Shake to report is disabled, not showing dialog');
      return;
    }
    
    if (context.mounted) {
      if (kDebugMode) print('DEBUG: Showing bug report dialog');
      _isDialogOpen = true;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const BugReportDialog(),
      ).whenComplete(() {
        _isDialogOpen = false;
        if (kDebugMode) print('DEBUG: Bug report dialog closed, flag reset');
      });
    } else {
      if (kDebugMode) print('DEBUG: Context not mounted, cannot show dialog');
    }
  }

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _descriptionController = TextEditingController();
  final _focusNode = FocusNode();
  bool _shakeToReportEnabled = true;
  bool _isSubmitting = false;
  bool _includeDeviceInfo = true;
  String? _deviceInfo;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDeviceInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shakeToReportEnabled = prefs.getBool('shake_to_report_enabled') ?? true;
    });
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      final iosInfo = await deviceInfo.iosInfo;
      setState(() {
        _deviceInfo = '${iosInfo.name} (${iosInfo.systemName} ${iosInfo.systemVersion})';
        _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      if (kDebugMode) print('Error loading device info: $e');
    }
  }

  Future<void> _toggleShakeToReport(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shake_to_report_enabled', value);
    setState(() {
      _shakeToReportEnabled = value;
    });
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the issue'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = FirebaseAuthService.instance;
      final userId = authService.currentUser?.uid ?? 'anonymous';
      final userEmail = authService.currentUser?.email ?? '';

      // Scrub PII from description before send/storage (users may paste journal content)
      final rawDescription = _descriptionController.text.trim();
      final scrubbedDescription = PiiScrubber.rivetScrub(rawDescription);

      final reportData = {
        'description': scrubbedDescription,
        'device': _includeDeviceInfo ? (_deviceInfo ?? 'Unknown') : 'Not included',
        'appVersion': _includeDeviceInfo ? (_appVersion ?? 'Unknown') : 'Not included',
        'userId': userId,
        'userEmail': userEmail,
      };
      
      // Send to Google Sheets via Apps Script
      final response = await http.post(
        Uri.parse(kBugReportWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reportData),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('{"success": false, "error": "timeout"}', 408),
      );
      
      // Check response
      final success = response.statusCode == 200 || response.statusCode == 302;
      
      // Store locally as backup (description already scrubbed in reportData)
      final prefs = await SharedPreferences.getInstance();
      final existingReports = prefs.getStringList('bug_reports') ?? [];
      existingReports.add('${DateTime.now().toIso8601String()}: ${reportData.toString()}');
      await prefs.setStringList('bug_reports', existingReports);
      
      if (mounted) {
        Navigator.of(context).pop();
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bug report submitted. Thank you!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report saved locally. Will retry later.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Store locally on error (scrub description before storing)
      try {
        final prefs = await SharedPreferences.getInstance();
        final existingReports = prefs.getStringList('bug_reports') ?? [];
        final scrubbedDesc =
            PiiScrubber.rivetScrub(_descriptionController.text.trim());
        existingReports.add('${DateTime.now().toIso8601String()}: $scrubbedDesc');
        await prefs.setStringList('bug_reports', existingReports);
      } catch (_) {}
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report saved locally. Will retry later.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _dismissKeyboard() {
    _focusNode.unfocus();
  }
  
  void _closeDialog() {
    _dismissKeyboard();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Container(
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Back arrow and handle bar row
                Row(
                  children: [
                    // Back arrow button
                    IconButton(
                      onPressed: _closeDialog,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    const Spacer(),
                    // Handle bar (centered)
                    Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                    const Spacer(),
                    // Spacer to balance the back button
                    const SizedBox(width: 40),
                  ],
              ),
                const SizedBox(height: 8),
              
              // Title
              const Text(
                'Report a bug?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              
              // Description
              Text(
                "If something isn't working correctly, you can report it to help improve ARC for everyone.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Description input
              TextField(
                controller: _descriptionController,
                focusNode: _focusNode,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe what happened...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: kcSurfaceAltColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kcAccentColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Include device info toggle
              Row(
                children: [
                  Checkbox(
                    value: _includeDeviceInfo,
                    onChanged: (value) {
                      setState(() => _includeDeviceInfo = value ?? true);
                    },
                    activeColor: kcAccentColor,
                  ),
                  Expanded(
                    child: Text(
                      'Include device info',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
              if (_includeDeviceInfo && _deviceInfo != null)
                Padding(
                  padding: const EdgeInsets.only(left: 48, bottom: 8),
                  child: Text(
                    '$_deviceInfo\n$_appVersion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Report bug',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Divider
              Divider(color: Colors.grey[800]),
              const SizedBox(height: 16),
              
              // Shake toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shake iPhone to report a bug',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toggle off to disable',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _shakeToReportEnabled,
                    onChanged: _toggleShakeToReport,
                    activeThumbColor: kcAccentColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Mixin to add shake detection to any StatefulWidget
mixin ShakeDetectorMixin<T extends StatefulWidget> on State<T> {
  late final _ShakeDetectorHelper _shakeHelper;
  
  @override
  void initState() {
    super.initState();
    _shakeHelper = _ShakeDetectorHelper(
      onShake: () => BugReportDialog.show(context),
    );
    _shakeHelper.init();
  }
  
  @override
  void dispose() {
    _shakeHelper.dispose();
    super.dispose();
  }
}

class _ShakeDetectorHelper {
  final VoidCallback onShake;
  
  _ShakeDetectorHelper({required this.onShake});
  
  void init() {
    // Initialize shake detection
    // This will be connected to the native shake detection
  }
  
  void dispose() {
    // Clean up
  }
}

