// lib/lumara/agents/forms/form_review_screen.dart
// Phase 6: Review pre-filled form and save to Outputs.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_app/arc/outputs/output_tagging.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';
import 'package:my_app/arc/outputs/outputs_chronicle_service.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/lumara/profile/user_profile_service.dart';
import 'form_matcher.dart';
import 'package:my_app/shared/app_colors.dart';

class FormReviewScreen extends StatefulWidget {
  final ParsedDocument document;
  final List<FormFieldMatch> matches;

  const FormReviewScreen({
    super.key,
    required this.document,
    required this.matches,
  });

  @override
  State<FormReviewScreen> createState() => _FormReviewScreenState();
}

class _FormReviewScreenState extends State<FormReviewScreen> {
  late List<TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = widget.matches
        .map((m) => TextEditingController(text: m.proposedValue ?? ''))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  Future<void> _saveToOutputs() async {
    setState(() => _saving = true);
    const sensitivePlaceholder = '[sensitive field — not stored]';
    final fields = <Map<String, String>>[];
    for (int i = 0; i < widget.matches.length; i++) {
      final m = widget.matches[i];
      final editedValue = _controllers[i].text.trim();
      final valueToStore = m.isSensitive ? sensitivePlaceholder : editedValue;
      fields.add({
        'label': m.detectedLabel,
        'value': valueToStore,
      });
    }

    final contentJson = jsonEncode({'fields': fields});

    final docType = detectDocumentType(widget.document);
    final path = pathTags('forms', 'completed_forms');
    final autoTags = [...path, docType];
    final title = widget.document.title?.trim().isNotEmpty == true
        ? widget.document.title!
        : 'Form — ${DateTime.now().toString().substring(0, 10)}';

    final item = OutputItem(
      id: '',
      agentKey: 'forms',
      folderKey: 'completed_forms',
      title: title,
      createdAt: DateTime.now(),
      contentJson: contentJson,
      autoTags: autoTags,
      userTags: [],
    );

    try {
      final saved = await OutputsRepository.instance.save(item);
      OutputsChronicleService.instance.onOutputSaved(type: 'output_created', item: saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Outputs')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchedCount = widget.matches.where((m) => m.profileKey != null).length;
    final total = widget.matches.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review pre-filled form'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$matchedCount of $total fields matched from your profile',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.matches.length,
              itemBuilder: (context, index) {
                final m = widget.matches[index];
                final hasMatch = m.profileKey != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            m.detectedLabel,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: kcPrimaryTextColor,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasMatch && m.confidence > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Matched',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.green[700],
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            TextField(
                              controller: _controllers[index],
                              decoration: InputDecoration(
                                hintText: hasMatch ? null : 'Fill in manually',
                                border: const OutlineInputBorder(),
                                filled: m.isSensitive,
                                fillColor: m.isSensitive ? Colors.purple.withOpacity(0.08) : null,
                                suffixIcon: m.isSensitive
                                    ? const Icon(Icons.lock_outline, size: 18, color: Colors.purple)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _saveToOutputs,
                    style: FilledButton.styleFrom(backgroundColor: kcPrimaryColor),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save to Outputs'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
