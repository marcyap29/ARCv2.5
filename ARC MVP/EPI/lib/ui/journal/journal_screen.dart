import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/journal_entry_state.dart';
import '../../state/feature_flags.dart';
import '../widgets/cached_thumbnail.dart';
import '../../services/thumbnail_cache_service.dart';
import '../widgets/keywords_discovered_widget.dart';
import '../widgets/ai_styled_text_field.dart';
import '../widgets/discovery_popup.dart';
import '../../telemetry/analytics.dart';
import '../../services/periodic_discovery_service.dart';
import '../../services/lumara/lumara_inline_api.dart';
import '../../lumara/services/enhanced_lumara_api.dart';
import '../../services/ocr/ocr_service.dart';
import '../../services/journal_session_cache.dart';
import '../../arc/core/keyword_extraction_cubit.dart';
import '../../arc/core/journal_capture_cubit.dart';
import '../../arc/core/journal_repository.dart';
import '../../arc/core/widgets/keyword_analysis_view.dart';
import '../../core/services/draft_cache_service.dart';
import '../../data/models/media_item.dart';
import '../../mcp/orchestrator/ios_vision_orchestrator.dart';
import 'widgets/lumara_suggestion_sheet.dart';
import 'widgets/enhanced_lumara_suggestion_sheet.dart' as enhanced;
import 'widgets/inline_reflection_block.dart';

/// Main journal screen with integrated LUMARA companion and OCR scanning
class JournalScreen extends StatefulWidget {
  final String? selectedEmotion;
  final String? selectedReason;
  final String? initialContent;
  
  const JournalScreen({
    super.key,
    this.selectedEmotion,
    this.selectedReason,
    this.initialContent,
  });

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  JournalEntryState _entryState = JournalEntryState();
  final Analytics _analytics = Analytics();
  late final LumaraInlineApi _lumaraApi;
  late final EnhancedLumaraApi _enhancedLumaraApi;
  late final OcrService _ocrService;
  final DraftCacheService _draftCache = DraftCacheService.instance;
  String? _currentDraftId;
  Timer? _autoSaveTimer;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Enhanced OCP/PRISM orchestrator
  late final IOSVisionOrchestrator _ocpOrchestrator;
  
  // Thumbnail cache service
  final ThumbnailCacheService _thumbnailCache = ThumbnailCacheService();
  
  // Manual keyword entry
  final TextEditingController _keywordController = TextEditingController();
  List<String> _manualKeywords = [];
  
  // UI state management
  bool _showKeywordsDiscovered = false;
  bool _showLumaraBox = false;
  
  // Periodic discovery service
  final PeriodicDiscoveryService _discoveryService = PeriodicDiscoveryService();
  bool _showDiscoveryPopup = false;

  @override
  void initState() {
    super.initState();
    _lumaraApi = LumaraInlineApi(_analytics);
    _enhancedLumaraApi = EnhancedLumaraApi(_analytics);
    _enhancedLumaraApi.initialize();
    _ocrService = StubOcrService(_analytics); // TODO: Use platform-specific implementation
    
    // Initialize enhanced OCP services
    _ocpOrchestrator = IOSVisionOrchestrator();
    _ocpOrchestrator.initialize();
    
    // Initialize thumbnail cache
    _thumbnailCache.initialize();
    
    _analytics.logJournalEvent('opened');

    // Initialize with draft content if provided
    if (widget.initialContent != null) {
      _textController.text = widget.initialContent!;
      _entryState.text = widget.initialContent!;
    }

    // Initialize draft cache and create new draft
    _initializeDraftCache();
    
    // Check for periodic discovery
    _checkForDiscovery();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _keywordController.dispose();
    
    // Clean up thumbnails when journal screen is closed
    _thumbnailCache.clearAllThumbnails();
    
    super.dispose();
  }

  void _onTextChanged(String text) {
    setState(() {
      _entryState.text = text;
    });
    
    // Update draft cache
    _updateDraftContent(text);
  }

  void _onLumaraFabTapped() {
    _analytics.logLumaraEvent('fab_tapped');
    
    if (_showLumaraBox) {
      // Hide the Lumara box
      _dismissLumaraBox();
    } else {
      // Show enhanced LUMARA suggestion sheet with cloud API analysis
      showModalBottomSheet(
        context: context,
        isScrollControlled: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => enhanced.EnhancedLumaraSuggestionSheet(
          // onSelect: (intent) => _onLumaraIntentSelected(intent), // COMMENTED OUT - type mismatch
          onSelect: (intent) {}, // Temporary empty function
          entryText: _entryState.text,
          phase: _entryState.phase,
        ),
      ).then((result) {
        // Handle AI suggestion if returned
        if (result is String) {
          _insertAISuggestion(result);
        } else {
          // Dismiss the Lumara box when the modal is closed
          _dismissLumaraBox();
        }
      });
      
      // Show the Lumara box
      setState(() {
        _showLumaraBox = true;
      });
    }
  }

  Future<void> _onLumaraIntentSelected(LumaraIntent intent) async {
    _analytics.logLumaraEvent('suggestion_selected', data: {
      'intent': intent.name,
    });

    try {
      // Use enhanced LUMARA API with full LLM support
      final reflection = await _enhancedLumaraApi.generatePromptedReflection(
        entryText: _entryState.text,
        intent: intent.name,
        phase: _entryState.phase,
      );

      final block = InlineBlock(
        type: 'inline_reflection',
        intent: intent.name,
        content: reflection,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.addReflection(block);
      });

      _analytics.logLumaraEvent('inline_reflection_inserted', data: {
        'intent': intent.name,
        'phase': _entryState.phase,
      });

      // Scroll to show the new reflection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          try {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } catch (e) {
            // Handle scroll animation errors gracefully
          }
        }
      });
    } catch (e) {
      _analytics.log('lumara_error', {'error': e.toString()});
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate reflection: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _onScanPage() async {
    if (!FeatureFlags.scanPage) return;

    _analytics.logScanEvent('started');
    
    // TODO: Implement camera scanning flow
    // For MVP, simulate scanning
    await _simulateScanning();
  }

  Future<void> _simulateScanning() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Scanning page...'),
          ],
        ),
      ),
    );

    try {
      // Simulate OCR processing
      final mockImageFile = await _createMockImageFile();
      final extractedText = await _ocrService.extractText(mockImageFile);
      
      // Create scan attachment
      final attachment = ScanAttachment(
        type: 'ocr_text',
        text: extractedText,
        sourceImageId: 'scan_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _entryState.addAttachment(attachment);
      });

      _analytics.logScanEvent('completed', data: {
        'text_length': extractedText.length,
      });

      // Show preview dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showScanPreview(extractedText);
      }
    } catch (e) {
      _analytics.log('scan_error', {'error': e.toString()});
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<File> _createMockImageFile() async {
    // Create a mock file for testing
    // In real implementation, this would be the captured image
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/mock_scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes([]); // Empty file for mock
    return file;
  }

  void _showScanPreview(String extractedText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanned Text'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(extractedText),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _insertTextIntoEntry(extractedText);
                  },
                  child: const Text('Insert into entry'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _insertTextIntoEntry(String text) {
    final currentText = _textController.text;
    final cursorPosition = _textController.selection.baseOffset;
    
    final newText = '${currentText.substring(0, cursorPosition)}\n\n$text${currentText.substring(cursorPosition)}';
    
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: cursorPosition + text.length + 2,
    );
    
    _onTextChanged(newText);
  }

  void _onContinue() {
    _analytics.logJournalEvent('continue_pressed', data: {
      'text_length': _entryState.text.length,
      'reflection_count': _entryState.blocks.length,
    });
    
    // Navigate to keyword analysis
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
            content: _entryState.text,
            mood: widget.selectedEmotion ?? 'Other',
            initialEmotion: widget.selectedEmotion,
            initialReason: widget.selectedReason,
            manualKeywords: _manualKeywords,
          ),
        ),
      ),
    ).then((result) {
      // Handle save result - if saved successfully, go back to home
      if (result != null && result['save'] == true) {
        // Complete the draft since entry was saved
        _completeDraft();
        // Clear the session cache since entry was saved
        JournalSessionCache.clearSession();
        // Clear the text field and reset state
        _textController.clear();
        setState(() {
          _entryState.clear();
        });
        // Navigate back to the previous screen
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Write what is true right now'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.home),
            tooltip: 'Home',
          ),
        ],
      ),
      body: SafeArea(
        bottom: true, // Ensure safe area at bottom for navigation
        child: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Text input area
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Dismiss both boxes when clicking on the journal page
                    if (_showKeywordsDiscovered || _showLumaraBox) {
                      setState(() {
                        _showKeywordsDiscovered = false;
                        _showLumaraBox = false;
                      });
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Bottom padding for FAB and nav
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Main text field with AI suggestion support
                      _buildAITextField(theme),
                      const SizedBox(height: 16),
                      
                      // Inline reflection blocks
                      ..._entryState.blocks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final block = entry.value;
                        return InlineReflectionBlock(
                          content: block.content,
                          intent: block.intent,
                          phase: block.phase,
                          onRegenerate: () => _onRegenerateReflection(index),
                          onSoften: () => _onSoftenReflection(index),
                          onMoreDepth: () => _onMoreDepthReflection(index),
                          onContinueWithLumara: _onContinueWithLumara,
                        );
                      }),
                      
                      // Keywords Discovered section (conditional visibility)
                      if (_showKeywordsDiscovered)
                        KeywordsDiscoveredWidget(
                          text: _entryState.text,
                          manualKeywords: _manualKeywords,
                          onKeywordsChanged: (keywords) {
                            setState(() {
                              _manualKeywords = keywords;
                            });
                          },
                          onAddKeywords: _showKeywordDialog,
                        ),
                      
                      // Attachments (scan and photo)
                      ..._entryState.attachments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final attachment = entry.value;
                        if (attachment is PhotoAttachment) {
                          return _buildPhotoAttachment(attachment, index);
                        } else if (attachment is ScanAttachment) {
                          return _buildScanAttachment(attachment);
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ),
              ),
              
              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary action row - flexible layout
                    Row(
                      children: [
                        // Left side: Media buttons (compact)
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Add photo button
                              IconButton(
                                onPressed: _handlePhotoGallery,
                                icon: const Icon(Icons.add_photo_alternate),
                                tooltip: 'Add Photo',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                              
                              // Add camera button
                              IconButton(
                                onPressed: _handleCamera,
                                icon: const Icon(Icons.camera_alt),
                                tooltip: 'Take Photo',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                              
                              // Add voice button
                              IconButton(
                                onPressed: _handleMicrophone,
                                icon: const Icon(Icons.mic),
                                tooltip: 'Add Voice Note',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                              
                              // Keyword toggle button
                              IconButton(
                                onPressed: _toggleKeywordsDiscovered,
                                icon: Icon(_showKeywordsDiscovered ? Icons.label_off : Icons.label),
                                tooltip: _showKeywordsDiscovered ? 'Hide Keywords' : 'Show Keywords',
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                style: IconButton.styleFrom(
                                  backgroundColor: _showKeywordsDiscovered 
                                    ? theme.colorScheme.primary.withOpacity(0.2)
                                    : null,
                                ),
                              ),
                              
                              // Scan page button removed - was bumping into lumara icon
                            ],
                          ),
                        ),
                        
                        // Center: LUMARA button (only show if text exists)
                        if (_entryState.text.isNotEmpty)
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16), // Add spacing from keyword icon
                                child: IconButton(
                                  onPressed: _onLumaraFabTapped,
                                  icon: const Icon(Icons.psychology),
                                  tooltip: 'Reflect with LUMARA',
                                  style: IconButton.styleFrom(
                                    foregroundColor: theme.colorScheme.primary,
                                    backgroundColor: _showLumaraBox 
                                      ? theme.colorScheme.primary.withOpacity(0.2)
                                      : theme.colorScheme.primary.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: theme.colorScheme.primary.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        
                        // Right side: Continue button (flexible)
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: _entryState.text.isNotEmpty ? _onContinue : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Continue'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
        ],
        ),
      ),
    );
  }

  Widget _buildScanAttachment(ScanAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.document_scanner,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Scanned Text',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            attachment.text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => _insertTextIntoEntry(attachment.text),
                child: const Text('Insert into entry'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _entryState.attachments.remove(attachment);
                  });
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoAttachment(PhotoAttachment attachment, int index) {
    final analysis = attachment.analysisResult;
    final summary = analysis['summary'] as String? ?? 'Photo analyzed';
    final ocrText = analysis['ocr']?['fullText'] as String? ?? '';
    final objects = analysis['objects'] as List? ?? [];
    final faces = analysis['faces'] as List? ?? [];
    final labels = analysis['labels'] as List? ?? [];
    final features = analysis['features'] as Map? ?? {};
    final keypoints = features['kp'] as int? ?? 0;
    
    // Extract keywords from analysis
    final keywords = <String>[];
    if (ocrText.isNotEmpty) {
      keywords.addAll(ocrText.split(' ').where((word) => word.length > 3).take(5));
    }
    if (objects.isNotEmpty) {
      keywords.addAll(objects.take(3).map((obj) => obj['label']?.toString() ?? ''));
    }
    if (labels.isNotEmpty) {
      keywords.addAll(labels.take(3).map((label) => label['label']?.toString() ?? ''));
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_camera,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Photo Analysis',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Photo thumbnail
          Row(
            children: [
              // Cached Thumbnail - Clickable
              CachedThumbnail(
                imagePath: attachment.imagePath,
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openPhotoInGallery(attachment.imagePath),
                showTapIndicator: true,
                placeholder: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Analysis details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show summary
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Keypoints with clickable details
                    InkWell(
                      onTap: () => _showKeypointsDetails(analysis),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Features: $keypoints keypoints',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.info_outline,
                              size: 10,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Show keywords if available
          if (keywords.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: keywords.take(8).map((keyword) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  keyword,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 10,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          
          // Show MCP format indicator
          Row(
            children: [
              Icon(
                Icons.data_object,
                size: 12,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                'MCP Format: ${analysis['mcp_format'] ?? 'Standard'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _openPhotoInGallery(attachment.imagePath),
            child: Text(
              'Tap to view photo in gallery',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontStyle: FontStyle.italic,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPhotoInGallery(String imagePath) async {
    try {
      print('DEBUG: Attempting to open photo: $imagePath');
      
      if (Platform.isIOS) {
        // For iOS, try to open in Photos app using file URL
        final file = File(imagePath);
        if (await file.exists()) {
          print('DEBUG: Photo file exists, attempting to launch');
          
          // Try different approaches to open the photo
          final uri = Uri.file(imagePath);
          
          // First try: Direct file URL
          if (await canLaunchUrl(uri)) {
            print('DEBUG: Can launch file URL, launching...');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
          
          // Second try: Use photos:// scheme if available
          final photosUri = Uri.parse('photos-redirect://$imagePath');
          if (await canLaunchUrl(photosUri)) {
            print('DEBUG: Can launch photos scheme, launching...');
            await launchUrl(photosUri, mode: LaunchMode.externalApplication);
            return;
          }
          
          // Third try: Copy to Photos and open
          await _copyToPhotosAndOpen(imagePath);
        } else {
          throw Exception('Photo file not found at: $imagePath');
        }
      } else {
        // For Android, open with default gallery app
        final uri = Uri.file(imagePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Cannot open photo');
        }
      }
    } catch (e) {
      print('DEBUG: Error opening photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open photo: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _copyToPhotosAndOpen(String imagePath) async {
    try {
      // This is a simplified approach - in a real app you'd use platform channels
      // to properly save to Photos and get the asset URL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo available: ${imagePath.split('/').last}\nTap to view in Photos app'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Open Photos',
            onPressed: () async {
              // Try to open Photos app directly
              final photosUri = Uri.parse('photos://');
              if (await canLaunchUrl(photosUri)) {
                await launchUrl(photosUri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    } catch (e) {
      throw Exception('Failed to save to Photos: $e');
    }
  }

  void _showKeywordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Keywords'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                hintText: 'Enter keywords separated by commas',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _addKeywords(),
            ),
            const SizedBox(height: 16),
            if (_manualKeywords.isNotEmpty) ...[
              const Text('Current keywords:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _manualKeywords.map((keyword) => Chip(
                  label: Text(keyword),
                  onDeleted: () => _removeKeyword(keyword),
                )).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _addKeywords,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addKeywords() {
    final text = _keywordController.text.trim();
    if (text.isNotEmpty) {
      final keywords = text.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
      setState(() {
        _manualKeywords.addAll(keywords);
        _manualKeywords = _manualKeywords.toSet().toList(); // Remove duplicates
      });
      _keywordController.clear();
    }
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _manualKeywords.remove(keyword);
    });
  }

  void _toggleKeywordsDiscovered() {
    setState(() {
      _showKeywordsDiscovered = !_showKeywordsDiscovered;
    });
  }

  void _toggleLumaraBox() {
    setState(() {
      _showLumaraBox = !_showLumaraBox;
    });
  }

  void _dismissLumaraBox() {
    setState(() {
      _showLumaraBox = false;
    });
  }

  Widget _buildAITextField(ThemeData theme) {
    return AIStyledTextField(
      controller: _textController,
      onChanged: _onTextChanged,
      maxLines: null,
      style: theme.textTheme.bodyLarge,
      hintText: 'What\'s on your mind right now?',
      textInputAction: TextInputAction.newline,
    );
  }

  void _insertAISuggestion(String suggestion) {
    // Insert AI suggestion text with special formatting (like Rosebud)
    final currentText = _textController.text;
    final cursorPosition = _textController.selection.baseOffset;

    // Create formatted suggestion text with special markers for styling
    final formattedSuggestion = '\n\n[AI_SUGGESTION_START]$suggestion[AI_SUGGESTION_END]\n';

    // Insert at cursor position
    final newText = currentText.substring(0, cursorPosition) +
                   formattedSuggestion +
                   currentText.substring(cursorPosition);

    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: cursorPosition + formattedSuggestion.length,
    );

    // Update entry state
    _onTextChanged(newText);

    // Dismiss the Lumara box
    _dismissLumaraBox();
    
    // Increment activation count for periodic discovery
    _discoveryService.incrementActivationCount();
  }

  /// Check for periodic discovery popup
  Future<void> _checkForDiscovery() async {
    try {
      final shouldShow = await _discoveryService.shouldShowDiscovery();
      if (shouldShow && mounted) {
        // Get recent entries for analysis
        final recentEntries = await _getRecentEntries();
        
        // Generate discovery suggestion
        final suggestion = await _discoveryService.generateDiscoverySuggestion(
          recentEntries: recentEntries,
          currentPhase: _entryState.phase ?? 'Discovery', // Fix null safety
        );
        
        if (mounted) {
          setState(() {
            _showDiscoveryPopup = true;
          });
          
          // Show discovery popup
          _showDiscoveryDialog(suggestion);
        }
      }
    } catch (e) {
      _analytics.log('discovery_check_error', {'error': e.toString()});
    }
  }

  /// Get recent journal entries for discovery analysis
  Future<List<String>> _getRecentEntries() async {
    try {
      // Get recent entries from journal repository
      // final entries = await _journalRepository.getRecentEntries(limit: 5); // COMMENTED OUT - missing repository
      // return entries.map((entry) => entry.text).toList();
      return []; // Temporary empty list
    } catch (e) {
      _analytics.log('recent_entries_error', {'error': e.toString()});
      return [];
    }
  }

  /// Show discovery popup dialog
  void _showDiscoveryDialog(DiscoverySuggestion suggestion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DiscoveryPopup(
        suggestion: suggestion,
        onDismiss: () {
          setState(() {
            _showDiscoveryPopup = false;
          });
          Navigator.of(context).pop();
        },
        onAcceptSuggestion: (suggestion) {
          _insertAISuggestion(suggestion);
        },
      ),
    );
  }


  Future<void> _onRegenerateReflection(int index) async {
    final block = _entryState.blocks[index];
    try {
      final newReflection = await _lumaraApi.generatePromptedReflection(
        entryText: _entryState.text,
        intent: block.intent,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: newReflection,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
        );
      });
    } catch (e) {
      _analytics.log('lumara_regenerate_error', {'error': e.toString()});
    }
  }

  Future<void> _onSoftenReflection(int index) async {
    final block = _entryState.blocks[index];
    try {
      final softerReflection = await _lumaraApi.generateSofterReflection(
        entryText: _entryState.text,
        intent: block.intent,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: softerReflection,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
        );
      });
    } catch (e) {
      _analytics.log('lumara_soften_error', {'error': e.toString()});
    }
  }

  Future<void> _onMoreDepthReflection(int index) async {
    final block = _entryState.blocks[index];
    try {
      final deeperReflection = await _lumaraApi.generateDeeperReflection(
        entryText: _entryState.text,
        intent: block.intent,
        phase: _entryState.phase,
      );

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: deeperReflection,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
        );
      });
    } catch (e) {
      _analytics.log('lumara_depth_error', {'error': e.toString()});
    }
  }

  void _onContinueWithLumara() {
    _analytics.logLumaraEvent('continue_with_lumara_opened_chat');
    
    // Show LUMARA suggestion sheet for in-context integration
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LumaraSuggestionSheet(
        onSelect: (intent) async {
          // Convert LumaraIntent to string for the API
          final suggestion = intent.name;
          await _handleLumaraSuggestion(suggestion);
        },
      ),
    );
  }

  /// Handle LUMARA suggestion selection
  Future<void> _handleLumaraSuggestion(String suggestion) async {
    try {
      _analytics.logLumaraEvent('suggestion_selected', data: {'intent': suggestion});
      
      // Generate reflection using LUMARA inline API
      final reflection = await _lumaraApi.generatePromptedReflection(
        entryText: _entryState.text,
        intent: suggestion,
        phase: _entryState.phase,
      );
      
      // Insert the reflection into the text
      final currentText = _textController.text;
      final cursorPosition = _textController.selection.baseOffset;
      
      // Insert reflection at cursor position or end of text
      final insertPosition = cursorPosition >= 0 ? cursorPosition : currentText.length;
      final newText = '${currentText.substring(0, insertPosition)}\n\n$reflection\n\n${currentText.substring(insertPosition)}';
      
      // Update text controller and state
      _textController.text = newText;
      _textController.selection = TextSelection.collapsed(
        offset: insertPosition + reflection.length + 4, // Position after inserted text
      );
      
      // Update entry state
      setState(() {
        _entryState.text = newText;
      });
      
      // Auto-save the updated content
      _updateDraftContent(newText);
      
      _analytics.logLumaraEvent('inline_reflection_inserted', data: {'intent': suggestion});
      
    } catch (e) {
      _analytics.log('lumara_suggestion_error', {'error': e.toString()});
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating reflection: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Initialize draft cache and create new draft
  Future<void> _initializeDraftCache() async {
    try {
      await _draftCache.initialize();
      
      // Create new draft with emotion and reason if available
      _currentDraftId = await _draftCache.createDraft(
        initialEmotion: widget.selectedEmotion,
        initialReason: widget.selectedReason,
        initialContent: _entryState.text,
      );
      
      debugPrint('JournalScreen: Created draft $_currentDraftId');
    } catch (e) {
      debugPrint('JournalScreen: Failed to initialize draft cache: $e');
    }
  }

  /// Update draft content with auto-save
  void _updateDraftContent(String content) {
    if (_currentDraftId == null) return;
    
    // Cancel existing timer
    _autoSaveTimer?.cancel();
    
    // Start new timer for auto-save
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _draftCache.updateDraftContent(content);
      debugPrint('JournalScreen: Auto-saved draft content');
    });
  }

  /// Complete the current draft when entry is saved
  Future<void> _completeDraft() async {
    try {
      await _draftCache.completeDraft();
      _currentDraftId = null;
      debugPrint('JournalScreen: Completed draft');
    } catch (e) {
      debugPrint('JournalScreen: Failed to complete draft: $e');
    }
  }

  // Multimodal functionality
  Future<void> _handlePhotoGallery() async {
    try {
      _analytics.logJournalEvent('photo_button_pressed');
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        for (final image in images) {
          await _processPhotoWithEnhancedOCP(image.path);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select photos: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleCamera() async {
    try {
      _analytics.logJournalEvent('camera_button_pressed');
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _processPhotoWithEnhancedOCP(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleMicrophone() async {
    try {
      _analytics.logJournalEvent('voice_button_pressed');
      
      // Check current permission status
      var status = await Permission.microphone.status;
      print('DEBUG: Microphone permission status: $status');
      
      if (status.isDenied) {
        // Request permission
        print('DEBUG: Requesting microphone permission...');
        status = await Permission.microphone.request();
        print('DEBUG: Permission request result: $status');
        
        // If still denied after request, show explanation
        if (status.isDenied) {
          _showPermissionExplanationDialog();
          return;
        }
      }
      
      if (status.isPermanentlyDenied) {
        // Show dialog to go to settings
        print('DEBUG: Permission permanently denied, showing settings dialog');
        _showPermissionDialog();
        return;
      }
      
      if (status.isGranted) {
        // Permission granted - show recording interface
        print('DEBUG: Permission granted, showing recording dialog');
        _showVoiceRecordingDialog();
      } else {
        // Permission denied
        print('DEBUG: Permission denied, showing error message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphone permission is required for voice recording. Current status: $status'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Microphone error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to access microphone: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showPermissionExplanationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission'),
        content: const Text(
          'ARC needs microphone access to record voice notes.\n\n'
          'If you don\'t see ARC in your microphone settings, please:\n\n'
          '1. Close and reopen the app\n'
          '2. Try the microphone button again\n'
          '3. Check Settings > Privacy & Security > Microphone\n\n'
          'The app needs to be restarted for permissions to register properly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'To record voice notes, please grant microphone permission in Settings.\n\n'
          '1. Go to Settings > Privacy & Security > Microphone\n'
          '2. Find "ARC" in the list\n'
          '3. Toggle the switch to enable microphone access',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showVoiceRecordingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Recording'),
        content: const Text(
          'Voice recording feature is coming soon! For now, you can type your thoughts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showKeypointsDetails(Map<String, dynamic> analysis) {
    final features = analysis['features'] as Map? ?? {};
    final keypoints = features['kp'] as int? ?? 0;
    final method = features['method'] as String? ?? 'ORB';
    final hashes = features['hashes'] as Map? ?? {};
    final phash = hashes['phash'] as String? ?? 'N/A';
    final orbPatch = hashes['orbPatch'] as String? ?? 'N/A';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feature Analysis Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Keypoints Detected', keypoints.toString()),
              _buildDetailRow('Detection Method', method),
              _buildDetailRow('Perceptual Hash', phash.length > 20 ? '${phash.substring(0, 20)}...' : phash),
              _buildDetailRow('ORB Patch Hash', orbPatch.length > 20 ? '${orbPatch.substring(0, 20)}...' : orbPatch),
              const SizedBox(height: 16),
              const Text(
                'Keypoints represent distinctive visual features in the image that can be used for:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text('• Object recognition and matching'),
              const Text('• Image similarity comparison'),
              const Text('• Visual search and retrieval'),
              const Text('• Duplicate detection'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  void _onMediaCaptured(MediaItem mediaItem) {
    // Try OCR if it's an image
    if (mediaItem.type == MediaType.image) {
      _performOCR(File(mediaItem.uri));
    }
  }

  /// Process photo with real OCP/PRISM orchestrator
  Future<void> _processPhotoWithEnhancedOCP(String imagePath) async {
    try {
      // Show processing indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔍 Analyzing photo with iOS Vision AI...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Run real OCP analysis
      final result = await _ocpOrchestrator.processPhoto(
        imagePath: imagePath,
        ocrEngine: 'ios_vision', // Use iOS Vision framework
        language: 'auto',
        maxProcessingMs: 1500,
      );

      if (result['success'] == true) {
        // Create photo attachment with analysis results
        final photoAttachment = PhotoAttachment(
          type: 'photo_analysis',
          imagePath: imagePath,
          analysisResult: result,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        
        setState(() {
          _entryState.attachments.add(photoAttachment);
        });

        // Insert analysis summary with clickable link
        final summary = result['summary'] as String? ?? 'Photo analyzed';
        final ocrText = result['ocr']?['fullText'] as String? ?? '';
        final objects = result['objects'] as List<Map<String, dynamic>>? ?? [];
        final faces = result['faces'] as List<Map<String, dynamic>>? ?? [];
        final labels = result['labels'] as List<Map<String, dynamic>>? ?? [];
        
        // Create rich analysis text
        final analysisText = _createPhotoAnalysisText(
          summary: summary,
          ocrText: ocrText,
          objects: objects,
          faces: faces,
          labels: labels,
          attachmentIndex: _entryState.attachments.length - 1,
        );
        
        _insertTextIntoEntry(analysisText);

        // Show success message with summary
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $summary'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Unknown error');
      }

    } catch (e) {
      debugPrint('Real OCP processing failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to analyze photo: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }


  /// Create rich photo analysis text with clickable links
  String _createPhotoAnalysisText({
    required String summary,
    required String ocrText,
    required List<Map<String, dynamic>> objects,
    required List<Map<String, dynamic>> faces,
    required List<Map<String, dynamic>> labels,
    required int attachmentIndex,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📸 **Photo Analysis**');
    buffer.writeln('*Click to view photo*');
    buffer.writeln();
    
    if (ocrText.isNotEmpty) {
      buffer.writeln('**📝 Text Found:**');
      buffer.writeln(ocrText);
      buffer.writeln();
    }
    
    if (objects.isNotEmpty) {
      buffer.writeln('**🎯 Objects Detected:**');
      for (final obj in objects.take(5)) {
        final label = obj['label'] as String? ?? 'Unknown';
        final confidence = obj['confidence'] as double? ?? 0.0;
        buffer.writeln('• $label (${(confidence * 100).toStringAsFixed(0)}%)');
      }
      buffer.writeln();
    }
    
    if (faces.isNotEmpty) {
      buffer.writeln('**👤 Faces:** ${faces.length} detected');
      buffer.writeln();
    }
    
    if (labels.isNotEmpty) {
      buffer.writeln('**🏷️ Scene:**');
      for (final label in labels.take(3)) {
        final labelText = label['label'] as String? ?? 'Unknown';
        final confidence = label['confidence'] as double? ?? 0.0;
        buffer.writeln('• $labelText (${(confidence * 100).toStringAsFixed(0)}%)');
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  Future<void> _performOCR(File imageFile) async {
    try {
      final extractedText = await _ocrService.extractText(imageFile);
      if (extractedText != null && extractedText.isNotEmpty) {
        // Create ScanAttachment for the attachments list
        final scanAttachment = ScanAttachment(
          type: 'ocr_text',
          text: extractedText,
          sourceImageId: DateTime.now().millisecondsSinceEpoch.toString(),
        );
        
        setState(() {
          _entryState.attachments.add(scanAttachment);
        });
        
        // Insert keywords in a more user-friendly format
        _insertTextIntoEntry('📸 Photo keywords: $extractedText');
        
        // Show a brief confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Keywords extracted: $extractedText'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Show that no text was found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text found in photo'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('OCR failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to analyze photo: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
