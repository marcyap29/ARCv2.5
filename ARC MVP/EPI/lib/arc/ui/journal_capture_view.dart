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
import 'package:my_app/arc/chat/voice/voice_chat_service.dart';
import 'package:my_app/arc/chat/voice/voice_orchestrator.dart';
import 'package:my_app/arc/chat/ui/voice_chat_panel.dart';
import 'package:my_app/arc/chat/voice/voice_permissions.dart';
import 'package:my_app/arc/chat/services/enhanced_lumara_api.dart';
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/arc/chat/data/context_provider.dart';
import 'package:my_app/telemetry/analytics.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';

class JournalCaptureView extends StatefulWidget {
  final String? initialEmotion;
  final String? initialReason;
  final bool startWithVoice; // If true, opens with voice mode activated
  
  const JournalCaptureView({
    super.key,
    this.initialEmotion,
    this.initialReason,
    this.startWithVoice = false,
  });

  @override
  State<JournalCaptureView> createState() => _JournalCaptureViewState();
}

/// Wrapper widget that opens journal capture with voice mode activated
class JournalCaptureViewWithVoice extends StatelessWidget {
  const JournalCaptureViewWithVoice({super.key});

  @override
  Widget build(BuildContext context) {
    return JournalCaptureView(startWithVoice: true);
  }
}

class _JournalCaptureViewState extends State<JournalCaptureView> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _showVoiceRecorder = false;
  
  // Media management
  final List<MediaItem> _mediaItems = [];
  final MediaStore _mediaStore = MediaStore();
  // final OCRService _ocrService = OCRService(); // TODO: Implement OCR service
  final ImagePicker _imagePicker = ImagePicker();
  
  // Manual keywords (matches regular journal mode architecture)
  List<String> _manualKeywords = [];
  
  // Voice chat service for journal context
  VoiceChatService? _voiceChatService;
  String? _partialTranscript;
  bool _voiceServiceInitialized = false; // Track initialization status

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    // Add listener for auto-save
    _textController.addListener(_onTextChanged);
    
    // Initialize voice chat service for journal context
    _initializeVoiceChat();
    
    // If startWithVoice is true, activate voice mode after initialization
    if (widget.startWithVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showVoiceRecorder = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _voiceChatService?.dispose();
    super.dispose();
  }
  
  /// Initialize voice chat service with journal context
  Future<void> _initializeVoiceChat() async {
    try {
      final journalCubit = context.read<JournalCaptureCubit>();
      
      // Get EnhancedLumaraApi
      final enhancedApi = EnhancedLumaraApi(Analytics());
      await enhancedApi.initialize();
      
      // Set LUMARA API on cubit for summary generation
      journalCubit.setLumaraApi(enhancedApi);
      
      // Try to get LumaraAssistantCubit from context (may not always be available)
      LumaraAssistantCubit? chatCubit;
      ContextProvider? contextProvider;
      try {
        chatCubit = context.read<LumaraAssistantCubit>();
        contextProvider = context.read<ContextProvider>();
      } catch (e) {
        debugPrint('LumaraAssistantCubit or ContextProvider not available in context: $e');
        // Continue without them - MainChatManager can work without cubit for basic functionality
      }
      
      _voiceChatService = VoiceChatService(
        lumaraApi: enhancedApi,
        journalCubit: journalCubit,
        chatCubit: chatCubit, // Provide cubit if available
        contextProvider: contextProvider, // Provide context provider if available
        context: VoiceContext.journal, // Set to journal context
        onTextWritten: (text) {
          // Append text to the text controller
          final currentText = _textController.text;
          _textController.text = currentText + text;
          // Move cursor to end
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        },
      );
      
      final initialized = await _voiceChatService!.initialize();
      if (mounted) {
        setState(() {
          _voiceServiceInitialized = true;
        });
      }
      
      if (!initialized && mounted) {
        // Permission not granted, but service is created
        debugPrint('Voice chat service not initialized - permissions may be needed');
      }
      
      // Listen to partial transcript stream
      if (mounted && _voiceChatService != null) {
        _voiceChatService!.partialTranscriptStream.listen((transcript) {
          if (mounted) {
            setState(() {
              _partialTranscript = transcript;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing voice chat for journal: $e');
      if (mounted) {
        setState(() {
          _voiceServiceInitialized = true; // Mark as initialized even on error to stop spinner
        });
      }
    }
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

  Future<void> _handleMicrophone() async {
    // Activate voice journal mode
    setState(() {
      _showVoiceRecorder = true;
    });
    
    // Request microphone permission if not already granted
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice journaling'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }
    
    // If voice service isn't initialized yet, initialize it
    if (_voiceChatService == null || !_voiceServiceInitialized) {
      await _initializeVoiceChat();
    }
    
    // Re-initialize if permission was just granted
    if (status == PermissionStatus.granted && _voiceChatService != null) {
      await _voiceChatService!.initialize();
      if (mounted) {
        setState(() {
          _voiceServiceInitialized = true;
        });
      }
    }
    
    // Ensure voice recorder stays visible after initialization
    if (mounted && !_showVoiceRecorder) {
      setState(() {
        _showVoiceRecorder = true;
      });
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
        if (_voiceChatService != null && cleanContent.isNotEmpty) {
          final traces = _voiceChatService!.getAttributionTraces(cleanContent);
          if (traces != null && traces.isNotEmpty) {
            attributionTracesJson = traces.map((trace) => trace.toJson()).toList();
          }
        }
        
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
                _showVoiceRecorder = false;
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
                                // Microphone button
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                  child: Semantics(
                                    label: 'Record voice note',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.mic, color: kcPrimaryColor),
                                      onPressed: _handleMicrophone,
                                    ),
                                  ),
                                ),
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
                                _buildStatusIndicator('Microphone', true, 'Voice recording ready'),
                                _buildStatusIndicator('Camera', true, 'Single photo capture'),
                                _buildStatusIndicator('Photo Gallery', true, 'Multi-select support'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Voice recording section (if enabled)
                    if (_showVoiceRecorder) ...[
                      Card(
                        color: kcSurfaceAltColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with collapse button - always visible
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Voice Journal',
                                    style: heading1Style(context).copyWith(fontSize: 18),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.expand_less,
                                      color: kcPrimaryColor,
                                    ),
                                    tooltip: 'Collapse voice journal',
                                    onPressed: () {
                                      // Dismiss keyboard first
                                      FocusScope.of(context).unfocus();
                                      setState(() {
                                        _showVoiceRecorder = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Voice chat panel for journal context - make it constrained and scrollable
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 400, // Limit height to prevent clipping
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_voiceServiceInitialized) ...[
                                        // Show loading while initializing
                                        const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(24.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                      ] else if (_voiceChatService != null && _voiceChatService!.controller != null) ...[
                                        VoiceChatPanel(
                                          controller: _voiceChatService!.controller!,
                                          diagnostics: _voiceChatService!.diagnostics,
                                          partialTranscript: _partialTranscript,
                                        ),
                                      ] else ...[
                                        // Show message if initialization failed (e.g., permissions not granted)
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Column(
                                              children: [
                                                const Icon(
                                                  Icons.mic_off,
                                                  size: 48,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Microphone permission required',
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Please grant microphone permission in Settings to use voice journaling.',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: Colors.grey,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                        // Prevent keyboard from hiding voice recorder
                        onTap: () {
                          // Keep voice recorder visible when keyboard appears
                          if (_showVoiceRecorder) {
                            // Optionally scroll to keep voice recorder in view
                          }
                        },
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

  Widget _buildPermissionSection(JournalCaptureState state) {
    return Column(
      children: [
        Text(
          'Record your thoughts with your voice',
          style: bodyStyle(context),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Semantics(
            label: 'Enable voice journaling and request microphone permission',
            button: true,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<JournalCaptureCubit>().requestMicrophonePermission();
              },
              icon: const Icon(Icons.mic, color: Colors.white),
              label: Text('Enable Voice Journaling', style: buttonStyle(context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ),
        if (state is JournalCapturePermissionDenied) ...[
          const SizedBox(height: 16),
          Text(
            state.message,
            style: bodyStyle(context).copyWith(color: kcDangerColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              openAppSettings();
            },
            child: Text(
              'Open Settings to Grant Permission',
              style: linkStyle(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordingSection(JournalCaptureState state) {
    Duration recordingDuration = Duration.zero;
    bool isRecording = false;
    bool isPaused = false;

    if (state is JournalCaptureRecording) {
      recordingDuration = state.recordingDuration;
      isRecording = true;
    } else if (state is JournalCaptureRecordingPaused) {
      recordingDuration = state.recordingDuration;
      isPaused = true;
    } else if (state is JournalCaptureRecordingStopped) {
      recordingDuration = state.recordingDuration;
    }

    return Column(
      children: [
        // Visualizer
        Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: kcPrimaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: isRecording
                ? _buildVisualizer()
                : const Icon(
                    Icons.mic,
                    size: 40,
                    color: Colors.white,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Timer
        Text(
          _formatDuration(recordingDuration),
          style: bodyStyle(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (isRecording) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Pause recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.pause, color: kcSecondaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().pauseRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Stop recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.stop, color: kcDangerColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().stopRecording();
                    },
                  ),
                ),
              ),
            ] else if (isPaused) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Resume recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, color: kcPrimaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().startRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Stop recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.stop, color: kcDangerColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().stopRecording();
                    },
                  ),
                ),
              ),
            ] else if (state is JournalCaptureRecordingStopped) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Play recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, color: kcPrimaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().playRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Start new recording',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.restart_alt, color: kcSecondaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().startRecording();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Transcribe audio to text',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<JournalCaptureCubit>().transcribeAudio();
                    },
                    icon: const Icon(Icons.translate, color: Colors.white),
                    label: Text('Transcribe', style: buttonStyle(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                    ),
                  ),
                ),
              ),
            ] else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Semantics(
                  label: 'Start recording voice',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.fiber_manual_record,
                        color: kcPrimaryColor),
                    onPressed: () {
                      context.read<JournalCaptureCubit>().startRecording();
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTranscriptionSection(JournalCaptureState state) {
    if (state is JournalCaptureTranscribing) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Transcribing your voice...', style: bodyStyle(context)),
        ],
      );
    }

    if (state is JournalCaptureTranscribed) {
      return Column(
        children: [
          Text('Transcription:', style: heading1Style(context)),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            style: bodyStyle(context),
            decoration: InputDecoration(
              hintText: 'Edit your transcription...',
              hintStyle: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kcSecondaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kcPrimaryColor),
              ),
            ),
            controller: TextEditingController(text: state.transcription),
            onChanged: (text) {
              context.read<JournalCaptureCubit>().updateTranscription(text);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'You can edit the transcription above before saving.',
            style: captionStyle(context),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildVisualizer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (index) {
        final height = 20 + (index % 5) * 10.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}