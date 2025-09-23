import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../models/journal_entry_model.dart';
import '../mode/first_responder/fr_settings_cubit.dart';
import '../mode/first_responder/redaction/redaction_service.dart';
import '../mode/first_responder/redaction/redaction_preview_sheet.dart';
import 'package:flutter/material.dart';

class EnhancedExportService {
  final FRSettingsCubit frSettingsCubit;
  final RedactionService redactionService;

  EnhancedExportService({
    required this.frSettingsCubit,
    required this.redactionService,
  });

  /// Share a journal entry with optional redaction
  Future<void> shareJournalEntry(
    BuildContext context,
    JournalEntry entry, {
    String? subject,
    bool showRedactionPreview = false,
  }) async {
    final settings = frSettingsCubit.state;
    String text = entry.content ?? '';
    
    if (text.isEmpty) {
      _showErrorSnackBar(context, 'No content to share');
      return;
    }

    // Check if we should apply redaction
    final shouldRedact = settings.redactionEnabled && 
                        (entry.metadata?['frMode'] == true || 
                         entry.tags.contains('first_responder') == true);

    if (shouldRedact) {
      if (showRedactionPreview) {
        await _showRedactionPreviewAndShare(
          context,
          entry,
          subject: subject,
        );
      } else {
        // Apply redaction directly
        try {
          text = await redactionService.redact(
            entryId: entry.id,
            originalText: text,
            createdAt: entry.createdAt,
            settings: settings,
          );
        } catch (e, st) {
          if (kDebugMode) {
            print('Redaction failed: $e\n$st');
          }
          _showErrorSnackBar(context, 'Redaction failed, sharing original text');
        }
      }
    }

    await _performShare(context, text, subject: subject ?? entry.title);
  }

  /// Share plain text with optional redaction (for debrief records, etc.)
  Future<void> shareText(
    BuildContext context,
    String text, {
    String? subject,
    String? entryId,
    DateTime? createdAt,
    bool forceRedaction = false,
    bool showRedactionPreview = false,
  }) async {
    if (text.isEmpty) {
      _showErrorSnackBar(context, 'No content to share');
      return;
    }

    final settings = frSettingsCubit.state;
    final shouldRedact = forceRedaction || settings.redactionEnabled;

    if (shouldRedact && entryId != null && createdAt != null) {
      if (showRedactionPreview) {
        await _showTextRedactionPreviewAndShare(
          context,
          text,
          entryId: entryId,
          createdAt: createdAt,
          subject: subject,
        );
      } else {
        // Apply redaction directly
        try {
          text = await redactionService.redact(
            entryId: entryId,
            originalText: text,
            createdAt: createdAt,
            settings: settings,
          );
        } catch (e, st) {
          if (kDebugMode) {
            print('Redaction failed: $e\n$st');
          }
          _showErrorSnackBar(context, 'Redaction failed, sharing original text');
        }
      }
    }

    await _performShare(context, text, subject: subject);
  }

  /// Show redaction preview for journal entry and then share
  Future<void> _showRedactionPreviewAndShare(
    BuildContext context,
    JournalEntry entry, {
    String? subject,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RedactionPreviewSheet(
        entryId: entry.id,
        originalText: entry.content ?? '',
        createdAt: entry.createdAt,
        settings: frSettingsCubit.state,
        onApplyAndShare: (redactedText) async {
          await _performShare(
            context,
            redactedText,
            subject: subject ?? entry.title,
          );
        },
      ),
    );
  }

  /// Show redaction preview for plain text and then share
  Future<void> _showTextRedactionPreviewAndShare(
    BuildContext context,
    String text, {
    required String entryId,
    required DateTime createdAt,
    String? subject,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RedactionPreviewSheet(
        entryId: entryId,
        originalText: text,
        createdAt: createdAt,
        settings: frSettingsCubit.state,
        onApplyAndShare: (redactedText) async {
          await _performShare(context, redactedText, subject: subject);
        },
      ),
    );
  }

  /// Perform the actual share operation
  Future<void> _performShare(
    BuildContext context,
    String text, {
    String? subject,
  }) async {
    try {
      await Share.share(text, subject: subject);
      
      // Analytics tracking
      // AnalyticsService.track('content_shared', {
      //   'has_redaction': text.contains('[') && text.contains(']'),
      //   'text_length': text.length,
      // });
      
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to share content');
      if (kDebugMode) {
        print('Share failed: $e');
      }
    }
  }

  /// Show error message to user
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Check if redaction is available for the current settings
  bool isRedactionAvailable() {
    return frSettingsCubit.state.redactionEnabled;
  }

  /// Get redaction status for display purposes
  String getRedactionStatus() {
    if (frSettingsCubit.state.redactionEnabled) {
      return 'Auto-redaction enabled';
    } else {
      return 'Redaction disabled';
    }
  }
}