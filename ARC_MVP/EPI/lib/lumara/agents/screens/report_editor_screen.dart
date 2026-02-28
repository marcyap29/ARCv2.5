/// Report Editor Screen
///
/// Reflection-style editor for editing research reports.
/// Save updates the artifact; changes appear in timeline and Outputs tab.
library;

import 'package:flutter/material.dart';
import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/services/agents_chronicle_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';

class ReportEditorScreen extends StatefulWidget {
  final ResearchReport report;

  const ReportEditorScreen({super.key, required this.report});

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final body = widget.report.detailedFindings.trim().isNotEmpty
        ? '${widget.report.summary}\n\n${widget.report.detailedFindings}'
        : widget.report.summary;
    _titleController = TextEditingController(text: widget.report.query);
    _bodyController = TextEditingController(text: body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title');
      return;
    }
    if (body.isEmpty) {
      setState(() => _error = 'Enter report content');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final userId = FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';
      final summary = body.length > 300 ? '${body.substring(0, 297)}...' : body;
      await AgentsChronicleService.instance.updateResearchReport(
        userId,
        widget.report.id,
        query: title,
        summary: summary,
        detailedFindings: body,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report saved. Changes appear in timeline and Outputs.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: const Text(
          'Edit Report',
          style: TextStyle(color: kcPrimaryTextColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(color: kcPrimaryColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Outputs',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
              ),
            ],
            Text(
              'Title',
              style: TextStyle(color: kcSecondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: kcPrimaryTextColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Research question or title',
                hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.6)),
                filled: true,
                fillColor: kcSurfaceAltColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Report',
              style: TextStyle(color: kcSecondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bodyController,
              style: const TextStyle(color: kcPrimaryTextColor, fontSize: 15, height: 1.5),
              maxLines: 20,
              minLines: 10,
              decoration: InputDecoration(
                hintText: 'Summary and detailed findings...',
                hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.6)),
                filled: true,
                fillColor: kcSurfaceAltColor,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
