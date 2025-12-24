import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../state/journal_entry_state.dart';
import '../../state/feature_flags.dart';
import '../../services/thumbnail_cache_service.dart';
import '../../services/media_alt_text_generator.dart';
import '../widgets/keywords_discovered_widget.dart';
import '../widgets/discovery_popup.dart';
import '../../telemetry/analytics.dart';
import '../../services/periodic_discovery_service.dart';
import 'package:my_app/services/lumara/lumara_inline_api.dart';
import 'package:my_app/arc/chat/services/enhanced_lumara_api.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/arc/chat/models/lumara_reflection_options.dart' as lumara_models;
import 'package:my_app/arc/internal/mira/memory_loader.dart';
import 'package:my_app/arc/chat/ui/lumara_settings_screen.dart';
import '../../models/user_profile_model.dart';
import 'package:hive/hive.dart';
import 'package:my_app/arc/chat/config/api_config.dart';
import '../../services/llm_bridge_adapter.dart';
// REMOVED: gemini_send - no longer used in Firebase-only mode
// import '../../services/gemini_send.dart';
// import '../../services/ocr/ocr_service.dart'; // TODO: OCR service not yet implemented
import '../../services/journal_session_cache.dart';
import '../../arc/core/keyword_extraction_cubit.dart';
import '../../arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import '../../arc/core/widgets/keyword_analysis_view.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/aurora/services/circadian_profile_service.dart';
import 'package:my_app/data/models/media_item.dart';
import 'media_conversion_utils.dart';
import 'package:my_app/mira/store/mcp/orchestrator/ios_vision_orchestrator.dart';
import 'widgets/lumara_suggestion_sheet.dart';
import 'widgets/inline_reflection_block.dart';
// import '../../features/timeline/widgets/entry_content_renderer.dart'; // TODO: EntryContentRenderer not yet implemented
import 'widgets/full_screen_photo_viewer.dart' show FullScreenPhotoViewer, PhotoData;
import '../../ui/widgets/location_picker_dialog.dart';
import 'drafts_screen.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/memory/sentence_extraction_util.dart';
import 'package:my_app/mira/mira_service.dart';
import 'package:my_app/arc/chat/data/context_provider.dart';
import 'package:my_app/arc/chat/data/context_scope.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';
import 'package:my_app/arc/ui/widgets/attachment_menu_button.dart';
import 'package:my_app/arc/ui/widgets/private_notes_panel.dart';
import 'package:my_app/arc/core/private_notes_storage.dart';

/// Main journal screen with integrated LUMARA companion and OCR scanning
class JournalScreen extends StatefulWidget {
  final String? selectedEmotion;
  final String? selectedReason;
  final String? initialContent;
  final JournalEntry? existingEntry; // For loading existing entries with media
  final bool isViewOnly; // New parameter to distinguish viewing vs editing
  final bool openAsEdit; // Flag to indicate entry is opened directly for editing (no initial draft)
  final bool isTimelineEditing; // Flag to allow timestamp editing when editing from timeline

  const JournalScreen({
    super.key,
    this.selectedEmotion,
    this.selectedReason,
    this.initialContent,
    this.existingEntry,
    this.isViewOnly = false, // Default to editing mode for backward compatibility
    this.openAsEdit = false, // Default to false - will create draft normally
    this.isTimelineEditing = false, // Default to locked timestamps - only allow changes from timeline
  });

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  JournalEntryState _entryState = JournalEntryState();
  final Analytics _analytics = Analytics();
  late final LumaraInlineApi _lumaraApi;
  late final EnhancedLumaraApi _enhancedLumaraApi;
  // late final OcrService _ocrService; // TODO: OCR service not yet implemented
  final DraftCacheService _draftCache = DraftCacheService.instance;
  
  // Progressive memory loading for in-journal LUMARA
  late final ProgressiveMemoryLoader _memoryLoader;
  final JournalRepository _journalRepository = JournalRepository();
  late final ArcLLM _arcLLM;
  EnhancedMiraMemoryService? _memoryService;
  String? _currentDraftId;
  Timer? _autoSaveTimer;
  final ImagePicker _imagePicker = ImagePicker();
  
  /// Get the current entry ID for per-entry usage limit tracking
  /// Uses existing entry ID if editing, or draft ID for new entries
  String? get _currentEntryId => widget.existingEntry?.id ?? _currentDraftId;
  
  // Enhanced OCP/PRISM orchestrator
  late final IOSVisionOrchestrator _ocpOrchestrator;
  
  // Thumbnail cache service
  final ThumbnailCacheService _thumbnailCache = ThumbnailCacheService();
  
  // Photo selection state
  bool _isPhotoSelectionMode = false;
  final Set<int> _selectedPhotoIndices = <int>{};
  
  // Manual keyword entry
  final TextEditingController _keywordController = TextEditingController();
  List<String> _manualKeywords = [];
  
  // Text controllers for metadata editing
  late TextEditingController _locationController;
  final TextEditingController _titleController = TextEditingController();
  
  // Text controllers for continuation fields (one per block)
  final Map<int, TextEditingController> _continuationControllers = {};
  
  // Track loading states for LUMARA reflections (by block index)
  final Map<int, bool> _lumaraLoadingStates = {};
  final Map<int, String?> _lumaraLoadingMessages = {};
  
  // UI state management
  bool _showKeywordsDiscovered = false;
  bool _showLumaraBox = false;
  bool _isLumaraConfigured = false;
  bool _showPrivateNotes = false;
  
  // Scroll position tracking for scroll buttons
  bool _showScrollToTop = false;
  bool _showScrollToBottom = false;
  
  // Periodic discovery service
  final PeriodicDiscoveryService _discoveryService = PeriodicDiscoveryService();
  
  // Track if entry has been modified
  bool _hasBeenModified = false;
  String? _originalContent;
  
  // Track original entry text before any LUMARA blocks were added
  // This ensures we only use text that appears ABOVE each block position
  String? _originalEntryTextBeforeBlocks;
  
  // Track updated entry for phase override changes (local state)
  JournalEntry? _currentEntryOverride;
  
  // Track if we're currently in edit mode (can switch from view-only to edit)
  bool _isEditMode = false;
  
  // Metadata editing fields (only shown for existing entries)
  DateTime? _editableDate;
  TimeOfDay? _editableTime;
  String? _editableLocation;
  
  // Draft count for badge display
  int _draftCount = 0;

  @override
  void initState() {
    super.initState();
    // REMOVED: _lumaraApi initialization - using _enhancedLumaraApi exclusively
    // _lumaraApi = LumaraInlineApi(_analytics);
    _enhancedLumaraApi = EnhancedLumaraApi(_analytics);
    _memoryLoader = ProgressiveMemoryLoader(_journalRepository);
    
    // Add scroll listener for scroll-to-bottom button
    _scrollController.addListener(_onScrollChanged);
    // PRIORITY 2: Removed local API - journal uses enhancedLumaraApi which calls Firebase Functions
    // _arcLLM = provideArcLLM(); // DEPRECATED
    _initializeLumara();
    // _ocrService = StubOcrService(_analytics); // TODO: OCR service not yet implemented
    
    // Initialize enhanced OCP services
    _ocpOrchestrator = IOSVisionOrchestrator();
    _ocpOrchestrator.initialize();
    
    // Initialize thumbnail cache
    _thumbnailCache.initialize();
    
    // Initialize progressive memory loader
    _initProgressiveMemory();
    
    _analytics.logJournalEvent('opened');
    
    // Track journal mode entry and show prompt notice every 3-5 times
    _trackJournalModeEntry();
    
    // Add lifecycle observer for app state changes
    WidgetsBinding.instance.addObserver(this);

    // Initialize with draft content if provided
    if (widget.initialContent != null) {
      _textController.text = widget.initialContent!;
      _entryState.text = widget.initialContent!;
    }

    // Load existing entry with media if provided
    if (widget.existingEntry != null) {
      _textController.text = widget.existingEntry!.content;
      _entryState.text = widget.existingEntry!.content;
      
      // Store original values for change tracking
      _originalContent = widget.existingEntry!.content;
      
      // Initialize editable metadata fields
      _editableDate = widget.existingEntry!.createdAt;
      _editableTime = TimeOfDay.fromDateTime(widget.existingEntry!.createdAt);
      _editableLocation = widget.existingEntry!.location;
      
      // Initialize title controller with existing entry title
      if (widget.existingEntry!.title.isNotEmpty) {
        _titleController.text = widget.existingEntry!.title;
      }
      
      // Load existing keywords for display in editor
      if (widget.existingEntry!.keywords.isNotEmpty) {
        _manualKeywords = List.from(widget.existingEntry!.keywords);
        // Auto-show keywords section when editing existing entry with keywords
        _showKeywordsDiscovered = true;
      }
      
      // Debug: Check entry state before loading blocks
      debugPrint('JournalScreen: Loading entry ${widget.existingEntry!.id}');
      debugPrint('JournalScreen: Entry lumaraBlocks count: ${widget.existingEntry!.lumaraBlocks.length}');
      if (widget.existingEntry!.metadata != null && widget.existingEntry!.metadata!.containsKey('inlineBlocks')) {
        final metadataBlocks = widget.existingEntry!.metadata!['inlineBlocks'];
        debugPrint('JournalScreen: Entry has inlineBlocks in metadata, type: ${metadataBlocks.runtimeType}');
        if (metadataBlocks is List) {
          debugPrint('JournalScreen: Metadata has ${metadataBlocks.length} blocks');
        }
      }
      
      // Load LUMARA blocks from the entry's lumaraBlocks field
      // This is the single source of truth - blocks are stored here, not in metadata
      final lumaraBlocks = widget.existingEntry!.lumaraBlocks;
      
      if (lumaraBlocks.isNotEmpty) {
        debugPrint('✅ JournalScreen: Loading ${lumaraBlocks.length} LUMARA blocks from entry ${widget.existingEntry!.id}');
        
        for (int i = 0; i < lumaraBlocks.length; i++) {
          final block = lumaraBlocks[i];
          debugPrint('   Block $i: type=${block.type}, intent=${block.intent}, hasComment=${block.userComment != null && block.userComment!.isNotEmpty}');

          // Add block to entry state
          _entryState.addReflection(block);

          // Create controller for continuation field
          final controller = TextEditingController(text: block.userComment ?? '');
          _continuationControllers[i] = controller;
          
          // Listen for changes to user comments
          controller.addListener(() {
            if (i < _entryState.blocks.length && mounted) {
              setState(() {
                _entryState.blocks[i] = _entryState.blocks[i].copyWith(
                  userComment: controller.text.trim().isEmpty ? null : controller.text.trim(),
                );
                _hasBeenModified = true;
              });
              
              // Persist after a short delay (debounced)
              Future.delayed(const Duration(milliseconds: 500), () {
                if (widget.existingEntry != null && mounted) {
                  _persistLumaraBlocksToEntry();
                }
              });
            }
          });
        }
        
        debugPrint('✅ JournalScreen: Successfully loaded ${_entryState.blocks.length} LUMARA blocks');
      } else {
        debugPrint('JournalScreen: Entry has no LUMARA blocks');
      }
      
      // Initialize text controllers
      _locationController = TextEditingController(text: _editableLocation ?? '');
      
      // Convert MediaItems back to attachments
      if (widget.existingEntry!.media.isNotEmpty) {
        print('DEBUG: Loading ${widget.existingEntry!.media.length} media items from existing entry');
        // Debug: Log media types before conversion
        for (int i = 0; i < widget.existingEntry!.media.length; i++) {
          final media = widget.existingEntry!.media[i];
          print('DEBUG: Media $i - Type: ${media.type}, URI: ${media.uri}, ID: ${media.id}');
        }
        
        final attachments = MediaConversionUtils.mediaItemsToAttachments(widget.existingEntry!.media);
        print('DEBUG: Converted to ${attachments.length} attachments');
        
        // Debug: Log attachment types after conversion
        int photoCount = 0;
        int videoCount = 0;
        int scanCount = 0;
        for (final attachment in attachments) {
          if (attachment is PhotoAttachment) {
            photoCount++;
          } else if (attachment is VideoAttachment) {
            videoCount++;
            print('DEBUG: Video attachment - Path: ${attachment.videoPath}, ID: ${attachment.videoId}, Duration: ${attachment.duration}');
            // Verify video file exists (async check will be done in post-frame callback)
            final videoFile = File(attachment.videoPath);
            final existsSync = videoFile.existsSync();
            print('DEBUG: Video attachment file exists (sync check): $existsSync');
            if (!existsSync) {
              print('WARNING: Video attachment file does not exist: ${attachment.videoPath}');
            }
          } else if (attachment is ScanAttachment) {
            scanCount++;
          }
        }
        print('DEBUG: Attachment breakdown - Photos: $photoCount, Videos: $videoCount, Scans: $scanCount');
        
        _entryState.attachments.addAll(attachments);
        print('DEBUG: Total attachments in state: ${_entryState.attachments.length}');
        print('DEBUG: Entry ID: ${widget.existingEntry!.id}');
        print('DEBUG: Entry content length: ${widget.existingEntry!.content.length}');
        
        // Verify video files exist asynchronously and update UI
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          for (final attachment in attachments) {
            if (attachment is VideoAttachment) {
              final videoFile = File(attachment.videoPath);
              final exists = await videoFile.exists();
              if (!exists) {
                print('WARNING: Video file does not exist (async check): ${attachment.videoPath}');
              }
            }
          }
          // Force UI update to show videos
          if (mounted) {
            setState(() {});
          }
        });
      }
      
      // Check for existing draft linked to this entry (3d requirement) - after UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _checkForLinkedDraft(widget.existingEntry!.id);
      });
    } else {
      // Initialize text controllers for new entries
      _locationController = TextEditingController();
    }

    // Run deduplication before initializing draft
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _runDeduplication();
      await _initializeDraftCache();
    });
    
    // Load draft count for badge display
    _loadDraftCount();
    
    // Check for periodic discovery
    _checkForDiscovery();
  }

  /// Get the current entry for context (either existing entry or create from draft state)
  /// This allows LUMARA to use unsaved draft content as context
  JournalEntry? _getCurrentEntryForContext() {
    // Use local override state if available, otherwise use widget.existingEntry
    final baseEntry = _currentEntryOverride ?? widget.existingEntry;
    
    // If we have an existing entry, use it (may have been modified)
    if (baseEntry != null) {
      // Create entry from current draft state (includes unsaved changes)
      final now = DateTime.now();
      final entryDate = _editableDate ?? now;
      final entryTime = _editableTime ?? TimeOfDay.fromDateTime(now);
      final combinedDateTime = DateTime(
        entryDate.year,
        entryDate.month,
        entryDate.day,
        entryTime.hour,
        entryTime.minute,
      );
      
      // Convert attachments to media items
      final mediaItems = _entryState.attachments.isNotEmpty
          ? MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments)
          : <MediaItem>[];
      
      // Merge with existing entry media if any
      final allMedia = [
        ...baseEntry.media,
        ...mediaItems,
      ];
      
      return baseEntry.copyWith(
        content: _entryState.text.isNotEmpty ? _entryState.text : baseEntry.content,
        title: _titleController.text.trim().isNotEmpty 
            ? _titleController.text.trim() 
            : baseEntry.title,
        createdAt: combinedDateTime,
        updatedAt: DateTime.now(),
        media: allMedia,
        location: _editableLocation ?? baseEntry.location,
        // Preserve phase override from local state
        userPhaseOverride: baseEntry.userPhaseOverride,
        isPhaseLocked: baseEntry.isPhaseLocked,
      );
    }
    
    // If no existing entry, create a temporary entry from draft state
    if (_entryState.text.trim().isNotEmpty) {
      final now = DateTime.now();
      final entryDate = _editableDate ?? now;
      final entryTime = _editableTime ?? TimeOfDay.fromDateTime(now);
      final combinedDateTime = DateTime(
        entryDate.year,
        entryDate.month,
        entryDate.day,
        entryTime.hour,
        entryTime.minute,
      );
      
      // Convert attachments to media items
      final mediaItems = _entryState.attachments.isNotEmpty
          ? MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments)
          : <MediaItem>[];
      
      // Create temporary entry from draft state
      return JournalEntry(
        id: 'draft_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID for draft
        title: _titleController.text.trim().isNotEmpty 
            ? _titleController.text.trim() 
            : 'Draft Entry',
        content: _entryState.text,
        createdAt: combinedDateTime,
        updatedAt: DateTime.now(),
        tags: const [],
        mood: widget.selectedEmotion ?? 'Other',
        media: mediaItems,
        emotion: widget.selectedEmotion,
        emotionReason: widget.selectedReason,
        location: _editableLocation,
        keywords: _manualKeywords,
      );
    }
    
    return null;
  }
  
  /// Track scroll position to show/hide scroll buttons
  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    
    final position = _scrollController.position;
    final isNearTop = position.pixels <= 100;
    final isNearBottom = position.pixels >= position.maxScrollExtent - 100;
    
    // Show scroll-to-top when scrolled down (not near top)
    // Show scroll-to-bottom when scrolled up (not near bottom)
    final shouldShowTop = !isNearTop;
    final shouldShowBottom = !isNearBottom && position.maxScrollExtent > 200;
    
    if (_showScrollToTop != shouldShowTop || _showScrollToBottom != shouldShowBottom) {
      setState(() {
        _showScrollToTop = shouldShowTop;
        _showScrollToBottom = shouldShowBottom;
      });
    }
  }
  
  /// Scroll to top of journal entry
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _showScrollToTop = false;
      });
    }
  }
  
  /// Scroll to bottom of journal entry
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _showScrollToBottom = false;
      });
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    _autoSaveTimer?.cancel();
    
    // Persist LUMARA blocks one final time before disposing if editing existing entry
    if (widget.existingEntry != null && _entryState.blocks.isNotEmpty) {
      // Save immediately before disposing
      final lumaraBlocks = List<InlineBlock>.from(_entryState.blocks);
      final updatedEntry = widget.existingEntry!.copyWith(
        lumaraBlocks: lumaraBlocks,
        updatedAt: DateTime.now(),
      );
      _journalRepository.updateJournalEntry(updatedEntry).catchError((e) {
        debugPrint('JournalScreen: Error persisting LUMARA blocks on dispose: $e');
      });
    }
    
    // Save current draft before disposing (2 requirement)
    if (_currentDraftId != null && (!widget.isViewOnly || _isEditMode)) {
      final mediaItems = _entryState.attachments.isNotEmpty
          ? MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments)
          : const <MediaItem>[];
      
      final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
      _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
      _draftCache.saveCurrentDraftImmediately();
    }
    
    _textController.dispose();
    _scrollController.dispose();
    
    // Dispose all continuation controllers
    for (final controller in _continuationControllers.values) {
      controller.dispose();
    }
    _continuationControllers.clear();
    _keywordController.dispose();
    _locationController.dispose();
    _titleController.dispose();
    
    // Clean up thumbnails when journal screen is closed
    _thumbnailCache.clearAllThumbnails();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Save draft when app goes to background, becomes inactive, or is detached (2, 2a requirement)
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached) {
      // If editing existing entry and no draft exists yet, create one now
      if (widget.existingEntry != null && _currentDraftId == null && (!widget.isViewOnly || _isEditMode)) {
        _createDraftOnAppPause();
      } else if (_currentDraftId != null && (!widget.isViewOnly || _isEditMode)) {
        // Update existing draft with current content and media
        final mediaItems = _entryState.attachments.isNotEmpty
            ? MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments)
            : const <MediaItem>[];
        
        final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
        _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
        _draftCache.saveCurrentDraftImmediately();
        debugPrint('JournalScreen: App lifecycle changed to $state - saved draft $_currentDraftId with ${blocksJson.length} blocks');
      }
    } else {
      debugPrint('JournalScreen: App lifecycle changed to $state (no auto-save)');
    }
  }

  /// Create a draft when app pauses during direct entry editing
  Future<void> _createDraftOnAppPause() async {
    try {
      if (widget.existingEntry == null) return;
      
      await _draftCache.initialize();
      final mediaItems = _entryState.attachments.isNotEmpty
          ? MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments)
          : const <MediaItem>[];
      
      final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
      
      _currentDraftId = await _draftCache.createDraft(
        initialEmotion: widget.selectedEmotion,
        initialReason: widget.selectedReason,
        initialContent: _entryState.text,
        initialMedia: mediaItems,
        linkedEntryId: widget.existingEntry!.id,
      );
      
      await _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
      await _draftCache.saveCurrentDraftImmediately();
      debugPrint('JournalScreen: Created draft $_currentDraftId on app pause for entry ${widget.existingEntry!.id}');
    } catch (e) {
      debugPrint('JournalScreen: Failed to create draft on app pause: $e');
    }
  }

  void _onTextChanged(String text) {
    setState(() {
      _entryState.text = text;
    });
    
    // Mark as modified if content changed from original
    if (widget.existingEntry != null && _originalContent != null) {
      _hasBeenModified = text != _originalContent;
    } else {
      _hasBeenModified = text.trim().isNotEmpty;
    }
    
    // Only update draft cache if user is actively writing/editing (not just viewing)
    if (!widget.isViewOnly || _isEditMode) {
      _updateDraftContent(text);
    }
  }

  /// Initialize LUMARA with MCP bundle if available
  Future<void> _initializeLumara() async {
    try {
      // TODO: Get MCP bundle path from settings or last import
      // For now, initialize without bundle
      await _enhancedLumaraApi.initialize();
      
      // Check if LUMARA is properly configured
      _isLumaraConfigured = await _checkLumaraConfiguration();
      
      if (mounted) {
        setState(() {
          // Update UI state
        });
      }
      
      print('LUMARA: Initialized successfully (configured: $_isLumaraConfigured)');
    } catch (e) {
      print('LUMARA: Initialization error: $e');
      // Continue with degraded mode
    }
  }

  /// Initialize progressive memory loader for in-journal LUMARA
  Future<void> _initProgressiveMemory() async {
    try {
      await _memoryLoader.initialize();
      print('LUMARA Journal: Initialized progressive memory loader');
      
      // Initialize memory service for semantic search
      try {
        _memoryService = EnhancedMiraMemoryService(
          miraService: MiraService.instance,
        );
        await _memoryService!.initialize(
          userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
          sessionId: null,
          currentPhase: _entryState.phase ?? 'Discovery',
        );
        print('LUMARA Journal: Initialized memory service for semantic search');
      } catch (e) {
        print('LUMARA Journal: Memory service initialization error: $e');
        // Continue without memory service - will fall back to recent entries
      }
    } catch (e) {
      print('LUMARA Journal: Memory loader initialization error: $e');
    }
  }

  /// Check if LUMARA is properly configured with an API key
  Future<bool> _checkLumaraConfiguration() async {
    try {
      // If Firebase is initialized, consider LUMARA configured even without local API keys
      final firebaseReady = await FirebaseService.instance.ensureReady();
      if (firebaseReady) {
        print('LUMARA Journal: Firebase ready, treating configuration as satisfied');
        return true;
      }

      final apiConfig = LumaraAPIConfig.instance;
      await apiConfig.initialize();
      final availableProviders = apiConfig.getAvailableProviders();
      final bestProvider = apiConfig.getBestProvider();

      print('LUMARA Journal: Available providers: ${availableProviders.map((p) => p.name).join(', ')}');
      print('LUMARA Journal: Best provider: ${bestProvider?.name ?? 'none'}');

      // Even if no local keys, return true to avoid blocking when backend is present
      return bestProvider != null && availableProviders.isNotEmpty || firebaseReady;
    } catch (e) {
      print('LUMARA Journal: Configuration check error: $e');
      // Fail open to avoid blocking UX if config check fails
      return true;
    }
  }

  void _onLumaraFabTapped() async {
    _analytics.logLumaraEvent('fab_tapped');
    
    // Check if entry is empty - if so, show confirmation dialog for journaling prompt
    if (_entryState.text.trim().isEmpty) {
      final shouldGetPrompt = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Get a Journaling Prompt?'),
          content: const Text(
            'Would you like LUMARA to suggest a writing prompt based on your entries, chats, drafts, media, and current phase?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, thanks'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, please'),
            ),
          ],
        ),
      );
      
      if (shouldGetPrompt == true) {
        await _generateJournalingPrompt();
        return;
      } else {
        return; // User declined
      }
    }
    
    // If entry has text, directly generate a reflection using LUMARA
    _generateLumaraReflection();
  }
  

  Future<void> _generateLumaraReflectionWithIntent(String intent) async {
    // Store original text
    final originalText = _entryState.text.trim();
    
    // Modify entry text temporarily to include intent
    String intentPrompt = '';
    switch (intent) {
      case 'more_depth':
        intentPrompt = originalText.isEmpty 
          ? 'Can you provide more depth on this topic?' 
          : '$originalText\n\nCan you provide more depth on this?';
        break;
      case 'suggest_ideas':
        intentPrompt = originalText.isEmpty 
          ? 'Can you suggest some ideas?' 
          : '$originalText\n\nCan you suggest some ideas related to this?';
        break;
      case 'think_through':
        intentPrompt = originalText.isEmpty 
          ? 'Help me think things through' 
          : '$originalText\n\nHelp me think things through this.';
        break;
      case 'different_perspective':
        intentPrompt = originalText.isEmpty 
          ? 'Can you offer a different perspective?' 
          : '$originalText\n\nCan you offer a different perspective on this?';
        break;
      case 'next_steps':
        intentPrompt = originalText.isEmpty 
          ? 'What are the next steps?' 
          : '$originalText\n\nWhat are the next steps?';
        break;
    }
    
    // Temporarily update entry state with intent prompt
    setState(() {
      _entryState.text = intentPrompt;
      _textController.text = intentPrompt;
    });
    
    // Generate reflection with intent
    await _generateLumaraReflection();
    
    // Restore original text (the reflection will be added as a block, so we restore the entry text)
    setState(() {
      _entryState.text = originalText;
      _textController.text = originalText;
    });
  }
  
  Future<void> _generateJournalingPrompt() async {
    if (!mounted) return;

    // Note: LUMARA is generating prompts (no dialog needed)
    
    // Declare variables outside try block for use in catch block
    ContextWindow? contextWindow;
    String currentPhase = 'Discovery';
    List<String> recentEntries = [];
    List<String> recentChats = [];
    
    try {
      // Get context from past entries, chats, and phase
      final scope = LumaraScope.defaultScope;
      final contextProvider = ContextProvider(scope);
      contextWindow = await contextProvider.buildContext(
        daysBack: 30,
        maxEntries: 50,
      );
      
      // Get current phase
      try {
        currentPhase = await UserPhaseService.getCurrentPhase();
      } catch (e) {
        print('JournalScreen: Error getting current phase: $e');
      }
      
      // Prepare context for backend
      final journalNodes = contextWindow.nodes.where((n) => n['type'] == 'journal').toList();
      recentEntries = journalNodes.take(5).map((n) {
        final text = n['text'] as String? ?? '';
        return text.length > 200 ? text.substring(0, 200) + '...' : text;
      }).toList();
      
      final chatNodes = contextWindow.nodes.where((n) => n['type'] == 'chat').toList();
      recentChats = chatNodes.take(3).map((n) {
        final subject = n['meta']?['subject'] as String? ?? 'conversation';
        return subject;
      }).toList();
      
      bool useBackendPrompts = false;
      List<String> initialPrompts = [];
      
      // Use local prompt generation directly
      useBackendPrompts = false;

      // LUMARA prompt generation completed

      // Show prompt selection dialog
      if (mounted) {
        if (useBackendPrompts && initialPrompts.isNotEmpty) {
          // Use backend-generated prompts
          await _showPromptSelectionDialog(initialPrompts, recentEntries, recentChats, currentPhase);
        } else {
          // Fallback to local prompt generation
          if (contextWindow != null) {
            final contextAwarePrompts = _generateContextAwarePrompts(contextWindow, currentPhase);
            final traditionalPrompts = _getTraditionalPrompts();
            final allPrompts = [...contextAwarePrompts, ...traditionalPrompts];
            await _showPromptSelectionDialog(allPrompts, recentEntries, recentChats, currentPhase);
          }
        }
      }
    } catch (e) {
      // LUMARA prompt generation error - fallback to local

      // Fallback to local prompt generation on any error
      try {
        if (contextWindow != null) {
          final contextAwarePrompts = _generateContextAwarePrompts(contextWindow, currentPhase);
          final traditionalPrompts = _getTraditionalPrompts();
          final allPrompts = [...contextAwarePrompts, ...traditionalPrompts];
          if (mounted) {
            await _showPromptSelectionDialog(allPrompts, recentEntries, recentChats, currentPhase);
          }
        } else {
          // If contextWindow is null, use traditional prompts only
          final traditionalPrompts = _getTraditionalPrompts();
          if (mounted) {
            await _showPromptSelectionDialog(traditionalPrompts, [], [], currentPhase);
          }
        }
      } catch (fallbackError) {
        // If even fallback fails, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating prompts: $fallbackError'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
  
  List<String> _generateContextAwarePrompts(ContextWindow context, String currentPhase) {
    final prompts = <String>[];
    
    // Get recent journal entries
    final journalNodes = context.nodes.where((n) => n['type'] == 'journal').toList();
    final recentEntries = journalNodes.take(5).toList();
    
    // Get recent chat sessions
    final chatNodes = context.nodes.where((n) => n['type'] == 'chat').toList();
    final recentChats = chatNodes.take(3).toList();
    
    // Phase-based prompts
    prompts.add('What does being in the $currentPhase phase mean to you right now?');
    prompts.add('How has your journey through $currentPhase been different from what you expected?');
    
    // Context from recent entries
    if (recentEntries.isNotEmpty) {
      final lastEntry = recentEntries.first;
      final lastEntryText = lastEntry['text'] as String? ?? '';
      if (lastEntryText.length > 50) {
        final preview = lastEntryText.substring(0, 50);
        prompts.add('Continue exploring: "$preview..." - What else comes to mind?');
      }
      
      // Extract themes from recent entries
      final keywords = recentEntries
          .map((e) => e['meta']?['keywords'] as List? ?? [])
          .expand((k) => k)
          .whereType<List>()
          .map((k) => k[0] as String? ?? '')
          .where((k) => k.isNotEmpty)
          .toSet()
          .take(3)
          .toList();
      
      if (keywords.isNotEmpty) {
        prompts.add('You\'ve been reflecting on ${keywords.join(", ")}. What new insights have emerged?');
      }
    }
    
    // Context from recent chats
    if (recentChats.isNotEmpty) {
      final lastChat = recentChats.first;
      final chatSubject = lastChat['meta']?['subject'] as String? ?? 'conversations';
      prompts.add('You recently discussed "$chatSubject" with LUMARA. What would you like to explore further?');
    }
    
    // Time-based prompts
    final daysSinceStart = context.startDate.difference(DateTime.now()).inDays.abs();
    if (daysSinceStart > 7) {
      prompts.add('Looking back over the past ${daysSinceStart} days, what patterns do you notice?');
    }
    
    return prompts;
  }
  
  List<String> _getTraditionalPrompts() {
    return [
      'What\'s one thing that surprised you today?',
      'Describe a moment when you felt truly yourself.',
      'What question have you been avoiding asking yourself?',
      'Write about something you\'re grateful for that you haven\'t acknowledged recently.',
      'What would you tell your past self from a month ago?',
      'Describe a challenge you\'re facing and what you\'ve learned from it.',
      'What does growth look like for you right now?',
      'Write about a relationship that has changed recently.',
      'What are you curious about exploring?',
      'Describe a moment of clarity you\'ve had recently.',
    ];
  }
  
  Future<void> _showPromptSelectionDialog(
    List<String> prompts,
    List<String> recentEntries,
    List<String> recentChats,
    String currentPhase,
  ) async {
    if (!mounted) return;
    
    bool showingExpanded = false;
    List<String> expandedPrompts = [];
    bool isLoadingExpanded = false;
    
    final selectedPrompt = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a Writing Prompt',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: showingExpanded ? expandedPrompts.length : prompts.length,
                    itemBuilder: (context, index) {
                      final prompt = showingExpanded 
                          ? expandedPrompts[index]
                          : prompts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            prompt,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          onTap: () => Navigator.of(context).pop(prompt),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Show "See more" button if showing initial prompts
                if (!showingExpanded && !isLoadingExpanded)
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        setDialogState(() {
                          isLoadingExpanded = true;
                        });
                        
                        // Expanded prompts feature not available with direct API
                        setDialogState(() {
                          isLoadingExpanded = false;
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('More prompts feature is not available in this version'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.expand_more),
                      label: const Text('See more prompts'),
                    ),
                  ),
                if (isLoadingExpanded)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    if (selectedPrompt != null && mounted) {
      // Insert the selected prompt into the text field
      setState(() {
        _entryState.text = selectedPrompt;
        _textController.text = selectedPrompt;
      });
      
      // Optionally focus the text field
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: selectedPrompt.length),
      );
    }
  }
  
  /// Track when user enters journaling mode
  Future<void> _trackJournalModeEntry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entryCount = prefs.getInt('journal_mode_entry_count') ?? 0;
      final newCount = entryCount + 1;
      await prefs.setInt('journal_mode_entry_count', newCount);
      
      // Show prompt notice every 3-5 times (randomized between 3-5)
      if (newCount % 4 == 0 || (newCount >= 3 && newCount <= 5 && newCount % 3 == 0)) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPromptNotice();
          });
        }
      }
    } catch (e) {
      print('Error tracking journal mode entry: $e');
    }
  }
  
  /// Increment journal entry count when entry is saved
  Future<void> _incrementJournalEntryCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entryCount = prefs.getInt('journal_entry_saved_count') ?? 0;
      await prefs.setInt('journal_entry_saved_count', entryCount + 1);
    } catch (e) {
      print('Error incrementing journal entry count: $e');
    }
  }
  
  /// Show notice about writing prompts
  void _showPromptNotice() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need a Writing Prompt?'),
        content: const Text(
          'Press the LUMARA icon (🧠) to get personalized journaling prompts based on your entries, chats, drafts, media, and current phase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateLumaraReflection() async {
    // Declare newBlockIndex outside try block so it's accessible in catch
    int? newBlockIndex;
    
    try {
      // Check if there's text to reflect on
      if (_entryState.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please write something first before asking LUMARA to reflect'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        return;
      }

      // Check if LUMARA is properly configured
      final isConfigured = await _checkLumaraConfiguration();
      if (!isConfigured) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('LUMARA needs a Gemini API key to work. Configure it in Settings.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LumaraSettingsScreen(),
                    ),
                  );
                },
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      _analytics.logLumaraEvent('reflection_generated');

      // LUMARA is generating reflection (will show inline indicator)

      // CRITICAL: Sync _entryState.text with _textController.text to ensure we have the latest entry text
      // This prevents stale text from being used when building context
      // The text controller always has the most up-to-date text from the user's typing
      setState(() {
        _entryState.text = _textController.text;
      });
      print('LUMARA: Synced _entryState.text with _textController.text (length: ${_entryState.text.length})');

      // Loading indicator is now shown inline in the reflection block
      // PLUS the prominent popup dialog for better UX visibility
      
      // Get user ID from user profile
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      final userProfile = userBox.get('profile');
      
      // If no user profile exists, create a default one
      if (userProfile == null) {
        final defaultProfile = UserProfile(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: 'User',
          email: '',
          createdAt: DateTime.now(),
          preferences: const {},
          onboardingCompleted: false,
          onboardingCurrentSeason: 'Discovery',
          currentPhase: 'Discovery',
          lastPhaseChangeAt: DateTime.now(),
        );
        await userBox.put('profile', defaultProfile);
        print('DEBUG: Created default user profile with ID: ${defaultProfile.id}');
      }
      
      // Build context from progressive memory loader (current year only)
      final loadedEntries = _memoryLoader.getLoadedEntries();
      
      // Check if this is the first LUMARA activation (no existing blocks)
      final isFirstActivation = _entryState.blocks.isEmpty;
      
      // Capture original entry text when first block is created
      // This ensures we only use text that appears ABOVE subsequent blocks
      if (isFirstActivation) {
        _originalEntryTextBeforeBlocks = _textController.text.trim();
      }
      
      // The new block index will be the current length (0 for first activation)
      newBlockIndex = _entryState.blocks.length;
      final blockIndex = newBlockIndex; // Non-null after assignment
      
      // Build comprehensive context with mood, phase, chrono profile, chats, and media
      // Always pass currentBlockIndex to include conversation history from previous blocks
      // This ensures LUMARA sees user questions/comments from continuation fields
      final richContext = await _buildRichContext(
        loadedEntries, 
        userProfile,
        currentBlockIndex: blockIndex,
      );
      final phaseHint = _entryState.phase ?? 'Discovery';
      
      // Create placeholder block immediately so loading indicator shows
      final placeholderBlock = InlineBlock(
        type: 'reflection',
        intent: 'reflect',
        content: '', // Empty content will be replaced
        timestamp: DateTime.now().millisecondsSinceEpoch,
        phase: _entryState.phase,
      );
      
      // Add placeholder block and set loading state
      if (mounted) {
        setState(() {
          _entryState.blocks.add(placeholderBlock);
          _lumaraLoadingStates[blockIndex] = true;
          _lumaraLoadingMessages[blockIndex] = 'LUMARA is thinking...';
        });

        // Auto-scroll to bottom to show the thinking indicator
        // Use a small delay to ensure the UI has updated before scrolling
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
      
      String reflection;
      List<AttributionTrace>? attributionTraces;
      
      if (isFirstActivation) {
        // For first activation, use EnhancedLumaraApi with More Depth option to ensure
        // decisive, thorough responses that answer questions properly
        final result = await _enhancedLumaraApi.generatePromptedReflection(
          entryText: richContext['entryText'] ?? '',
          intent: 'journal',
          phase: phaseHint,
          userId: userProfile?.id,
          includeExpansionQuestions: true,
          mood: richContext['mood'],
          chronoContext: richContext['chronoContext'],
          chatContext: richContext['chatContext'],
          mediaContext: richContext['mediaContext'],
          entryId: _currentEntryId, // For per-entry usage limit tracking
          options: lumara_models.LumaraReflectionOptions(
            preferQuestionExpansion: true, // Use More Depth by default for first activation
            toneMode: lumara_models.ToneMode.normal,
            regenerate: false,
          ),
          onProgress: (message) {
            if (mounted) {
              setState(() {
                _lumaraLoadingMessages[blockIndex] = message;
              });
            }
          },
        );
        
        reflection = result.reflection;
        attributionTraces = result.attributionTraces;
        
        print('Journal: Retrieved ${attributionTraces.length} attribution traces from EnhancedLumaraApi');
        
        // Enrich attribution traces with actual journal entry content
        if (attributionTraces.isNotEmpty) {
          attributionTraces = await _enrichAttributionTraces(attributionTraces);
          print('Journal: Enriched ${attributionTraces.length} attribution traces with journal entry content');
        }
      } else {
        // For subsequent activations, also use EnhancedLumaraApi with More Depth
        // to ensure thorough responses that answer questions properly
        final result = await _enhancedLumaraApi.generatePromptedReflection(
          entryText: richContext['entryText'] ?? '',
          intent: 'journal',
          phase: phaseHint,
          userId: userProfile?.id,
          includeExpansionQuestions: true,
          mood: richContext['mood'],
          chronoContext: richContext['chronoContext'],
          chatContext: richContext['chatContext'],
          mediaContext: richContext['mediaContext'],
          entryId: _currentEntryId, // For per-entry usage limit tracking
          options: lumara_models.LumaraReflectionOptions(
            preferQuestionExpansion: true, // Use More Depth for all activations
            toneMode: lumara_models.ToneMode.normal,
            regenerate: false,
          ),
          onProgress: (message) {
            if (mounted) {
              setState(() {
                _lumaraLoadingMessages[blockIndex] = message;
              });
            }
          },
        );
        
        reflection = result.reflection;
        attributionTraces = result.attributionTraces;
        
        print('Journal: Retrieved ${attributionTraces.length} attribution traces from EnhancedLumaraApi');
        
        // Enrich attribution traces with actual journal entry content
        if (attributionTraces.isNotEmpty) {
          attributionTraces = await _enrichAttributionTraces(attributionTraces);
          print('Journal: Enriched ${attributionTraces.length} attribution traces with journal entry content');
        }
      }

      // Update the placeholder block with actual content, attributions, and clear loading state
      if (mounted) {
        setState(() {
          _entryState.blocks[blockIndex] = _entryState.blocks[blockIndex].copyWith(
            content: reflection,
            attributionTraces: attributionTraces,
          );
          _lumaraLoadingStates.remove(blockIndex);
          _lumaraLoadingMessages.remove(blockIndex);
        });
      }
      
      // Persist blocks to entry immediately if editing existing entry
      if (widget.existingEntry != null) {
        await _persistLumaraBlocksToEntry();
      }
      
      // Create controller for the new block if it doesn't exist
      if (!_continuationControllers.containsKey(blockIndex)) {
        final controller = TextEditingController();
        _continuationControllers[blockIndex] = controller;
        controller.addListener(() {
          if (blockIndex < _entryState.blocks.length) {
            setState(() {
              _entryState.blocks[blockIndex] = _entryState.blocks[blockIndex].copyWith(
                userComment: controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
              _hasBeenModified = true;
            });
            _updateDraftContent(_entryState.text);
            // Persist blocks to entry if editing existing entry
            if (widget.existingEntry != null) {
              _persistLumaraBlocksToEntry();
            }
          }
        });
      }
      
      // Auto-save the updated content
      _updateDraftContent(_textController.text);

      _analytics.logLumaraEvent('inline_reflection_inserted', data: {'intent': 'reflect'});

      // LUMARA reflection generation completed

      // Dismiss the Lumara box
      _dismissLumaraBox();
      
    } catch (e) {
      // LUMARA reflection generation error

      // Remove placeholder block on error
      if (mounted && newBlockIndex != null && newBlockIndex < _entryState.blocks.length) {
        setState(() {
          _entryState.blocks.removeAt(newBlockIndex!);
          _lumaraLoadingStates.remove(newBlockIndex);
          _lumaraLoadingMessages.remove(newBlockIndex);
        });
      }

      // Snackbar removed - loading indicator is now inline

      _analytics.log('lumara_error', {'error': e.toString()});
      
      // Check if it's an API key issue
      if (e.toString().contains('API key') || 
          e.toString().contains('not configured') || 
          e.toString().contains('Gemini API key') ||
          e.toString().contains('not configured')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('LUMARA needs a Gemini API key to work. Configure it in Settings.'),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LumaraSettingsScreen(),
                    ),
                  );
                },
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Show generic error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('LUMARA reflection failed: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
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
      await _createMockImageFile(); // Create mock file for OCR (not yet implemented)
      // TODO: OCR service not yet implemented
      // final extractedText = await _ocrService.extractText(mockImageFile);
      final extractedText = ''; // Placeholder until OCR is implemented
      
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
    
    // Handle invalid cursor position (e.g., -1)
    if (cursorPosition < 0 || cursorPosition > currentText.length) {
      // Default to end of text if cursor position is invalid
      final newText = currentText + '\n\n$text';
      _textController.text = newText;
      _textController.selection = TextSelection.collapsed(
        offset: currentText.length + text.length + 2,
      );
      _onTextChanged(newText);
      return;
    }
    
    final newText = '${currentText.substring(0, cursorPosition)}\n\n$text${currentText.substring(cursorPosition)}';
    
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: cursorPosition + text.length + 2,
    );
    
    _onTextChanged(newText);
  }

  void _togglePhotoSelectionMode() {
    setState(() {
      _isPhotoSelectionMode = !_isPhotoSelectionMode;
      if (!_isPhotoSelectionMode) {
        _selectedPhotoIndices.clear();
      }
    });
  }

  void _togglePhotoSelection(int index) {
    setState(() {
      if (_selectedPhotoIndices.contains(index)) {
        _selectedPhotoIndices.remove(index);
      } else {
        _selectedPhotoIndices.add(index);
      }
    });
  }

  void _deleteSelectedPhotos() {
    if (_selectedPhotoIndices.isEmpty) return;

    // Sort indices in descending order to avoid index shifting issues
    final sortedIndices = _selectedPhotoIndices.toList()..sort((a, b) => b.compareTo(a));
    
    // Count photos vs videos for message
    int photoCount = 0;
    int videoCount = 0;
    
    setState(() {
      for (final index in sortedIndices) {
        if (index < _entryState.attachments.length) {
          final attachment = _entryState.attachments[index];
          if (attachment is PhotoAttachment) {
            photoCount++;
          } else if (attachment is VideoAttachment) {
            videoCount++;
          }
          _entryState.attachments.removeAt(index);
        }
      }
      _selectedPhotoIndices.clear();
      _isPhotoSelectionMode = false;
    });

    // Update draft if exists
    if (_currentDraftId != null && (!widget.isViewOnly || _isEditMode)) {
      final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
      final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
      _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
    }

    // Build confirmation message
    final List<String> parts = [];
    if (photoCount > 0) parts.add('$photoCount photo${photoCount == 1 ? '' : 's'}');
    if (videoCount > 0) parts.add('$videoCount video${videoCount == 1 ? '' : 's'}');
    final message = 'Deleted ${parts.join(' and ')}';

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show context menu for a single photo (long-press)
  void _showPhotoContextMenu(PhotoAttachment photo, int photoIndex) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _openPhotoInGallery(photo.imagePath);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('Delete Photo', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteSinglePhoto(photoIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Delete a single photo
  void _deleteSinglePhoto(int photoIndex) {
    if (photoIndex >= _entryState.attachments.length) return;

    setState(() {
      _entryState.attachments.removeAt(photoIndex);
    });

    // Update draft if exists
    if (_currentDraftId != null && (!widget.isViewOnly || _isEditMode)) {
      final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
      final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
      _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleted photo'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show options for handling broken photo references
  void _showBrokenPhotoOptions(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo Unavailable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This photo is no longer accessible. It may have been deleted from your photo library or the reference is no longer valid.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Photo reference: ${imagePath.length > 40 ? '${imagePath.substring(0, 40)}...' : imagePath}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeBrokenPhotoReference(imagePath);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Photo'),
          ),
        ],
      ),
    );
  }

  /// Remove a broken photo reference from the entry
  void _removeBrokenPhotoReference(String imagePath) {
    // Find the attachment with this image path
    final attachmentIndex = _entryState.attachments.indexWhere(
      (attachment) => attachment is PhotoAttachment && attachment.imagePath == imagePath,
    );

    if (attachmentIndex != -1) {
      setState(() {
        _entryState.attachments.removeAt(attachmentIndex);
      });

      // No text placeholders to remove - photos are displayed as separate thumbnails
      print('🗑️ Removed broken photo reference: $imagePath');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed broken photo reference'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print('⚠️ Could not find attachment with path: $imagePath');
    }
  }

  Widget _buildPhotoSelectionControls() {
    final photoCount = _entryState.attachments.where((attachment) => attachment is PhotoAttachment).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.photo_library,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$photoCount photo(s)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_isPhotoSelectionMode) ...[
            if (_selectedPhotoIndices.isNotEmpty) ...[
              Text(
                '${_selectedPhotoIndices.length} selected',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _deleteSelectedPhotos,
                icon: const Icon(Icons.delete),
                iconSize: 18,
                color: Theme.of(context).colorScheme.error,
                tooltip: 'Delete selected photos',
              ),
            ],
            IconButton(
              onPressed: _togglePhotoSelectionMode,
              icon: const Icon(Icons.close),
              iconSize: 18,
              tooltip: 'Cancel selection',
            ),
          ] else ...[
            // Prompt for selection when mode active but nothing selected
            if (_isPhotoSelectionMode && _selectedPhotoIndices.isEmpty) ...[
              Text(
                'Tap photos to select',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              onPressed: _togglePhotoSelectionMode,
              icon: const Icon(Icons.checklist),
              iconSize: 18,
              tooltip: 'Select photos',
            ),
          ],
        ],
      ),
    );
  }

  /// Combined photo selection toggle + gallery grid displayed near the top of the entry
  Widget _buildPhotoGallerySection(ThemeData theme) {
    final photoAttachments = _entryState.attachments
        .whereType<PhotoAttachment>()
        .toList();

    if (photoAttachments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Preserve user ordering or fallback to timestamp ordering
    photoAttachments.sort((a, b) {
      if (a.insertionPosition != null && b.insertionPosition != null) {
        return a.insertionPosition!.compareTo(b.insertionPosition!);
      } else if (a.insertionPosition != null) {
        return -1;
      } else if (b.insertionPosition != null) {
        return 1;
      } else {
        return a.timestamp.compareTo(b.timestamp);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPhotoSelectionControls(),
        const SizedBox(height: 12),
        _buildPhotoThumbnailGrid(photoAttachments, theme),
      ],
    );
  }

  void _onContinue() {
    _analytics.logJournalEvent('continue_pressed', data: {
      'text_length': _entryState.text.length,
      'reflection_count': _entryState.blocks.length,
    });
    
    // Track journal entry completion
    _incrementJournalEntryCount();
    
    // Navigate to keyword analysis
    Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) {
          print('DEBUG: JournalScreen - Passing date/time to KeywordAnalysisView:');
          print('DEBUG: - _editableDate: $_editableDate');
          print('DEBUG: - _editableTime: $_editableTime');
          print('DEBUG: - existingEntry.createdAt: ${widget.existingEntry?.createdAt}');
          
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (context) {
                  final cubit = JournalCaptureCubit(context.read<JournalRepository>());
                  // Set LUMARA API for summary generation
                  cubit.setLumaraApi(_enhancedLumaraApi);
                  return cubit;
                },
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
            existingEntry: _getCurrentEntryForContext(),
            selectedDate: _editableDate,
            selectedTime: _editableTime,
            selectedLocation: _editableLocation,
            mediaItems: (() {
              final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
              print('DEBUG: Saving entry with ${mediaItems.length} media items');
              print('DEBUG: Attachments count: ${_entryState.attachments.length}');
              for (int i = 0; i < mediaItems.length; i++) {
                final media = mediaItems[i];
                print('DEBUG: Media $i - Type: ${media.type}, URI: ${media.uri}, AnalysisData: ${media.analysisData?.keys}');
              }
              return mediaItems;
            })(),
            lumaraBlocks: () {
              final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
              debugPrint('JournalScreen: Saving entry with ${blocksJson.length} LUMARA blocks');
              for (int i = 0; i < blocksJson.length; i++) {
                final block = blocksJson[i];
                debugPrint('JournalScreen: Block $i - type: ${block['type']}, intent: ${block['intent']}, hasComment: ${block['userComment'] != null}');
              }
              return blocksJson;
            }(),
            title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
            isTimelineEditing: widget.isTimelineEditing, // Pass timeline editing flag for timestamp control
            ),
          );
        },
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
        
        // Refresh the timeline to show the new entry
        _refreshTimelineAfterSave();
        
        // Navigate back to the previous screen
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.isViewOnly && !_isEditMode ? 'View Entry' : 'Write what is true right now'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Show Edit button when in view-only mode and not yet editing
          if (widget.isViewOnly && !_isEditMode)
            IconButton(
              onPressed: _switchToEditMode,
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Entry',
            ),
          Stack(
            children: [
              IconButton(
                onPressed: () => _navigateToDrafts(),
                icon: const Icon(Icons.drafts),
                tooltip: 'Drafts',
              ),
              if (_draftCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_draftCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () async {
              final shouldPop = await _onBackPressed();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
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
                    // Dismiss boxes when clicking on the journal page
                    if (_showKeywordsDiscovered || _showLumaraBox || _showPrivateNotes) {
                      setState(() {
                        _showKeywordsDiscovered = false;
                        _showLumaraBox = false;
                        _showPrivateNotes = false;
                      });
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Bottom padding for FAB and nav
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Entry title - always show field for new and existing entries
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                hintText: 'Give your entry a title...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              enabled: widget.existingEntry == null || !widget.isViewOnly || _isEditMode,
                              ),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _hasBeenModified = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                        // Metadata editing section (only for existing entries)
                        if (widget.existingEntry != null) ...[
                          _buildMetadataEditingSection(theme),
                          const SizedBox(height: 16),
                        ],

                        // Photo gallery + selection (displayed near top, before main text)
                        _buildPhotoGallerySection(theme),
                        if (_entryState.attachments.whereType<PhotoAttachment>().isNotEmpty)
                          const SizedBox(height: 16),

                        // Always show the TextField (handles view-only vs edit mode internally)
                        _buildAITextField(theme),
                        const SizedBox(height: 16),

                        // Show inline photos and reflections
                        ..._buildInterleavedContent(theme),

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

                      // Private Notes section (conditional visibility)
                      if (_showPrivateNotes)
                        PrivateNotesPanel(
                          entryId: _currentEntryId ?? 'draft_${_currentDraftId ?? DateTime.now().millisecondsSinceEpoch}',
                          onClose: () {
                            setState(() {
                              _showPrivateNotes = false;
                            });
                          },
                        ),

                      // Scan attachments (OCR text) - shown separately
                      ..._entryState.attachments.where((a) => a is ScanAttachment).map((attachment) {
                        return _buildScanAttachment(attachment as ScanAttachment);
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
                    // Primary action row - optimized layout with even spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Consolidated attachment menu (replaces separate photo/camera/video icons)
                              AttachmentMenuButton(
                                onPhotoGallery: _handlePhotoGallery,
                                onCamera: _handleCamera,
                                onVideoGallery: _handleVideoGallery,
                              ),
                              
                              // Private Notes button
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showPrivateNotes = !_showPrivateNotes;
                                  });
                                },
                                icon: Icon(
                                  _showPrivateNotes ? Icons.lock : Icons.lock_outline,
                                  size: 18,
                                ),
                                tooltip: 'Private Notes',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                style: IconButton.styleFrom(
                                  backgroundColor: _showPrivateNotes 
                                    ? theme.colorScheme.primary.withOpacity(0.2)
                                    : null,
                                ),
                        ),
                              
                              // Keyword toggle button
                              IconButton(
                                onPressed: _toggleKeywordsDiscovered,
                                icon: Icon(
                                  _showKeywordsDiscovered ? Icons.label_off : Icons.label,
                                  size: 18,
                                ),
                                tooltip: _showKeywordsDiscovered ? 'Hide Keywords' : 'Show Keywords',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                style: IconButton.styleFrom(
                                  backgroundColor: _showKeywordsDiscovered 
                                    ? theme.colorScheme.primary.withOpacity(0.2)
                                    : null,
                          ),
                        ),
                        
                              // LUMARA button
                              IconButton(
                          onPressed: _onLumaraFabTapped,
                          icon: LumaraIcon(
                            size: 18,
                            color: _isLumaraConfigured 
                              ? null 
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                                tooltip: 'LUMARA',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          style: IconButton.styleFrom(
                            backgroundColor: _showLumaraBox 
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : _isLumaraConfigured 
                                ? null 
                                : theme.colorScheme.surface.withOpacity(0.5),
                          ),
                        ),
                        
                        // Continue button
                              // Enable if entry has user text OR LUMARA blocks (allow entries that start with reflections)
                              ElevatedButton(
                                onPressed: (_entryState.text.trim().isNotEmpty || _entryState.blocks.isNotEmpty) ? _onContinue : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                ),
                                child: const Text(
                                  'Continue',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Floating scroll-to-top button (appears when scrolled down)
          if (_showScrollToTop)
            Positioned(
              bottom: 200, // Above scroll-to-bottom button
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'scrollToTop',
                onPressed: _scrollToTop,
                backgroundColor: kcSurfaceAltColor,
                elevation: 4,
                child: const Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.white,
                ),
              ),
            ),
          // Floating scroll-to-bottom button (appears when not at bottom)
          if (_showScrollToBottom)
            Positioned(
              bottom: 140, // Above FAB and nav bar
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'scrollToBottom',
                onPressed: _scrollToBottom,
                backgroundColor: kcSurfaceAltColor,
                elevation: 4,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ),
            ),
        ],
        ),
      ),
    ),
    );
  }

  /// Check for existing draft linked to an entry (3d requirement)
  Future<void> _checkForLinkedDraft(String entryId) async {
    try {
      final draft = await _draftCache.getDraftByLinkedEntryId(entryId);
      if (draft != null && draft.hasContent) {
        // Found a draft for this entry - redirect user to it
        if (mounted && !_isEditMode) {
          // Only show dialog if not already in edit mode
          final shouldOpenDraft = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unfinished Draft Found'),
              content: Text(
                'You have an unfinished draft for this entry from ${_formatDraftDate(draft.lastModified)}. Would you like to continue editing the draft?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('View Original'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open Draft'),
                ),
              ],
            ),
          );
          
          if (shouldOpenDraft == true && mounted) {
            // Load draft content
            _textController.text = draft.content;
            _entryState.text = draft.content;
            
            // Restore LUMARA blocks from draft
            _entryState.blocks.clear();
            // Clean up existing controllers
            for (final controller in _continuationControllers.values) {
              controller.dispose();
            }
            _continuationControllers.clear();
            
            if (draft.lumaraBlocks.isNotEmpty) {
              for (int i = 0; i < draft.lumaraBlocks.length; i++) {
                final blockJson = draft.lumaraBlocks[i];
                try {
                  final block = InlineBlock.fromJson(Map<String, dynamic>.from(blockJson));
                  _entryState.addReflection(block);
                  
                  // Create and initialize continuation controller for this block
                  final controller = TextEditingController(text: block.userComment ?? '');
                  _continuationControllers[i] = controller;
                  controller.addListener(() {
                    // Save comment to block when text changes
                    if (i < _entryState.blocks.length) {
                      setState(() {
                        _entryState.blocks[i] = _entryState.blocks[i].copyWith(
                          userComment: controller.text.trim().isEmpty ? null : controller.text.trim(),
                        );
                        _hasBeenModified = true;
                      });
                      // Auto-save draft with updated blocks
                      _updateDraftContent(_entryState.text);
                    }
                  });
                } catch (e) {
                  debugPrint('JournalScreen: Error loading LUMARA block from draft: $e');
                }
              }
              debugPrint('JournalScreen: Restored ${_entryState.blocks.length} LUMARA blocks from draft');
            }
            
            // Convert draft media items to attachments
            if (draft.mediaItems.isNotEmpty) {
              final attachments = MediaConversionUtils.mediaItemsToAttachments(draft.mediaItems);
              _entryState.attachments.clear();
              _entryState.attachments.addAll(attachments);
            }
            
            // Switch to edit mode and restore draft
            _switchToEditMode();
            await _draftCache.restoreDraft(draft);
            _currentDraftId = draft.id;
            
            setState(() {
              _hasBeenModified = true;
            });
            
            debugPrint('JournalScreen: Loaded draft ${draft.id} for entry $entryId');
          }
        }
      }
    } catch (e) {
      debugPrint('JournalScreen: Error checking for linked draft: $e');
    }
  }

  String _formatDraftDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Handle back button press - show save/discard dialog (2a, 3b requirement)
  Future<bool> _onBackPressed() async {
    // Only prompt if we're in edit mode or have content
    if (widget.isViewOnly && !_isEditMode) {
      // View-only mode with no edits, allow navigation
      return true;
    }
    
    // For existing entries, only show dialog if content has been modified
    if (widget.existingEntry != null) {
      if (!_hasBeenModified) {
        // No changes made, allow navigation without dialog
        return true;
      }
    }
    
    // Check if there's any content to save
    // Allow entries that start with LUMARA reflections (blocks) even if no user text
    final hasContent = _entryState.text.trim().isNotEmpty || 
                       _entryState.attachments.isNotEmpty || 
                       _entryState.blocks.isNotEmpty;
    
    if (!hasContent) {
      // No content, allow navigation
      return true;
    }
    
    // Always ask user permission for manual navigation (back/home buttons) (2a, 3b requirement)
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Draft?'),
        content: Text(
          widget.existingEntry != null
              ? 'You have unsaved changes. Would you like to save your work as a draft?'
              : 'Would you like to save your work as a draft?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save Draft'),
          ),
        ],
      ),
    );
    
    if (result == 'save') {
      // Save draft with current content and media
      final mediaItems = _entryState.attachments.isNotEmpty
          ? MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments)
          : const <MediaItem>[];
      
      final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
      await _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
      await _draftCache.saveCurrentDraftImmediately();
      return true;
    } else if (result == 'discard') {
      // Discard draft
      await _draftCache.discardDraft();
      _currentDraftId = null;
      return true;
    } else {
      // Cancel navigation
      return false;
    }
  }


  /// Build metadata editing section for existing entries
  Widget _buildMetadataEditingSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Edit Entry Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Date and Time row
          Row(
            children: [
              // Date picker
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                          _editableDate != null 
                            ? '${_editableDate!.day}/${_editableDate!.month}/${_editableDate!.year}'
                            : 'Select Date',
                          style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Time picker
              Expanded(
                child: InkWell(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                          _editableTime != null 
                            ? _editableTime!.format(context)
                            : 'Select Time',
                          style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Location field
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Where were you?',
              prefixIcon: const Icon(Icons.location_on, size: 16),
              suffixIcon: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.search, size: 20),
                    onPressed: _showLocationPicker,
                    tooltip: 'Search locations',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                  ),
                  IconButton(
                      icon: const Icon(Icons.my_location, size: 20),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Get current location',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                  ),
                ],
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _editableLocation = value.trim().isEmpty ? null : value.trim();
                _hasBeenModified = true;
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Phase override dropdown
          _buildPhaseOverrideSection(theme),
        ],
      ),
    );
  }
  
  /// Build phase override section for existing entries
  Widget _buildPhaseOverrideSection(ThemeData theme) {
    // Use local override state if available, otherwise use widget.existingEntry
    final entry = _currentEntryOverride ?? widget.existingEntry;
    if (entry == null) return const SizedBox.shrink();
    
    // Ensure legacyPhaseTag is populated for older entries (and save if needed)
    final entryWithLegacy = entry.ensureLegacyPhaseTag();
    if (entryWithLegacy != entry && _currentEntryOverride == null) {
      // Save the entry with legacyPhaseTag populated (only if not already overridden)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final journalRepository = JournalRepository();
        await journalRepository.updateJournalEntry(entryWithLegacy);
      });
    }
    
    final currentPhase = entryWithLegacy.computedPhase ?? 'Discovery';
    final isManual = entryWithLegacy.isPhaseManuallyOverridden;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Phase',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isManual)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Manual',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Auto',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: currentPhase,
                decoration: InputDecoration(
                  labelText: 'Phase',
                  hintText: 'Select phase',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  'Discovery',
                  'Expansion',
                  'Transition',
                  'Consolidation',
                  'Recovery',
                  'Breakthrough',
                ].map((phase) {
                  return DropdownMenuItem<String>(
                    value: phase,
                    child: Text(phase),
                  );
                }).toList(),
                onChanged: (String? newPhase) {
                  if (newPhase != null) {
                    _updateEntryPhaseOverride(entryWithLegacy, newPhase);
                  }
                },
              ),
            ),
            if (isManual) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _resetPhaseToAuto(entryWithLegacy),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset to Auto'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
  
  /// Update entry phase override
  Future<void> _updateEntryPhaseOverride(JournalEntry entry, String newPhase) async {
    try {
      final updatedEntry = entry.copyWith(
        userPhaseOverride: newPhase,
        isPhaseLocked: true,
      );
      
      final journalRepository = JournalRepository();
      await journalRepository.updateJournalEntry(updatedEntry);
      
      setState(() {
        _hasBeenModified = true;
        _currentEntryOverride = updatedEntry;  // Update local state to reflect change
      });
      
      print('DEBUG: Updated entry ${entry.id} phase override to: $newPhase');
    } catch (e) {
      print('ERROR: Failed to update phase override: $e');
    }
  }
  
  /// Reset phase to auto-detected
  Future<void> _resetPhaseToAuto(JournalEntry entry) async {
    try {
      final updatedEntry = entry.copyWith(
        userPhaseOverride: null,
        isPhaseLocked: false,
      );
      
      final journalRepository = JournalRepository();
      await journalRepository.updateJournalEntry(updatedEntry);
      
      setState(() {
        _hasBeenModified = true;
        _currentEntryOverride = updatedEntry;  // Update local state to reflect change
      });
      
      print('DEBUG: Reset entry ${entry.id} phase to auto-detected');
    } catch (e) {
      print('ERROR: Failed to reset phase: $e');
    }
  }

  /// Build content showing photos, videos, and reflections (without duplicating text)
  List<Widget> _buildInterleavedContent(ThemeData theme) {
    final widgets = <Widget>[];

    // Get all video attachments
    final videoAttachments = _entryState.attachments
        .whereType<VideoAttachment>()
        .toList();
    
    // Debug: Log video attachments found
    if (videoAttachments.isNotEmpty) {
      print('DEBUG: Found ${videoAttachments.length} video attachments to display');
      for (int i = 0; i < videoAttachments.length; i++) {
        final video = videoAttachments[i];
        print('DEBUG: Video $i - Path: ${video.videoPath}, ID: ${video.videoId}, Exists: ${File(video.videoPath).existsSync()}');
      }
    }

    // Sort videos by insertion position if available, otherwise by timestamp
    videoAttachments.sort((a, b) {
      if (a.insertionPosition != null && b.insertionPosition != null) {
        return a.insertionPosition!.compareTo(b.insertionPosition!);
      } else if (a.insertionPosition != null) {
        return -1;
      } else if (b.insertionPosition != null) {
        return 1;
      } else {
        return a.timestamp.compareTo(b.timestamp);
      }
    });

    // Show videos as a grid
    if (videoAttachments.isNotEmpty) {
      widgets.add(_buildVideoThumbnailGrid(videoAttachments, theme));
      widgets.add(const SizedBox(height: 16));
    }

    // Add inline reflection blocks with continuation field after each
    for (int index = 0; index < _entryState.blocks.length; index++) {
      final block = _entryState.blocks[index];
      
      // Ensure we have a controller for this block
      if (!_continuationControllers.containsKey(index)) {
        final controller = TextEditingController(text: block.userComment ?? '');
        _continuationControllers[index] = controller;
        controller.addListener(() {
          // Save comment to block when text changes
          if (index < _entryState.blocks.length) {
            setState(() {
              _entryState.blocks[index] = _entryState.blocks[index].copyWith(
                userComment: controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
              // Mark as modified
              _hasBeenModified = true;
            });
            // Auto-save draft with updated blocks
            _updateDraftContent(_entryState.text);
            // Persist blocks to entry if editing existing entry (debounced)
            if (widget.existingEntry != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (widget.existingEntry != null && mounted) {
                  _persistLumaraBlocksToEntry();
                }
              });
            }
          }
        });
      }
      
      // Add the reflection block
      // Generate a unique ID for favorites tracking using timestamp
      final blockId = 'journal_${block.timestamp}_${index}';
      widgets.add(InlineReflectionBlock(
        content: block.content,
        intent: block.intent,
        phase: block.phase,
        isLoading: _lumaraLoadingStates[index] ?? false,
        loadingMessage: _lumaraLoadingMessages[index],
        attributionTraces: block.attributionTraces,
        blockId: blockId,
        onRegenerate: () => _onRegenerateReflection(index),
        onSoften: () => _onSoftenReflection(index),
        onMoreDepth: () => _onMoreDepthReflection(index),
        onContinueThought: () => _onContinueThought(index),
        onContinueWithLumara: () => _onContinueWithLumara(index),
        onDelete: () => _onDeleteReflection(index),
      ));
      
      // Add a text field below each reflection to continue the conversation
      widgets.add(const SizedBox(height: 8));
      widgets.add(_buildContinuationField(theme, index));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }
  
  /// Build continuation text field for user to respond after LUMARA reflection
  Widget _buildContinuationField(ThemeData theme, int blockIndex) {
    final controller = _continuationControllers[blockIndex];
    if (controller == null) {
      // Should not happen, but handle gracefully
      return const SizedBox.shrink();
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
              height: 1.5,
            ),
            cursorColor: theme.colorScheme.primary,
            decoration: InputDecoration(
              hintText: 'Write...',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 16,
                height: 1.5,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _onContinueThought(blockIndex),
                icon: const Icon(Icons.arrow_upward, size: 20),
                color: theme.colorScheme.onPrimary,
                tooltip: 'Send to LUMARA',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build a grid of video thumbnails
  Widget _buildVideoThumbnailGrid(List<VideoAttachment> videos, ThemeData theme) {
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
        children: [
          Row(
            children: [
              Icon(
                Icons.videocam,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Videos (${videos.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show videos as a grid wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: videos.map((video) => _buildVideoThumbnailCard(video, theme)).toList(),
          ),
        ],
      ),
    );
  }

  /// Build individual video thumbnail card for grid display
  Widget _buildVideoThumbnailCard(VideoAttachment video, ThemeData theme) {
    // Find the index of this video in the attachments list
    final videoIndex = _entryState.attachments.indexOf(video);
    final isSelected = _selectedPhotoIndices.contains(videoIndex);
    
    // Check if video file exists
    final videoFile = File(video.videoPath);
    final fileExists = videoFile.existsSync();
    
    return GestureDetector(
      onTap: () {
        if (_isPhotoSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedPhotoIndices.remove(videoIndex);
            } else {
              _selectedPhotoIndices.add(videoIndex);
            }
          });
        } else {
          if (fileExists) {
            _playVideo(video.videoPath);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Video file not found: ${video.videoPath.split('/').last}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      onLongPress: () {
        if (!_isPhotoSelectionMode) {
          _showVideoContextMenu(video, videoIndex);
        }
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary.withOpacity(0.3)
              : fileExists
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : fileExists
                    ? theme.colorScheme.outline.withOpacity(0.3)
                    : theme.colorScheme.error.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Try to show video thumbnail if available
            if (fileExists && video.thumbnailPath != null && File(video.thumbnailPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(video.thumbnailPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildVideoThumbnailPlaceholder(theme, fileExists);
                  },
                ),
              )
            else if (fileExists)
              // Try to load thumbnail from photo library if it's a photo library video
              FutureBuilder<String?>(
                future: _getVideoThumbnailPath(video.videoPath),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final thumbPath = snapshot.data!;
                    if (File(thumbPath).existsSync()) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(thumbPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildVideoThumbnailPlaceholder(theme, fileExists);
                          },
                        ),
                      );
                    }
                  }
                  return _buildVideoThumbnailPlaceholder(theme, fileExists);
                },
              )
            else
              _buildVideoThumbnailPlaceholder(theme, fileExists),
            // Duration overlay if available
            if (video.duration != null)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(video.duration!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Selection indicator
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Play video using native iOS Photos framework or fallback methods
  Future<void> _playVideo(String videoPath) async {
    try {
      print('DEBUG: Attempting to play video: $videoPath');
      
      // Check if file exists
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video file not found: ${videoPath.split('/').last}'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Try native iOS Photos framework first, then fallback methods
      final success = await _tryOpenSpecificVideo(videoPath);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video player. Please try opening the file manually.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('ERROR: Failed to play video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play video: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Try to open a specific video using native iOS Photos framework or fallback methods
  Future<bool> _tryOpenSpecificVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        print('DEBUG: Video file does not exist: $videoPath');
        return false;
      }

      // Method 1: Try to use native iOS Photos framework to find and open the specific video
      if (Platform.isIOS) {
        try {
          const platform = MethodChannel('com.epi.arcmvp/photos');
          // Use timeout and comprehensive error handling to prevent crashes
          final result = await platform.invokeMethod(
            'getVideoIdentifierAndOpen', 
            videoPath,
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('DEBUG: MethodChannel timeout - method may not exist or is slow');
              return false;
            },
          ).catchError((e, stackTrace) {
            print('DEBUG: MethodChannel invokeMethod failed (non-fatal): $e');
            print('DEBUG: Stack trace: $stackTrace');
            return false; // Return false instead of throwing to prevent crash
          });
          
          if (result == true) {
            print('DEBUG: Successfully opened video using native iOS Photos framework');
            return true;
          }
        } catch (e, stackTrace) {
          print('DEBUG: Native iOS Photos method failed (non-fatal): $e');
          print('DEBUG: Stack trace: $stackTrace');
          // Don't rethrow - continue to fallback methods to prevent crash
        }
      }

      // Method 2: Try to extract video identifier from path and use photos:// scheme
      final fileName = videoPath.split('/').last;
      final videoId = _extractPhotoIdFromFileName(fileName);

      if (videoId != null) {
        final photosUri = Uri.parse('photos://$videoId');
        if (await canLaunchUrl(photosUri)) {
          await launchUrl(photosUri, mode: LaunchMode.externalApplication);
          print('DEBUG: Opened video using photos:// scheme');
          return true;
        }
      }

      // Method 3: Try to open with file:// scheme
      final fileUri = Uri.file(videoPath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        print('DEBUG: Opened video using file:// scheme');
        return true;
      }

      // Method 4: Try to use the Photos app with a search query
      final searchUri = Uri.parse(
          'photos-redirect://search?query=${Uri.encodeComponent(fileName)}');
      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
        print('DEBUG: Opened video using photos-redirect:// scheme');
        return true;
      }

      return false;
    } catch (e) {
      print('ERROR: Error trying to open specific video: $e');
      return false;
    }
  }

  /// Build video thumbnail placeholder (icon)
  Widget _buildVideoThumbnailPlaceholder(ThemeData theme, bool fileExists) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            fileExists ? Icons.play_circle_outline : Icons.error_outline,
            size: 40,
            color: fileExists 
                ? theme.colorScheme.primary 
                : theme.colorScheme.error,
          ),
          if (!fileExists)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Missing',
                style: TextStyle(
                  fontSize: 8,
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Try to get video thumbnail path from photo library or generate one
  Future<String?> _getVideoThumbnailPath(String videoPath) async {
    try {
      // For now, videos from image_picker are temporary files, not photo library references
      // So we can't use PhotoLibraryService.getPhotoThumbnail for them
      // TODO: Generate video thumbnails when video is first selected using video_player or platform channels
      
      // Check if this is a photo library video (starts with ph://)
      if (videoPath.startsWith('ph://')) {
        // Try to get thumbnail using PhotoLibraryService
        final thumbnailPath = await PhotoLibraryService.getPhotoThumbnail(
          videoPath,
          size: 200,
        );
        if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
          return thumbnailPath;
        }
      }
      
      // For temporary video files from image_picker, we'd need to generate thumbnails
      // This is not yet implemented - will show placeholder for now
      return null;
    } catch (e) {
      print('DEBUG: Error getting video thumbnail: $e');
      return null;
    }
  }

  /// Extract photo/video identifier from filename (for photos:// scheme)
  String? _extractPhotoIdFromFileName(String fileName) {
    // Try to extract identifier from filename patterns like:
    // image_picker_45FE5AF3-DE4A-43B8-A7A0-E3219BFC36D8-19957-000003EB1F39CDE7IMG_5364.mov
    // Look for UUID-like patterns or photo identifiers
    try {
      // Pattern 1: Extract UUID from image_picker filenames
      final uuidPattern = RegExp(r'([A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12})');
      final uuidMatch = uuidPattern.firstMatch(fileName);
      if (uuidMatch != null) {
        return uuidMatch.group(1);
      }

      // Pattern 2: Extract from IMG_ or VID_ patterns
      final imgPattern = RegExp(r'(IMG|VID)_([A-Z0-9]+)');
      final imgMatch = imgPattern.firstMatch(fileName);
      if (imgMatch != null) {
        return imgMatch.group(2);
      }

      // Pattern 3: Try to use the filename without extension as identifier
      final nameWithoutExt = fileName.split('.').first;
      if (nameWithoutExt.isNotEmpty) {
        return nameWithoutExt;
      }
    } catch (e) {
      print('DEBUG: Error extracting photo ID from filename: $e');
    }
    return null;
  }

  /// Show context menu for a video (long-press)
  void _showVideoContextMenu(VideoAttachment video, int videoIndex) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play Video'),
              onTap: () {
                Navigator.of(context).pop();
                _playVideo(video.videoPath);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('Delete Video', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteSingleVideo(videoIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Delete a single video
  void _deleteSingleVideo(int videoIndex) {
    if (videoIndex >= _entryState.attachments.length) return;
    if (_entryState.attachments[videoIndex] is! VideoAttachment) return;
    
    setState(() {
      _entryState.attachments.removeAt(videoIndex);
      _selectedPhotoIndices.remove(videoIndex);
    });
    
    // Update draft if exists
    if (_currentDraftId != null && (!widget.isViewOnly || _isEditMode)) {
      final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
      final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
      _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Build a clean list of photo references (no thumbnails)
  Widget _buildPhotoThumbnailGrid(List<PhotoAttachment> photos, ThemeData theme) {
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
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Photos (${photos.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show photos as a grid wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: photos.map((photo) => _buildPhotoThumbnailCard(photo, theme)).toList(),
          ),
        ],
      ),
    );
  }

  /// Generate SHA-256 hash for photo linking
  Future<String?> _generatePhotoHash(String imagePath) async {
    try {
      // For photo library IDs, we need to load the actual file first
      if (imagePath.startsWith('ph://')) {
        final actualPath = await PhotoLibraryService.loadPhotoFromLibrary(imagePath);
        if (actualPath == null) return null;
        imagePath = actualPath;
      }
      
      // Generate SHA-256 hash of the file
      final file = File(imagePath);
      if (!await file.exists()) return null;
      
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Error generating photo hash: $e');
      return null;
    }
  }


  /// Build individual photo thumbnail card for grid display
  Widget _buildPhotoThumbnailCard(PhotoAttachment photo, ThemeData theme) {
    // Find the index of this photo in the attachments list
    final photoIndex = _entryState.attachments.indexOf(photo);
    final isSelected = _selectedPhotoIndices.contains(photoIndex);
    
    return GestureDetector(
      onTap: () {
        if (_isPhotoSelectionMode) {
          _togglePhotoSelection(photoIndex);
        } else {
          _openPhotoInGallery(photo.imagePath);
        }
      },
      onLongPress: () {
        // Show context menu on long press for quick deletion
        _showPhotoContextMenu(photo, photoIndex);
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Image.file(
                    File(photo.imagePath),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image, color: theme.colorScheme.error),
                      );
                    },
                  ),
                ),
                if (photo.altText != null && photo.altText!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      photo.altText!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            // Selection checkbox overlay
            if (_isPhotoSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.surface.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      )
                    : null,
                ),
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

  Widget _buildPhotoThumbnail(String imagePath) {
    // Check if this is a photo library ID (starts with "ph://") or a file path
    final isPhotoLibraryId = imagePath.startsWith('ph://');
    print('🔍 DEBUG _buildPhotoThumbnail: imagePath=$imagePath, isPhotoLibraryId=$isPhotoLibraryId');

    if (isPhotoLibraryId) {
      // Load thumbnail from photo library
      return FutureBuilder<String?>(
        future: PhotoLibraryService.getPhotoThumbnail(imagePath, size: 80),
        builder: (context, snapshot) {
          print('🔍 DEBUG FutureBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, data=${snapshot.data}, error=${snapshot.error}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            print('🔍 DEBUG: Loading thumbnail for $imagePath...');
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (snapshot.hasError || (snapshot.connectionState == ConnectionState.done && snapshot.data == null)) {
            print('🔍 DEBUG: Thumbnail loading failed for $imagePath - error: ${snapshot.error}, data: ${snapshot.data}');
            // Photo library reference is broken or inaccessible
            final errorMessage = snapshot.hasError 
                ? 'Photo unavailable'
                : 'Photo not found';
            print('🚫 Photo library access failed for $imagePath: ${snapshot.error}');
            print('📋 This photo may have been deleted from the device photo library');
            
            return GestureDetector(
              onTap: () => _showBrokenPhotoOptions(imagePath),
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      errorMessage,
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to remove',
                      style: TextStyle(
                        fontSize: 8,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            print('✅ DEBUG: Successfully loaded thumbnail from: ${snapshot.data}');
            return Image.file(
              File(snapshot.data!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('🚫 DEBUG: Image.file error for ${snapshot.data}: $error');
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.photo,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                );
              },
            );
          }

          // Fallback for photo library errors
          print('🚫 DEBUG: No data received from getPhotoThumbnail for $imagePath');
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Photo unavailable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Load from file path (temporary files)
      print('🔍 DEBUG: Loading image directly from file: $imagePath');
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('🚫 DEBUG: File image loading error for $imagePath: $error');
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'File not found',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }


  void _openPhotoInGallery(String imagePath) async {
    try {
      // Get all photo attachments from entry state
      final photoAttachments = _entryState.attachments
          .whereType<PhotoAttachment>()
          .toList();
      
      if (photoAttachments.isEmpty) {
        // Fallback: if no attachments found, show single photo
        String actualImagePath = imagePath;
        
        // If this is a photo library ID, load the full resolution image
        if (imagePath.startsWith('ph://')) {
          final fullImagePath = await PhotoLibraryService.loadPhotoFromLibrary(imagePath);
          if (fullImagePath == null) {
            throw Exception('Failed to load photo from photo library');
          }
          actualImagePath = fullImagePath;
        }
        
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenPhotoViewer.single(
              imagePath: actualImagePath,
              analysisText: _getPhotoAnalysisText(imagePath),
            ),
          ),
        );
        return;
      }
      
      // Normalize the input imagePath for comparison (remove file:// prefix if present)
      String normalizedInputPath = imagePath.replaceFirst('file://', '');
      
      // Find the index of the current photo by comparing paths (handle both original and resolved paths)
      int currentIndex = 0;
      for (int i = 0; i < photoAttachments.length; i++) {
        String attachmentPath = photoAttachments[i].imagePath;
        String normalizedAttachmentPath = attachmentPath.replaceFirst('file://', '');
        
        // Match by exact path or normalized path
        if (photoAttachments[i].imagePath == imagePath || 
            normalizedAttachmentPath == normalizedInputPath) {
          currentIndex = i;
          break;
        }
      }
      
      // Build list of PhotoData objects with resolved paths
      final List<PhotoData> photos = [];
      for (final attachment in photoAttachments) {
        String actualImagePath = attachment.imagePath;
        
        // If this is a photo library ID, load the full resolution image
        if (attachment.imagePath.startsWith('ph://')) {
          final fullImagePath = await PhotoLibraryService.loadPhotoFromLibrary(attachment.imagePath);
          if (fullImagePath != null) {
            actualImagePath = fullImagePath;
          }
        } else {
          // For file paths, normalize them (remove file:// prefix)
          actualImagePath = attachment.imagePath.replaceFirst('file://', '');
        }
        
        // Safely get analysis text - handle errors gracefully
        String? analysisText;
        try {
          analysisText = _getPhotoAnalysisText(attachment.imagePath);
        } catch (e) {
          debugPrint('Warning: Could not get analysis text for ${attachment.imagePath}: $e');
          // Use altText as fallback if available
          analysisText = attachment.altText;
        }
        
        photos.add(PhotoData(
          imagePath: actualImagePath,
          analysisText: analysisText,
        ));
      }
      
      // Open full-screen photo viewer with gallery support
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenPhotoViewer(
            photos: photos,
            initialIndex: currentIndex,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening photo viewer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open photo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Show dialog when photo library permissions are permanently denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Photo Library Access Required'),
          content: const Text(
            'This app needs access to your photo library to save photos. '
            'Please go to Settings > Privacy & Security > Photos and allow access for this app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Open app settings
                      PhotoLibraryService.openSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
          ],
        );
      },
    );
  }

  /// Get analysis text for a photo attachment
  String? _getPhotoAnalysisText(String imagePath) {
    try {
      // Normalize path for comparison (remove file:// prefix)
      String normalizedPath = imagePath.replaceFirst('file://', '');
      
      // Find the matching PhotoAttachment from entry state
      PhotoAttachment? photoAttachment;
      try {
        photoAttachment = _entryState.attachments
            .whereType<PhotoAttachment>()
            .firstWhere(
              (attachment) {
                String attachmentPath = attachment.imagePath.replaceFirst('file://', '');
                return attachment.imagePath == imagePath || attachmentPath == normalizedPath;
              },
            );
      } catch (e) {
        // If exact match fails, try fuzzy matching on filename
        final filename = imagePath.split('/').last;
        try {
          photoAttachment = _entryState.attachments
              .whereType<PhotoAttachment>()
              .firstWhere((attachment) {
                final attachmentFilename = attachment.imagePath.split('/').last;
                return attachmentFilename == filename;
              });
        } catch (e2) {
          // No matching photo found by filename either
          photoAttachment = null;
        }
      }
      
      if (photoAttachment == null) {
        return null; // Return null instead of throwing
      }

      final analysis = photoAttachment.analysisResult;
      // Use altText (3-5 keywords) instead of full summary
      final summary = photoAttachment.altText ?? 'Photo analyzed';
      final ocrText = analysis['ocr']?['fullText'] as String? ?? '';
      final objects = analysis['objects'] as List? ?? [];
      final faces = analysis['faces'] as List? ?? [];
      final labels = analysis['labels'] as List? ?? [];

      // Build analysis text
      final buffer = StringBuffer();

      if (summary.isNotEmpty) {
        buffer.writeln(summary);
        buffer.writeln();
      }

      if (ocrText.isNotEmpty) {
        buffer.writeln('Text Found:');
        buffer.writeln(ocrText);
        buffer.writeln();
      }

      if (objects.isNotEmpty) {
        buffer.writeln('Objects Detected:');
        for (final obj in objects.take(5)) {
          final label = obj['label'] as String? ?? 'Unknown';
          final confidence = obj['confidence'] as double? ?? 0.0;
          buffer.writeln('• $label (${(confidence * 100).toStringAsFixed(0)}%)');
        }
        buffer.writeln();
      }

      if (faces.isNotEmpty) {
        buffer.writeln('Faces: ${faces.length} detected');
        buffer.writeln();
      }

      if (labels.isNotEmpty) {
        buffer.writeln('Scene:');
        for (final label in labels.take(3)) {
          final labelText = label['label'] as String? ?? 'Unknown';
          final confidence = label['confidence'] as double? ?? 0.0;
          buffer.writeln('• $labelText (${(confidence * 100).toStringAsFixed(0)}%)');
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      debugPrint('Error getting photo analysis text: $e');
      return null;
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
              textCapitalization: TextCapitalization.words,
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

  /// Select date for metadata editing
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _editableDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _editableDate) {
      setState(() {
        _editableDate = picked;
        _hasBeenModified = true;
      });
    }
  }

  /// Select time for metadata editing
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _editableTime ?? TimeOfDay.now(),
    );
    
    if (picked != null && picked != _editableTime) {
      setState(() {
        _editableTime = picked;
        _hasBeenModified = true;
      });
    }
  }

  /// Get current location using GPS
  Future<void> _getCurrentLocation() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationPermissionDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Dismiss loading indicator
      if (mounted) Navigator.of(context).pop();

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String location = _formatLocation(place);
        
        setState(() {
          _editableLocation = location;
          _locationController.text = location;
          _hasBeenModified = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location set: $location'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss loading indicator if still showing
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Format location from placemark
  String _formatLocation(Placemark place) {
    List<String> parts = [];
    
    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }
    
    return parts.join(', ');
  }

  /// Show location permission dialog
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location permission to automatically set your current location. '
          'You can also manually enter your location.',
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

  /// Show location picker dialog
  Future<void> _showLocationPicker() async {
    await showDialog<String>(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLocation: _editableLocation,
        onLocationSelected: (location) {
          setState(() {
            _editableLocation = location;
            _locationController.text = location;
            _hasBeenModified = true;
          });
        },
      ),
    );
  }

  void _toggleKeywordsDiscovered() {
    setState(() {
      _showKeywordsDiscovered = !_showKeywordsDiscovered;
    });
  }


  void _dismissLumaraBox() {
    setState(() {
      _showLumaraBox = false;
    });
  }

  /// Build content view with inline thumbnails for view-only mode
  Widget _buildContentView(ThemeData theme) {
    // In view-only mode, just show the text content
    // Photos are displayed separately via _buildPhotoGallerySection -> _buildPhotoThumbnailGrid
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _entryState.text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAITextField(ThemeData theme) {
    final isReadOnly = widget.isViewOnly && !_isEditMode;
    
    if (isReadOnly) {
      // In view-only mode, show content with inline thumbnails
      return _buildContentView(theme);
    }
    
    // In edit mode, show regular text field
    return TextField(
      controller: _textController,
      onChanged: _onTextChanged,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: Colors.white,
        fontSize: 16,
        height: 1.5,
      ),
      cursorColor: Colors.white,
      cursorWidth: 2.0,
      cursorHeight: 20.0,
      decoration: InputDecoration(
        hintText: 'What\'s on your mind right now?',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: Colors.white.withOpacity(0.5),
          fontSize: 16,
          height: 1.5,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
      ),
      textInputAction: TextInputAction.newline,
    );
  }

  /// Build journal context from loaded entries for reflection
  Future<String> _buildJournalContext(List<JournalEntry> loadedEntries, {String? query, String? originalEntryText}) async {
    final buffer = StringBuffer();
    final Set<String> addedEntryIds = {}; // Track added entries to avoid duplicates
    
    // Add current entry text with date information
    // CRITICAL: When originalEntryText is provided, use it instead of current text
    // This ensures we only include text that appears ABOVE the current block position
    // (not text written after blocks, which would be chronologically incorrect)
    final currentEntryText = originalEntryText ?? _textController.text;
    buffer.writeln('=== CURRENT ENTRY (LATEST - YOU ARE EDITING THIS NOW) ===');
    // Include date if available (from existing entry or editable date)
    if (widget.existingEntry != null) {
      final dateStr = _formatDateForContext(widget.existingEntry!.createdAt);
      buffer.writeln('Date: $dateStr (LATEST ENTRY)');
    } else if (_editableDate != null) {
      final dateStr = _formatDateForContext(_editableDate!);
      buffer.writeln('Date: $dateStr (LATEST ENTRY)');
    } else {
      buffer.writeln('Date: ${_formatDateForContext(DateTime.now())} (LATEST ENTRY - BEING WRITTEN NOW)');
    }
    buffer.writeln('');
    buffer.writeln(currentEntryText);
    buffer.writeln('=== END CURRENT ENTRY ===');
    buffer.writeln('');
    
    // If we have a query and memory service, use semantic search
    // Use _textController.text as query source (most up-to-date text)
    final searchQuery = query ?? _textController.text;
    if (searchQuery.isNotEmpty && _memoryService != null) {
      try {
        final settingsService = LumaraReflectionSettingsService.instance;
        final similarityThreshold = await settingsService.getSimilarityThreshold();
        final lookbackYears = await settingsService.getEffectiveLookbackYears();
        final maxMatches = await settingsService.getEffectiveMaxMatches();
        final therapeuticEnabled = await settingsService.isTherapeuticPresenceEnabled();
        final therapeuticDepthLevel = therapeuticEnabled 
            ? await settingsService.getTherapeuticDepthLevel() 
            : null;
        final crossModalEnabled = await settingsService.isCrossModalEnabled();
        
        print('LUMARA Journal: Searching for relevant entries with query: "$searchQuery"');
        print('LUMARA Journal: Settings - threshold: $similarityThreshold, lookback: $lookbackYears years, maxMatches: $maxMatches');
        
        final memoryResult = await _memoryService!.retrieveMemories(
          query: searchQuery,
          domains: [MemoryDomain.personal, MemoryDomain.creative, MemoryDomain.learning],
          limit: maxMatches,
          similarityThreshold: similarityThreshold,
          lookbackYears: lookbackYears,
          maxMatches: maxMatches,
          therapeuticDepthLevel: therapeuticDepthLevel,
          crossModalEnabled: crossModalEnabled,
        );
        
        print('LUMARA Journal: Found ${memoryResult.nodes.length} semantically relevant nodes');
        
        // Extract entry IDs from memory nodes and fetch full content
        if (memoryResult.nodes.isNotEmpty) {
          buffer.writeln('Semantically similar journal history:');
          for (final node in memoryResult.nodes) {
            // Try to extract entry ID from node
            String? entryId;
            
            if (node.data.containsKey('original_entry_id')) {
              entryId = node.data['original_entry_id'] as String?;
            } else if (node.id.startsWith('entry:')) {
              entryId = node.id.replaceFirst('entry:', '');
            }
            
            // If we found an entry ID, try to get the full entry
            if (entryId != null && !addedEntryIds.contains(entryId)) {
              try {
                final allEntries = await _journalRepository.getAllJournalEntries();
                final entry = allEntries.firstWhere(
                  (e) => e.id == entryId,
                  orElse: () => allEntries.first,
                );
                
                if (entry.content.isNotEmpty) {
                  // Include date to help LUMARA understand entry chronology
                  final dateStr = _formatDateForContext(entry.createdAt);
                  buffer.writeln('Date: $dateStr (OLDER ENTRY)');
                  buffer.writeln(entry.content);
                  buffer.writeln('---');
                  addedEntryIds.add(entryId);
                }
              } catch (e) {
                // If entry not found, use node narrative as fallback
                if (node.narrative.isNotEmpty && !addedEntryIds.contains(node.id)) {
                  buffer.writeln(node.narrative);
                  buffer.writeln('---');
                  addedEntryIds.add(node.id);
                }
              }
            } else if (node.narrative.isNotEmpty && !addedEntryIds.contains(node.id)) {
              // Use node narrative directly if no entry ID found
              buffer.writeln(node.narrative);
              buffer.writeln('---');
              addedEntryIds.add(node.id);
            }
          }
        }
      } catch (e) {
        print('LUMARA Journal: Error in semantic search: $e');
        // Fall through to use recent entries
      }
    }
    
    // Also include recent entries from loaded entries for context continuity
    if (loadedEntries.isNotEmpty) {
      buffer.writeln('Recent journal history:');
      int recentCount = 0;
      for (final entry in loadedEntries) {
        if (!addedEntryIds.contains(entry.id) && recentCount < 10) {
          if (entry.content.isNotEmpty) {
            // Include date to help LUMARA understand entry chronology
            final dateStr = _formatDateForContext(entry.createdAt);
            buffer.writeln('Date: $dateStr (OLDER ENTRY)');
            buffer.writeln(entry.content);
            buffer.writeln('---');
            addedEntryIds.add(entry.id);
            recentCount++;
          }
        }
      }
    }
    
    return buffer.toString().trim();
  }

  /// Format date for LUMARA context (human-readable format)
  String _formatDateForContext(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    final daysDiff = today.difference(entryDate).inDays;
    
    if (daysDiff == 0) {
      return 'Today (${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')})';
    } else if (daysDiff == 1) {
      return 'Yesterday (${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')})';
    } else if (daysDiff < 7) {
      return '$daysDiff days ago (${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')})';
    } else if (daysDiff < 30) {
      final weeks = (daysDiff / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago (${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')})';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// Build rich context including mood, phase, chrono profile, chats, and media
  /// [currentBlockIndex] is optional - if provided, includes user comments from previous blocks
  Future<Map<String, dynamic>> _buildRichContext(
    List<JournalEntry> loadedEntries,
    UserProfile? userProfile, {
    int? currentBlockIndex,
  }) async {
    final context = <String, dynamic>{};
    
    // Build entry text from loaded journal entries
    // CRITICAL: When currentBlockIndex is provided, use original entry text (before any blocks)
    // This ensures we only include text that appears ABOVE the current block position
    // Text written after blocks should NOT be included (chronologically incorrect)
    final entryTextForContext = (currentBlockIndex != null && currentBlockIndex > 0 && _originalEntryTextBeforeBlocks != null)
        ? _originalEntryTextBeforeBlocks!
        : _textController.text;
    
    String baseEntryText = await _buildJournalContext(
      loadedEntries, 
      query: entryTextForContext,
      originalEntryText: (currentBlockIndex != null && currentBlockIndex > 0 && _originalEntryTextBeforeBlocks != null)
          ? _originalEntryTextBeforeBlocks!
          : null,
    );
    
    // Include LUMARA responses and user comments from previous blocks if currentBlockIndex is provided
    // CRITICAL: Only include blocks that appear ABOVE the current block (index < currentBlockIndex)
    // This ensures chronological order - LUMARA only sees what came before it
    if (currentBlockIndex != null && currentBlockIndex > 0 && _entryState.blocks.isNotEmpty) {
      final userCommentsBuffer = StringBuffer();
      
      // Calculate sliding weight based on number of blocks
      // More blocks = higher weight for user responses
      final totalBlocks = _entryState.blocks.length;
      final blocksWithUserComments = _entryState.blocks.where((b) => 
        b.userComment != null && b.userComment!.trim().isNotEmpty
      ).length;
      
      // Weight increases from 0.5 (1 block) to 1.0 (5+ blocks)
      final conversationWeight = (0.5 + (totalBlocks * 0.1)).clamp(0.5, 1.0);
      final userResponseWeight = (0.6 + (blocksWithUserComments * 0.08)).clamp(0.6, 1.0);
      
      userCommentsBuffer.writeln('\n\n=== CONTENT ABOVE THIS LUMARA RESPONSE (CHRONOLOGICAL ORDER - HIGH PRIORITY) ===');
      userCommentsBuffer.writeln('This LUMARA response is at position ${currentBlockIndex + 1} in the entry.');
      userCommentsBuffer.writeln('Below is ONLY the content that appears ABOVE this position (text and previous LUMARA responses).');
      userCommentsBuffer.writeln('Content written BELOW this position is NOT included (chronologically comes after).');
      userCommentsBuffer.writeln('Weight: ${conversationWeight.toStringAsFixed(2)}, User response weight: ${userResponseWeight.toStringAsFixed(2)}');
      userCommentsBuffer.writeln('');
      
      // CRITICAL: Only include blocks that appear ABOVE the current block (chronologically before)
      // Blocks with index < currentBlockIndex are above, blocks with index >= currentBlockIndex are below
      for (int i = 0; i < currentBlockIndex && i < _entryState.blocks.length; i++) {
        final block = _entryState.blocks[i];
        
        // Always include LUMARA's response from above (high weight)
        if (block.content.isNotEmpty) {
          userCommentsBuffer.writeln('\n[LUMARA Response ${i + 1} - ABOVE THIS POSITION]:');
          userCommentsBuffer.writeln(block.content);
        }
        
        // Include user comment/question from above with emphasis based on weight
        if (block.userComment != null && block.userComment!.trim().isNotEmpty) {
          userCommentsBuffer.writeln('\n[USER Response ${i + 1} - ABOVE THIS POSITION - HIGH PRIORITY (Weight: ${userResponseWeight.toStringAsFixed(2)})]:');
          userCommentsBuffer.writeln(block.userComment);
          userCommentsBuffer.writeln('(This user response is important - reference it in your answer)');
        }
        
        userCommentsBuffer.writeln('---');
      }
      
      // Also include the current block's user comment if it exists (user just typed it)
      if (currentBlockIndex < _entryState.blocks.length) {
        final currentBlock = _entryState.blocks[currentBlockIndex];
        if (currentBlock.userComment != null && currentBlock.userComment!.trim().isNotEmpty) {
          userCommentsBuffer.writeln('\n[CURRENT USER QUESTION/COMMENT - HIGHEST PRIORITY]:');
          userCommentsBuffer.writeln(currentBlock.userComment);
          userCommentsBuffer.writeln('(This is the most recent user input - address it directly)');
          userCommentsBuffer.writeln('---');
        }
      }
      
      // Prepend conversation history to baseEntryText with high priority marking
      // CRITICAL: The original entry text below is ONLY the text that appears ABOVE this block position
      // Text written after this block position is NOT included (chronologically incorrect)
      baseEntryText = '''${userCommentsBuffer.toString()}

=== ORIGINAL JOURNAL ENTRY TEXT (ABOVE THIS POSITION ONLY - Reference - Lower Priority) ===
$baseEntryText

=== CRITICAL INSTRUCTIONS - CHRONOLOGICAL ORDER ===
1. PRIORITIZE the conversation history above (CONTENT ABOVE THIS POSITION) - it has HIGH WEIGHT
2. The original journal entry text shown is ONLY text that appears ABOVE your response position
3. You are responding at position ${currentBlockIndex + 1} - you can ONLY see content from positions 1-${currentBlockIndex}
4. Content written BELOW your position (after you) is NOT visible to you - do not reference it
5. User responses in the conversation have INCREASED WEIGHT as more responses accumulate
6. Reference past entries (below) with LOWER WEIGHT - they are for context only
7. Focus on the user's most recent questions/comments in the conversation history ABOVE you
8. Build on the LUMARA responses that appear ABOVE you - reference and continue the conversation thread''';
      
      print('Journal: Included ${currentBlockIndex} previous LUMARA blocks with sliding weights (conversation: ${conversationWeight.toStringAsFixed(2)}, user responses: ${userResponseWeight.toStringAsFixed(2)})');
    }
    
    context['entryText'] = baseEntryText;
    
    // Get mood/emotion from current entry or widget
    String? mood;
    String? emotion;
    if (widget.selectedEmotion != null) {
      emotion = widget.selectedEmotion;
    } else if (widget.existingEntry != null) {
      emotion = widget.existingEntry!.emotion;
      mood = widget.existingEntry!.mood;
    }
    context['mood'] = mood;
    context['emotion'] = emotion;
    
    // Compute circadian context from all entries
    final circadianService = CircadianProfileService();
    final allEntries = await _journalRepository.getAllJournalEntries();
    final chronoContext = await circadianService.compute(allEntries);
    context['chronoContext'] = {
      'window': chronoContext.window,
      'chronotype': chronoContext.chronotype,
      'rhythmScore': chronoContext.rhythmScore,
      'isFragmented': chronoContext.isFragmented,
      'isCoherent': chronoContext.isCoherent,
    };
    
    // Gather recent chat sessions and messages
    String? chatContext;
    try {
      final chatRepo = ChatRepoImpl.instance;
      await chatRepo.initialize();
      final recentSessions = await chatRepo.listActive();
      
      if (recentSessions.isNotEmpty) {
        final chatBuffer = StringBuffer();
        chatBuffer.writeln('Recent chat sessions:');
        for (final session in recentSessions.take(5)) {
          final messages = await chatRepo.getMessages(session.id, lazy: false);
          chatBuffer.writeln('Session: "${session.subject}" (${session.createdAt.toString().split(' ')[0]}):');
          for (final msg in messages.take(3)) {
            chatBuffer.writeln('  ${msg.role}: ${msg.content.substring(0, msg.content.length > 100 ? 100 : msg.content.length)}${msg.content.length > 100 ? '...' : ''}');
          }
          chatBuffer.writeln('---');
        }
        chatContext = chatBuffer.toString().trim();
      }
    } catch (e) {
      print('LUMARA: Error gathering chat context: $e');
    }
    context['chatContext'] = chatContext;
    
    // Gather media information from current entry
    String? mediaContext;
    final mediaItems = <MediaItem>[];
    
    // From existing entry media
    if (widget.existingEntry != null && widget.existingEntry!.media.isNotEmpty) {
      mediaItems.addAll(widget.existingEntry!.media);
    }
    
    // From current state attachments - convert to MediaItems
    if (_entryState.attachments.isNotEmpty) {
      final convertedMedia = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
      mediaItems.addAll(convertedMedia);
    }
    
    if (mediaItems.isNotEmpty) {
      final mediaBuffer = StringBuffer();
      mediaBuffer.writeln('Media in this entry:');
      for (final media in mediaItems) {
        mediaBuffer.write('  - ${media.type.name}');
        if (media.altText != null && media.altText!.isNotEmpty) {
          mediaBuffer.write(': ${media.altText!.substring(0, media.altText!.length > 80 ? 80 : media.altText!.length)}');
        }
        if (media.ocrText != null && media.ocrText!.isNotEmpty) {
          mediaBuffer.write(' [OCR: ${media.ocrText!.substring(0, media.ocrText!.length > 60 ? 60 : media.ocrText!.length)}...]');
        }
        if (media.transcript != null && media.transcript!.isNotEmpty) {
          mediaBuffer.write(' [Transcript: ${media.transcript!.substring(0, media.transcript!.length > 60 ? 60 : media.transcript!.length)}...]');
        }
        mediaBuffer.writeln();
      }
      mediaContext = mediaBuffer.toString().trim();
    }
    context['mediaContext'] = mediaContext;
    
    return context;
  }

  /// Build phase hint JSON for ArcLLM
  String? _buildPhaseHintJson() {
    final phase = _entryState.phase ?? 'Discovery';
    return jsonEncode({
      'current_phase': phase,
      'current_phase_source': 'entry_state',
      'confidence': 1.0,
    });
  }

  /// Build keywords JSON for ArcLLM
  String? _buildKeywordsJson() {
    if (_manualKeywords.isEmpty) return null;
    final uniqueKeywords = _manualKeywords.take(10).toSet().toList();
    return jsonEncode({'keywords': uniqueKeywords});
  }

  void _insertAISuggestion(String suggestion) {
    // Add as inline reflection block instead of inserting into text
    final block = InlineBlock(
      type: 'reflection',
      intent: 'reflect',
      content: suggestion,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      phase: _entryState.phase,
    );
    
    final newBlockIndex = _entryState.blocks.length;
    setState(() {
      _entryState.blocks.add(block);
    });
    
    // Create controller for the new block
    final controller = TextEditingController();
    _continuationControllers[newBlockIndex] = controller;
    controller.addListener(() {
      // Save comment to block when text changes
      if (newBlockIndex < _entryState.blocks.length) {
        setState(() {
          _entryState.blocks[newBlockIndex] = _entryState.blocks[newBlockIndex].copyWith(
            userComment: controller.text.trim().isEmpty ? null : controller.text.trim(),
          );
          _hasBeenModified = true;
        });
        // Auto-save draft with updated blocks
        _updateDraftContent(_textController.text);
      }
    });
    
    // Auto-save the updated content
    _updateDraftContent(_textController.text);
    
    _analytics.logLumaraEvent('inline_reflection_inserted', data: {'intent': 'reflect'});
    
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
    
    // Set loading state
    setState(() {
      _lumaraLoadingStates[index] = true;
      _lumaraLoadingMessages[index] = 'Regenerating reflection...';
    });

    try {
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      final richContext = await _buildRichContext(loadedEntries, null, currentBlockIndex: index);
      final entryText = richContext['entryText'] ?? _entryState.text;
      final phaseHint = _entryState.phase;
      
      // Use EnhancedLumaraApi v2.3 with regenerate option
      final result = await _enhancedLumaraApi.generatePromptedReflection(
        entryText: entryText,
        intent: 'journal',
        phase: phaseHint,
        userId: null,
        mood: richContext['mood'],
        chronoContext: richContext['chronoContext'],
        chatContext: richContext['chatContext'],
        mediaContext: richContext['mediaContext'],
        entryId: _currentEntryId, // For per-entry usage limit tracking
        options: lumara_models.LumaraReflectionOptions(
          regenerate: true,
          toneMode: lumara_models.ToneMode.normal,
          preferQuestionExpansion: true, // More Depth is now default
        ),
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _lumaraLoadingMessages[index] = message;
            });
          }
        },
      );

      // Extract just the reflection text (remove "✨ Reflection\n\n" prefix if present)
      String reflectionText = result.reflection;
      if (reflectionText.startsWith('✨ Reflection\n\n')) {
        reflectionText = reflectionText.substring('✨ Reflection\n\n'.length);
      }

      // Enrich attribution traces with actual journal entry content
      List<AttributionTrace>? attributionTraces = result.attributionTraces;
      if (attributionTraces.isNotEmpty) {
        attributionTraces = await _enrichAttributionTraces(attributionTraces);
      }

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: reflectionText,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
          attributionTraces: attributionTraces,
          userComment: block.userComment, // Preserve user comment when regenerating
        );
        // Clear loading state
        _lumaraLoadingStates[index] = false;
        _lumaraLoadingMessages[index] = null;
      });
      
      _analytics.logLumaraEvent('inline_reflection_regenerated');
    } catch (e) {
      _analytics.log('lumara_regenerate_error', {'error': e.toString()});
      
      setState(() {
        // Clear loading state on error
        _lumaraLoadingStates[index] = false;
        _lumaraLoadingMessages[index] = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating reflection: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _onSoftenReflection(int index) async {
    final block = _entryState.blocks[index];
    
    // Set loading state
    setState(() {
      _lumaraLoadingStates[index] = true;
      _lumaraLoadingMessages[index] = 'Softening the tone...';
    });

    try {
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      final richContext = await _buildRichContext(loadedEntries, null, currentBlockIndex: index);
      final entryText = richContext['entryText'] ?? _entryState.text;
      final phaseHint = _entryState.phase;
      
      // Use EnhancedLumaraApi v2.3 with soft tone option
      final result = await _enhancedLumaraApi.generatePromptedReflection(
        entryText: entryText,
        intent: 'journal',
        phase: phaseHint,
        userId: null,
        mood: richContext['mood'],
        chronoContext: richContext['chronoContext'],
        chatContext: richContext['chatContext'],
        mediaContext: richContext['mediaContext'],
        entryId: _currentEntryId, // For per-entry usage limit tracking
        options: lumara_models.LumaraReflectionOptions(
          toneMode: lumara_models.ToneMode.soft,
          regenerate: false,
          preferQuestionExpansion: true, // More Depth is now default
        ),
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _lumaraLoadingMessages[index] = message;
            });
          }
        },
      );

      // Extract just the reflection text (remove "✨ Reflection\n\n" prefix if present)
      String reflectionText = result.reflection;
      if (reflectionText.startsWith('✨ Reflection\n\n')) {
        reflectionText = reflectionText.substring('✨ Reflection\n\n'.length);
      }

      // Enrich attribution traces with actual journal entry content
      List<AttributionTrace>? attributionTraces = result.attributionTraces;
      if (attributionTraces.isNotEmpty) {
        attributionTraces = await _enrichAttributionTraces(attributionTraces);
      }

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: reflectionText,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
          attributionTraces: attributionTraces,
          userComment: block.userComment, // Preserve user comment when softening
        );
        // Clear loading state
        _lumaraLoadingStates[index] = false;
        _lumaraLoadingMessages[index] = null;
      });
      
      _analytics.logLumaraEvent('inline_reflection_softened');
    } catch (e) {
      _analytics.log('lumara_soften_error', {'error': e.toString()});
      
      setState(() {
        // Clear loading state on error
        _lumaraLoadingStates[index] = false;
        _lumaraLoadingMessages[index] = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error softening reflection: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _onMoreDepthReflection(int index) async {
    final block = _entryState.blocks[index];
    
    // Set loading state
    setState(() {
      _lumaraLoadingStates[index] = true;
      _lumaraLoadingMessages[index] = 'Going deeper into reflection...';
    });

    try {
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      final richContext = await _buildRichContext(loadedEntries, null, currentBlockIndex: index);
      final entryText = richContext['entryText'] ?? _entryState.text;
      final phaseHint = _entryState.phase;
      
      // Use EnhancedLumaraApi v2.3 with More Depth option
      final result = await _enhancedLumaraApi.generatePromptedReflection(
        entryText: entryText,
        intent: 'journal',
        phase: phaseHint,
        userId: null,
        mood: richContext['mood'],
        chronoContext: richContext['chronoContext'],
        chatContext: richContext['chatContext'],
        mediaContext: richContext['mediaContext'],
        entryId: _currentEntryId, // For per-entry usage limit tracking
        options: lumara_models.LumaraReflectionOptions(
          preferQuestionExpansion: true, // More depth
          toneMode: lumara_models.ToneMode.normal,
          regenerate: false,
        ),
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _lumaraLoadingMessages[index] = message;
            });
          }
        },
      );

      // Extract just the reflection text (remove "✨ Reflection\n\n" prefix if present)
      String reflectionText = result.reflection;
      if (reflectionText.startsWith('✨ Reflection\n\n')) {
        reflectionText = reflectionText.substring('✨ Reflection\n\n'.length);
      }

      // Enrich attribution traces with actual journal entry content
      List<AttributionTrace>? attributionTraces = result.attributionTraces;
      if (attributionTraces.isNotEmpty) {
        attributionTraces = await _enrichAttributionTraces(attributionTraces);
      }

      setState(() {
        _entryState.blocks[index] = InlineBlock(
          type: block.type,
          intent: block.intent,
          content: reflectionText,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          phase: block.phase,
          attributionTraces: attributionTraces,
          userComment: block.userComment, // Preserve user comment when adding depth
        );
        // Clear loading state
        _lumaraLoadingStates[index] = false;
        _lumaraLoadingMessages[index] = null;
      });
      
      _analytics.logLumaraEvent('inline_reflection_deepened');
    } catch (e) {
      _analytics.log('lumara_depth_error', {'error': e.toString()});
      
      setState(() {
        // Clear loading state on error
        _lumaraLoadingStates[index] = false;
        _lumaraLoadingMessages[index] = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deepening reflection: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onDeleteReflection(int index) {
    setState(() {
      _entryState.blocks.removeAt(index);
      
      // Clean up controller for deleted block
      final controller = _continuationControllers.remove(index);
      controller?.dispose();
      
      // Rebuild controllers map for remaining blocks
      // We need to shift indices since we removed one
      final oldControllers = Map<int, TextEditingController>.from(_continuationControllers);
      _continuationControllers.clear();
      for (final entry in oldControllers.entries) {
        if (entry.key > index) {
          // Shift index down by 1
          _continuationControllers[entry.key - 1] = entry.value;
        } else if (entry.key < index) {
          // Keep same index
          _continuationControllers[entry.key] = entry.value;
        }
        // entry.key == index is deleted, so skip it
      }
    });
    _analytics.logLumaraEvent('inline_reflection_deleted');
  }

  void _onContinueWithLumara([int? blockIndex]) {
    _analytics.logLumaraEvent('continue_with_lumara_opened_chat');
    
    // Show LUMARA suggestion sheet for in-context integration
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LumaraSuggestionSheet(
        onSelect: (intent) async {
          // Map LumaraIntent to ConversationMode
          lumara_models.ConversationMode? conversationMode;
          switch (intent) {
            case LumaraIntent.ideas:
              conversationMode = lumara_models.ConversationMode.ideas;
              break;
            case LumaraIntent.think:
              conversationMode = lumara_models.ConversationMode.think;
              break;
            case LumaraIntent.perspective:
              conversationMode = lumara_models.ConversationMode.perspective;
              break;
            case LumaraIntent.next:
              conversationMode = lumara_models.ConversationMode.nextSteps;
              break;
            case LumaraIntent.analyze:
              conversationMode = lumara_models.ConversationMode.reflectDeeply;
              break;
          }
          await _handleLumaraContinuation(conversationMode, blockIndex);
        },
      ),
    );
  }

  Future<void> _onContinueThought(int index) async {
    await _handleLumaraContinuation(lumara_models.ConversationMode.continueThought, index);
  }

  /// Handle LUMARA continuation with conversation mode (v2.3)
  Future<void> _handleLumaraContinuation(
    lumara_models.ConversationMode? conversationMode,
    int? blockIndex,
  ) async {
    // Get loading message based on conversation mode
    String loadingMessage;
    switch (conversationMode) {
      case lumara_models.ConversationMode.ideas:
        loadingMessage = 'Generating ideas...';
        break;
      case lumara_models.ConversationMode.think:
        loadingMessage = 'Thinking this through...';
        break;
      case lumara_models.ConversationMode.perspective:
        loadingMessage = 'Offering a different perspective...';
        break;
      case lumara_models.ConversationMode.nextSteps:
        loadingMessage = 'Suggesting next steps...';
        break;
      case lumara_models.ConversationMode.reflectDeeply:
        loadingMessage = 'Reflecting more deeply...';
        break;
      default:
        loadingMessage = 'LUMARA is thinking...';
    }

    // Create placeholder block to show loading state
    final placeholderBlock = InlineBlock(
      type: 'reflection',
      intent: conversationMode?.name ?? 'reflect',
      content: '', // Empty content will be replaced
      timestamp: DateTime.now().millisecondsSinceEpoch,
      phase: _entryState.phase,
    );
    
    final newBlockIndex = _entryState.blocks.length;
    
    // Set loading state and add placeholder block
    setState(() {
      _lumaraLoadingStates[newBlockIndex] = true;
      _lumaraLoadingMessages[newBlockIndex] = loadingMessage;
      _entryState.blocks.add(placeholderBlock);
    });

    try {
      _analytics.logLumaraEvent('continuation_selected', data: {'mode': conversationMode?.name});
      
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      // Include user comments from previous blocks (blockIndex is the previous block)
      final richContext = await _buildRichContext(
        loadedEntries, 
        null, 
        currentBlockIndex: blockIndex != null ? blockIndex + 1 : newBlockIndex,
      );
      final entryText = richContext['entryText'] ?? _entryState.text;
      final phaseHint = _entryState.phase;
      
      // Use EnhancedLumaraApi v2.3 with conversation mode
      final result = await _enhancedLumaraApi.generatePromptedReflection(
        entryText: entryText,
        intent: 'journal',
        phase: phaseHint,
        userId: null,
        mood: richContext['mood'],
        chronoContext: richContext['chronoContext'],
        chatContext: richContext['chatContext'],
        mediaContext: richContext['mediaContext'],
        entryId: _currentEntryId, // For per-entry usage limit tracking
        options: lumara_models.LumaraReflectionOptions(
          conversationMode: conversationMode,
          toneMode: lumara_models.ToneMode.normal,
          regenerate: false,
          preferQuestionExpansion: conversationMode == lumara_models.ConversationMode.reflectDeeply,
        ),
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _lumaraLoadingMessages[newBlockIndex] = message;
            });
          }
        },
      );

      // Extract just the reflection text (remove "✨ Reflection\n\n" prefix if present)
      String reflectionText = result.reflection;
      if (reflectionText.startsWith('✨ Reflection\n\n')) {
        reflectionText = reflectionText.substring('✨ Reflection\n\n'.length);
      }

      // Enrich attribution traces with actual journal entry content
      List<AttributionTrace>? attributionTraces = result.attributionTraces;
      if (attributionTraces.isNotEmpty) {
        attributionTraces = await _enrichAttributionTraces(attributionTraces);
      }
      
      // Update the placeholder block with actual content
      final block = InlineBlock(
        type: 'reflection',
        intent: conversationMode?.name ?? 'reflect',
        content: reflectionText,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        attributionTraces: attributionTraces,
        phase: _entryState.phase,
      );
      
      setState(() {
        _entryState.blocks[newBlockIndex] = block;
        // Clear loading state for this block
        _lumaraLoadingStates[newBlockIndex] = false;
        _lumaraLoadingMessages[newBlockIndex] = null;
      });
      
      // Persist blocks to entry immediately if editing existing entry
      if (widget.existingEntry != null) {
        await _persistLumaraBlocksToEntry();
      }
      
      // Create controller for the new block
      final controller = TextEditingController();
      _continuationControllers[newBlockIndex] = controller;
      controller.addListener(() {
        // Save comment to block when text changes
        if (newBlockIndex < _entryState.blocks.length) {
          setState(() {
            _entryState.blocks[newBlockIndex] = _entryState.blocks[newBlockIndex].copyWith(
              userComment: controller.text.trim().isEmpty ? null : controller.text.trim(),
            );
            _hasBeenModified = true;
          });
          // Auto-save draft with updated blocks
          _updateDraftContent(_textController.text);
          // Persist blocks to entry if editing existing entry (debounced)
          if (widget.existingEntry != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (widget.existingEntry != null && mounted) {
                _persistLumaraBlocksToEntry();
              }
            });
          }
        }
      });
      
      // Auto-save the updated content
      _updateDraftContent(_textController.text);
      
      _analytics.logLumaraEvent('inline_reflection_continuation', data: {'mode': conversationMode?.name});
      
    } catch (e) {
      _analytics.log('lumara_continuation_error', {'error': e.toString()});
      
      setState(() {
        // Remove placeholder block and clear loading state on error
        if (newBlockIndex < _entryState.blocks.length) {
          _entryState.blocks.removeAt(newBlockIndex);
        }
        _lumaraLoadingStates[newBlockIndex] = false;
        _lumaraLoadingMessages[newBlockIndex] = null;
      });
      
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

  /// Map intent string to user prompt for ArcLLM
  String _mapIntentToUserPrompt(String intent) {
    switch (intent.toLowerCase()) {
      case 'ideas':
      case 'suggestideas':
        return 'Suggest some ideas';
      case 'think':
      case 'thinkthrough':
        return 'Help me think through this';
      case 'perspective':
      case 'differentperspective':
        return 'Offer a different perspective';
      case 'next':
      case 'nextsteps':
        return 'Suggest next steps';
      case 'analyze':
      case 'analyze_further':
        return 'Analyze further';
      default:
        return 'reflect';
    }
  }

  /// Map suggestion string to user prompt for ArcLLM
  String _mapSuggestionToUserPrompt(String suggestion) {
    switch (suggestion.toLowerCase()) {
      case 'suggestideas':
      case 'suggest_ideas':
      case 'ideas':
        return 'Suggest some ideas';
      case 'thinkthrough':
      case 'think_through':
      case 'think':
        return 'Help me think through this';
      case 'differentperspective':
      case 'different_perspective':
      case 'perspective':
        return 'Offer a different perspective';
      case 'nextsteps':
      case 'next_steps':
      case 'next':
        return 'Suggest next steps';
      case 'analyzefurther':
      case 'analyze_further':
      case 'analyze':
        return 'Analyze further';
      default:
        // Try to use as-is, might be a natural language prompt
        return suggestion;
    }
  }

  /// Initialize draft cache and create new draft
  /// Run deduplication on journal entries (silently in background)
  Future<void> _runDeduplication() async {
    try {
      // Run deduplication silently in background
      final deletedCount = await _journalRepository.removeDuplicateEntries();
      if (deletedCount > 0) {
        debugPrint('JournalScreen: Removed $deletedCount duplicate entries during initialization');
        // Refresh timeline if we're in a context that has it
        try {
          final timelineCubit = context.read<TimelineCubit>();
          timelineCubit.refreshEntries();
        } catch (e) {
          // Timeline cubit not available, that's okay
        }
      }
    } catch (e) {
      debugPrint('JournalScreen: Error running deduplication: $e');
      // Don't show error to user - this is a background operation
    }
  }

  Future<void> _initializeDraftCache() async {
    try {
      await _draftCache.initialize();
      
      // Skip draft creation when editing existing entries - drafts created on app lifecycle only
      // This prevents drafts from being created immediately when editing
      if (widget.existingEntry != null && (_isEditMode || !widget.isViewOnly)) {
        debugPrint('JournalScreen: Editing existing entry - no draft created initially (will create on app pause)');
        return;
      }
      
      // Only create a draft if user is actively writing/editing (not just viewing)
      if (!widget.isViewOnly || _isEditMode) {
        // Link draft to existing entry if we're editing one
        final linkedEntryId = widget.existingEntry?.id;
        
        _currentDraftId = await _draftCache.createDraft(
          initialEmotion: widget.selectedEmotion,
          initialReason: widget.selectedReason,
          initialContent: _entryState.text,
          initialMedia: widget.existingEntry?.media ?? [],
          linkedEntryId: linkedEntryId,
        );
        debugPrint('JournalScreen: Created/reused draft $_currentDraftId${linkedEntryId != null ? ' (linked to entry $linkedEntryId)' : ''}');
      } else {
        debugPrint('JournalScreen: View-only mode - no draft created');
      }
    } catch (e) {
      debugPrint('JournalScreen: Failed to initialize draft cache: $e');
    }
  }

  /// Switch from view-only mode to edit mode
  void _switchToEditMode() {
    setState(() {
      _isEditMode = true;
    });
    
    // When switching to edit mode on an existing entry, don't create draft initially
    // Draft will be created on app lifecycle events (pause/resume) or crashes
    if (widget.existingEntry != null) {
      debugPrint('JournalScreen: Switched to edit mode for existing entry - no draft created initially');
      // Just initialize the cache without creating a draft
      _draftCache.initialize();
    } else {
      // For new entries, create draft normally
      _initializeDraftCache();
    }
    
    debugPrint('JournalScreen: Switched to edit mode');
  }

  /// Update draft content with auto-save (only for app lifecycle changes)
  void _updateDraftContent(String content) {
    if (_currentDraftId == null) return;
    
    // Cancel existing timer
    _autoSaveTimer?.cancel();
    
    // Convert blocks to JSON for persistence
    final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
    
    // Update the draft content in the cache service with LUMARA blocks
    _draftCache.updateDraftContent(content, lumaraBlocks: blocksJson);
    
    // Also update media items if we have attachments
    if (_entryState.attachments.isNotEmpty) {
      final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
      _draftCache.updateDraftContentAndMedia(content, mediaItems, lumaraBlocks: blocksJson);
    } else {
      _draftCache.updateDraftContent(content, lumaraBlocks: blocksJson);
      }
    
    debugPrint('JournalScreen: Draft content updated with ${blocksJson.length} LUMARA blocks');
  }

  /// Persist LUMARA blocks to journal entry immediately
  /// This is called whenever blocks change (generation, user comments, etc.)
  Future<void> _persistLumaraBlocksToEntry() async {
    if (widget.existingEntry == null) return;
    
    try {
      // Get current blocks from entry state
      final lumaraBlocks = List<InlineBlock>.from(_entryState.blocks);
      
      // Create updated entry with current blocks
      final updatedEntry = widget.existingEntry!.copyWith(
        lumaraBlocks: lumaraBlocks,
        updatedAt: DateTime.now(),
      );
      
      // Save to database
      await _journalRepository.updateJournalEntry(updatedEntry);
      
      debugPrint('✅ JournalScreen: Saved ${lumaraBlocks.length} LUMARA blocks to entry ${widget.existingEntry!.id}');
      
      // Verify the save worked
      final savedEntry = await _journalRepository.getJournalEntryById(widget.existingEntry!.id);
      if (savedEntry != null && savedEntry.lumaraBlocks.length == lumaraBlocks.length) {
        debugPrint('✅ JournalScreen: Verified ${savedEntry.lumaraBlocks.length} blocks saved correctly');
      } else {
        debugPrint('❌ JournalScreen: WARNING - Block count mismatch after save!');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ JournalScreen: ERROR persisting LUMARA blocks: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  /// Navigate to drafts screen
  Future<void> _navigateToDrafts() async {
    try {
      // Save current draft before navigating
      if (_currentDraftId != null) {
        await _draftCache.saveCurrentDraftImmediately();
      }

      // Navigate to drafts screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DraftsScreen(),
        ),
      );

      // Refresh draft count after returning from drafts screen
      await _loadDraftCount();
    } catch (e) {
      debugPrint('JournalScreen: Error navigating to drafts: $e');
    }
  }

  /// Complete the current draft when entry is saved
  Future<void> _completeDraft() async {
    try {
      await _draftCache.completeDraft();
      _currentDraftId = null;
      // Refresh draft count after completing a draft
      await _loadDraftCount();
      debugPrint('JournalScreen: Completed draft');
    } catch (e) {
      debugPrint('JournalScreen: Failed to complete draft: $e');
    }
  }

  /// Refresh timeline after saving an entry
  Future<void> _refreshTimelineAfterSave() async {
    try {
      // Get the timeline cubit from the context
      final timelineCubit = context.read<TimelineCubit>();
      await timelineCubit.refreshEntries();
      print('DEBUG: Timeline refreshed after saving entry');
    } catch (e) {
      print('DEBUG: Failed to refresh timeline after save: $e');
    }
  }

  /// Load draft count for badge display
  Future<void> _loadDraftCount() async {
    try {
      final drafts = await _draftCache.getAllDrafts();
      setState(() {
        _draftCount = drafts.length;
      });
      debugPrint('JournalScreen: Loaded draft count: $_draftCount');
    } catch (e) {
      debugPrint('JournalScreen: Failed to load draft count: $e');
    }
  }

  // Multimodal functionality
  Future<void> _handlePhotoGallery() async {
    try {
      _analytics.logJournalEvent('photo_button_pressed');
      print('DEBUG: Requesting photo library permissions...');
      
      // Request permissions first
      final hasPermissions = await PhotoLibraryService.requestPermissions();
      if (!hasPermissions) {
        print('DEBUG: Photo library permissions denied');
        _showPermissionDeniedDialog();
        return;
      }
      
      print('DEBUG: Photo library permissions granted, opening photo picker');
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        print('DEBUG: Selected ${images.length} images');
        for (final image in images) {
          print('DEBUG: Processing image: ${image.path}');
          await _processPhotoWithEnhancedOCP(image.path);
        }
      } else {
        print('DEBUG: No images selected');
      }
    } catch (e) {
      print('DEBUG: Photo picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select photos: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Handle video selection from gallery
  Future<void> _handleVideoGallery() async {
    try {
      _analytics.logJournalEvent('video_button_pressed');
      print('DEBUG: Requesting photo library permissions for video...');
      
      // Request permissions first
      final hasPermissions = await PhotoLibraryService.requestPermissions();
      if (!hasPermissions) {
        print('DEBUG: Photo library permissions denied');
        _showPermissionDeniedDialog();
        return;
      }
      
      print('DEBUG: Photo library permissions granted, opening video picker');
      final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        print('DEBUG: Selected video: ${video.path}');
        await _processVideo(video.path);
      } else {
        print('DEBUG: No video selected');
      }
    } catch (e) {
      print('DEBUG: Video picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select video: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Process a selected video file
  Future<void> _processVideo(String videoPath) async {
    try {
      print('DEBUG: Processing video: $videoPath');
      
      // Get video file info if possible
      final videoFile = File(videoPath);
      int? sizeBytes;
      Duration? duration;
      
      if (await videoFile.exists()) {
        sizeBytes = await videoFile.length();
        print('DEBUG: Video file exists, size: $sizeBytes bytes');
        
        // Extract video duration using video_player package
        try {
          final videoController = VideoPlayerController.file(videoFile);
          await videoController.initialize();

          if (videoController.value.isInitialized) {
            duration = videoController.value.duration;
            print('DEBUG: Video duration extracted: $duration');
          } else {
            print('WARNING: VideoPlayer failed to initialize for: $videoPath');
          }

          // Clean up the controller
          await videoController.dispose();
        } catch (e) {
          print('WARNING: Failed to extract video duration: $e');
          // Duration remains null, which is acceptable for fallback behavior
        }
      } else {
        print('WARNING: Video file does not exist at path: $videoPath');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video file not found: ${videoPath.split('/').last}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Create a VideoAttachment directly
      final videoAttachment = VideoAttachment(
        type: 'video',
        videoPath: videoPath,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        videoId: DateTime.now().millisecondsSinceEpoch.toString(),
        sizeBytes: sizeBytes,
        duration: duration,
        altText: 'Video: ${videoPath.split('/').last}',
      );

      setState(() {
        _entryState.addVideoAttachment(videoAttachment);
        print('DEBUG: Video attachment added to state. Total attachments: ${_entryState.attachments.length}');
        // Count videos
        final videoCount = _entryState.attachments.whereType<VideoAttachment>().length;
        print('DEBUG: Total videos in attachments: $videoCount');
      });
      
      // Update draft if exists
      if (_currentDraftId != null) {
        final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
        final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
        await _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
        print('DEBUG: Updated draft with ${mediaItems.length} media items');
      }
      
      print('DEBUG: Video added to entry successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video added to entry (${_formatFileSize(sizeBytes ?? 0)})'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('DEBUG: Error processing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process video: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _handleCamera() async {
    try {
      _analytics.logJournalEvent('camera_button_pressed');
      print('DEBUG: Requesting photo library permissions...');
      
      // Request permissions first
      final hasPermissions = await PhotoLibraryService.requestPermissions();
      if (!hasPermissions) {
        print('DEBUG: Photo library permissions denied');
        _showPermissionDeniedDialog();
        return;
      }
      
      print('DEBUG: Photo library permissions granted, opening camera');
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        print('DEBUG: Camera captured image: ${image.path}');
        await _processPhotoWithEnhancedOCP(image.path);
      } else {
        print('DEBUG: No image captured from camera');
      }
    } catch (e) {
      print('DEBUG: Camera error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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
              _buildDetailRow('Perceptual Hash', phash.isNotEmpty && phash.length > 20 ? '${phash.substring(0, 20)}...' : phash),
              _buildDetailRow('ORB Patch Hash', orbPatch.isNotEmpty && orbPatch.length > 20 ? '${orbPatch.substring(0, 20)}...' : orbPatch),
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
        print('DEBUG: Photo analysis successful');

        // Generate alt text from analysis (3-5 keywords)
        final altText = MediaAltTextGenerator.generateAltText(result);

        // Generate unique photo ID
        final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';

        // Store the original picked path directly - no copying yet
        final photoAttachment = PhotoAttachment(
          type: 'photo_analysis',
          imagePath: imagePath, // Use original picked path
          analysisResult: result,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          altText: altText,
          photoId: photoId,
          sha256: null, // Will be generated when entry is saved
        );

        setState(() {
          _entryState.attachments.add(photoAttachment);
        });

        // Show success message with alt text
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Photo added: $altText'),
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



  Future<void> _performOCR(File imageFile) async {
    try {
      // TODO: OCR service not yet implemented
      // final extractedText = await _ocrService.extractText(imageFile);
      final extractedText = ''; // Placeholder until OCR is implemented
      if (extractedText.isNotEmpty) {
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

  /// Enrich attribution traces with actual journal entry content
  /// Replaces LUMARA response excerpts and placeholders with actual journal entry content
  Future<List<AttributionTrace>> _enrichAttributionTraces(List<AttributionTrace> traces) async {
    final enrichedTraces = <AttributionTrace>[];
    
    for (final trace in traces) {
      AttributionTrace enrichedTrace = trace;
      
      // Check if excerpt needs enrichment
      final excerpt = trace.excerpt ?? '';
      final excerptLower = excerpt.toLowerCase();
      
      // Check if excerpt is a LUMARA response or placeholder
      final isLumaraResponse = excerptLower.contains("hello! i'm lumara") ||
          excerptLower.contains("i'm lumara") ||
          excerptLower.contains("i'm your personal assistant") ||
          (excerptLower.startsWith("hello") && excerptLower.contains("lumara")) ||
          excerptLower.contains("[journal entry content") ||
          excerptLower.contains("[memory reference");
      
      if (isLumaraResponse || excerpt.isEmpty) {
        // Try to extract entry ID from node reference
        String? entryId;
        
        // Try different ID patterns
        if (trace.nodeRef.startsWith('entry:')) {
          entryId = trace.nodeRef.replaceFirst('entry:', '');
        } else if (trace.nodeRef.contains('_')) {
          final parts = trace.nodeRef.split('_');
          if (parts.length > 1) {
            entryId = parts.last;
          }
        } else {
          // Try to extract from the excerpt placeholder
          final entryIdMatch = RegExp(r'entry\s+([a-zA-Z0-9_-]+)').firstMatch(excerpt);
          if (entryIdMatch != null) {
            entryId = entryIdMatch.group(1);
          }
        }
        
        // If we found an entry ID, try to get the actual journal entry
        if (entryId != null) {
          try {
            final allEntries = await _journalRepository.getAllJournalEntries();
            JournalEntry entry;
            try {
              entry = allEntries.firstWhere((e) => e.id == entryId);
            } catch (e) {
              // If exact match not found, try partial match
              try {
                final entryIdNonNull = entryId; // We know it's not null here
                entry = allEntries.firstWhere(
                  (e) => e.id.contains(entryIdNonNull) || entryIdNonNull.contains(e.id),
                );
              } catch (e2) {
                // Fallback to first entry if no match found
                entry = allEntries.first;
              }
            }
            
            if (entry.content.isNotEmpty) {
              // Extract 2-3 most relevant sentences instead of just first 200 chars
              // Use trace reasoning or relation as query context for relevance
              final queryContext = trace.reasoning ?? trace.relation;
              final actualContent = extractRelevantSentences(
                entry.content,
                query: queryContext,
                maxSentences: 3,
              );
              
              enrichedTrace = AttributionTrace(
                nodeRef: trace.nodeRef,
                relation: trace.relation,
                confidence: trace.confidence,
                timestamp: trace.timestamp,
                reasoning: trace.reasoning,
                phaseContext: trace.phaseContext,
                excerpt: actualContent,
              );
              
              print('Journal: Enriched trace ${trace.nodeRef} with ${actualContent.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length} relevant sentences (${actualContent.length} chars)');
            }
          } catch (e) {
            print('Journal: Could not find entry $entryId for trace ${trace.nodeRef}: $e');
            // Keep original trace if entry not found
          }
        } else {
          // Try to find entry by searching through all entries for matching content
          // This is a fallback if we can't extract entry ID
          // For now, skip this as it's expensive and not reliable
          print('Journal: Could not extract entry ID from trace ${trace.nodeRef}, skipping enrichment');
        }
      }
      
      enrichedTraces.add(enrichedTrace);
    }
    
    return enrichedTraces;
  }
}
