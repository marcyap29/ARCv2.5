import 'package:hive/hive.dart';

/// Hive TypeAdapter for [Duration]. Required so that [MediaItem] with
/// [MediaItem.duration] (e.g. video entries) can be saved and loaded.
/// Without this, entries containing video fail to serialize/deserialize.
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 105;

  @override
  Duration read(BinaryReader reader) {
    return Duration(microseconds: reader.readInt());
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}
