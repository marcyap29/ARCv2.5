// lib/arc/outputs/output_detail_screen.dart
//
// Phase 5a: Full content view for an OutputItem.
// For scanner/scans: shows photo gallery (reflection-style) + extracted text.
// For completed forms: shows form layout (label/value) and export to PDF/DOCX.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/arc/outputs/completed_form_export_service.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/widgets/tag_chip_row.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/ui/journal/widgets/full_screen_photo_viewer.dart';

class OutputDetailScreen extends StatelessWidget {
  final OutputItem item;

  const OutputDetailScreen({super.key, required this.item});

  /// Whether this item is a completed form (Outputs → Completed Forms).
  static bool isCompletedFormItem(OutputItem item) {
    return item.agentKey == 'forms' && item.folderKey == 'completed_forms';
  }

  /// Parse completed form content: list of {label, value}. Returns null if not valid.
  static List<FormFieldExport>? parseCompletedFormContent(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return null;
    try {
      final map = jsonDecode(contentJson) as Map<String, dynamic>?;
      if (map == null) return null;
      final list = map['fields'] as List<dynamic>?;
      if (list == null) return null;
      final out = <FormFieldExport>[];
      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;
        final label = (e['label'] as String?) ?? '';
        final value = (e['value'] as String?) ?? '';
        out.add(FormFieldExport(label: label, value: value));
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Parse research (ContentBrief) content for Research folder. Returns null if not valid.
  static ContentBrief? parseResearchContent(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return null;
    try {
      final map = jsonDecode(contentJson) as Map<String, dynamic>?;
      if (map == null) return null;
      return ContentBrief.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse scan content: returns (rawText, list of image paths) if scan format.
  static ({String? rawText, List<String> imagePaths}) parseScanContent(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return (rawText: null, imagePaths: []);
    try {
      final map = jsonDecode(contentJson) as Map<String, dynamic>?;
      if (map == null) return (rawText: null, imagePaths: []);
      final rawText = map['raw_text'] as String?;
      final paths = <String>[];
      final single = map['image_path'] as String?;
      if (single != null && single.isNotEmpty) paths.add(single);
      final list = map['image_paths'] as List<dynamic>?;
      if (list != null) {
        for (final e in list) {
          if (e is String && e.isNotEmpty && !paths.contains(e)) paths.add(e);
        }
      }
      return (rawText: rawText, imagePaths: paths);
    } catch (_) {
      return (rawText: null, imagePaths: []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScan = item.agentKey == 'scanner' && item.folderKey == 'scans';
    final scanData = isScan ? parseScanContent(item.contentJson) : (rawText: null, imagePaths: <String>[]);
    final hasScanImages = scanData.imagePaths.isNotEmpty;
    final isCompletedForm = isCompletedFormItem(item);
    final formFields = isCompletedForm ? parseCompletedFormContent(item.contentJson) : null;
    final isResearch = item.agentKey == 'research' && item.folderKey == 'research';
    final researchBrief = isResearch ? parseResearchContent(item.contentJson) : null;
    final showGenericContent = item.contentJson != null &&
        item.contentJson!.isNotEmpty &&
        (!isCompletedForm || formFields == null || formFields.isEmpty) &&
        (!isResearch || researchBrief == null);

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        title: Text(
          item.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isCompletedForm && formFields != null && formFields.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Export form',
              onPressed: () => _showExportFormSheet(context, item, formFields),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMd().add_Hm().format(item.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
            if (item.autoTags.isNotEmpty || item.userTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              TagChipRow(
                autoTags: item.autoTags,
                userTags: item.userTags,
                editable: false,
              ),
            ],
            // Scan gallery (reflection-style): horizontal thumbnails, tap for full screen
            if (hasScanImages) ...[
              const SizedBox(height: 20),
              Text(
                'Scan',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: scanData.imagePaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = scanData.imagePaths[index];
                    return _ScanThumbnail(
                      imagePath: path,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (ctx) => FullScreenPhotoViewer(
                              photos: scanData.imagePaths
                                  .map((p) => PhotoData(imagePath: p))
                                  .toList(),
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
            // Completed form: organized label/value layout
            if (isCompletedForm && formFields != null && formFields.isNotEmpty) ...[
              const SizedBox(height: 20),
              _CompletedFormContent(fields: formFields),
            ],
            // Research: readable form layout (title, summary, key points, sources)
            if (isResearch && researchBrief != null) ...[
              const SizedBox(height: 20),
              _ResearchFormContent(brief: researchBrief),
            ],
            // Extracted text (scans) or generic content (or fallback when form parse fails)
            if (showGenericContent) ...[
              if (!isScan || (scanData.rawText != null && scanData.rawText!.isNotEmpty)) ...[
                const SizedBox(height: 20),
                Text(
                  isScan ? 'Extracted text' : 'Content',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kcSurfaceAltColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    isScan ? (scanData.rawText ?? '') : item.contentJson!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kcPrimaryTextColor,
                        ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static void _showExportFormSheet(BuildContext context, OutputItem item, List<FormFieldExport> fields) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kcSurfaceAltColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Export form',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: kcPrimaryTextColor),
                title: const Text('PDF'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await CompletedFormExportService.instance.exportAndShare(
                    title: item.title,
                    createdAt: item.createdAt,
                    fields: fields,
                    format: CompletedFormExportFormat.pdf,
                  );
                  if (ctx.mounted && !ok) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Export failed')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: kcPrimaryTextColor),
                title: const Text('Word (.docx)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await CompletedFormExportService.instance.exportAndShare(
                    title: item.title,
                    createdAt: item.createdAt,
                    fields: fields,
                    format: CompletedFormExportFormat.docx,
                  );
                  if (ctx.mounted && !ok) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Export failed')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Research-form layout for ContentBrief (title, summary, key points, sources).
class _ResearchFormContent extends StatelessWidget {
  final ContentBrief brief;

  const _ResearchFormContent({required this.brief});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Title'),
        const SizedBox(height: 4),
        _valueBlock(context, brief.title.isEmpty ? brief.query : brief.title),
        if (brief.summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionLabel(context, 'Summary'),
          const SizedBox(height: 4),
          _valueBlock(context, brief.summary),
        ],
        if (brief.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionLabel(context, 'Key points'),
          const SizedBox(height: 8),
          ...brief.keyPoints.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kcPrimaryTextColor),
                    ),
                    Expanded(
                      child: SelectableText(
                        p,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kcPrimaryTextColor),
                      ),
                    ),
                  ],
                ),
              )),
        ],
        if (brief.sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionLabel(context, 'Sources'),
          const SizedBox(height: 8),
          ...brief.sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      s.title.isNotEmpty ? s.title : s.url,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: kcPrimaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (s.url.isNotEmpty)
                      SelectableText(
                        s.url,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: kcSecondaryTextColor,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: kcSecondaryTextColor,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _valueBlock(BuildContext context, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kcSecondaryTextColor.withValues(alpha: 0.2)),
      ),
      child: SelectableText(
        value.isEmpty ? '—' : value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kcPrimaryTextColor),
      ),
    );
  }
}

/// Form-style layout for completed form fields (label + value rows).
class _CompletedFormContent extends StatelessWidget {
  final List<FormFieldExport> fields;

  const _CompletedFormContent({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Form',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ...fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: kcSecondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: kcSurfaceAltColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kcSecondaryTextColor.withValues(alpha: 0.2)),
                    ),
                    child: SelectableText(
                      f.value.isEmpty ? '—' : f.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: kcPrimaryTextColor,
                          ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

/// Thumbnail for a scan image (file path); tap opens full-screen viewer.
/// Restore step-by-step: uncomment one block at a time and run `flutter build ios --release` until it fails, then fix that block.
class _ScanThumbnail extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;

  const _ScanThumbnail({required this.imagePath, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    // Minimal working: tap target with placeholder. Uncomment below blocks one at a time to restore full UI.
    return Material(
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 120,
            height: 120,
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 32,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
