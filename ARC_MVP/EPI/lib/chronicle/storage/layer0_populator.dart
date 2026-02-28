import 'dart:io';

import '../../../arc/chat/chat/chat_models.dart';
import '../../../arc/chat/chat/content_parts.dart';
import '../../../data/models/media_item.dart';
import '../../../models/journal_entry_model.dart';
import '../../../prism/atlas/phase/phase_history_repository.dart';
import '../../../core/services/pdf_content_service.dart';
import '../../../crossroads/models/decision_capture.dart';
import 'layer0_repository.dart';
import 'raw_entry_schema.dart';

/// Service for populating Layer 0 from journal entries
/// 
/// Extracts data from:
/// - JournalEntry (content, timestamp, metadata)
/// - PhaseHistoryEntry (phase scores, reason)
/// - SENTINEL/RIVET calculations (if available)
/// - Existing theme/keyword extractors

class Layer0Populator {
  final Layer0Repository _layer0Repo;

  Layer0Populator(this._layer0Repo);

  /// Populate Layer 0 from a journal entry
  /// 
  /// Backwards compatible: tolerates null/empty content and null keywords from legacy entries.
  /// Returns true if saved, false if failed (e.g. legacy/corrupt entry).
  Future<bool> populateFromJournalEntry({
    required JournalEntry journalEntry,
    required String userId,
  }) async {
    try {
      // Backwards compatibility: safe content and keywords (legacy Hive entries may have null)
      String content = _safeContent(journalEntry);
      List<String> keywords = List<String>.from(_safeKeywords(journalEntry));

      // Enrich from media attachments: images (altText/keywords), PDFs, files
      for (final media in journalEntry.media) {
        if (media.type == MediaType.image || media.type == MediaType.video) {
          // Image/video: use altText and analysisData for content + keyword extraction
          if (media.altText != null && media.altText!.trim().isNotEmpty) {
            content += '\n\n[Media: ${media.altText!.trim()}]';
            _addKeywordsFromText(media.altText!, keywords);
          }
          if (media.ocrText != null && media.ocrText!.trim().isNotEmpty) {
            content += '\n\n[OCR: ${media.ocrText!.trim()}]';
            _addKeywordsFromText(media.ocrText!, keywords);
          }
          if (media.analysisData != null && media.analysisData!.isNotEmpty) {
            final labels = media.analysisData!['labels'] as List? ?? [];
            final objects = media.analysisData!['objects'] as List? ?? [];
            for (final item in [...labels, ...objects]) {
              if (item is Map) {
                final label = item['label'] ?? item['identifier'];
                if (label is String && label.length > 1 && !keywords.contains(label)) {
                  if (keywords.length < 50) keywords.add(label);
                }
              } else if (item is String && item.length > 1 && !keywords.contains(item)) {
                if (keywords.length < 50) keywords.add(item);
              }
            }
          }
          continue;
        }
        if (media.type != MediaType.file) continue;
        final path = media.uri.replaceFirst(RegExp(r'^file://'), '');
        final name = media.altText ?? path.split(RegExp(r'[/\\]')).last;
        final isPdf = path.toLowerCase().endsWith('.pdf') ||
            name.toLowerCase().endsWith('.pdf');

        if (isPdf) {
          // PDF: re-extract for page image analysis and keywords
          try {
            final file = File(path);
            if (!await file.exists()) continue;
            final result = await PdfContentService.extractForChronicle(
              path,
              includePageImageAnalysis: true,
            );
            if (!result.hasContent) continue;
            content += '\n\n[Attachment: $name]\n';
            if (result.text.trim().isNotEmpty) {
              content += result.text.trim();
            }
            if (result.pageImageInsights.trim().isNotEmpty) {
              content += '\n\n[From PDF pages]\n${result.pageImageInsights.trim()}';
            }
            for (final k in result.keywords) {
              if (k.length > 1 && !keywords.contains(k) && keywords.length < 50) {
                keywords.add(k);
              }
            }
          } catch (_) {
            // Non-fatal: skip this attachment
          }
        } else if (media.ocrText != null && media.ocrText!.trim().isNotEmpty) {
          // txt, md, docx: use pre-extracted text from MediaItem.ocrText
          content += '\n\n[Attachment: $name]\n${media.ocrText!.trim()}';
        }
      }

      // 1. Get phase history entry if available
      final phaseHistory = await PhaseHistoryRepository.getEntryByJournalId(journalEntry.id);

      // 2. Extract metadata (word count from enriched content)
      final wordCount = content.isEmpty ? 0 : content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      final mediaList = journalEntry.media;
      final mediaIds = mediaList.isNotEmpty
          ? mediaList.map((m) => m.id).whereType<String>().where((id) => id.isNotEmpty).toList()
          : <String>[];

      final metadata = RawEntryMetadata(
        wordCount: wordCount,
        voiceTranscribed: journalEntry.audioUri != null,
        mediaAttachments: mediaIds,
      );

      // 3. Extract analysis data (with PDF-derived keywords)
      final analysis = RawEntryAnalysis(
        atlasPhase: _getEffectivePhase(journalEntry, phaseHistory),
        atlasScores: phaseHistory?.phaseScores,
        extractedThemes: keywords,
        keywords: keywords,
      );

      // 4. Create raw entry schema
      final schema = RawEntrySchema(
        entryId: journalEntry.id,
        timestamp: journalEntry.createdAt,
        content: content,
        metadata: metadata,
        analysis: analysis,
      );

      // 5. Convert to Hive model and save
      final rawEntry = ChronicleRawEntry.fromSchema(schema, userId);
      await _layer0Repo.saveEntry(rawEntry);

      print('✅ Layer0Populator: Populated Layer 0 for entry ${journalEntry.id}');
      return true;
    } catch (e) {
      print('❌ Layer0Populator: Failed to populate Layer 0 for entry ${journalEntry.id}: $e');
      return false;
    }
  }

  /// Extract significant words from text and add to keywords (for Chronicle searchability).
  void _addKeywordsFromText(String text, List<String> keywords) {
    const stop = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must', 'can', 'this', 'that', 'these', 'those', 'it', 'its'};
    final words = text.toLowerCase().split(RegExp(r'[\s,;.!?\-:]+')).where((w) => w.length > 2).toList();
    for (final w in words) {
      if (stop.contains(w)) continue;
      if (!keywords.contains(w) && keywords.length < 50) {
        keywords.add(w);
      }
    }
  }

  /// Backwards compatibility: content may be null on legacy Hive entries
  String _safeContent(JournalEntry entry) {
    try {
      final c = (entry as dynamic).content;
      if (c == null) return '';
      if (c is String) return c;
      return c.toString();
    } catch (_) {
      return '';
    }
  }

  /// Backwards compatibility: keywords may be null on legacy Hive entries
  List<String> _safeKeywords(JournalEntry entry) {
    try {
      final k = (entry as dynamic).keywords;
      if (k == null) return const [];
      if (k is List) return List<String>.from(k.whereType<String>());
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Get the effective phase for an entry
  /// Priority: userPhaseOverride > autoPhase > phaseHistory phase > legacy phase
  String? _getEffectivePhase(JournalEntry entry, PhaseHistoryEntry? phaseHistory) {
    // Check user override first
    if (entry.userPhaseOverride != null) {
      return entry.userPhaseOverride;
    }

    // Check auto phase
    if (entry.autoPhase != null) {
      return entry.autoPhase;
    }

    // Check phase history (dominant phase from scores)
    if (phaseHistory != null && phaseHistory.phaseScores.isNotEmpty) {
      final dominantPhase = phaseHistory.phaseScores.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      return dominantPhase;
    }

    // Check legacy phase field
    if (entry.phase != null) {
      return entry.phase;
    }

    return null;
  }

  /// Populate Layer 0 for multiple entries (batch operation)
  Future<({int succeeded, int failed})> populateFromJournalEntries({
    required List<JournalEntry> entries,
    required String userId,
  }) async {
    int succeeded = 0, failed = 0;
    for (final entry in entries) {
      final ok = await populateFromJournalEntry(journalEntry: entry, userId: userId);
      if (ok) {
        succeeded++;
      } else {
        failed++;
      }
    }
    return (succeeded: succeeded, failed: failed);
  }

  /// Populate Layer 0 from a Crossroads DecisionCapture.
  /// Decision entries use entry_type "decision" and store full decision_data in analysis.
  Future<bool> populateFromDecisionCapture({
    required DecisionCapture capture,
    required String userId,
  }) async {
    try {
      final content = [
        capture.decisionStatement,
        capture.lifeContext,
        capture.optionsConsidered,
        capture.successMarker,
      ].where((s) => s.isNotEmpty).join('\n\n');
      final wordCount = content.isEmpty ? 0 : content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;

      final themes = _extractThemesFromDecision(capture.decisionStatement, capture.lifeContext);

      final decisionData = <String, dynamic>{
        'decision_capture_id': capture.id,
        'decision_statement': capture.decisionStatement,
        'life_context': capture.lifeContext,
        'options_considered': capture.optionsConsidered,
        'success_marker': capture.successMarker,
        'outcome_log': capture.outcomeLog,
        'outcome_logged_at': capture.outcomeLoggedAt?.toIso8601String(),
        'phase_at_capture': capture.phaseAtCapture.name,
        'trigger_confidence': capture.triggerConfidence,
        'user_initiated': capture.userInitiated,
      };

      final analysis = RawEntryAnalysis(
        sentinelScore: SentinelScore(
          emotionalIntensity: capture.sentinelScoreAtCapture,
          frequency: 0,
          density: capture.sentinelScoreAtCapture,
        ),
        atlasPhase: capture.phaseAtCapture.name,
        rivetTransitions: const ['decisionCapture'],
        extractedThemes: themes,
        keywords: themes,
        entryType: 'decision',
        decisionData: decisionData,
      );

      final schema = RawEntrySchema(
        entryId: 'decision_${capture.id}',
        timestamp: capture.capturedAt,
        content: content,
        metadata: RawEntryMetadata(
          wordCount: wordCount,
          voiceTranscribed: false,
          mediaAttachments: const [],
        ),
        analysis: analysis,
      );

      final rawEntry = ChronicleRawEntry.fromSchema(schema, userId);
      await _layer0Repo.saveEntry(rawEntry);
      print('✅ Layer0Populator: Populated Layer 0 for decision ${capture.id}');
      return true;
    } catch (e) {
      print('❌ Layer0Populator: Failed to populate Layer 0 for decision ${capture.id}: $e');
      return false;
    }
  }

  List<String> _extractThemesFromDecision(String statement, String lifeContext) {
    final combined = '$statement $lifeContext'.toLowerCase();
    final words = combined.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
    final stop = {'what', 'that', 'this', 'with', 'from', 'have', 'been', 'when', 'where', 'about', 'would', 'could', 'should'};
    final counted = <String, int>{};
    for (final w in words) {
      if (stop.contains(w)) continue;
      counted[w] = (counted[w] ?? 0) + 1;
    }
    final sorted = counted.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  /// Populate Layer 0 from a chat session.
  /// Extracts content from messages (text, media alt/analysis) and builds keywords for Chronicle.
  /// Uses entryId `chat_${session.id}` so sessions can be updated on new messages.
  Future<bool> populateFromChatSession({
    required ChatSession session,
    required List<ChatMessage> messages,
    required String userId,
  }) async {
    try {
      final contentParts = <String>[];
      final keywords = <String>[];
      final mediaIds = <String>[];

      for (final msg in messages) {
        final role = msg.role == MessageRole.user ? 'User' : 'Assistant';
        if (msg.textContent.trim().isNotEmpty) {
          contentParts.add('[$role]: ${msg.textContent.trim()}');
          _addKeywordsFromText(msg.textContent, keywords);
        }
        if (msg.contentParts != null) {
          for (final part in msg.contentParts!) {
            if (part is TextContentPart && part.text.trim().isNotEmpty) {
              contentParts.add('[$role]: ${part.text.trim()}');
              _addKeywordsFromText(part.text, keywords);
            }
            if (part is MediaContentPart) {
              if (part.alt != null && part.alt!.trim().isNotEmpty) {
                contentParts.add('[Media: ${part.alt!.trim()}]');
                _addKeywordsFromText(part.alt!, keywords);
              }
              final meta = part.pointer.metadata;
              if (meta.isNotEmpty) {
                final kws = meta['keywords'];
                if (kws is List) {
                  for (final k in kws) {
                    if (k is String && k.length > 1 && !keywords.contains(k) && keywords.length < 50) {
                      keywords.add(k);
                    }
                  }
                }
                final labels = meta['labels'] as List?;
                if (labels != null) {
                  for (final item in labels) {
                    if (item is String && item.length > 1 && !keywords.contains(item) && keywords.length < 50) {
                      keywords.add(item);
                    } else if (item is Map && item['label'] != null) {
                      final label = item['label'].toString();
                      if (label.length > 1 && !keywords.contains(label) && keywords.length < 50) {
                        keywords.add(label);
                      }
                    }
                  }
                }
              }
              if (part.pointer.uri.isNotEmpty) mediaIds.add(part.pointer.uri);
            }
            if (part is PrismContentPart) {
              final s = part.summary;
              if (s.captions != null) {
                for (final c in s.captions!) {
                  contentParts.add('[Caption: $c]');
                  _addKeywordsFromText(c, keywords);
                }
              }
              if (s.transcript != null && s.transcript!.trim().isNotEmpty) {
                contentParts.add('[Transcript: ${s.transcript!.trim()}]');
                _addKeywordsFromText(s.transcript!, keywords);
              }
              if (s.objects != null) {
                for (final o in s.objects!) {
                  if (o.length > 1 && !keywords.contains(o) && keywords.length < 50) {
                    keywords.add(o);
                  }
                }
              }
            }
          }
        }
      }

      final content = [
        'Chat: ${session.subject}',
        if (session.tags.isNotEmpty) 'Tags: ${session.tags.join(", ")}',
        '',
        contentParts.join('\n'),
      ].join('\n');

      final wordCount = content.isEmpty ? 0 : content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      _addKeywordsFromText(session.subject, keywords);
      for (final t in session.tags) {
        if (t.length > 1 && !keywords.contains(t) && keywords.length < 50) keywords.add(t);
      }

      final chatData = <String, dynamic>{
        'session_id': session.id,
        'subject': session.subject,
        'message_count': session.messageCount,
        'tags': session.tags,
        if (session.displayPhase != null) 'phase': session.displayPhase,
      };

      final analysis = RawEntryAnalysis(
        extractedThemes: keywords,
        keywords: keywords,
        entryType: 'chat',
        chatData: chatData,
      );

      final schema = RawEntrySchema(
        entryId: 'chat_${session.id}',
        timestamp: session.updatedAt,
        content: content,
        metadata: RawEntryMetadata(
          wordCount: wordCount,
          voiceTranscribed: false,
          mediaAttachments: mediaIds,
        ),
        analysis: analysis,
      );

      final rawEntry = ChronicleRawEntry.fromSchema(schema, userId);
      await _layer0Repo.saveEntry(rawEntry);
      print('✅ Layer0Populator: Populated Layer 0 for chat ${session.id}');
      return true;
    } catch (e) {
      print('❌ Layer0Populator: Failed to populate Layer 0 for chat ${session.id}: $e');
      return false;
    }
  }

  /// Populate Layer 0 for multiple chat sessions (batch operation).
  Future<({int succeeded, int failed})> populateFromChatSessions({
    required List<ChatSession> sessions,
    required String userId,
    required Future<List<ChatMessage>> Function(String sessionId) getMessages,
  }) async {
    int succeeded = 0, failed = 0;
    for (final session in sessions) {
      final messages = await getMessages(session.id);
      final ok = await populateFromChatSession(
        session: session,
        messages: messages,
        userId: userId,
      );
      if (ok) {
        succeeded++;
      } else {
        failed++;
      }
    }
    return (succeeded: succeeded, failed: failed);
  }
}
