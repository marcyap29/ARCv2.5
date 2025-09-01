// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 2;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      createdAt: fields[3] as DateTime,
      preferences: (fields[4] as Map).cast<String, dynamic>(),
      onboardingPurpose: fields[5] as String?,
      onboardingFeeling: fields[6] as String?,
      onboardingRhythm: fields[7] as String?,
      onboardingCompleted: fields[8] as bool,
      onboardingCurrentSeason: fields[9] as String?,
      onboardingCentralWord: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.preferences)
      ..writeByte(5)
      ..write(obj.onboardingPurpose)
      ..writeByte(6)
      ..write(obj.onboardingFeeling)
      ..writeByte(7)
      ..write(obj.onboardingRhythm)
      ..writeByte(8)
      ..write(obj.onboardingCompleted)
      ..writeByte(9)
      ..write(obj.onboardingCurrentSeason)
      ..writeByte(10)
      ..write(obj.onboardingCentralWord);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
