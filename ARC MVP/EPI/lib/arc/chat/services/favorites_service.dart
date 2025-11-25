import 'package:hive/hive.dart';
import '../data/models/lumara_favorite.dart';

/// Service for managing LUMARA favorites
/// Enforces category-specific limits: 25 for answers, 25 for chats, 25 for journal entries
class FavoritesService {
  static const int _maxAnswers = 25;
  static const int _maxChats = 25;
  static const int _maxJournalEntries = 25;
  static const int _maxFavorites = 25; // Legacy limit for backward compatibility
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

      // Migration: Ensure existing favorites have category field (default to 'answer')
      await _migrateExistingFavorites();

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

  /// Get favorites by category
  Future<List<LumaraFavorite>> getFavoritesByCategory(String category) async {
    await _ensureInitialized();
    final all = await getAllFavorites();
    return all.where((fav) => fav.category == category).toList();
  }

  /// Get saved chats (category: 'chat')
  Future<List<LumaraFavorite>> getSavedChats() async {
    return getFavoritesByCategory('chat');
  }

  /// Get favorite journal entries (category: 'journal_entry')
  Future<List<LumaraFavorite>> getFavoriteJournalEntries() async {
    return getFavoritesByCategory('journal_entry');
  }

  /// Get LUMARA answers (category: 'answer')
  Future<List<LumaraFavorite>> getLumaraAnswers() async {
    return getFavoritesByCategory('answer');
  }

  /// Get category-specific limit
  int getCategoryLimit(String category) {
    switch (category) {
      case 'answer':
        return _maxAnswers;
      case 'chat':
        return _maxChats;
      case 'journal_entry':
        return _maxJournalEntries;
      default:
        return _maxFavorites; // Legacy default
    }
  }

  /// Get count for a specific category
  Future<int> getCountByCategory(String category) async {
    final favorites = await getFavoritesByCategory(category);
    return favorites.length;
  }

  /// Check if a category is at capacity
  Future<bool> isCategoryAtCapacity(String category) async {
    final count = await getCountByCategory(category);
    final limit = getCategoryLimit(category);
    return count >= limit;
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

  /// Add a favorite (enforces category-specific limits)
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

    // Check category-specific capacity
    final category = favorite.category;
    if (await isCategoryAtCapacity(category)) {
      final limit = getCategoryLimit(category);
      print('⚠️ Favorites at capacity for category $category: $limit');
      return false;
    }

    // Add favorite
    await _favoritesBox!.put(favorite.id, favorite);
    print('✅ Added favorite: ${favorite.id} (category: $category)');
    return true;
  }

  /// Add a saved chat
  Future<bool> addSavedChat(LumaraFavorite favorite) async {
    if (favorite.category != 'chat') {
      throw ArgumentError('Favorite must have category "chat"');
    }
    return addFavorite(favorite);
  }

  /// Add a favorite journal entry
  Future<bool> addFavoriteJournalEntry(LumaraFavorite favorite) async {
    if (favorite.category != 'journal_entry') {
      throw ArgumentError('Favorite must have category "journal_entry"');
    }
    return addFavorite(favorite);
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

  /// Check if at capacity (legacy method - checks total count)
  Future<bool> isAtCapacity() async {
    final count = await getCount();
    return count >= _maxFavorites;
  }

  /// Check if a specific chat session is saved
  Future<bool> isChatSaved(String sessionId) async {
    await _ensureInitialized();
    return _favoritesBox!.values.any((fav) => 
      fav.category == 'chat' && fav.sessionId == sessionId
    );
  }

  /// Check if a specific journal entry is favorited
  Future<bool> isJournalEntryFavorited(String entryId) async {
    await _ensureInitialized();
    return _favoritesBox!.values.any((fav) => 
      fav.category == 'journal_entry' && fav.entryId == entryId
    );
  }

  /// Find favorite chat by session ID
  Future<LumaraFavorite?> findFavoriteChatBySessionId(String sessionId) async {
    await _ensureInitialized();
    try {
      return _favoritesBox!.values.firstWhere(
        (fav) => fav.category == 'chat' && fav.sessionId == sessionId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Find favorite journal entry by entry ID
  Future<LumaraFavorite?> findFavoriteJournalEntryByEntryId(String entryId) async {
    await _ensureInitialized();
    try {
      return _favoritesBox!.values.firstWhere(
        (fav) => fav.category == 'journal_entry' && fav.entryId == entryId,
      );
    } catch (e) {
      return null;
    }
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

  /// Migrate existing favorites to have category='answer' for backward compatibility
  Future<void> _migrateExistingFavorites() async {
    try {
      bool needsMigration = false;
      for (final key in _favoritesBox!.keys) {
        final favorite = _favoritesBox!.get(key);
        if (favorite != null) {
          // If category is empty or invalid, set to 'answer' (backward compatibility)
          if (favorite.category.isEmpty || 
              (favorite.category != 'answer' && favorite.category != 'chat' && favorite.category != 'journal_entry')) {
            final updated = favorite.copyWith(category: 'answer');
            await _favoritesBox!.put(key, updated);
            needsMigration = true;
          }
        }
      }
      
      if (needsMigration) {
        print('✅ Migrated existing favorites to include category field');
      }
    } catch (e) {
      print('⚠️ Error during favorites migration: $e');
      // Don't fail initialization if migration fails
    }
  }
}

