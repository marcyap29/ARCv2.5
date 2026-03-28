import 'package:my_app/features/agents/worker_service.dart';
import 'package:my_app/lumara/agents/services/timeline_context_service.dart';

String _clip(String s, int max) {
  final t = s.trim();
  if (t.isEmpty) return '';
  return t.length > max ? '${t.substring(0, max)}...' : t;
}

/// Builds [ChronicleBundle] from real CHRONICLE timeline/theme data (not demo personas).
Future<ChronicleBundle> buildChronicleBundleForWorkflow({
  required String userId,
  required String contentTopic,
}) async {
  final svc = TimelineContextService();
  final ctx = await svc.getWritingContext(
    userId: userId,
    contentTopic: contentTopic,
  );
  final profile = _clip(
    '${ctx.currentPhase}: ${ctx.phaseDescription}'.trim(),
    500,
  );
  final tags = _clip(ctx.dominantThemes, 600);
  final recent = _clip(ctx.recentEntries, 3500);
  final topical = _clip(
    '${ctx.timelineSummary}\n\nDominant themes: ${ctx.dominantThemes}\nPatterns: ${ctx.patterns}',
    4000,
  );
  return ChronicleBundle(
    profile: profile.isEmpty ? 'Journal timeline (CHRONICLE)' : profile,
    tags: tags.isEmpty ? '—' : tags,
    recent: recent.isEmpty ? 'No recent journal entries indexed yet.' : recent,
    topical: topical.isEmpty ? tags : topical,
  );
}
