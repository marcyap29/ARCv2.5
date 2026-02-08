import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen in-app PDF viewer with optional "Open in app" (system) action.
class PdfPreviewScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  PdfControllerPinch? _controller;
  String? _fileNotFoundError;

  static String _normalizePath(String path) {
    return path.replaceFirst(RegExp(r'^file://'), '');
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final path = _normalizePath(widget.filePath);
    final exists = await File(path).exists();
    if (!mounted) return;
    setState(() {
      if (!exists) {
        _fileNotFoundError = 'File not found';
      } else {
        _controller = PdfControllerPinch(
          document: PdfDocument.openFile(path),
          initialPage: 1,
        );
      }
    });
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
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
      body: _fileNotFoundError != null
          ? _buildErrorBody(theme)
          : _controller != null
              ? PdfViewPinch(
                  controller: _controller!,
                  onDocumentError: (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to load PDF: $error'),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  },
                  builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorBuilder: (context, error) => Center(
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
                              error.toString(),
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
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
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
              _fileNotFoundError!,
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
}
