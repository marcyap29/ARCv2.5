import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

// part 'coach_models.g.dart';

@HiveType(typeId: 50)
enum DropletFieldType {
  @HiveField(0)
  text,
  @HiveField(1)
  multi,
  @HiveField(2)
  scale,
  @HiveField(3)
  bool,
  @HiveField(4)
  chips,
  @HiveField(5)
  date,
  @HiveField(6)
  number,
  @HiveField(7)
  time,
  @HiveField(8)
  datetime,
  @HiveField(9)
  image,
}

@HiveType(typeId: 51)
class DropletField extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DropletFieldType type;
  @HiveField(2)
  final String label;
  @HiveField(3)
  final String? help;
  @HiveField(4)
  final bool required;
  @HiveField(5)
  final List<String>? options;
  @HiveField(6)
  final int? min;
  @HiveField(7)
  final int? max;

  const DropletField({
    required this.id,
    required this.type,
    required this.label,
    this.help,
    this.required = false,
    this.options,
    this.min,
    this.max,
  });

  @override
  List<Object?> get props => [id, type, label, help, required, options, min, max];
}

@HiveType(typeId: 52)
class CoachDropletTemplate extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String subtitle;
  @HiveField(3)
  final List<DropletField> fields;
  @HiveField(4)
  final List<String> tags;
  @HiveField(5)
  final bool isDefault;

  const CoachDropletTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.tags,
    this.isDefault = false,
  });

  @override
  List<Object?> get props => [id, title, subtitle, fields, tags, isDefault];
}

@HiveType(typeId: 53)
class CoachDropletResponse extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String templateId;
  @HiveField(2)
  final DateTime createdAt;
  @HiveField(3)
  final Map<String, dynamic> values;
  @HiveField(4)
  final bool includeInShare;
  @HiveField(5)
  final String? coachId;

  const CoachDropletResponse({
    required this.id,
    required this.templateId,
    required this.createdAt,
    required this.values,
    this.includeInShare = false,
    this.coachId,
  });

  CoachDropletResponse copyWith({
    String? id,
    String? templateId,
    DateTime? createdAt,
    Map<String, dynamic>? values,
    bool? includeInShare,
    String? coachId,
  }) {
    return CoachDropletResponse(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
      values: values ?? this.values,
      includeInShare: includeInShare ?? this.includeInShare,
      coachId: coachId ?? this.coachId,
    );
  }

  @override
  List<Object?> get props => [id, templateId, createdAt, values, includeInShare, coachId];
}

@HiveType(typeId: 54)
enum SharePolicy {
  @HiveField(0)
  redactableByUser,
  @HiveField(1)
  fullAccess,
  @HiveField(2)
  noShare,
}

@HiveType(typeId: 55)
class CoachShareBundle extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime createdAt;
  @HiveField(2)
  final List<String> dropletResponseIds;
  @HiveField(3)
  final SharePolicy policy;
  @HiveField(4)
  final List<String> redactedFieldPaths;
  @HiveField(5)
  final String version;
  @HiveField(6)
  final String? coachId;

  const CoachShareBundle({
    required this.id,
    required this.createdAt,
    required this.dropletResponseIds,
    required this.policy,
    required this.redactedFieldPaths,
    required this.version,
    this.coachId,
  });

  @override
  List<Object?> get props => [id, createdAt, dropletResponseIds, policy, redactedFieldPaths, version, coachId];
}

@HiveType(typeId: 56)
class CoachRecommendation extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String why;
  @HiveField(3)
  final List<String> steps;
  @HiveField(4)
  final String priority;
  @HiveField(5)
  final int? durationMin;
  @HiveField(6)
  final List<String>? tags;

  const CoachRecommendation({
    required this.id,
    required this.title,
    required this.why,
    required this.steps,
    required this.priority,
    this.durationMin,
    this.tags,
  });

  @override
  List<Object?> get props => [id, title, why, steps, priority, durationMin, tags];
}

@HiveType(typeId: 57)
class CoachRef extends Equatable {
  @HiveField(0)
  final String displayName;
  @HiveField(1)
  final String? coachId;

  const CoachRef({
    required this.displayName,
    this.coachId,
  });

  @override
  List<Object?> get props => [displayName, coachId];
}

@HiveType(typeId: 58)
class ReplyRefs extends Equatable {
  @HiveField(0)
  final String? csbId;
  @HiveField(1)
  final String? clientAlias;

  const ReplyRefs({
    this.csbId,
    this.clientAlias,
  });

  @override
  List<Object?> get props => [csbId, clientAlias];
}

@HiveType(typeId: 59)
class Cadence extends Equatable {
  @HiveField(0)
  final String checkIn;
  @HiveField(1)
  final String? nextSessionPrompt;

  const Cadence({
    required this.checkIn,
    this.nextSessionPrompt,
  });

  @override
  List<Object?> get props => [checkIn, nextSessionPrompt];
}

@HiveType(typeId: 60)
class CoachReplyBundle extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String version;
  @HiveField(2)
  final DateTime createdAt;
  @HiveField(3)
  final CoachRef coach;
  @HiveField(4)
  final ReplyRefs references;
  @HiveField(5)
  final List<CoachRecommendation> recommendations;
  @HiveField(6)
  final Cadence? cadence;
  @HiveField(7)
  final String? notes;
  @HiveField(8)
  final List<String>? attachments;
  @HiveField(9)
  final String? hash;

  const CoachReplyBundle({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.coach,
    required this.references,
    required this.recommendations,
    this.cadence,
    this.notes,
    this.attachments,
    this.hash,
  });

  @override
  List<Object?> get props => [id, version, createdAt, coach, references, recommendations, cadence, notes, attachments, hash];
}
