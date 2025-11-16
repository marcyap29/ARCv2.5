import 'package:hive/hive.dart';
import '../data/models/lumara_favorite.dart';

/// Service for managing LUMARA favorites
/// Enforces 25-item limit per user
class FavoritesService {
  static const int _maxFavorites = 25;
  static const String _boxName = 'lumara_favorites';
  static const String _firstTimeKey = 'favorites_first_time_shown';

  static FavoritesService? _instance;
  static FavoritesService get instance {
    _instance ??= FavoritesService._();
    return _instance!;
  }

  FavoritesService._();

  Box<LumaraFavorite>? _favoritesBox;
  Box? _settingsBox;
  bool _initialized = false;

  /// Initialize the favorites service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(80)) {
        Hive.registerAdapter(LumaraFavoriteAdapter());
      }

      // Open favorites box
      _favoritesBox = await Hive.openBox<LumaraFavorite>(_boxName);

      // Open settings box for first-time flag
      _settingsBox = await Hive.openBox('settings');

      _initialized = true;
      print('✅ FavoritesService initialized');
    } catch (e) {
      print('❌ Error initializing FavoritesService: $e');
      rethrow;
    }
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Get all favorites, sorted by timestamp (newest first)
  Future<List<LumaraFavorite>> getAllFavorites() async {
    await _ensureInitialized();
    final favorites = _favoritesBox!.values.toList();
    favorites.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return favorites;
  }

  /// Get a subset of favorites for prompt inclusion (typically 3-7)
  /// Returns a random sample to provide variety
  Future<List<LumaraFavorite>> getFavoritesForPrompt({int count = 5}) async {
    await _ensureInitialized();
    final all = await getAllFavorites();
    if (all.length <= count) return all;
    
    // Shuffle and take first N for variety
    final shuffled = List<LumaraFavorite>.from(all)..shuffle();
    return shuffled.take(count).toList();
  }

  /// Check if a message/block is already a favorite by source ID
  Future<bool> isFavorite(String? sourceId) async {
    if (sourceId == null) return false;
    await _ensureInitialized();
    return _favoritesBox!.values.any((fav) => fav.sourceId == sourceId);
  }

  /// Find favorite by source ID
  Future<LumaraFavorite?> findFavoriteBySourceId(String sourceId) async {
    await _ensureInitialized();
    try {
      return _favoritesBox!.values.firstWhere(
        (fav) => fav.sourceId == sourceId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Add a favorite (enforces 25-item limit)
  /// Returns true if added, false if at capacity
  Future<bool> addFavorite(LumaraFavorite favorite) async {
    await _ensureInitialized();

    // Check if already exists
    if (favorite.sourceId != null) {
      final existing = await findFavoriteBySourceId(favorite.sourceId!);
      if (existing != null) {
        print('⚠️ Favorite already exists for sourceId: ${favorite.sourceId}');
        return false; // Already exists
      }
    }

    // Check capacity
    if (_favoritesBox!.length >= _maxFavorites) {
      print('⚠️ Favorites at capacity: $_maxFavorites');
      return false;
    }

    // Add favorite
    await _favoritesBox!.put(favorite.id, favorite);
    print('✅ Added favorite: ${favorite.id}');
    return true;
  }

  /// Remove a favorite by ID
  Future<void> removeFavorite(String favoriteId) async {
    await _ensureInitialized();
    await _favoritesBox!.delete(favoriteId);
    print('✅ Removed favorite: $favoriteId');
  }

  /// Remove a favorite by source ID
  Future<bool> removeFavoriteBySourceId(String sourceId) async {
    await _ensureInitialized();
    final favorite = await findFavoriteBySourceId(sourceId);
    if (favorite != null) {
      await removeFavorite(favorite.id);
      return true;
    }
    return false;
  }

  /// Get current count of favorites
  Future<int> getCount() async {
    await _ensureInitialized();
    return _favoritesBox!.length;
  }

  /// Check if at capacity
  Future<bool> isAtCapacity() async {
    final count = await getCount();
    return count >= _maxFavorites;
  }

  /// Check if first-time snackbar has been shown
  Future<bool> hasShownFirstTimeSnackbar() async {
    await _ensureInitialized();
    return _settingsBox!.get(_firstTimeKey, defaultValue: false) as bool;
  }

  /// Mark first-time snackbar as shown
  Future<void> markFirstTimeSnackbarShown() async {
    await _ensureInitialized();
    await _settingsBox!.put(_firstTimeKey, true);
  }

  /// Clear all favorites
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _favoritesBox!.clear();
    print('✅ Cleared all favorites');
  }
}

