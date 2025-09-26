import '../../../arc/models/journal_entry_model.dart';
import 'debrief_models.dart';

class DebriefToJournalMapper {
  static JournalEntry mapDebriefToJournalEntry(DebriefRecord debrief) {
    final buffer = StringBuffer();
    
    // Add debrief content with lightweight headers
    if (debrief.snapshot.isNotEmpty) {
      buffer.writeln('## Snapshot');
      buffer.writeln(debrief.snapshot);
      buffer.writeln();
    }
    
    if (debrief.wentWell.isNotEmpty || debrief.wasHard.isNotEmpty) {
      if (debrief.wentWell.isNotEmpty) {
        buffer.writeln('## What Went Well');
        for (final item in debrief.wentWell) {
          buffer.writeln('• $item');
        }
        buffer.writeln();
      }
      
      if (debrief.wasHard.isNotEmpty) {
        buffer.writeln('## What Was Challenging');
        for (final item in debrief.wasHard) {
          buffer.writeln('• $item');
        }
        buffer.writeln();
      }
    }
    
    // Body check
    buffer.writeln('## Body Check');
    buffer.writeln('Overall feeling: ${debrief.bodyScore}/5');
    if (debrief.breathCompleted) {
      buffer.writeln('Completed breathing exercise');
    }
    buffer.writeln();
    
    // Essence and next step
    if (debrief.essence.isNotEmpty) {
      buffer.writeln('## Key Takeaway');
      buffer.writeln(debrief.essence);
      buffer.writeln();
    }
    
    if (debrief.nextStep.isNotEmpty) {
      buffer.writeln('## Next Step');
      buffer.writeln(debrief.nextStep);
      buffer.writeln();
    }
    
    // Create journal entry
    return JournalEntry(
      id: debrief.id,
      title: 'Debrief — ${_formatDateTime(debrief.createdAt)}',
      content: buffer.toString().trim(),
      createdAt: debrief.createdAt,
      updatedAt: debrief.createdAt,
      tags: _generateTags(debrief),
      mood: _inferMoodFromDebrief(debrief) ?? 'Mixed',
      keywords: _extractKeywords(debrief),
    );
  }
  
  static List<String> _generateTags(DebriefRecord debrief) {
    final tags = ['first_responder', 'debrief'];
    
    // Add tags from selected chips
    tags.addAll(debrief.wentWell.map((item) => item.toLowerCase().replaceAll(' ', '_')));
    tags.addAll(debrief.wasHard.map((item) => item.toLowerCase().replaceAll(' ', '_')));
    
    return tags;
  }
  
  static String? _inferMoodFromDebrief(DebriefRecord debrief) {
    // Simple mood inference based on body score and content
    if (debrief.bodyScore >= 4) {
      return 'Good';
    } else if (debrief.bodyScore <= 2) {
      return 'Challenging';
    } else {
      return 'Mixed';
    }
  }
  
  static List<String> _extractKeywords(DebriefRecord debrief) {
    final keywords = <String>[];
    
    // Add significant words from essence and snapshot
    keywords.addAll(debrief.wentWell);
    keywords.addAll(debrief.wasHard);
    
    if (debrief.essence.isNotEmpty) {
      keywords.addAll(_extractWordsFromText(debrief.essence));
    }
    
    // Deduplicate and limit
    final uniqueKeywords = keywords.toSet().toList();
    return uniqueKeywords.take(10).toList();
  }
  
  
  static String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    final month = _getMonthAbbreviation(dateTime.month);
    final day = dateTime.day;
    
    return '$month $day, $displayHour:$minute $period';
  }
  
  static String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
  
  static List<String> _extractWordsFromText(String text) {
    // Simple keyword extraction - split by common delimiters and filter
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .where((word) => !_isStopWord(word))
        .toList();
    
    return words.take(5).toList();
  }
  
  static bool _isStopWord(String word) {
    const stopWords = {
      'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
      'by', 'from', 'up', 'about', 'into', 'through', 'during', 'before',
      'after', 'above', 'below', 'between', 'among', 'this', 'that', 'these',
      'those', 'was', 'were', 'been', 'have', 'has', 'had', 'will', 'would',
      'could', 'should', 'may', 'might', 'must', 'can', 'did', 'does', 'do'
    };
    return stopWords.contains(word);
  }
}