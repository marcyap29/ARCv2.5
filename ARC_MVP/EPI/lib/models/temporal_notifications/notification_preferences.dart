// lib/models/temporal_notifications/notification_preferences.dart
// Model for notification preferences

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_preferences.g.dart';

@JsonSerializable()
class NotificationPreferences {
  final bool dailyEnabled;
  @JsonKey(fromJson: _timeFromJson, toJson: _timeToJson)
  final TimeOfDay dailyTime;          // Default: 9:00 AM
  final bool monthlyEnabled;
  final int monthlyDay;               // Day of month, default: 1
  final bool sixMonthEnabled;
  final bool yearlyEnabled;
  final bool allowTemporalCallbacks;  // "X days ago" style notifications
  
  // Quiet hours
  @JsonKey(fromJson: _timeFromJson, toJson: _timeToJson)
  final TimeOfDay quietStart;
  @JsonKey(fromJson: _timeFromJson, toJson: _timeToJson)
  final TimeOfDay quietEnd;

  NotificationPreferences({
    this.dailyEnabled = true,
    TimeOfDay? dailyTime,
    this.monthlyEnabled = true,
    this.monthlyDay = 1,
    this.sixMonthEnabled = true,
    this.yearlyEnabled = true,
    this.allowTemporalCallbacks = true,
    TimeOfDay? quietStart,
    TimeOfDay? quietEnd,
  })  : dailyTime = dailyTime ?? const TimeOfDay(hour: 9, minute: 0),
        quietStart = quietStart ?? const TimeOfDay(hour: 22, minute: 0),
        quietEnd = quietEnd ?? const TimeOfDay(hour: 7, minute: 0);

  static TimeOfDay _timeFromJson(Map<String, dynamic> json) =>
      TimeOfDay(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );

  static Map<String, dynamic> _timeToJson(TimeOfDay time) =>
      {'hour': time.hour, 'minute': time.minute};

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationPreferencesToJson(this);

  NotificationPreferences copyWith({
    bool? dailyEnabled,
    TimeOfDay? dailyTime,
    bool? monthlyEnabled,
    int? monthlyDay,
    bool? sixMonthEnabled,
    bool? yearlyEnabled,
    bool? allowTemporalCallbacks,
    TimeOfDay? quietStart,
    TimeOfDay? quietEnd,
  }) {
    return NotificationPreferences(
      dailyEnabled: dailyEnabled ?? this.dailyEnabled,
      dailyTime: dailyTime ?? this.dailyTime,
      monthlyEnabled: monthlyEnabled ?? this.monthlyEnabled,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      sixMonthEnabled: sixMonthEnabled ?? this.sixMonthEnabled,
      yearlyEnabled: yearlyEnabled ?? this.yearlyEnabled,
      allowTemporalCallbacks: allowTemporalCallbacks ?? this.allowTemporalCallbacks,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }

  // Load from SharedPreferences
  static Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('notification_preferences');
    if (jsonString == null) {
      return NotificationPreferences(); // Defaults
    }
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(json);
    } catch (e) {
      return NotificationPreferences(); // Defaults on error
    }
  }

  // Save to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(toJson());
    await prefs.setString('notification_preferences', jsonString);
  }
}

