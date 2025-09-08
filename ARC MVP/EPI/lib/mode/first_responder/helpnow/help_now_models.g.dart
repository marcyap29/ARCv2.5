// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'help_now_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HelpNowContactAdapter extends TypeAdapter<HelpNowContact> {
  @override
  final int typeId = 52;

  @override
  HelpNowContact read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HelpNowContact(
      id: fields[0] as String,
      name: fields[1] as String,
      phoneNumber: fields[2] as String,
      email: fields[3] as String?,
      type: fields[4] as ContactType,
      notes: fields[5] as String?,
      isActive: fields[6] as bool,
      priority: fields[7] as int,
      createdAt: fields[8] as DateTime,
      lastUsed: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HelpNowContact obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phoneNumber)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.priority)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.lastUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HelpNowContactAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NationalResourceAdapter extends TypeAdapter<NationalResource> {
  @override
  final int typeId = 54;

  @override
  NationalResource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NationalResource(
      id: fields[0] as String,
      name: fields[1] as String,
      phoneNumber: fields[2] as String,
      website: fields[3] as String?,
      description: fields[4] as String,
      type: fields[5] as ResourceType,
      is24Hour: fields[6] as bool,
      specialties: (fields[7] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, NationalResource obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phoneNumber)
      ..writeByte(3)
      ..write(obj.website)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.is24Hour)
      ..writeByte(7)
      ..write(obj.specialties);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NationalResourceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HelpNowSettingsAdapter extends TypeAdapter<HelpNowSettings> {
  @override
  final int typeId = 56;

  @override
  HelpNowSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HelpNowSettings(
      showDisclaimer: fields[0] as bool,
      requireConfirmation: fields[1] as bool,
      customDisclaimer: fields[2] as String,
      quickAccessContacts: (fields[3] as List).cast<String>(),
      showNationalResources: fields[4] as bool,
      showEmergencyWarning: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HelpNowSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.showDisclaimer)
      ..writeByte(1)
      ..write(obj.requireConfirmation)
      ..writeByte(2)
      ..write(obj.customDisclaimer)
      ..writeByte(3)
      ..write(obj.quickAccessContacts)
      ..writeByte(4)
      ..write(obj.showNationalResources)
      ..writeByte(5)
      ..write(obj.showEmergencyWarning);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HelpNowSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContactTypeAdapter extends TypeAdapter<ContactType> {
  @override
  final int typeId = 53;

  @override
  ContactType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ContactType.peer;
      case 1:
        return ContactType.supervisor;
      case 2:
        return ContactType.counselor;
      case 3:
        return ContactType.family;
      case 4:
        return ContactType.friend;
      case 5:
        return ContactType.emergency;
      case 6:
        return ContactType.other;
      default:
        return ContactType.peer;
    }
  }

  @override
  void write(BinaryWriter writer, ContactType obj) {
    switch (obj) {
      case ContactType.peer:
        writer.writeByte(0);
        break;
      case ContactType.supervisor:
        writer.writeByte(1);
        break;
      case ContactType.counselor:
        writer.writeByte(2);
        break;
      case ContactType.family:
        writer.writeByte(3);
        break;
      case ContactType.friend:
        writer.writeByte(4);
        break;
      case ContactType.emergency:
        writer.writeByte(5);
        break;
      case ContactType.other:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ResourceTypeAdapter extends TypeAdapter<ResourceType> {
  @override
  final int typeId = 55;

  @override
  ResourceType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ResourceType.crisis;
      case 1:
        return ResourceType.peerSupport;
      case 2:
        return ResourceType.professional;
      case 3:
        return ResourceType.emergency;
      case 4:
        return ResourceType.information;
      default:
        return ResourceType.crisis;
    }
  }

  @override
  void write(BinaryWriter writer, ResourceType obj) {
    switch (obj) {
      case ResourceType.crisis:
        writer.writeByte(0);
        break;
      case ResourceType.peerSupport:
        writer.writeByte(1);
        break;
      case ResourceType.professional:
        writer.writeByte(2);
        break;
      case ResourceType.emergency:
        writer.writeByte(3);
        break;
      case ResourceType.information:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
