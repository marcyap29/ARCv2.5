import 'package:hive/hive.dart';
import 'sync_models.dart';

class SyncItemAdapter extends TypeAdapter<SyncItem> {
  @override
  final int typeId = 100; // Use a unique type ID

  @override
  SyncItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncItem(
      id: fields[0] as String,
      kind: SyncKind.values[fields[1] as int],
      refId: fields[2] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      retries: fields[4] as int,
      state: SyncState.values[fields[5] as int],
      payload: Map<String, dynamic>.from(fields[6] as Map),
    );
  }

  @override
  void write(BinaryWriter writer, SyncItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.kind.index)
      ..writeByte(2)
      ..write(obj.refId)
      ..writeByte(3)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(4)
      ..write(obj.retries)
      ..writeByte(5)
      ..write(obj.state.index)
      ..writeByte(6)
      ..write(obj.payload);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
