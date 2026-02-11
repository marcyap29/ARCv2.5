import '../models/chronicle_layer.dart';

/// In-memory cache for built CHRONICLE contexts to speed up repeated queries
/// on the same period. Invalidated when new journal entries are created.
class ChronicleContextCache {
  ChronicleContextCache._();
  static final ChronicleContextCache instance = ChronicleContextCache._();

  static const int maxCacheSize = 50;
  static const Duration defaultTTL = Duration(minutes: 30);

  final Map<String, _CachedContext> _cache = {};

  /// Get cached context if available and not expired.
  String? get({
    required String userId,
    required List<ChronicleLayer> layers,
    required String period,
  }) {
    final key = _buildKey(userId, layers, period);
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.context;
    }
    _cache.removeWhere((_, v) => v.isExpired);
    return null;
  }

  /// Store context in cache.
  void put({
    required String userId,
    required List<ChronicleLayer> layers,
    required String period,
    required String context,
    Duration? ttl,
  }) {
    final key = _buildKey(userId, layers, period);
    _cache[key] = _CachedContext(
      context: context,
      expiresAt: DateTime.now().add(ttl ?? defaultTTL),
    );
    if (_cache.length > maxCacheSize) {
      final oldestKey = _cache.entries
          .reduce((a, b) => a.value.cachedAt.isBefore(b.value.cachedAt) ? a : b)
          .key;
      _cache.remove(oldestKey);
    }
  }

  /// Invalidate cache entries (e.g. when a new journal entry is created).
  void invalidate({
    required String userId,
    ChronicleLayer? layer,
    String? period,
  }) {
    _cache.removeWhere((key, _) {
      final parts = key.split(':');
      if (parts.length < 3 || parts[0] != userId) return false;
      final layerPeriodPart = parts[1];
      if (layer != null && !layerPeriodPart.contains(layer.name)) return false;
      if (period != null && parts[2] != period) return false;
      return true;
    });
  }

  void clear() {
    _cache.clear();
  }

  String _buildKey(String userId, List<ChronicleLayer> layers, String period) {
    final layerStr = layers.map((l) => l.name).join(',');
    return '$userId:$layerStr:$period';
  }
}

class _CachedContext {
  final String context;
  final DateTime cachedAt;
  final DateTime expiresAt;

  _CachedContext({
    required this.context,
    required this.expiresAt,
  }) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
