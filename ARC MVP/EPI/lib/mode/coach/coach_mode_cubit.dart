import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'coach_mode_state.dart';
import 'models/coach_models.dart';
import 'coach_droplet_service.dart';
import 'coach_share_service.dart';

class CoachModeCubit extends Cubit<CoachModeState> {
  final CoachDropletService _dropletService;
  final CoachShareService _shareService;
  final Box _settingsBox;
  // final Uuid _uuid;

  CoachModeCubit({
    required CoachDropletService dropletService,
    required CoachShareService shareService,
    required Box settingsBox,
    Uuid? uuid,
  })  : _dropletService = dropletService,
        _shareService = shareService,
        _settingsBox = settingsBox,
        super(const CoachModeInitial()) {
    _initialize();
  }

  void _initialize() async {
    emit(const CoachModeLoading());
    
    try {
      final enabled = _settingsBox.get('coach_mode_enabled', defaultValue: false) as bool;
      final suggestionCooldown = _settingsBox.get('coach_suggestion_cooldown', defaultValue: false) as bool;
      final templates = await _dropletService.getAvailableTemplates();
      final recentResponses = await _dropletService.getRecentResponses(limit: 10);
      final pendingShareCount = await _shareService.getPendingShareCount();

      emit(CoachModeEnabled(
        enabled: enabled,
        suggestionCooldown: suggestionCooldown,
        availableTemplates: templates,
        recentResponses: recentResponses,
        pendingShareCount: pendingShareCount,
      ));
    } catch (e) {
      emit(CoachModeError('Failed to initialize Coach Mode: $e'));
    }
  }

  Future<void> enable() async {
    try {
      await _settingsBox.put('coach_mode_enabled', true);
      final currentState = state;
      if (currentState is CoachModeEnabled) {
        emit(currentState.copyWith(enabled: true));
      }
    } catch (e) {
      emit(CoachModeError('Failed to enable Coach Mode: $e'));
    }
  }

  Future<void> disable() async {
    try {
      await _settingsBox.put('coach_mode_enabled', false);
      final currentState = state;
      if (currentState is CoachModeEnabled) {
        emit(currentState.copyWith(enabled: false));
      }
    } catch (e) {
      emit(CoachModeError('Failed to disable Coach Mode: $e'));
    }
  }

  Future<void> openDrawer() async {
    final currentState = state;
    if (currentState is CoachModeEnabled && currentState.enabled) {
      // Drawer opening logic handled by UI
      emit(currentState);
    }
  }

  Future<void> markSuggestionShown() async {
    try {
      await _settingsBox.put('coach_suggestion_cooldown', true);
      final currentState = state;
      if (currentState is CoachModeEnabled) {
        emit(currentState.copyWith(suggestionCooldown: true));
      }
    } catch (e) {
      emit(CoachModeError('Failed to mark suggestion shown: $e'));
    }
  }

  Future<void> resetSuggestionCooldown() async {
    try {
      await _settingsBox.put('coach_suggestion_cooldown', false);
      final currentState = state;
      if (currentState is CoachModeEnabled) {
        emit(currentState.copyWith(suggestionCooldown: false));
      }
    } catch (e) {
      emit(CoachModeError('Failed to reset suggestion cooldown: $e'));
    }
  }

  Future<void> startDroplet(String templateId) async {
    try {
      final currentState = state;
      if (currentState is CoachModeEnabled) {
        emit(currentState.copyWith(activeDropletId: templateId));
      }
    } catch (e) {
      emit(CoachModeError('Failed to start droplet: $e'));
    }
  }

  Future<void> completeDroplet(CoachDropletResponse response) async {
    try {
      await _dropletService.saveResponse(response);
      await refreshState();
    } catch (e) {
      emit(CoachModeError('Failed to complete droplet: $e'));
    }
  }

  Future<void> refreshState() async {
    try {
      final currentState = state;
      if (currentState is CoachModeEnabled) {
        final templates = await _dropletService.getAvailableTemplates();
        final recentResponses = await _dropletService.getRecentResponses(limit: 10);
        final pendingShareCount = await _shareService.getPendingShareCount();

        emit(currentState.copyWith(
          availableTemplates: templates,
          recentResponses: recentResponses,
          pendingShareCount: pendingShareCount,
        ));
      }
    } catch (e) {
      emit(CoachModeError('Failed to refresh state: $e'));
    }
  }

  Future<void> exportShareBundle() async {
    try {
      await _shareService.exportShareBundle();
      await refreshState();
    } catch (e) {
      emit(CoachModeError('Failed to export share bundle: $e'));
    }
  }

  Future<void> importCoachReply(String filePath) async {
    try {
      await _shareService.importCoachReply(filePath);
      await refreshState();
    } catch (e) {
      emit(CoachModeError('Failed to import coach reply: $e'));
    }
  }
}
