// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationPreferences _$NotificationPreferencesFromJson(
        Map<String, dynamic> json) =>
    NotificationPreferences(
      dailyEnabled: json['dailyEnabled'] as bool? ?? true,
      dailyTime: NotificationPreferences._timeFromJson(
          json['dailyTime'] as Map<String, dynamic>),
      monthlyEnabled: json['monthlyEnabled'] as bool? ?? true,
      monthlyDay: (json['monthlyDay'] as num?)?.toInt() ?? 1,
      sixMonthEnabled: json['sixMonthEnabled'] as bool? ?? true,
      yearlyEnabled: json['yearlyEnabled'] as bool? ?? true,
      allowTemporalCallbacks: json['allowTemporalCallbacks'] as bool? ?? true,
      quietStart: NotificationPreferences._timeFromJson(
          json['quietStart'] as Map<String, dynamic>),
      quietEnd: NotificationPreferences._timeFromJson(
          json['quietEnd'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$NotificationPreferencesToJson(
        NotificationPreferences instance) =>
    <String, dynamic>{
      'dailyEnabled': instance.dailyEnabled,
      'dailyTime': NotificationPreferences._timeToJson(instance.dailyTime),
      'monthlyEnabled': instance.monthlyEnabled,
      'monthlyDay': instance.monthlyDay,
      'sixMonthEnabled': instance.sixMonthEnabled,
      'yearlyEnabled': instance.yearlyEnabled,
      'allowTemporalCallbacks': instance.allowTemporalCallbacks,
      'quietStart': NotificationPreferences._timeToJson(instance.quietStart),
      'quietEnd': NotificationPreferences._timeToJson(instance.quietEnd),
    };
