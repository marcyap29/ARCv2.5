import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:audioplayers/audioplayers.dart';

import '../mcp_pointer_service.dart';
import '../../models/mcp_schemas.dart';

/// Inline thumbnail widget for MCP pointers
class InlineThumbnail extends StatefulWidget {
  final McpPointer pointer;
  final String size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const InlineThumbnail({
    super.key,
    required this.pointer,
    this.size = 'mini',
    this.onTap,
    this.onLongPress,
  });

  @override
  State<InlineThumbnail> createState() => _InlineThumbnailState();
}

class _InlineThumbnailState extends State<InlineThumbnail> {
  ThumbnailResult? _thumbnailResult;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final result = await McpPointerService.generateThumbnail(
        widget.pointer,
        widget.size,
      );
      
      if (mounted) {
        setState(() {
          _thumbnailResult = result;
          _isLoading = false;
          _error = result.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _getThumbnailSize();
    
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildThumbnailContent(),
        ),
      ),
    );
  }

  Widget _buildThumbnailContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorThumbnail();
    }

    if (_thumbnailResult?.thumbnailUri != null) {
      return Image.network(
        _thumbnailResult!.thumbnailUri!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorThumbnail(),
      );
    }

    return _buildPlaceholderThumbnail();
  }

  Widget _buildErrorThumbnail() {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.error_outline,
        color: Colors.grey.shade400,
        size: _getThumbnailSize().width * 0.4,
      ),
    );
  }

  Widget _buildPlaceholderThumbnail() {
    IconData iconData;
    Color iconColor;
    
    switch (widget.pointer.mediaType) {
      case 'image':
        iconData = Icons.image;
        iconColor = Colors.blue;
        break;
      case 'video':
        iconData = Icons.videocam;
        iconColor = Colors.red;
        break;
      case 'audio':
        iconData = Icons.audiotrack;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    return Container(
      color: Colors.grey.shade50,
      child: Icon(
        iconData,
        color: iconColor,
        size: _getThumbnailSize().width * 0.5,
      ),
    );
  }

  Size _getThumbnailSize() {
    switch (widget.size) {
      case 'mini':
        return const Size(48, 48);
      case 'small':
        return const Size(72, 72);
      case 'medium':
        return const Size(120, 120);
      default:
        return const Size(48, 48);
    }
  }
}

/// Rich popup for displaying MCP pointer content
class McpPointerPopup extends StatefulWidget {
  final McpPointer pointer;
  final Map<String, dynamic> extractedData;

  const McpPointerPopup({
    super.key,
    required this.pointer,
    required this.extractedData,
  });

  @override
  State<McpPointerPopup> createState() => _McpPointerPopupState();
}

class _McpPointerPopupState extends State<McpPointerPopup> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMediaContent(),
                    const SizedBox(height: 16),
                    _buildMetadata(),
                    const SizedBox(height: 16),
                    _buildAnalysisData(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          _getMediaIcon(),
          color: _getMediaColor(),
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${widget.pointer.mediaType.toUpperCase()} Content',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildMediaContent() {
    switch (widget.pointer.mediaType) {
      case 'image':
        return _buildImageContent();
      case 'video':
        return _buildVideoContent();
      case 'audio':
        return _buildAudioContent();
      default:
        return _buildFileContent();
    }
  }

  Widget _buildImageContent() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.pointer.sourceUri ?? '',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: Icon(Icons.image_not_supported, size: 48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent() {
    return Container(
      width: double.infinity,
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleAudioPlayback,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 32,
            color: Colors.green,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Audio Recording',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.pointer.descriptor.duration != null)
                  Text(
                    _formatDuration(Duration(seconds: widget.pointer.descriptor.duration!)),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent() {
    return Container(
      width: double.infinity,
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'File Attachment',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.pointer.descriptor.mimeType ?? 'unknown',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (widget.pointer.descriptor.sizeBytes != null && widget.pointer.descriptor.sizeBytes! > 0)
                  Text(
                    _formatFileSize(widget.pointer.descriptor.sizeBytes!),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metadata',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildMetadataRow('Type', widget.pointer.mediaType),
            _buildMetadataRow('MIME Type', widget.pointer.descriptor.mimeType ?? 'unknown'),
            if (widget.pointer.descriptor.sizeBytes != null && widget.pointer.descriptor.sizeBytes! > 0)
              _buildMetadataRow('Size', _formatFileSize(widget.pointer.descriptor.sizeBytes!)),
            if (widget.pointer.descriptor.duration != null)
              _buildMetadataRow('Duration', _formatDuration(Duration(seconds: widget.pointer.descriptor.duration!))),
            _buildMetadataRow('Created', widget.pointer.createdAt != null ? _formatDateTime(widget.pointer.createdAt!) : 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisData() {
    if (widget.extractedData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis Results',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (widget.extractedData['ocrText'] != null)
              _buildAnalysisRow('OCR Text', widget.extractedData['ocrText']),
            if (widget.extractedData['transcript'] != null)
              _buildAnalysisRow('Transcript', widget.extractedData['transcript']),
            if (widget.extractedData['objects'] != null)
              _buildAnalysisRow('Objects', widget.extractedData['objects'].toString()),
            if (widget.extractedData['sage'] != null)
              _buildAnalysisRow('SAGE Analysis', widget.extractedData['sage'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _shareContent,
          child: const Text('Share'),
        ),
      ],
    );
  }

  IconData _getMediaIcon() {
    switch (widget.pointer.mediaType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getMediaColor() {
    switch (widget.pointer.mediaType) {
      case 'image':
        return Colors.blue;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _toggleAudioPlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.pointer.sourceUri ?? ''));
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _shareContent() {
    // TODO: Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing functionality coming soon')),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Gallery widget for multiple MCP pointers
class McpPointerGallery extends StatelessWidget {
  final List<McpPointer> pointers;
  final String size;

  const McpPointerGallery({
    super.key,
    required this.pointers,
    this.size = 'small',
  });

  @override
  Widget build(BuildContext context) {
    if (pointers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: _getGalleryHeight(),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pointers.length,
        itemBuilder: (context, index) {
          final pointer = pointers[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InlineThumbnail(
              pointer: pointer,
              size: size,
              onTap: () => _showPointerPopup(context, pointer),
            ),
          );
        },
      ),
    );
  }

  double _getGalleryHeight() {
    switch (size) {
      case 'mini':
        return 56;
      case 'small':
        return 80;
      case 'medium':
        return 128;
      default:
        return 80;
    }
  }

  void _showPointerPopup(BuildContext context, McpPointer pointer) {
    showDialog(
      context: context,
      builder: (context) => McpPointerPopup(
        pointer: pointer,
        extractedData: {}, // TODO: Pass actual extracted data
      ),
    );
  }
}
