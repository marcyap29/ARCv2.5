import 'dart:async';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'sync_models.dart';

class SyncService {
  static const String _boxName = 'sync_queue';
  static const int _maxRetries = 3;
  
  late Box<SyncItem> _queueBox;
  Timer? _workerTimer;
  final _uuid = const Uuid();
  
  // Stream controllers for real-time updates
  final StreamController<List<SyncItem>> _queueController = StreamController<List<SyncItem>>.broadcast();
  final StreamController<SyncState> _statusController = StreamController<SyncState>.broadcast();

  Stream<List<SyncItem>> get queueStream => _queueController.stream;
  Stream<SyncState> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    try {
      _queueBox = await Hive.openBox<SyncItem>(_boxName);
    } catch (e) {
      // Box might already be open, try to get it
      _queueBox = Hive.box<SyncItem>(_boxName);
    }
    _startWorker();
    _emitQueueUpdate();
  }

  /// Enqueue a new sync item
  Future<void> enqueue({
    required SyncKind kind,
    required String refId,
    Map<String, dynamic>? payload,
  }) async {
    final item = SyncItem(
      id: _uuid.v4(),
      kind: kind,
      refId: refId,
      createdAt: DateTime.now(),
      payload: payload ?? {},
    );

    await _queueBox.put(item.id, item);
    _emitQueueUpdate();
  }

  /// Get all queued items
  List<SyncItem> list() {
    return _queueBox.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get queued items count
  int get queuedCount {
    return _queueBox.values.where((item) => item.state == SyncState.queued).length;
  }

  /// Mark an item as done
  Future<void> markDone(String id) async {
    final item = _queueBox.get(id);
    if (item != null) {
      final updatedItem = item.copyWith(state: SyncState.done);
      await _queueBox.put(id, updatedItem);
      _emitQueueUpdate();
    }
  }

  /// Mark an item as failed
  Future<void> markFailed(String id) async {
    final item = _queueBox.get(id);
    if (item != null) {
      final updatedItem = item.copyWith(
        state: SyncState.failed,
        retries: item.retries + 1,
      );
      await _queueBox.put(id, updatedItem);
      _emitQueueUpdate();
    }
  }

  /// Clear all items from queue
  Future<void> clearAll() async {
    await _queueBox.clear();
    _emitQueueUpdate();
  }

  /// Clear completed items (keep queued and failed)
  Future<void> clearCompleted() async {
    final itemsToRemove = _queueBox.values
        .where((item) => item.state == SyncState.done)
        .map((item) => item.id)
        .toList();
    
    for (final id in itemsToRemove) {
      await _queueBox.delete(id);
    }
    _emitQueueUpdate();
  }

  /// Start the worker timer (simulates sync work)
  void _startWorker() {
    _workerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _processQueue();
    });
  }

  /// Process the queue (stub implementation)
  Future<void> _processQueue() async {
    final queuedItems = _queueBox.values
        .where((item) => item.state == SyncState.queued)
        .take(1) // Process one item at a time
        .toList();

    for (final item in queuedItems) {
      await _processItem(item);
    }
  }

  /// Process a single item (stub - just marks as done after delay)
  Future<void> _processItem(SyncItem item) async {
    // Mark as syncing
    final syncingItem = item.copyWith(state: SyncState.syncing);
    await _queueBox.put(item.id, syncingItem);
    _emitQueueUpdate();

    // Simulate work delay
    await Future.delayed(const Duration(seconds: 2));

    // In DEV mode, mark as done; in RELEASE, keep as queued
    const bool isDevMode = true; // TODO: Use kDebugMode or build config
    if (isDevMode) {
      await markDone(item.id);
    } else {
      // Keep as queued in release mode
      final queuedItem = item.copyWith(state: SyncState.queued);
      await _queueBox.put(item.id, queuedItem);
      _emitQueueUpdate();
    }
  }

  /// Emit queue update to stream
  void _emitQueueUpdate() {
    _queueController.add(list());
  }

  /// Dispose resources
  void dispose() {
    _workerTimer?.cancel();
    _queueController.close();
    _statusController.close();
  }
}
