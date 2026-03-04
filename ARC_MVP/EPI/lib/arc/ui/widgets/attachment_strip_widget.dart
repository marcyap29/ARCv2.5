// lib/arc/ui/widgets/attachment_strip_widget.dart
// Shared attachment strip: same format/architecture as the reflection (journal) editor.
// Use in journal and chat for consistent UI/UX and less code duplication.

import 'dart:io';

import 'package:flutter/material.dart';

/// One file item for display in the strip (path, name, mime).
class AttachmentFileItem {
  final String path;
  final String fileName;
  final String mimeType;
  final String? extractedText;

  const AttachmentFileItem({
    required this.path,
    required this.fileName,
    required this.mimeType,
    this.extractedText,
  });
}

/// One image item for display (path only).
class AttachmentImageItem {
  final String imagePath;

  const AttachmentImageItem({required this.imagePath});
}

/// Strip of file chips + photo thumbnails in the same style as the journal/reflection editor.
/// Use for pending attachments in chat or for attached files/photos in journal.
class AttachmentStripWidget extends StatelessWidget {
  final List<AttachmentFileItem> files;
  final List<AttachmentImageItem> images;
  final void Function(int index)? onRemoveFile;
  final void Function(int index)? onRemoveImage;
  final void Function(int index)? onTapFile;
  final void Function(int index)? onLongPressFile;
  final void Function(int index)? onTapImage;

  const AttachmentStripWidget({
    super.key,
    this.files = const [],
    this.images = const [],
    this.onRemoveFile,
    this.onRemoveImage,
    this.onTapFile,
    this.onLongPressFile,
    this.onTapImage,
  });

  bool get hasContent => files.isNotEmpty || images.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hasContent) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (files.isNotEmpty) ...[
            _buildSectionHeader(theme, Icons.attach_file, 'Files (${files.length})'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(files.length, (index) {
                return _buildFileChip(context, theme, files[index], index);
              }),
            ),
            if (images.isNotEmpty) const SizedBox(height: 16),
          ],
          if (images.isNotEmpty) ...[
            _buildSectionHeader(theme, Icons.photo_library, 'Photos (${images.length})'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(images.length, (index) {
                return _buildImageThumbnail(context, theme, images[index], index);
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFileChip(BuildContext context, ThemeData theme, AttachmentFileItem file, int index) {
    final lower = file.fileName.toLowerCase();
    IconData icon = Icons.insert_drive_file;
    if (lower.endsWith('.pdf')) icon = Icons.picture_as_pdf;
    if (lower.endsWith('.md') || lower.endsWith('.docx') || lower.endsWith('.doc')) icon = Icons.description;
    if (lower.endsWith('.txt')) icon = Icons.text_snippet;

    return GestureDetector(
      onTap: () => onTapFile?.call(index),
      onLongPress: onLongPressFile != null ? () => onLongPressFile!(index) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                file.fileName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (onRemoveFile != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onRemoveFile!(index),
                child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, ThemeData theme, AttachmentImageItem image, int index) {
    final file = File(image.imagePath);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: file.existsSync()
              ? Image.file(
                  file,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 56,
                  height: 56,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
                ),
        ),
        if (onTapImage != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTapImage!(index),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        if (onRemoveImage != null)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => onRemoveImage!(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
