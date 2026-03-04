import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// In-app viewer for DOCX attachments. Shows extracted text so users can read
/// document content in reflections without leaving the app.
class DocxPreviewScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  /// Pre-extracted text if already available (e.g. from FileAttachment.extractedText).
  final String? extractedText;

  const DocxPreviewScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.extractedText,
  });

  @override
  State<DocxPreviewScreen> createState() => _DocxPreviewScreenState();
}

class _DocxPreviewScreenState extends State<DocxPreviewScreen> {
  String? _text;
  String? _error;
  bool _loading = true;

  static String _normalizePath(String path) {
    return path.replaceFirst(RegExp(r'^file://'), '');
  }

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (widget.extractedText != null && widget.extractedText!.trim().isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _text = widget.extractedText;
        _loading = false;
      });
      return;
    }
    final path = _normalizePath(widget.filePath);
    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      setState(() {
        _error = 'File not found';
        _loading = false;
      });
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final text = docxToText(bytes);
      if (!mounted) return;
      setState(() {
        _text = text.trim().isEmpty ? '(No text content)' : text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not read document: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openInSystemApp() async {
    final path = _normalizePath(widget.filePath);
    final uri = Uri.file(path);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open ${widget.fileName} in external app'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in default app',
            onPressed: _openInSystemApp,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorBody(theme)
              : _buildContent(theme),
    );
  }

  Widget _buildErrorBody(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openInSystemApp,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in default app'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          _text ?? '',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
