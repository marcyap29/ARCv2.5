import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/journal_capture_state.dart';
import 'package:my_app/arc/core/keyword_extraction_cubit.dart';
import 'package:my_app/arc/core/widgets/keyword_analysis_view.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_app/core/perf/frame_budget.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/media/media_strip.dart';
import 'package:my_app/arc/core/media/media_preview_dialog.dart';
import 'package:my_app/arc/core/media/ocr_text_insert_dialog.dart';
import 'package:my_app/core/services/media_store.dart';
import 'package:my_app/mira/store/mcp/orchestrator/ios_vision_orchestrator.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:image_picker/image_picker.dart';

class JournalCaptureView extends StatefulWidget {
  final String? initialEmotion;
  final String? initialReason;
  
  const JournalCaptureView({
    super.key,
    this.initialEmotion,
    this.initialReason,
  });

  @override
  State<JournalCaptureView> createState() => _JournalCaptureViewState();
}

class _JournalCaptureViewState extends State<JournalCaptureView> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  
  // Media management
  final List<MediaItem> _mediaItems = [];
  final MediaStore _mediaStore = MediaStore();
  // final OCRService _ocrService = OCRService(); // TODO: Implement OCR service
  final ImagePicker _imagePicker = ImagePicker();
  
  // Manual keywords (matches regular journal mode architecture)
  List<String> _manualKeywords = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    // Add listener for auto-save
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    context.read<JournalCaptureCubit>().updateDraft(_textController.text);
  }

  // Media handling methods
  void _onMediaCaptured(MediaItem mediaItem) async {
    // Add to draft cache first
    context.read<JournalCaptureCubit>().addMediaToDraft(mediaItem);

    // If it's an image, try OCR
    if (mediaItem.type == MediaType.image && mediaItem.ocrText == null) {
      try {
        // Read the image file as bytes
        final imageFile = File(mediaItem.uri);
        if (await imageFile.exists()) {
          // final imageBytes = await imageFile.readAsBytes();
          // final ocrText = await _ocrService.extractText(imageBytes);
          // TODO: Implement OCR when service is available
          final ocrText = null; // OCR service not available
          if (ocrText != null && ocrText.isNotEmpty) {
            // Show OCR text insert dialog
            if (mounted) {
              final insertedText = await showDialog<String>(
                context: context,
                builder: (context) => OCRTextInsertDialog(
                  extractedText: ocrText,
                  onTextInserted: (text) => text,
                ),
              );
              
              if (insertedText != null && insertedText.isNotEmpty) {
                // Insert OCR text into editor
                final currentText = _textController.text;
                final newText = currentText.isEmpty 
                  ? '[from photo] $insertedText'
                  : '$currentText\n\n[from photo] $insertedText';
                _textController.text = newText;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: newText.length),
                );
              }
            }
          }
        }
      } catch (e) {
        // OCR failed, continue without it
        print('OCR failed: $e');
      }
    }
  }

  void _onMediaDeleted(MediaItem mediaItem) async {
    try {
      await _mediaStore.deleteMedia(mediaItem.uri);
      // Remove from draft cache
      context.read<JournalCaptureCubit>().removeMediaFromDraft(mediaItem);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete media: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  void _onMediaPreview(MediaItem mediaItem) {
    showDialog(
      context: context,
      builder: (context) => MediaPreviewDialog(
        mediaItem: mediaItem,
        onDelete: () {
          _onMediaDeleted(mediaItem);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // Working multimodal methods
  Future<void> _handlePhotoGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        for (final image in images) {
          // Save photo to iOS photo library to get ph:// identifier
          final photoId = await PhotoLibraryService.savePhotoToLibrary(image.path);
          if (photoId != null) {
            final mediaItem = MediaItem(
              id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
              uri: photoId, // Use ph:// identifier instead of file path
              type: MediaType.image,
              createdAt: DateTime.now(),
            );
            _onMediaCaptured(mediaItem);
          } else {
            // Fallback to file path if photo library save fails
            final mediaItem = MediaItem(
              id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
              uri: image.path,
              type: MediaType.image,
              createdAt: DateTime.now(),
            );
            _onMediaCaptured(mediaItem);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select photos: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  Future<void> _handleCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        // Save photo to iOS photo library to get ph:// identifier
        final photoId = await PhotoLibraryService.savePhotoToLibrary(image.path);
        if (photoId != null) {
          final mediaItem = MediaItem(
            id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
            uri: photoId, // Use ph:// identifier instead of file path
            type: MediaType.image,
            createdAt: DateTime.now(),
          );
          _onMediaCaptured(mediaItem);
        } else {
          // Fallback to file path if photo library save fails
          final mediaItem = MediaItem(
            id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
            uri: image.path,
            type: MediaType.image,
            createdAt: DateTime.now(),
          );
          _onMediaCaptured(mediaItem);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }



  void _onNextPressed() async {
    // Validate that we have content to proceed
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before proceeding'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    // Remove LUMARA markdown text from content and extract blocks with position tracking
    // This prevents duplicate LUMARA responses (markdown text + InlineBlock)
    // Blocks maintain their insertion positions for proper inline placement
    final result = _removeLumaraMarkdownAndExtractBlocks(_textController.text);

    // Navigate directly to keyword analysis screen (skip emotion selection)
    // This uses the same save mechanic as regular journal entries
    Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => JournalCaptureCubit(context.read<JournalRepository>()),
            ),
            BlocProvider(
              create: (context) => KeywordExtractionCubit()..initialize(),
            ),
          ],
          child: KeywordAnalysisView(
            content: result.cleanedContent, // Use cleaned content without LUMARA markdown
            mood: '', // Empty mood since we're skipping emotion selection
            initialEmotion: widget.initialEmotion,
            initialReason: widget.initialReason,
            manualKeywords: _manualKeywords, // Pass manual keywords (matches regular journal mode)
            mediaItems: _mediaItems.isEmpty ? null : _mediaItems,
            // Extract LUMARA blocks with position tracking for inline placement
            lumaraBlocks: result.blocks.isEmpty ? null : result.blocks,
          ),
        ),
      ),
    ).then((result) {
      // If entry was saved successfully, clear the text and navigate back
      if (result != null && result['save'] == true) {
        _textController.clear();
        _mediaItems.clear();
        // Navigate back to home
        Navigator.of(context).pop();
      }
    });
  }
  
  /// Remove LUMARA markdown text from content and extract blocks with position tracking
  /// Returns cleaned content and blocks with timestamps to maintain conversation order
  ({String cleanedContent, List<Map<String, dynamic>> blocks}) _removeLumaraMarkdownAndExtractBlocks(String content) {
    final blocks = <Map<String, dynamic>>[];
    String cleanedContent = content;
    
    // Find all LUMARA blocks and track their positions in conversation order
    // Pattern matches: **LUMARA:** followed by content until next **You:** or end
    final lumaraPattern = RegExp(r'\*\*LUMARA:\*\*\s*(.+?)(?=\n\n\*\*You:\*\*|\*\*You:\*\*|$)', dotAll: true);
    final matches = lumaraPattern.allMatches(content).toList();
    
    // Process matches in forward order to maintain conversation sequence
    // Each LUMARA block appears after a user turn, so we track the sequence
    // Use a base timestamp and decrement for each earlier block to maintain order
    final baseTimestamp = DateTime.now().millisecondsSinceEpoch;
    int blockIndex = 0;
    
    for (final match in matches) {
      if (match.group(1) != null) {
        final lumaraContent = match.group(1)!.trim();
        // Remove "Reflection" prefix if present
        final cleanContent = lumaraContent.replaceFirst(RegExp(r'^✨\s*Reflection\s*\n?\n?', caseSensitive: false), '').trim();
        
        // Calculate timestamp based on position in conversation
        // Earlier blocks (earlier in conversation) get earlier timestamps
        // This ensures blocks are sorted correctly when displayed
        // Each block gets a timestamp that's 1 second earlier than the next one
        final blockTimestamp = baseTimestamp - ((matches.length - blockIndex - 1) * 1000);
        
        // Get attribution traces for this LUMARA response
        List<Map<String, dynamic>>? attributionTracesJson;
        
        final block = {
          'type': 'inline_reflection', // Correct type for InlineBlock
          'intent': 'chat',
          'content': cleanContent,
          'timestamp': blockTimestamp, // Timestamp maintains conversation order (earlier = smaller timestamp)
        };
        
        // Add attribution traces if available
        if (attributionTracesJson != null && attributionTracesJson.isNotEmpty) {
          block['attributionTraces'] = attributionTracesJson;
        }
        
        blocks.add(block); // Add in order to maintain sequence
        blockIndex++;
      }
    }
    
    // Remove all LUMARA blocks from content in reverse order to maintain positions
    for (int i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      cleanedContent = cleanedContent.substring(0, match.start) + 
                       cleanedContent.substring(match.end);
    }
    
    return (cleanedContent: cleanedContent.trim(), blocks: blocks);
  }
  
  /// Extract LUMARA blocks from text content (legacy method - kept for compatibility)
  /// Format matches regular journal entries for proper purple box rendering
  /// Includes attribution traces for memory attribution display
  List<Map<String, dynamic>>? _extractLumaraBlocks(String content) {
    final result = _removeLumaraMarkdownAndExtractBlocks(content);
    return result.blocks.isEmpty ? null : result.blocks;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocListener<JournalCaptureCubit, JournalCaptureState>(
          listener: (context, state) {
            if (state is JournalCaptureSaved) {
              _textController.clear();
              setState(() {
                _mediaItems.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entry saved successfully'),
                  backgroundColor: kcSuccessColor,
                ),
              );
              Navigator.pop(context);
            } else if (state is JournalCaptureTranscribed) {
              _textController.text = state.transcription;
            } else if (state is JournalCaptureDraftRestored) {
              // Restore draft content and media
              _textController.text = state.content;
              setState(() {
                _mediaItems.clear();
                _mediaItems.addAll(state.mediaItems);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draft restored successfully'),
                  backgroundColor: kcSuccessColor,
                ),
              );
            } else if (state is JournalCaptureMediaAdded) {
              // Add media to local list
              setState(() {
                _mediaItems.add(state.mediaItem);
              });
            } else if (state is JournalCaptureMediaRemoved) {
              // Remove media from local list
              setState(() {
                _mediaItems.removeWhere((item) => item.uri == state.mediaItem.uri);
              });
            }
          },
          child: Scaffold(
            backgroundColor: kcBackgroundColor,
            appBar: AppBar(
              backgroundColor: kcBackgroundColor,
              title: Text('New Entry', style: heading1Style(context)),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Semantics(
                      label: 'Continue to next step',
                      button: true,
                      child: ElevatedButton(
                        onPressed: _onNextPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kcPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text('Next', style: buttonStyle(context)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context from start entry flow
                    if (widget.initialEmotion != null || widget.initialReason != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          gradient: kcPrimaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your reflection context:',
                              style: captionStyle(context).copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (widget.initialEmotion != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      widget.initialEmotion!,
                                      style: captionStyle(context).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                if (widget.initialReason != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      widget.initialReason!,
                                      style: captionStyle(context).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Media Capture Toolbar
                    Card(
                      color: kcSurfaceAltColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Add Media',
                                  style: heading1Style(context).copyWith(fontSize: 18),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Working',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Camera button
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                  child: Semantics(
                                    label: 'Take photo',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt, color: kcPrimaryColor),
                                      onPressed: _handleCamera,
                                    ),
                                  ),
                                ),
                                // Gallery button
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                  child: Semantics(
                                    label: 'Import from gallery',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.photo_library, color: kcPrimaryColor),
                                      onPressed: _handlePhotoGallery,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Status indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatusIndicator('Camera', true, 'Single photo capture'),
                                _buildStatusIndicator('Photo Gallery', true, 'Multi-select support'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Media Strip
                    if (_mediaItems.isNotEmpty) ...[
                      MediaStrip(
                        mediaItems: _mediaItems,
                        onMediaTapped: _onMediaPreview,
                        onMediaDeleted: _onMediaDeleted,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Text editor
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: bodyStyle(context),
                        decoration: InputDecoration(
                          hintText: widget.initialEmotion != null 
                              ? 'Write what is true about feeling ${widget.initialEmotion!.toLowerCase()}...'
                              : 'Write what is true right now.',
                          hintStyle: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        maxLines: null,
                        expands: true,
                        textInputAction: TextInputAction.newline,
                        cursorColor: kcPrimaryColor,
                        cursorWidth: 2,
                        cursorRadius: const Radius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // FPS Performance Overlay (debug only)
        const FrameBudgetOverlay(targetFps: 45),
      ],
    );
  }

  Widget _buildStatusIndicator(String title, bool isWorking, String description) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isWorking ? Icons.check_circle : Icons.error,
                color: isWorking ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isWorking ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

}