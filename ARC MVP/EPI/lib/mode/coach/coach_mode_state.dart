import 'package:equatable/equatable.dart';
import 'models/coach_models.dart';

abstract class CoachModeState extends Equatable {
  const CoachModeState();

  @override
  List<Object?> get props => [];
}

class CoachModeInitial extends CoachModeState {
  const CoachModeInitial();
}

class CoachModeEnabled extends CoachModeState {
  final bool enabled;
  final bool suggestionCooldown;
  final String? activeDropletId;
  final int pendingShareCount;
  final List<CoachDropletTemplate> availableTemplates;
  final List<CoachDropletResponse> recentResponses;

  const CoachModeEnabled({
    required this.enabled,
    this.suggestionCooldown = false,
    this.activeDropletId,
    this.pendingShareCount = 0,
    this.availableTemplates = const [],
    this.recentResponses = const [],
  });

  CoachModeEnabled copyWith({
    bool? enabled,
    bool? suggestionCooldown,
    String? activeDropletId,
    int? pendingShareCount,
    List<CoachDropletTemplate>? availableTemplates,
    List<CoachDropletResponse>? recentResponses,
  }) {
    return CoachModeEnabled(
      enabled: enabled ?? this.enabled,
      suggestionCooldown: suggestionCooldown ?? this.suggestionCooldown,
      activeDropletId: activeDropletId ?? this.activeDropletId,
      pendingShareCount: pendingShareCount ?? this.pendingShareCount,
      availableTemplates: availableTemplates ?? this.availableTemplates,
      recentResponses: recentResponses ?? this.recentResponses,
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        suggestionCooldown,
        activeDropletId,
        pendingShareCount,
        availableTemplates,
        recentResponses,
      ];
}

class CoachModeLoading extends CoachModeState {
  const CoachModeLoading();
}

class CoachModeError extends CoachModeState {
  final String message;

  const CoachModeError(this.message);

  @override
  List<Object?> get props => [message];
}
