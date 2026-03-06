import 'dart:math';
import 'package:my_app/arc/chat/data/context_provider.dart';
import 'package:my_app/arc/chat/data/context_scope.dart';
import 'package:my_app/services/user_phase_service.dart';

/// Provides three randomized prompts based on Chronicle data (journal, chat, phase)
/// for use when the user long-presses the LUMARA send button in chat or reflection.
class ChroniclePromptService {
  ChroniclePromptService._();

  static final Random _random = Random();

  static const List<String> _traditionalPrompts = [
    "What's one thing that surprised you today?",
    "Describe a moment when you felt truly yourself.",
    "What question have you been avoiding asking yourself?",
    "Write about something you're grateful for that you haven't acknowledged recently.",
    "What would you tell your past self from a month ago?",
    "Describe a challenge you're facing and what you've learned from it.",
    "What does growth look like for you right now?",
    "Write about a relationship that has changed recently.",
    "What are you curious about exploring?",
    "Describe a moment of clarity you've had recently.",
    "What's on your mind right now?",
    "How are you feeling today?",
    "What happened today that you want to remember?",
    "What's one thing you learned recently?",
  ];

  /// Returns [count] randomized prompts (default 3) built from Chronicle context.
  /// Uses journal entries, recent chats, and current phase when available.
  static Future<List<String>> getChroniclePromptSuggestions({int count = 3}) async {
    final pool = <String>[];
    String currentPhase = 'Discovery';

    try {
      currentPhase = await UserPhaseService.getCurrentPhase();
    } catch (_) {}

    try {
      const scope = LumaraScope.defaultScope;
      final contextProvider = ContextProvider(scope);
      final contextWindow = await contextProvider.buildContext(
        daysBack: 30,
        maxEntries: 50,
      );

      // Context-aware prompts from Chronicle
      final journalNodes = contextWindow.nodes.where((n) => n['type'] == 'journal').toList();
      final recentEntries = journalNodes.take(5).toList();
      final chatNodes = contextWindow.nodes.where((n) => n['type'] == 'chat').toList();
      final recentChats = chatNodes.take(3).toList();

      pool.add('What does being in the $currentPhase phase mean to you right now?');
      pool.add('How has your journey through $currentPhase been different from what you expected?');

      if (recentEntries.isNotEmpty) {
        final lastEntry = recentEntries.first;
        final lastEntryText = lastEntry['text'] as String? ?? '';
        if (lastEntryText.length > 50) {
          final preview = lastEntryText.substring(0, 50);
          pool.add('Continue exploring: "$preview..." - What else comes to mind?');
        }
        final keywords = recentEntries
            .map((e) => e['meta']?['keywords'] as List? ?? [])
            .expand((k) => k)
            .whereType<List>()
            .map((k) => k[0] as String? ?? '')
            .where((k) => k.isNotEmpty)
            .toSet()
            .take(3)
            .toList();
        if (keywords.isNotEmpty) {
          pool.add("You've been reflecting on ${keywords.join(", ")}. What new insights have emerged?");
        }
      }

      if (recentChats.isNotEmpty) {
        final lastChat = recentChats.first;
        final chatSubject = lastChat['meta']?['subject'] as String? ?? 'conversations';
        pool.add('You recently discussed "$chatSubject" with LUMARA. What would you like to explore further?');
      }

      final daysSinceStart = contextWindow.startDate.difference(DateTime.now()).inDays.abs();
      if (daysSinceStart > 7) {
        pool.add('Looking back over the past $daysSinceStart days, what patterns do you notice?');
      }
    } catch (_) {}

    pool.addAll(_traditionalPrompts);
    pool.shuffle(_random);
    return pool.take(count).toList();
  }
}
