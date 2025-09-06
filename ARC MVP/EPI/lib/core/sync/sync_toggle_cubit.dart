import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'sync_models.dart';
import 'sync_service.dart';

class SyncToggleState {
  final bool enabled;
  final String status;
  final int queuedCount;
  final bool isLoading;

  SyncToggleState({
    this.enabled = false,
    this.status = 'Sync off',
    this.queuedCount = 0,
    this.isLoading = false,
  });

  SyncToggleState copyWith({
    bool? enabled,
    String? status,
    int? queuedCount,
    bool? isLoading,
  }) {
    return SyncToggleState(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      queuedCount: queuedCount ?? this.queuedCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SyncToggleCubit extends Cubit<SyncToggleState> {
  static const String _settingsKey = 'sync_enabled';
  late Box _settingsBox;
  late SyncService _syncService;
  StreamSubscription? _queueSubscription;

  SyncToggleCubit() : super(SyncToggleState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    emit(state.copyWith(isLoading: true));
    
    try {
      // Initialize settings box
      _settingsBox = await Hive.openBox('settings');
      
      // Initialize sync service
      _syncService = SyncService();
      await _syncService.initialize();
      
      // Load saved enabled state
      final enabled = _settingsBox.get(_settingsKey, defaultValue: false) as bool;
      
      // Listen to queue changes
      _queueSubscription = _syncService.queueStream.listen((items) {
        _updateStatus(enabled, items);
      });
      
      // Initial status update
      _updateStatus(enabled, _syncService.list());
      
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      print('ERROR: Failed to initialize SyncToggleCubit: $e');
      // Fallback to disabled state
      emit(state.copyWith(
        isLoading: false,
        enabled: false,
        status: 'Sync off',
        queuedCount: 0,
      ));
    }
  }

  void _updateStatus(bool enabled, List<SyncItem> items) {
    final queuedCount = items.where((item) => item.state == SyncState.queued).length;
    final syncingCount = items.where((item) => item.state == SyncState.syncing).length;
    
    String status;
    if (!enabled) {
      status = 'Sync off';
    } else if (syncingCount > 0) {
      status = 'Syncing...';
    } else if (queuedCount > 0) {
      status = 'Queued $queuedCount';
    } else {
      status = 'Idle';
    }

    emit(state.copyWith(
      enabled: enabled,
      status: status,
      queuedCount: queuedCount,
    ));
  }

  Future<void> toggleSync(bool enabled) async {
    await _settingsBox.put(_settingsKey, enabled);
    _updateStatus(enabled, _syncService.list());
  }

  Future<void> clearQueue() async {
    await _syncService.clearAll();
  }

  Future<void> clearCompleted() async {
    await _syncService.clearCompleted();
  }

  @override
  Future<void> close() {
    _queueSubscription?.cancel();
    _syncService.dispose();
    return super.close();
  }
}
