// lib/arc/outputs/scan_action_sheet.dart
//
// Phase 5a: Post-scan action sheet (Save to Outputs, Add to Research, type-specific actions).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_app/arc/outputs/output_tagging.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/lumara/profile/user_profile_service.dart';
import 'package:my_app/lumara/profile/profile_fields_screen.dart';
import 'package:my_app/lumara/agents/forms/form_matcher.dart';
import 'package:my_app/lumara/agents/forms/form_review_screen.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/shared/app_colors.dart';

/// Shows the post-scan action sheet. Call after DocumentParser.parseDocument() returns.
void showScanActionSheet({
  required BuildContext context,
  required ParsedDocument document,
  required void Function(OutputSaveRequest) onSaveToOutputs,
  required void Function(String rawText) onAddToResearch,
}) {
  final docType = detectDocumentType(document);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kcBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: _ScanActionSheetContent(
        document: document,
        documentType: docType,
        onSaveToOutputs: onSaveToOutputs,
        onAddToResearch: onAddToResearch,
      ),
    ),
  );
}

/// Request to save a scan to Outputs (agentKey: scanner, folderKey: scans).
class OutputSaveRequest {
  final String title;
  final String contentJson;
  final String agentKey;
  final String folderKey;
  final List<String> autoTags;
  final String? thumbnailUrl;

  const OutputSaveRequest({
    required this.title,
    required this.contentJson,
    required this.agentKey,
    required this.folderKey,
    required this.autoTags,
    this.thumbnailUrl,
  });
}

class _ScanActionSheetContent extends StatelessWidget {
  final ParsedDocument document;
  final String documentType;
  final void Function(OutputSaveRequest) onSaveToOutputs;
  final void Function(String rawText) onAddToResearch;

  const _ScanActionSheetContent({
    required this.document,
    required this.documentType,
    required this.onSaveToOutputs,
    required this.onAddToResearch,
  });

  void _saveToOutputs(BuildContext context) {
    final title = document.title?.trim().isNotEmpty == true
        ? document.title!
        : (document.rawText.length > 50 ? '${document.rawText.substring(0, 50)}...' : 'Scanned document');
    const folderKey = 'scans';
    final path = pathTags('scanner', folderKey);
    final content = contentTagsFromParsedDocument(document, documentType);
    final autoTags = [...path, ...content];
    Navigator.pop(context);
    onSaveToOutputs(OutputSaveRequest(
      title: title,
      contentJson: _documentToJson(document),
      agentKey: 'scanner',
      folderKey: folderKey,
      autoTags: autoTags,
    ));
  }

  String _documentToJson(ParsedDocument doc) {
    return jsonEncode(doc.toJson());
  }

  void _addToResearch(BuildContext context) {
    Navigator.pop(context);
    onAddToResearch(document.rawText);
  }

  void _stubComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — Coming soon')),
    );
  }

  Future<void> _prefillForm(BuildContext context) async {
    final hasProfile = await UserProfileService.instance.hasProfile();
    if (!hasProfile) {
      Navigator.pop(context);
      if (!context.mounted) return;
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set up your profile first to use form pre-fill',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (c) => ProfileFieldsScreen(
                          standaloneMode: true,
                          onSaveAndComplete: () => Navigator.pop(c),
                          onSkip: () => Navigator.pop(c),
                        ),
                      ),
                    );
                  },
                  child: const Text('Set up profile'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    final profile = await UserProfileService.instance.getProfile();
    final matches = FormMatcher.match(document, profile);
    final fieldsUsed = matches
        .where((m) => m.profileKey != null)
        .map((m) => m.profileKey!)
        .toSet()
        .toList();
    final sensitiveFields = fieldsUsed
        .where((k) => UserProfileService.instance.isSensitive(k))
        .toList();
    Navigator.pop(context);
    if (!context.mounted) return;
    if (fieldsUsed.isNotEmpty) {
      final allowed = await PrismService.requestFormPrefillConsent(
        context,
        fieldsUsed: fieldsUsed,
        sensitiveFields: sensitiveFields,
      );
      if (!allowed || !context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form pre-fill cancelled')),
        );
        return;
      }
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => FormReviewScreen(
          document: document,
          matches: matches,
        ),
      ),
    );
  }

  Future<void> _summariseContract(BuildContext context) async {
    final prompt = 'Summarise the key terms of this contract in 3–5 bullet points. Be concise.\n\n'
        'Document text:\n${document.rawText}';
    final result = await PrismService.instance.authoriseAndCall(
      pluginId: 'gemini-flash',
      params: {'prompt': prompt},
      context: context,
    );
    if (!context.mounted) return;
    if (result.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summarise was cancelled')),
      );
      return;
    }
    final text = result.result?.data?['text'] as String? ??
        result.result?.data?['response'] as String? ??
        'No summary returned.';
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Key terms'),
        content: SingleChildScrollView(
          child: Text(text, style: TextStyle(color: kcPrimaryTextColor)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: kcSecondaryTextColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'What would you like to do?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (documentType != 'unknown') ...[
          const SizedBox(height: 4),
          Text(
            'Detected: $documentType',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kcSecondaryTextColor,
                ),
          ),
        ],
        const SizedBox(height: 20),
        _ActionTile(
          icon: Icons.save_outlined,
          label: 'Save to Outputs',
          onTap: () => _saveToOutputs(context),
        ),
        _ActionTile(
          icon: Icons.search,
          label: 'Add to Research',
          onTap: () => _addToResearch(context),
        ),
        if (documentType == 'invoice' || documentType == 'receipt')
          _ActionTile(
            icon: Icons.receipt_long,
            label: 'Save as expense',
            onTap: () => _stubComingSoon(context, 'Save as expense'),
          ),
        if (documentType == 'business_card')
          _ActionTile(
            icon: Icons.contact_page,
            label: 'Save contact',
            onTap: () => _stubComingSoon(context, 'Save contact'),
          ),
        if (documentType == 'form')
          _ActionTile(
            icon: Icons.edit_note,
            label: 'Pre-fill this form',
            onTap: () => _prefillForm(context),
          ),
        if (documentType == 'medical')
          _ActionTile(
            icon: Icons.medical_services_outlined,
            label: 'Save to health records',
            onTap: () => _stubComingSoon(context, 'Save to health records'),
          ),
        if (documentType == 'contract')
          _ActionTile(
            icon: Icons.summarize,
            label: 'Summarise key terms',
            onTap: () => _summariseContract(context),
          ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.close,
          label: 'Dismiss',
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kcPrimaryColor, size: 24),
      title: Text(label, style: TextStyle(color: kcPrimaryTextColor, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

/// Inline result actions (Save to Outputs, Add to Research, Use to fill form, Dismiss) shown below scan result.
/// Use this instead of the modal when the result must stay visible and actions persistent.
class ScanResultActionsInline extends StatelessWidget {
  final ParsedDocument document;
  final void Function(OutputSaveRequest) onSaveToOutputs;
  final void Function(String rawText) onAddToResearch;
  final void Function(ParsedDocument document)? onFillForm;
  final VoidCallback onDismiss;

  const ScanResultActionsInline({
    required this.document,
    required this.onSaveToOutputs,
    required this.onAddToResearch,
    this.onFillForm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final docType = detectDocumentType(document);
    const folderKey = 'scans';
    final title = document.title?.trim().isNotEmpty == true
        ? document.title!
        : (document.rawText.length > 50 ? '${document.rawText.substring(0, 50)}...' : 'Scanned document');
    final path = pathTags('scanner', folderKey);
    final content = contentTagsFromParsedDocument(document, docType);
    final autoTags = [...path, ...content];

    void save() {
      onSaveToOutputs(OutputSaveRequest(
        title: title,
        contentJson: jsonEncode(document.toJson()),
        agentKey: 'scanner',
        folderKey: folderKey,
        autoTags: autoTags,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          'What would you like to do?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (docType != 'unknown') ...[
          const SizedBox(height: 4),
          Text(
            'Detected: $docType',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcSecondaryTextColor),
          ),
        ],
        const SizedBox(height: 12),
        _ActionTile(icon: Icons.save_outlined, label: 'Save to Outputs', onTap: save),
        _ActionTile(icon: Icons.search, label: 'Add to Research', onTap: () => onAddToResearch(document.rawText)),
        if (onFillForm != null)
          _ActionTile(
            icon: Icons.edit_note,
            label: 'Use to fill form',
            onTap: () => onFillForm!(document),
          ),
        _ActionTile(icon: Icons.close, label: 'Dismiss', onTap: onDismiss),
      ],
    );
  }
}
