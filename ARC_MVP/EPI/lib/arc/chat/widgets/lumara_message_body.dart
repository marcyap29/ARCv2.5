/// LumaraMessageBody
///
/// Renders LUMARA chat/reflection message content with full markdown support:
/// - Headers, bold, italic, lists, code blocks, block quotes, etc.
/// - Entry references as clickable links with human-readable titles
/// - Replaces raw UUIDs with entry titles for display
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/arc/outputs/outputs_tab_screen.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'package:my_app/arc/unified_feed/widgets/expanded_entry_view.dart';
import 'package:my_app/lumara/agents/screens/research_report_detail_screen.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// Markdown entry link: [title](entry:uuid)
final RegExp _entryLinkPattern = RegExp(
  r'\[([^\]]*)\]\((entry:[0-9a-f-]+)\)',
  caseSensitive: false,
);

/// Patterns for raw UUID citations: (entry uuid), **entry uuid**, (Feb 23, entry uuid), (**Feb 23, entry uuid**)
final RegExp _entryUuidInParens = RegExp(
  r'\((?:(?:entry|Feb|Jan|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[^)]*?\s+)?entry\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\)',
  caseSensitive: false,
);
final RegExp _entryUuidBoldParens = RegExp(
  r'\(\*\*[^*]*entry\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})[^*]*\*\*\)',
  caseSensitive: false,
);
final RegExp _entryUuidBold = RegExp(
  r'\*\*entry\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\*\*',
  caseSensitive: false,
);
final RegExp _entryUuidPlain = RegExp(
  r'\bentry\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b',
  caseSensitive: false,
);

/// Renders LUMARA message content with full markdown and clickable entry references.
class LumaraMessageBody extends StatefulWidget {
  final String content;
  final TextStyle? textStyle;
  final Color? linkColor;

  const LumaraMessageBody({
    super.key,
    required this.content,
    this.textStyle,
    this.linkColor,
  });

  @override
  State<LumaraMessageBody> createState() => _LumaraMessageBodyState();
}

class _LumaraMessageBodyState extends State<LumaraMessageBody> {
  final Map<String, String> _titleCache = {};

  @override
  void initState() {
    super.initState();
    _loadTitlesForUuids();
  }

  Future<void> _loadTitlesForUuids() async {
    final uuids = _extractAllUuids(widget.content);
    if (uuids.isEmpty) return;
    final repo = JournalRepository();
    for (final uuid in uuids) {
      if (_titleCache.containsKey(uuid)) continue;
      try {
        final entry = await repo.getJournalEntryById(uuid);
        if (entry != null) {
          final title = _entryDisplayTitle(entry);
          if (mounted) {
            setState(() => _titleCache[uuid] = title);
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Set<String> _extractAllUuids(String text) {
    final uuids = <String>{};
    for (final m in _entryLinkPattern.allMatches(text)) {
      final raw = m.group(2) ?? '';
      if (raw.startsWith('entry:')) {
        uuids.add(raw.substring(6));
      }
    }
    for (final m in _entryUuidInParens.allMatches(text)) {
      uuids.add(m.group(1) ?? '');
    }
    for (final m in _entryUuidBoldParens.allMatches(text)) {
      uuids.add(m.group(1) ?? '');
    }
    for (final m in _entryUuidBold.allMatches(text)) {
      uuids.add(m.group(1) ?? '');
    }
    for (final m in _entryUuidPlain.allMatches(text)) {
      uuids.add(m.group(1) ?? '');
    }
    return uuids.where((s) => s.isNotEmpty).toSet();
  }

  String _entryDisplayTitle(JournalEntry entry) {
    if (entry.title.isNotEmpty) return entry.title;
    final first = entry.content.split('\n').first.trim();
    if (first.isNotEmpty) {
      return first.length > 60 ? '${first.substring(0, 57)}...' : first;
    }
    return 'Entry';
  }

  String _getTitleForUuid(String uuid) {
    return _titleCache[uuid] ?? 'Entry';
  }

  /// Pre-process content: replace raw UUID patterns with [title](entry:uuid) markdown links
  String _processContentForMarkdown(String content) {
    String result = content;

    // Replace (**Feb 23, entry uuid**) or (**entry uuid**)
    result = result.replaceAllMapped(_entryUuidBoldParens, (m) {
      final uuid = m.group(1) ?? '';
      final title = _getTitleForUuid(uuid);
      return '[$title](entry:$uuid)';
    });

    // Replace (Feb 23, entry uuid) or (entry uuid)
    result = result.replaceAllMapped(_entryUuidInParens, (m) {
      final uuid = m.group(1) ?? '';
      final title = _getTitleForUuid(uuid);
      return '[$title](entry:$uuid)';
    });

    // Replace **entry uuid**
    result = result.replaceAllMapped(_entryUuidBold, (m) {
      final uuid = m.group(1) ?? '';
      final title = _getTitleForUuid(uuid);
      return '[$title](entry:$uuid)';
    });

    // Replace plain "entry uuid"
    result = result.replaceAllMapped(_entryUuidPlain, (m) {
      final uuid = m.group(1) ?? '';
      final title = _getTitleForUuid(uuid);
      return '[$title](entry:$uuid)';
    });

    return result;
  }

  void _openEntry(BuildContext context, String entryId) {
    JournalRepository().getJournalEntryById(entryId).then((entry) {
      if (entry != null && context.mounted) {
        final feedEntry = FeedHelpers.journalEntryToFeedEntry(entry);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (ctx) => ExpandedEntryView(
              entry: feedEntry,
              onEntryDeleted: () {},
            ),
          ),
        );
      }
    });
  }

  Future<void> _openReport(BuildContext context, String reportId) async {
    final userId = await AgentsChronicleService.instance.getCurrentUserId();
    final report = await AgentsChronicleService.instance.getResearchReportById(userId, reportId);
    if (report != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => ResearchReportDetailScreen(report: report),
        ),
      );
    }
  }

  void _openOutputsTab(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => const OutputsTabScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultColor = theme.textTheme.bodyMedium?.color ?? kcPrimaryTextColor;
    final baseStyle = (widget.textStyle ?? const TextStyle(fontSize: 15, height: 1.4))
        .copyWith(color: widget.textStyle?.color ?? defaultColor);
    final linkColor = widget.linkColor ?? theme.colorScheme.primary;
    final processedContent = _processContentForMarkdown(widget.content);

    final styleSheet = MarkdownStyleSheet(
      p: baseStyle,
      h1: baseStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
      h2: baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
      h3: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      h4: baseStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
      h5: baseStyle.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      h6: baseStyle.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
      listIndent: 24,
      blockquote: baseStyle.copyWith(
        color: (baseStyle.color ?? defaultColor).withValues(alpha: 0.85),
        fontStyle: FontStyle.italic,
      ),
      code: baseStyle.copyWith(
        fontFamily: 'monospace',
        fontSize: (baseStyle.fontSize ?? 15) * 0.9,
        backgroundColor: (baseStyle.color ?? defaultColor).withValues(alpha: 0.12),
      ),
      codeblockDecoration: BoxDecoration(
        color: (baseStyle.color ?? defaultColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      blockSpacing: 12,
      listBullet: baseStyle,
      tableHead: baseStyle.copyWith(fontWeight: FontWeight.bold),
      tableBody: baseStyle,
      tableBorder: TableBorder.all(
        color: (baseStyle.color ?? defaultColor).withValues(alpha: 0.25),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: (baseStyle.color ?? defaultColor).withValues(alpha: 0.35),
          ),
        ),
      ),
    ).copyWith(
      a: baseStyle.copyWith(
        color: linkColor,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      ),
    );

    return MarkdownBody(
      data: processedContent,
      selectable: true,
      styleSheet: styleSheet,
      onTapLink: (text, href, title) {
        if (href == null || href.isEmpty) return;
        if (href.startsWith('entry:')) {
          final uuid = href.substring(6);
          _openEntry(context, uuid);
        } else if (href.startsWith('report:')) {
          final reportId = href.substring(7);
          _openReport(context, reportId);
        } else if (href == 'outputs:' || href.startsWith('outputs:')) {
          _openOutputsTab(context);
        } else {
          final uri = Uri.tryParse(href);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
    );
  }
}
