import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'reflection_session.g.dart';

@HiveType(typeId: 125)
class ReflectionSession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String entryId;

  @HiveField(3)
  DateTime startTime;

  @HiveField(4)
  List<ReflectionExchange> exchanges;

  @HiveField(5)
  DateTime? pausedUntil;

  ReflectionSession({
    required this.id,
    required this.userId,
    required this.entryId,
    required this.startTime,
    List<ReflectionExchange>? exchanges,
    this.pausedUntil,
  }) : exchanges = exchanges ?? [];

  factory ReflectionSession.create({
    required String userId,
    required String entryId,
  }) {
    return ReflectionSession(
      id: Uuid().v4(),
      userId: userId,
      entryId: entryId,
      startTime: DateTime.now(),
    );
  }

  bool get isPaused =>
      pausedUntil != null && DateTime.now().isBefore(pausedUntil!);
}

@HiveType(typeId: 126)
class ReflectionExchange extends HiveObject {
  @HiveField(0)
  DateTime timestamp;

  @HiveField(1)
  String userQuery;

  @HiveField(2)
  String lumaraResponse;

  @HiveField(3)
  bool citedChronicle;

  ReflectionExchange({
    required this.timestamp,
    required this.userQuery,
    required this.lumaraResponse,
    required this.citedChronicle,
  });
}
