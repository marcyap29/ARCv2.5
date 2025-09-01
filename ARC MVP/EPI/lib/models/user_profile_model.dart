import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'user_profile_model.g.dart';

@HiveType(typeId: 2)
class UserProfile extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final Map<String, dynamic> preferences;

  // Onboarding fields
  @HiveField(5)
  final String? onboardingPurpose;

  @HiveField(6)
  final String? onboardingFeeling;

  @HiveField(7)
  final String? onboardingRhythm;

  @HiveField(8)
  final bool onboardingCompleted;

  @HiveField(9)
  final String? onboardingCurrentSeason;

  @HiveField(10)
  final String? onboardingCentralWord;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    required this.preferences,
    this.onboardingPurpose,
    this.onboardingFeeling,
    this.onboardingRhythm,
    this.onboardingCompleted = false,
    this.onboardingCurrentSeason,
    this.onboardingCentralWord,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? createdAt,
    Map<String, dynamic>? preferences,
    String? onboardingPurpose,
    String? onboardingFeeling,
    String? onboardingRhythm,
    bool? onboardingCompleted,
    String? onboardingCurrentSeason,
    String? onboardingCentralWord,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
      onboardingPurpose: onboardingPurpose ?? this.onboardingPurpose,
      onboardingFeeling: onboardingFeeling ?? this.onboardingFeeling,
      onboardingRhythm: onboardingRhythm ?? this.onboardingRhythm,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingCurrentSeason: onboardingCurrentSeason ?? this.onboardingCurrentSeason,
      onboardingCentralWord: onboardingCentralWord ?? this.onboardingCentralWord,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        createdAt,
        preferences,
        onboardingPurpose,
        onboardingFeeling,
        onboardingRhythm,
        onboardingCompleted,
        onboardingCurrentSeason,
        onboardingCentralWord,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'preferences': preferences,
      'onboardingPurpose': onboardingPurpose,
      'onboardingFeeling': onboardingFeeling,
      'onboardingRhythm': onboardingRhythm,
      'onboardingCompleted': onboardingCompleted,
      'onboardingCurrentSeason': onboardingCurrentSeason,
      'onboardingCentralWord': onboardingCentralWord,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      preferences: json['preferences'] as Map<String, dynamic>,
      onboardingPurpose: json['onboardingPurpose'] as String?,
      onboardingFeeling: json['onboardingFeeling'] as String?,
      onboardingRhythm: json['onboardingRhythm'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      onboardingCurrentSeason: json['onboardingCurrentSeason'] as String?,
      onboardingCentralWord: json['onboardingCentralWord'] as String?,
    );
  }
}
