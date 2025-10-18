// lib/mira/sync/crdt_sync.dart
// CRDT-lite Sync and Concurrency for MIRA Memory
// Implements last-writer-wins for scalars, set-merge for tags, additive edges

import '../../lumara/chat/ulid.dart';

/// Device information for sync operations
class DeviceInfo {
  final String deviceId;
  final String deviceType;
  final String appVersion;
  final DateTime lastSync;
  final int monotonicTick;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceType,
    required this.appVersion,
    required this.lastSync,
    required this.monotonicTick,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'device_type': deviceType,
    'app_version': appVersion,
    'last_sync': lastSync.toUtc().toIso8601String(),
    'monotonic_tick': monotonicTick,
  };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    deviceId: json['device_id'] as String,
    deviceType: json['device_type'] as String,
    appVersion: json['app_version'] as String,
    lastSync: DateTime.parse(json['last_sync'] as String),
    monotonicTick: json['monotonic_tick'] as int,
  );
}

/// Sync operation with device context
class SyncOperation {
  final String id;
  final String operationType; // create, update, delete, merge
  final String objectId;
  final String objectType; // node, edge, pointer
  final Map<String, dynamic> data;
  final DeviceInfo deviceInfo;
  final DateTime wallTime;
  final int deviceTick;
  final String? parentOperationId;
  final Map<String, dynamic> metadata;

  const SyncOperation({
    required this.id,
    required this.operationType,
    required this.objectId,
    required this.objectType,
    required this.data,
    required this.deviceInfo,
    required this.wallTime,
    required this.deviceTick,
    this.parentOperationId,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation_type': operationType,
    'object_id': objectId,
    'object_type': objectType,
    'data': data,
    'device_info': deviceInfo.toJson(),
    'wall_time': wallTime.toUtc().toIso8601String(),
    'device_tick': deviceTick,
    if (parentOperationId != null) 'parent_operation_id': parentOperationId,
    'metadata': metadata,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'] as String,
    operationType: json['operation_type'] as String,
    objectId: json['object_id'] as String,
    objectType: json['object_type'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    deviceInfo: DeviceInfo.fromJson(json['device_info'] as Map<String, dynamic>),
    wallTime: DateTime.parse(json['wall_time'] as String),
    deviceTick: json['device_tick'] as int,
    parentOperationId: json['parent_operation_id'] as String?,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

/// Sync conflict resolution result
class SyncConflictResult {
  final bool hasConflict;
  final String? conflictType;
  final String? resolutionStrategy;
  final Map<String, dynamic>? resolvedData;
  final List<String>? conflicts;

  const SyncConflictResult({
    required this.hasConflict,
    this.conflictType,
    this.resolutionStrategy,
    this.resolvedData,
    this.conflicts,
  });

  Map<String, dynamic> toJson() => {
    'has_conflict': hasConflict,
    if (conflictType != null) 'conflict_type': conflictType,
    if (resolutionStrategy != null) 'resolution_strategy': resolutionStrategy,
    if (resolvedData != null) 'resolved_data': resolvedData,
    if (conflicts != null) 'conflicts': conflicts,
  };
}

/// CRDT-lite sync engine
class CrdtSyncEngine {
  final String _deviceId;
  final String _deviceType;
  final String _appVersion;
  int _monotonicTick;
  final Map<String, SyncOperation> _pendingOperations;
  final Map<String, DeviceInfo> _knownDevices;

  CrdtSyncEngine({
    required String deviceId,
    required String deviceType,
    required String appVersion,
  }) : _deviceId = deviceId,
       _deviceType = deviceType,
       _appVersion = appVersion,
       _monotonicTick = 0,
       _pendingOperations = {},
       _knownDevices = {};

  /// Create a sync operation
  SyncOperation createOperation({
    required String operationType,
    required String objectId,
    required String objectType,
    required Map<String, dynamic> data,
    String? parentOperationId,
    Map<String, dynamic>? metadata,
  }) {
    _monotonicTick++;
    
    final deviceInfo = DeviceInfo(
      deviceId: _deviceId,
      deviceType: _deviceType,
      appVersion: _appVersion,
      lastSync: DateTime.now().toUtc(),
      monotonicTick: _monotonicTick,
    );

    final operation = SyncOperation(
      id: ULID.generate(),
      operationType: operationType,
      objectId: objectId,
      objectType: objectType,
      data: data,
      deviceInfo: deviceInfo,
      wallTime: DateTime.now().toUtc(),
      deviceTick: _monotonicTick,
      parentOperationId: parentOperationId,
      metadata: metadata ?? {},
    );

    _pendingOperations[operation.id] = operation;
    return operation;
  }

  /// Merge operations from another device
  Future<List<SyncConflictResult>> mergeOperations(
    List<SyncOperation> remoteOperations,
  ) async {
    final conflicts = <SyncConflictResult>[];

    for (final remoteOp in remoteOperations) {
      // Update known devices
      _knownDevices[remoteOp.deviceInfo.deviceId] = remoteOp.deviceInfo;

      // Check for conflicts with pending operations
      final conflict = _detectConflict(remoteOp);
      if (conflict.hasConflict) {
        conflicts.add(conflict);
        continue;
      }

      // Apply the operation
      await _applyOperation(remoteOp);
    }

    return conflicts;
  }

  /// Detect conflicts between operations
  SyncConflictResult _detectConflict(SyncOperation remoteOp) {
    // Check for conflicts with pending operations on the same object
    final conflictingOps = _pendingOperations.values.where((localOp) =>
      localOp.objectId == remoteOp.objectId &&
      localOp.objectType == remoteOp.objectType &&
      localOp.operationType != 'delete' &&
      remoteOp.operationType != 'delete'
    ).toList();

    if (conflictingOps.isEmpty) {
      return SyncConflictResult(hasConflict: false);
    }

    // Resolve conflicts using CRDT-lite rules
    return _resolveConflict(remoteOp, conflictingOps);
  }

  /// Resolve conflicts using CRDT-lite merge rules
  SyncConflictResult _resolveConflict(
    SyncOperation remoteOp,
    List<SyncOperation> localOps,
  ) {
    // Last-writer-wins for scalars (based on wall time, then device tick)
    final allOps = [remoteOp, ...localOps];
    allOps.sort((a, b) {
      final timeComparison = a.wallTime.compareTo(b.wallTime);
      if (timeComparison != 0) return timeComparison;
      return a.deviceTick.compareTo(b.deviceTick);
    });

    final winningOp = allOps.last;
    final isRemoteWinning = winningOp == remoteOp;

    if (isRemoteWinning) {
      // Remote operation wins
      return SyncConflictResult(
        hasConflict: false,
        resolutionStrategy: 'last_writer_wins',
        resolvedData: remoteOp.data,
      );
    } else {
      // Local operation wins, but we need to merge
      return SyncConflictResult(
        hasConflict: true,
        conflictType: 'scalar_conflict',
        resolutionStrategy: 'local_wins',
        conflicts: ['Local operation takes precedence over remote'],
      );
    }
  }

  /// Apply an operation to the local state
  Future<void> _applyOperation(SyncOperation operation) async {
    switch (operation.objectType) {
      case 'node':
        await _applyNodeOperation(operation);
        break;
      case 'edge':
        await _applyEdgeOperation(operation);
        break;
      case 'pointer':
        await _applyPointerOperation(operation);
        break;
      default:
        throw Exception('Unknown object type: ${operation.objectType}');
    }
  }

  /// Apply node operation
  Future<void> _applyNodeOperation(SyncOperation operation) async {
    // In a real implementation, this would update the repository
    // For now, we just track the operation
    print('Applying node operation: ${operation.operationType} on ${operation.objectId}');
  }

  /// Apply edge operation
  Future<void> _applyEdgeOperation(SyncOperation operation) async {
    // In a real implementation, this would update the repository
    // For now, we just track the operation
    print('Applying edge operation: ${operation.operationType} on ${operation.objectId}');
  }

  /// Apply pointer operation
  Future<void> _applyPointerOperation(SyncOperation operation) async {
    // In a real implementation, this would update the repository
    // For now, we just track the operation
    print('Applying pointer operation: ${operation.operationType} on ${operation.objectId}');
  }

  /// Merge tags using set-merge strategy
  Map<String, dynamic> mergeTags(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
  ) {
    final merged = Map<String, dynamic>.from(localData);
    
    // Merge tags (set union)
    final localTags = Set<String>.from(localData['tags'] ?? []);
    final remoteTags = Set<String>.from(remoteData['tags'] ?? []);
    final mergedTags = localTags.union(remoteTags).toList();
    merged['tags'] = mergedTags;

    // Merge keywords (set union)
    final localKeywords = Set<String>.from(localData['keywords'] ?? []);
    final remoteKeywords = Set<String>.from(remoteData['keywords'] ?? []);
    final mergedKeywords = localKeywords.union(remoteKeywords).toList();
    merged['keywords'] = mergedKeywords;

    return merged;
  }

  /// Merge edges using additive strategy
  List<Map<String, dynamic>> mergeEdges(
    List<Map<String, dynamic>> localEdges,
    List<Map<String, dynamic>> remoteEdges,
  ) {
    final edgeMap = <String, Map<String, dynamic>>{};

    // Add local edges
    for (final edge in localEdges) {
      final key = '${edge['src']}-${edge['dst']}-${edge['label']}';
      edgeMap[key] = edge;
    }

    // Add remote edges (only if not tombstoned)
    for (final edge in remoteEdges) {
      final key = '${edge['src']}-${edge['dst']}-${edge['label']}';
      final isTombstoned = edge['is_tombstoned'] as bool? ?? false;
      
      if (!isTombstoned) {
        edgeMap[key] = edge;
      } else {
        // Remove tombstoned edge
        edgeMap.remove(key);
      }
    }

    return edgeMap.values.toList();
  }

  /// Get pending operations for sync
  List<SyncOperation> getPendingOperations() {
    return _pendingOperations.values.toList();
  }

  /// Mark operation as synced
  void markOperationSynced(String operationId) {
    _pendingOperations.remove(operationId);
  }

  /// Get sync status
  Map<String, dynamic> getSyncStatus() => {
    'device_id': _deviceId,
    'device_type': _deviceType,
    'app_version': _appVersion,
    'monotonic_tick': _monotonicTick,
    'pending_operations': _pendingOperations.length,
    'known_devices': _knownDevices.length,
    'last_sync': DateTime.now().toUtc().toIso8601String(),
  };

  /// Get known devices
  Map<String, DeviceInfo> getKnownDevices() {
    return Map.unmodifiable(_knownDevices);
  }

  /// Reset sync state (for testing)
  void resetSyncState() {
    _monotonicTick = 0;
    _pendingOperations.clear();
    _knownDevices.clear();
  }
}

/// Sync conflict resolver
class SyncConflictResolver {
  /// Resolve scalar conflicts using last-writer-wins
  static Map<String, dynamic> resolveScalarConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
    DateTime localTime,
    DateTime remoteTime,
  ) {
    // Last writer wins based on timestamp
    if (remoteTime.isAfter(localTime)) {
      return remoteData;
    } else if (localTime.isAfter(remoteTime)) {
      return localData;
    } else {
      // Same timestamp, use device ID for deterministic resolution
      final localDeviceId = localData['device_id'] as String? ?? '';
      final remoteDeviceId = remoteData['device_id'] as String? ?? '';
      
      if (remoteDeviceId.compareTo(localDeviceId) > 0) {
        return remoteData;
      } else {
        return localData;
      }
    }
  }

  /// Resolve set conflicts using union
  static Map<String, dynamic> resolveSetConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
    String fieldName,
  ) {
    final localSet = Set<String>.from(localData[fieldName] ?? []);
    final remoteSet = Set<String>.from(remoteData[fieldName] ?? []);
    final mergedSet = localSet.union(remoteSet).toList();
    
    final result = Map<String, dynamic>.from(localData);
    result[fieldName] = mergedSet;
    return result;
  }

  /// Resolve edge conflicts using additive merge
  static List<Map<String, dynamic>> resolveEdgeConflict(
    List<Map<String, dynamic>> localEdges,
    List<Map<String, dynamic>> remoteEdges,
  ) {
    final edgeMap = <String, Map<String, dynamic>>{};

    // Add all non-tombstoned edges
    for (final edges in [localEdges, remoteEdges]) {
      for (final edge in edges) {
        final isTombstoned = edge['is_tombstoned'] as bool? ?? false;
        if (isTombstoned) continue;

        final key = '${edge['src']}-${edge['dst']}-${edge['label']}';
        edgeMap[key] = edge;
      }
    }

    return edgeMap.values.toList();
  }
}
