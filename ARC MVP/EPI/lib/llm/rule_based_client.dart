import 'llm_client.dart';

class RuleBasedClient implements LLMClient {
  @override
  Stream<String> streamChat(String prompt, {Map<String, dynamic>? opts}) async* {
    final lower = prompt.toLowerCase();

    if (lower.contains("stress") || lower.contains("anxious")) {
      yield "It looks like you’re writing about stress. Try taking a short break, breathe, and write what feels heavy.";
    } else if (lower.contains("goal") || lower.contains("plan")) {
      yield "You’re reflecting on goals. Break one goal into three small steps you can do this week.";
    } else if (lower.contains("sad") || lower.contains("lonely")) {
      yield "I hear sadness here. Consider reaching out to someone you trust, and give yourself permission to rest.";
    } else if (lower.contains("gratitude") || lower.contains("thank")) {
      yield "Gratitude noted. Capture three specifics you appreciated today and why they mattered.";
    } else {
      yield "Thanks for your entry. Keep reflecting — each note makes patterns easier to see.";
    }
  }
}


