// lib/lumara/services/progressive_memory_loader.dart
// Progressive loading of journal entries by year for efficient memory access

import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';

/// Manages progressive loading of journal entries by year
class ProgressiveMemoryLoader {
  final JournalRepository _journalRepository;
  
  // Track what's loaded
  final Set<int> _loadedYears = {};
  final int _currentYear = DateTime.now().year;
  
  // Cache of loaded entries by year
  final Map<int, List<JournalEntry>> _yearCache = {};
  
  // Available years in the data
  final Set<int> _availableYears = {};
  
  ProgressiveMemoryLoader(this._journalRepository);
  
  /// Initialize by detecting available years and loading current year
  Future<void> initialize() async {
    print('LUMARA Memory Loader: Initializing...');
    
    // Get all entries to detect available years
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    for (final entry in allEntries) {
      final year = entry.createdAt.year;
      _availableYears.add(year);
    }
    
    print('LUMARA Memory Loader: Found entries from years: ${_availableYears.toList()..sort()}');
    
    // Load current year by default
    await loadYear(_currentYear);
    
    print('LUMARA Memory Loader: Loaded current year ($_currentYear) with ${_yearCache[_currentYear]?.length ?? 0} entries');
  }
  
  /// Load entries for a specific year
  Future<void> loadYear(int year) async {
    if (_loadedYears.contains(year)) {
      print('LUMARA Memory Loader: Year $year already loaded');
      return;
    }
    
    print('LUMARA Memory Loader: Loading year $year...');
    
    final allEntries = await _journalRepository.getAllJournalEntries();
    final yearEntries = allEntries.where((entry) => entry.createdAt.year == year).toList();
    
    _yearCache[year] = yearEntries;
    _loadedYears.add(year);
    
    print('LUMARA Memory Loader: Loaded ${yearEntries.length} entries for year $year');
  }
  
  /// Load entries for a range of years
  Future<void> loadYears(int startYear, int endYear) async {
    print('LUMARA Memory Loader: Loading years $startYear-$endYear...');
    
    for (int year = startYear; year <= endYear; year++) {
      await loadYear(year);
    }
  }
  
  /// Get entries from currently loaded years (most recent first)
  List<JournalEntry> getLoadedEntries() {
    final entries = <JournalEntry>[];
    
    for (final year in _loadedYears.toList()..sort()) {
      final yearEntries = _yearCache[year] ?? [];
      entries.addAll(yearEntries);
    }
    
    // Sort by date (newest first)
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return entries;
  }
  
  /// Check if there are more years available to load
  bool hasMoreYears() {
    return _availableYears.difference(_loadedYears).isNotEmpty;
  }
  
  /// Get next unloaded year (oldest first)
  int? getNextUnloadedYear() {
    final unloaded = _availableYears.difference(_loadedYears);
    if (unloaded.isEmpty) return null;
    
    return unloaded.reduce((a, b) => a < b ? a : b); // Oldest year
  }
  
  /// Load next 2-3 years of history
  Future<bool> loadMoreHistory() async {
    if (!hasMoreYears()) {
      print('LUMARA Memory Loader: No more years to load');
      return false;
    }
    
    final nextYear = getNextUnloadedYear();
    if (nextYear == null) return false;
    
    // Find the range to load (2-3 years back)
    final sortedAvailable = _availableYears.where((y) => !_loadedYears.contains(y)).toList()..sort();
    
    if (sortedAvailable.isEmpty) return false;
    
    // Load next 2-3 years
    final yearsToLoad = sortedAvailable.take(3).toList();
    
    print('LUMARA Memory Loader: Loading next ${yearsToLoad.length} years: $yearsToLoad');
    
    for (final year in yearsToLoad) {
      await loadYear(year);
    }
    
    return true;
  }
  
  /// Check what years are available
  List<int> getAvailableYears() {
    return _availableYears.toList()..sort();
  }
  
  /// Check what years are loaded
  List<int> getLoadedYears() {
    return _loadedYears.toList()..sort();
  }
  
  /// Clear all loaded data
  void clear() {
    _yearCache.clear();
    _loadedYears.clear();
    print('LUMARA Memory Loader: Cleared all loaded data');
  }
  
  /// Get count of entries in currently loaded years
  int getLoadedEntryCount() {
    return getLoadedEntries().length;
  }
  
  /// Get count of entries in all available years
  Future<int> getTotalEntryCount() async {
    final entries = await _journalRepository.getAllJournalEntries();
    return entries.length;
  }
}

