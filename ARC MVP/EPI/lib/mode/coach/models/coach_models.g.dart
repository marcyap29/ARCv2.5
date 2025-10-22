// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DropletFieldAdapter extends TypeAdapter<DropletField> {
  @override
  final int typeId = 51;

  @override
  DropletField read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DropletField(
      id: fields[0] as String,
      type: fields[1] as DropletFieldType,
      label: fields[2] as String,
      help: fields[3] as String?,
      required: fields[4] as bool,
      options: (fields[5] as List?)?.cast<String>(),
      min: fields[6] as int?,
      max: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, DropletField obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.help)
      ..writeByte(4)
      ..write(obj.required)
      ..writeByte(5)
      ..write(obj.options)
      ..writeByte(6)
      ..write(obj.min)
      ..writeByte(7)
      ..write(obj.max);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropletFieldAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoachDropletTemplateAdapter extends TypeAdapter<CoachDropletTemplate> {
  @override
  final int typeId = 52;

  @override
  CoachDropletTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoachDropletTemplate(
      id: fields[0] as String,
      title: fields[1] as String,
      subtitle: fields[2] as String,
      fields: (fields[3] as List).cast<DropletField>(),
      tags: (fields[4] as List).cast<String>(),
      isDefault: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CoachDropletTemplate obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.subtitle)
      ..writeByte(3)
      ..write(obj.fields)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachDropletTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoachDropletResponseAdapter extends TypeAdapter<CoachDropletResponse> {
  @override
  final int typeId = 53;

  @override
  CoachDropletResponse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoachDropletResponse(
      id: fields[0] as String,
      templateId: fields[1] as String,
      createdAt: fields[2] as DateTime,
      values: (fields[3] as Map).cast<String, dynamic>(),
      includeInShare: fields[4] as bool,
      coachId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CoachDropletResponse obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.templateId)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.values)
      ..writeByte(4)
      ..write(obj.includeInShare)
      ..writeByte(5)
      ..write(obj.coachId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachDropletResponseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoachShareBundleAdapter extends TypeAdapter<CoachShareBundle> {
  @override
  final int typeId = 55;

  @override
  CoachShareBundle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoachShareBundle(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      dropletResponseIds: (fields[2] as List).cast<String>(),
      policy: fields[3] as SharePolicy,
      redactedFieldPaths: (fields[4] as List).cast<String>(),
      version: fields[5] as String,
      coachId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CoachShareBundle obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.dropletResponseIds)
      ..writeByte(3)
      ..write(obj.policy)
      ..writeByte(4)
      ..write(obj.redactedFieldPaths)
      ..writeByte(5)
      ..write(obj.version)
      ..writeByte(6)
      ..write(obj.coachId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachShareBundleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoachRecommendationAdapter extends TypeAdapter<CoachRecommendation> {
  @override
  final int typeId = 56;

  @override
  CoachRecommendation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoachRecommendation(
      id: fields[0] as String,
      title: fields[1] as String,
      why: fields[2] as String,
      steps: (fields[3] as List).cast<String>(),
      priority: fields[4] as String,
      durationMin: fields[5] as int?,
      tags: (fields[6] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, CoachRecommendation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.why)
      ..writeByte(3)
      ..write(obj.steps)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.durationMin)
      ..writeByte(6)
      ..write(obj.tags);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachRecommendationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoachRefAdapter extends TypeAdapter<CoachRef> {
  @override
  final int typeId = 57;

  @override
  CoachRef read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoachRef(
      displayName: fields[0] as String,
      coachId: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CoachRef obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.displayName)
      ..writeByte(1)
      ..write(obj.coachId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachRefAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReplyRefsAdapter extends TypeAdapter<ReplyRefs> {
  @override
  final int typeId = 58;

  @override
  ReplyRefs read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReplyRefs(
      csbId: fields[0] as String?,
      clientAlias: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReplyRefs obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.csbId)
      ..writeByte(1)
      ..write(obj.clientAlias);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplyRefsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CadenceAdapter extends TypeAdapter<Cadence> {
  @override
  final int typeId = 59;

  @override
  Cadence read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Cadence(
      checkIn: fields[0] as String,
      nextSessionPrompt: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Cadence obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.checkIn)
      ..writeByte(1)
      ..write(obj.nextSessionPrompt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CadenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoachReplyBundleAdapter extends TypeAdapter<CoachReplyBundle> {
  @override
  final int typeId = 60;

  @override
  CoachReplyBundle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoachReplyBundle(
      id: fields[0] as String,
      version: fields[1] as String,
      createdAt: fields[2] as DateTime,
      coach: fields[3] as CoachRef,
      references: fields[4] as ReplyRefs,
      recommendations: (fields[5] as List).cast<CoachRecommendation>(),
      cadence: fields[6] as Cadence?,
      notes: fields[7] as String?,
      attachments: (fields[8] as List?)?.cast<String>(),
      hash: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CoachReplyBundle obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.version)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.coach)
      ..writeByte(4)
      ..write(obj.references)
      ..writeByte(5)
      ..write(obj.recommendations)
      ..writeByte(6)
      ..write(obj.cadence)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.attachments)
      ..writeByte(9)
      ..write(obj.hash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachReplyBundleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DropletFieldTypeAdapter extends TypeAdapter<DropletFieldType> {
  @override
  final int typeId = 50;

  @override
  DropletFieldType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DropletFieldType.text;
      case 1:
        return DropletFieldType.multi;
      case 2:
        return DropletFieldType.scale;
      case 3:
        return DropletFieldType.bool;
      case 4:
        return DropletFieldType.chips;
      case 5:
        return DropletFieldType.date;
      case 6:
        return DropletFieldType.number;
      case 7:
        return DropletFieldType.time;
      case 8:
        return DropletFieldType.datetime;
      case 9:
        return DropletFieldType.image;
      default:
        return DropletFieldType.text;
    }
  }

  @override
  void write(BinaryWriter writer, DropletFieldType obj) {
    switch (obj) {
      case DropletFieldType.text:
        writer.writeByte(0);
        break;
      case DropletFieldType.multi:
        writer.writeByte(1);
        break;
      case DropletFieldType.scale:
        writer.writeByte(2);
        break;
      case DropletFieldType.bool:
        writer.writeByte(3);
        break;
      case DropletFieldType.chips:
        writer.writeByte(4);
        break;
      case DropletFieldType.date:
        writer.writeByte(5);
        break;
      case DropletFieldType.number:
        writer.writeByte(6);
        break;
      case DropletFieldType.time:
        writer.writeByte(7);
        break;
      case DropletFieldType.datetime:
        writer.writeByte(8);
        break;
      case DropletFieldType.image:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropletFieldTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SharePolicyAdapter extends TypeAdapter<SharePolicy> {
  @override
  final int typeId = 54;

  @override
  SharePolicy read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SharePolicy.redactableByUser;
      case 1:
        return SharePolicy.fullAccess;
      case 2:
        return SharePolicy.noShare;
      default:
        return SharePolicy.redactableByUser;
    }
  }

  @override
  void write(BinaryWriter writer, SharePolicy obj) {
    switch (obj) {
      case SharePolicy.redactableByUser:
        writer.writeByte(0);
        break;
      case SharePolicy.fullAccess:
        writer.writeByte(1);
        break;
      case SharePolicy.noShare:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharePolicyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
