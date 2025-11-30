// lib/lumara/services/memory_notification_service.dart
// Detects and manages memory notifications for past journal entries

import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Represents a memory notification
class MemoryNotification {
  final JournalEntry entry;
  final int yearsAgo;
  final DateTime memoryDate;
  final String notificationText;
  final bool isExactMatch; // Same day and month
  final String? phaseAtTime; // Phase from the past memory
  final String? currentPhase; // User's current phase
  final double relevanceScore; // How relevant this memory is (0-1)

  MemoryNotification({
    required this.entry,
    required this.yearsAgo,
    required this.memoryDate,
    required this.notificationText,
    required this.isExactMatch,
    this.phaseAtTime,
    this.currentPhase,
    this.relevanceScore = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'entryId': entry.id,
      'yearsAgo': yearsAgo,
      'memoryDate': memoryDate.toIso8601String(),
      'notificationText': notificationText,
      'isExactMatch': isExactMatch,
      'phaseAtTime': phaseAtTime,
      'currentPhase': currentPhase,
      'relevanceScore': relevanceScore,
    };
  }
  
  /// Get the phase connection description
  String? getPhaseConnectionText() {
    if (phaseAtTime == null || currentPhase == null) return null;
    if (phaseAtTime == currentPhase) {
      return 'You were in the same phase';
    }
    return 'You were in $phaseAtTime phase';
  }
}

/// Service for detecting and managing memory notifications
class MemoryNotificationService {
  final JournalRepository _journalRepository;
  final DateTime _today = DateTime.now();
  
  MemoryNotificationService(this._journalRepository);
  
  /// Get memories for today (entries from previous years)
  Future<List<MemoryNotification>> getMemoriesForToday({
    int maxYearsBack = 5,
    bool onlyExactMatches = false,
    String? currentPhase,
  }) async {
    final memories = <MemoryNotification>[];
    
    final allEntries = await _journalRepository.getAllJournalEntries();
    final todayMonth = _today.month;
    final todayDay = _today.day;
    
    for (final entry in allEntries) {
      final entryDate = entry.createdAt;
      final entryMonth = entryDate.month;
      final entryDay = entryDate.day;
      final entryYear = entryDate.year;
      
      // Check if it's the same day/month but different year
      final isExactMatch = entryMonth == todayMonth && entryDay == todayDay;
      
      if (!onlyExactMatches || isExactMatch) {
        final yearsDifference = _today.year - entryYear;
        
        if (yearsDifference > 0 && yearsDifference <= maxYearsBack) {
          // Check how close to today (within a few days for approximate matches)
          final daysDiff = (entryDate.day - _today.day).abs() + 
                          (entryDate.month - _today.month).abs() * 30;
          
          if (isExactMatch || daysDiff <= 5) {
            // It's a memory from X years ago (or close to today)
            final text = _generateNotificationText(yearsDifference, isExactMatch);
            final pastPhase = entry.metadata?['phase'] as String? ?? entry.phase;
            
            // Calculate relevance score based on phase connection
            final relevanceScore = _calculatePhaseRelevance(
              currentPhase: currentPhase,
              pastPhase: pastPhase,
              isExactMatch: isExactMatch,
            );
            
            memories.add(MemoryNotification(
              entry: entry,
              yearsAgo: yearsDifference,
              memoryDate: entryDate,
              notificationText: text,
              isExactMatch: isExactMatch,
              phaseAtTime: pastPhase,
              currentPhase: currentPhase,
              relevanceScore: relevanceScore,
            ));
          }
        }
      }
    }
    
    // Sort by relevance (highest first), then by years ago (most recent first)
    memories.sort((a, b) {
      final relevanceComp = b.relevanceScore.compareTo(a.relevanceScore);
      if (relevanceComp != 0) return relevanceComp;
      return a.yearsAgo.compareTo(b.yearsAgo);
    });
    
    return memories.take(3).toList(); // Return top 3 memories
  }
  
  /// Calculate relevance score based on phase connection
  double _calculatePhaseRelevance({
    String? currentPhase,
    String? pastPhase,
    required bool isExactMatch,
  }) {
    if (currentPhase == null || pastPhase == null) return isExactMatch ? 0.8 : 0.5;
    
    // Phase pairs that are particularly relevant
    final phaseConnections = {
      // Discovery → Expansion, Expansion → Transition
      ('Discovery', 'Expansion'): 1.0,
      ('Expansion', 'Discovery'): 0.9,
      
      // Expansion → Transition, Transition → Consolidation
      ('Expansion', 'Transition'): 1.0,
      ('Transition', 'Expansion'): 0.9,
      
      // Same phase is very relevant
      (currentPhase, pastPhase): 1.0,
      
      // Adjacent phases
      ('Transition', 'Consolidation'): 0.9,
      ('Consolidation', 'Transition'): 0.8,
      
      // Breakthrough and Recovery are significant
      ('Breakthrough', 'Discovery'): 0.9,
      ('Recovery', 'Consolidation'): 0.9,
    };
    
    // Check for exact match first
    if (currentPhase == pastPhase) {
      return isExactMatch ? 1.0 : 0.95;
    }
    
    // Check for known connections
    final connection = phaseConnections[(currentPhase, pastPhase)];
    if (connection != null) {
      return connection;
    }
    
    // Default relevance based on exact match
    return isExactMatch ? 0.7 : 0.5;
  }
  
  /// Get memories for a specific date
  Future<List<MemoryNotification>> getMemoriesForDate({
    required DateTime date,
    int maxYearsBack = 5,
  }) async {
    final memories = <MemoryNotification>[];
    
    final allEntries = await _journalRepository.getAllJournalEntries();
    final targetMonth = date.month;
    final targetDay = date.day;
    
    for (final entry in allEntries) {
      final entryDate = entry.createdAt;
      final entryMonth = entryDate.month;
      final entryDay = entryDate.day;
      final entryYear = entryDate.year;
      
      final isExactMatch = entryMonth == targetMonth && entryDay == targetDay;
      
      if (isExactMatch && entryYear < date.year) {
        final yearsDifference = date.year - entryYear;
        
        if (yearsDifference > 0 && yearsDifference <= maxYearsBack) {
          final text = _generateNotificationText(yearsDifference, isExactMatch);
          
          memories.add(MemoryNotification(
            entry: entry,
            yearsAgo: yearsDifference,
            memoryDate: entryDate,
            notificationText: text,
            isExactMatch: isExactMatch,
          ));
        }
      }
    }
    
    // Sort by years ago (most recent first)
    memories.sort((a, b) => a.yearsAgo.compareTo(b.yearsAgo));
    
    return memories;
  }
  
  String _generateNotificationText(int yearsAgo, bool isExact) {
    if (isExact) {
      if (yearsAgo == 1) {
        return '📖 A memory from 1 year ago';
      } else {
        return '📖 A memory from $yearsAgo years ago';
      }
    } else {
      return '📖 A similar memory from $yearsAgo years ago';
    }
  }
  
  /// Get memories related to a specific entry or query
  Future<List<MemoryNotification>> getRelatedMemories({
    required String query,
    int maxYearsBack = 5,
    int limit = 3,
  }) async {
    final memories = <MemoryNotification>[];
    final queryLower = query.toLowerCase();
    
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    for (final entry in allEntries) {
      final entryDate = entry.createdAt;
      final yearsDifference = _today.year - entryDate.year;
      
      if (yearsDifference > 0 && yearsDifference <= maxYearsBack) {
        // Check if entry is related to query
        final isRelated = _entryMatchesQuery(entry, queryLower);
        
        if (isRelated) {
          final text = _generateNotificationText(yearsDifference, true);
          
          memories.add(MemoryNotification(
            entry: entry,
            yearsAgo: yearsDifference,
            memoryDate: entryDate,
            notificationText: text,
            isExactMatch: true,
          ));
        }
      }
    }
    
    // Sort by relevance (newer memories first, then by content similarity)
    memories.sort((a, b) {
      // First sort by years ago (more recent first)
      final yearComp = a.yearsAgo.compareTo(b.yearsAgo);
      if (yearComp != 0) return yearComp;
      
      // Then by date (newer first)
      return b.memoryDate.compareTo(a.memoryDate);
    });
    
    return memories.take(limit).toList();
  }
  
  bool _entryMatchesQuery(JournalEntry entry, String queryLower) {
    // Check if query appears in entry content
    if (entry.content.toLowerCase().contains(queryLower)) return true;
    
    // Check if query appears in entry keywords
    if (entry.keywords.any((k) => k.toLowerCase().contains(queryLower))) return true;
    
    // Check if query appears in entry tags
    if (entry.tags.any((t) => t.toLowerCase().contains(queryLower))) return true;
    
    return false;
  }
  
  /// Get weekly memories (entries from same week in previous years)
  Future<List<MemoryNotification>> getWeeklyMemories() async {
    final memories = <MemoryNotification>[];
    final weekStart = DateTime(_today.year, _today.month, _today.day - _today.weekday);
    
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    for (final entry in allEntries) {
      final entryDate = entry.createdAt;
      final entryWeekStart = DateTime(entryDate.year, entryDate.month, entryDate.day - entryDate.weekday);
      
      // Check if same week in a different year
      if (entryDate.month == _today.month && 
          entryDate.day >= weekStart.day && 
          entryDate.day <= weekStart.day + 6 &&
          entryDate.year < _today.year) {
        
        final yearsDifference = _today.year - entryDate.year;
        
        if (yearsDifference > 0 && yearsDifference <= 5) {
          final text = '📖 A memory from $yearsDifference year${yearsDifference > 1 ? 's' : ''} ago this week';
          
          memories.add(MemoryNotification(
            entry: entry,
            yearsAgo: yearsDifference,
            memoryDate: entryDate,
            notificationText: text,
            isExactMatch: false,
          ));
        }
      }
    }
    
    return memories.take(5).toList();
  }
  
  /// Get monthly memories (entries from same month in previous years)
  Future<List<MemoryNotification>> getMonthlyMemories() async {
    final memories = <MemoryNotification>[];
    
    final allEntries = await _journalRepository.getAllJournalEntries();
    
    for (final entry in allEntries) {
      final entryDate = entry.createdAt;
      
      // Same month, different year
      if (entryDate.month == _today.month && entryDate.year < _today.year) {
        final yearsDifference = _today.year - entryDate.year;
        
        if (yearsDifference > 0 && yearsDifference <= 5) {
          final text = '📖 A memory from $yearsDifference year${yearsDifference > 1 ? 's' : ''} ago this month';
          
          memories.add(MemoryNotification(
            entry: entry,
            yearsAgo: yearsDifference,
            memoryDate: entryDate,
            notificationText: text,
            isExactMatch: false,
          ));
        }
      }
    }
    
    return memories.take(10).toList();
  }
}

