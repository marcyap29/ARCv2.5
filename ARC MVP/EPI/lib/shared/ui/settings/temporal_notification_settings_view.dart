// lib/shared/ui/settings/temporal_notification_settings_view.dart
// UI for configuring temporal notification preferences

import 'package:flutter/material.dart';
import 'package:my_app/models/temporal_notifications/notification_preferences.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/services/temporal_notification_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';

class TemporalNotificationSettingsView extends StatefulWidget {
  const TemporalNotificationSettingsView({super.key});

  @override
  State<TemporalNotificationSettingsView> createState() => _TemporalNotificationSettingsViewState();
}

class _TemporalNotificationSettingsViewState extends State<TemporalNotificationSettingsView> {
  NotificationPreferences? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await NotificationPreferences.load();
      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading preferences: $e')),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    if (_preferences == null) return;

    setState(() => _isSaving = true);
    try {
      await _preferences!.save();
      
      // Reschedule notifications with new preferences
      final userId = FirebaseAuthService().currentUser?.uid;
      if (userId != null) {
        await TemporalNotificationService().scheduleNotifications(userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay initialTime, Function(TimeOfDay) onTimeSelected) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null && _preferences != null) {
      setState(() {
        onTimeSelected(picked);
      });
      await _savePreferences();
    }
  }

  Future<void> _selectMonthlyDay() async {
    if (_preferences == null) return;

    final days = List.generate(28, (i) => i + 1); // Days 1-28 (safe for all months)
    final selectedDay = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Day of Month'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return ListTile(
                title: Text('Day $day'),
                selected: day == _preferences!.monthlyDay,
                onTap: () => Navigator.pop(context, day),
              );
            },
          ),
        ),
      ),
    );

    if (selectedDay != null) {
      setState(() {
        _preferences = _preferences!.copyWith(monthlyDay: selectedDay);
      });
      await _savePreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kcBackgroundColor,
        appBar: AppBar(
          backgroundColor: kcBackgroundColor,
          title: Text('Temporal Notifications', style: heading1Style(context)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_preferences == null) {
      return Scaffold(
        backgroundColor: kcBackgroundColor,
        appBar: AppBar(
          backgroundColor: kcBackgroundColor,
          title: Text('Temporal Notifications', style: heading1Style(context)),
        ),
        body: Center(
          child: Text('Error loading preferences', style: bodyStyle(context)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        title: Text('Temporal Notifications', style: heading1Style(context)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure when ARC surfaces insights and reflections',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),

            // Daily Resonance Prompts
            _buildNotificationCard(
              title: 'Daily Resonance Prompts',
              description: 'Surface relevant themes, callbacks, and patterns',
              enabled: _preferences!.dailyEnabled,
              onToggle: (value) {
                setState(() {
                  _preferences = _preferences!.copyWith(dailyEnabled: value);
                });
                _savePreferences();
              },
              child: _preferences!.dailyEnabled
                  ? ListTile(
                      title: Text('Time', style: bodyStyle(context)),
                      trailing: TextButton(
                        onPressed: () => _selectTime(
                          context,
                          _preferences!.dailyTime,
                          (time) => _preferences = _preferences!.copyWith(dailyTime: time),
                        ),
                        child: Text(
                          _preferences!.dailyTime.format(context),
                          style: bodyStyle(context).copyWith(color: kcPrimaryColor),
                        ),
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: 16),

            // Monthly Thread Review
            _buildNotificationCard(
              title: 'Monthly Thread Review',
              description: 'Synthesize emotional threads and phase status',
              enabled: _preferences!.monthlyEnabled,
              onToggle: (value) {
                setState(() {
                  _preferences = _preferences!.copyWith(monthlyEnabled: value);
                });
                _savePreferences();
              },
              child: _preferences!.monthlyEnabled
                  ? ListTile(
                      title: Text('Day of Month', style: bodyStyle(context)),
                      trailing: TextButton(
                        onPressed: _selectMonthlyDay,
                        child: Text(
                          'Day ${_preferences!.monthlyDay}',
                          style: bodyStyle(context).copyWith(color: kcPrimaryColor),
                        ),
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: 16),

            // 6-Month Arc View
            _buildNotificationCard(
              title: '6-Month Arc View',
              description: 'Show developmental trajectory with phase visualization',
              enabled: _preferences!.sixMonthEnabled,
              onToggle: (value) {
                setState(() {
                  _preferences = _preferences!.copyWith(sixMonthEnabled: value);
                });
                _savePreferences();
              },
            ),

            const SizedBox(height: 16),

            // Yearly Becoming Summary
            _buildNotificationCard(
              title: 'Yearly Becoming Summary',
              description: 'Full narrative of transformation',
              enabled: _preferences!.yearlyEnabled,
              onToggle: (value) {
                setState(() {
                  _preferences = _preferences!.copyWith(yearlyEnabled: value);
                });
                _savePreferences();
              },
            ),

            const SizedBox(height: 24),

            // Temporal Callbacks
            _buildNotificationCard(
              title: 'Temporal Callbacks',
              description: 'Allow "X days ago" style notifications',
              enabled: _preferences!.allowTemporalCallbacks,
              onToggle: (value) {
                setState(() {
                  _preferences = _preferences!.copyWith(allowTemporalCallbacks: value);
                });
                _savePreferences();
              },
            ),

            const SizedBox(height: 24),

            // Quiet Hours
            Card(
              color: kcSurfaceAltColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiet Hours',
                      style: heading2Style(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notifications will not be sent during these hours',
                      style: captionStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Start', style: bodyStyle(context)),
                      trailing: TextButton(
                        onPressed: () => _selectTime(
                          context,
                          _preferences!.quietStart,
                          (time) => _preferences = _preferences!.copyWith(quietStart: time),
                        ),
                        child: Text(
                          _preferences!.quietStart.format(context),
                          style: bodyStyle(context).copyWith(color: kcPrimaryColor),
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text('End', style: bodyStyle(context)),
                      trailing: TextButton(
                        onPressed: () => _selectTime(
                          context,
                          _preferences!.quietEnd,
                          (time) => _preferences = _preferences!.copyWith(quietEnd: time),
                        ),
                        child: Text(
                          _preferences!.quietEnd.format(context),
                          style: bodyStyle(context).copyWith(color: kcPrimaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String description,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    Widget? child,
  }) {
    return Card(
      color: kcSurfaceAltColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: heading2Style(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: kcPrimaryColor,
                ),
              ],
            ),
            if (child != null) ...[
              const Divider(height: 24),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

