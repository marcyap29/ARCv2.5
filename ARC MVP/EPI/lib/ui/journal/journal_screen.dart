import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../services/lumara/lumara_inline_api.dart';
import 'package:my_app/lumara/services/enhanced_lumara_api.dart';
import 'package:my_app/lumara/services/progressive_memory_loader.dart';
import 'package:my_app/lumara/ui/lumara_settings_screen.dart';
import '../../models/user_profile_model.dart';
import 'package:hive/hive.dart';
import 'package:my_app/lumara/config/api_config.dart';
import '../../services/llm_bridge_adapter.dart';
import '../../services/gemini_send.dart';
// import '../../services/ocr/ocr_service.dart'; // TODO: OCR service not yet implemented
import '../../services/journal_session_cache.dart';
import '../../arc/core/keyword_extraction_cubit.dart';
import '../../arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import '../../arc/core/widgets/keyword_analysis_view.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/data/models/media_item.dart';
import 'media_conversion_utils.dart';
import '../../core/mcp/orchestrator/ios_vision_orchestrator.dart';
import 'widgets/lumara_suggestion_sheet.dart';
import 'widgets/inline_reflection_block.dart';
// import '../../features/timeline/widgets/entry_content_renderer.dart'; // TODO: EntryContentRenderer not yet implemented
import 'widgets/full_screen_photo_viewer.dart';
import '../../ui/widgets/location_picker_dialog.dart';
import 'drafts_screen.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/lumara/chat/chat_repo_impl.dart';
import 'package:my_app/lumara/chat/chat_models.dart';
import 'package:my_app/aurora/services/circadian_profile_service.dart';

/// Main journal screen with integrated LUMARA companion and OCR scanning
class JournalScreen extends StatefulWidget {
  final String? selectedEmotion;
  final String? selectedReason;
  final String? initialContent;
  final JournalEntry? existingEntry; // For loading existing entries with media
  final bool isViewOnly; // New parameter to distinguish viewing vs editing
  
  const JournalScreen({
    super.key,
    this.selectedEmotion,
    this.selectedReason,
    this.initialContent,
    this.existingEntry,
    this.isViewOnly = false, // Default to editing mode for backward compatibility
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
  String? _currentDraftId;
  Timer? _autoSaveTimer;
  final ImagePicker _imagePicker = ImagePicker();
  
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
  
  // UI state management
  bool _showKeywordsDiscovered = false;
  bool _showLumaraBox = false;
  bool _isLumaraConfigured = false;
  
  // Periodic discovery service
  final PeriodicDiscoveryService _discoveryService = PeriodicDiscoveryService();
  
  // Track if entry has been modified
  bool _hasBeenModified = false;
  String? _originalContent;
  
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
    _lumaraApi = LumaraInlineApi(_analytics);
    _enhancedLumaraApi = EnhancedLumaraApi(_analytics);
    _memoryLoader = ProgressiveMemoryLoader(_journalRepository);
    _arcLLM = provideArcLLM();
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
      
      // Load existing keywords for display in editor
      if (widget.existingEntry!.keywords.isNotEmpty) {
        _manualKeywords = List.from(widget.existingEntry!.keywords);
        // Auto-show keywords section when editing existing entry with keywords
        _showKeywordsDiscovered = true;
      }
      
      // Restore LUMARA blocks from metadata if present
      if (widget.existingEntry!.metadata != null) {
        final inlineBlocks = widget.existingEntry!.metadata!['inlineBlocks'] as List?;
        if (inlineBlocks != null && inlineBlocks.isNotEmpty) {
          for (final blockJson in inlineBlocks) {
            try {
              final block = InlineBlock.fromJson(Map<String, dynamic>.from(blockJson));
              _entryState.addReflection(block);
            } catch (e) {
              debugPrint('JournalScreen: Error loading LUMARA block: $e');
            }
          }
          debugPrint('JournalScreen: Restored ${_entryState.blocks.length} LUMARA blocks from metadata');
        }
      }
      
      // Initialize text controllers
      _locationController = TextEditingController(text: _editableLocation ?? '');
      
      // Convert MediaItems back to attachments
      if (widget.existingEntry!.media.isNotEmpty) {
        final attachments = MediaConversionUtils.mediaItemsToAttachments(widget.existingEntry!.media);
        _entryState.attachments.addAll(attachments);
        print('DEBUG: Loaded ${attachments.length} attachments from existing entry');
        print('DEBUG: Entry ID: ${widget.existingEntry!.id}');
        print('DEBUG: Entry content length: ${widget.existingEntry!.content.length}');
        print('DEBUG: Entry media count: ${widget.existingEntry!.media.length}');
      }
      
      // Check for existing draft linked to this entry (3d requirement) - after UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _checkForLinkedDraft(widget.existingEntry!.id);
      });
    } else {
      // Initialize text controllers for new entries
      _locationController = TextEditingController();
    }

    // Initialize draft cache and create new draft (done after checking for linked drafts)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeDraftCache();
    });
    
    // Load draft count for badge display
    _loadDraftCount();
    
    // Check for periodic discovery
    _checkForDiscovery();
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    _autoSaveTimer?.cancel();
    
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
    _keywordController.dispose();
    _locationController.dispose();
    
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
      if (_currentDraftId != null && (!widget.isViewOnly || _isEditMode)) {
        // Update draft with current content and media
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
    } catch (e) {
      print('LUMARA Journal: Memory loader initialization error: $e');
    }
  }

  /// Check if LUMARA is properly configured with an API key
  Future<bool> _checkLumaraConfiguration() async {
    try {
      final apiConfig = LumaraAPIConfig.instance;
      await apiConfig.initialize();
      final availableProviders = apiConfig.getAvailableProviders();
      final bestProvider = apiConfig.getBestProvider();
      
      print('LUMARA Journal: Available providers: ${availableProviders.map((p) => p.name).join(', ')}');
      print('LUMARA Journal: Best provider: ${bestProvider?.name ?? 'none'}');
      
      return bestProvider != null && availableProviders.isNotEmpty;
    } catch (e) {
      print('LUMARA Journal: Configuration check error: $e');
      return false;
    }
  }

  void _onLumaraFabTapped() {
    _analytics.logLumaraEvent('fab_tapped');
    
    // Directly generate a reflection using LUMARA
    _generateLumaraReflection();
  }

  Future<void> _generateLumaraReflection() async {
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
              content: Text('LUMARA needs an API key to work. Configure it in Settings.'),
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
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('LUMARA is thinking...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
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
      
      // Build comprehensive context with mood, phase, chrono profile, chats, and media
      final richContext = await _buildRichContext(loadedEntries, userProfile);
      final phaseHint = _entryState.phase ?? 'Discovery';
      
      // Check if this is the first LUMARA activation (no existing blocks)
      final isFirstActivation = _entryState.blocks.isEmpty;
      
      String reflection;
      if (isFirstActivation) {
        // For first activation, use EnhancedLumaraApi to get full ECHO structure with expansion questions
        reflection = await _enhancedLumaraApi.generatePromptedReflection(
          entryText: richContext['entryText'] ?? '',
          intent: 'journal',
          phase: phaseHint,
          userId: userProfile?.id,
          includeExpansionQuestions: true,
          mood: richContext['mood'],
          chronoContext: richContext['chronoContext'],
          chatContext: richContext['chatContext'],
          mediaContext: richContext['mediaContext'],
        );
      } else {
        // For subsequent activations, use the brief ArcLLM format
        reflection = await _arcLLM.chat(
          userIntent: 'reflect',
          entryText: richContext['entryText'] ?? '',
          phaseHintJson: phaseHint,
          lastKeywordsJson: '',
        );
      }

      // Insert the reflection directly into the text
      _insertAISuggestion(reflection);
      
    } catch (e) {
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
    
    // Collect photo IDs to remove from content
    final photoIdsToRemove = <String>[];
    
    setState(() {
      for (final index in sortedIndices) {
        if (index < _entryState.attachments.length) {
          final attachment = _entryState.attachments[index];
          if (attachment is PhotoAttachment && attachment.photoId != null) {
            photoIdsToRemove.add(attachment.photoId!);
          }
          _entryState.attachments.removeAt(index);
        }
      }
      _selectedPhotoIndices.clear();
      _isPhotoSelectionMode = false;
    });

    // No text placeholders to remove - photos are displayed as separate thumbnails

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${sortedIndices.length} photo(s)'),
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
            // Always show delete option when in selection mode but no photos selected yet
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

  void _onContinue() {
    _analytics.logJournalEvent('continue_pressed', data: {
      'text_length': _entryState.text.length,
      'reflection_count': _entryState.blocks.length,
    });
    
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
            existingEntry: widget.existingEntry,
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
            lumaraBlocks: _entryState.blocks.map((b) => b.toJson()).toList(),
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
                        // Photo/video selection controls (show at top when there are photos or videos)
                        if (_entryState.attachments.any((attachment) => attachment is PhotoAttachment || attachment is VideoAttachment)) ...[
                          _buildPhotoSelectionControls(),
                          const SizedBox(height: 16),
                        ],

                        // Metadata editing section (only for existing entries)
                        if (widget.existingEntry != null) ...[
                          _buildMetadataEditingSection(theme),
                          const SizedBox(height: 16),
                        ],

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
                        // Add photo button
                        IconButton(
                          onPressed: _handlePhotoGallery,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          tooltip: 'Add Photo',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                        
                        // Add camera button
                        IconButton(
                          onPressed: _handleCamera,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          tooltip: 'Take Photo',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                        
                        // Add video button
                        IconButton(
                          onPressed: _handleVideoGallery,
                          icon: const Icon(Icons.videocam, size: 18),
                          tooltip: 'Add Video',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                        
                        // Add voice button
                        IconButton(
                          onPressed: _handleMicrophone,
                          icon: const Icon(Icons.mic, size: 18),
                          tooltip: 'Add Voice Note',
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
                          icon: Icon(
                            Icons.psychology, 
                            size: 18,
                            color: _isLumaraConfigured 
                              ? null 
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          tooltip: _isLumaraConfigured 
                            ? 'Reflect with LUMARA' 
                            : 'LUMARA needs API key configuration',
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
                        ElevatedButton(
                          onPressed: _entryState.text.isNotEmpty ? _onContinue : null,
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
            if (draft.lumaraBlocks.isNotEmpty) {
              for (final blockJson in draft.lumaraBlocks) {
                try {
                  final block = InlineBlock.fromJson(Map<String, dynamic>.from(blockJson));
                  _entryState.addReflection(block);
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
    final hasContent = _entryState.text.trim().isNotEmpty || _entryState.attachments.isNotEmpty;
    
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
        ],
      ),
    );
  }

  /// Build content showing photos, videos, and reflections (without duplicating text)
  List<Widget> _buildInterleavedContent(ThemeData theme) {
    final widgets = <Widget>[];

    // Get all photo attachments - show all photos when loading existing entries
    final photoAttachments = _entryState.attachments
        .whereType<PhotoAttachment>()
        .toList();

    // Get all video attachments
    final videoAttachments = _entryState.attachments
        .whereType<VideoAttachment>()
        .toList();

    // Sort photos by insertion position if available, otherwise by timestamp
    photoAttachments.sort((a, b) {
      if (a.insertionPosition != null && b.insertionPosition != null) {
        return a.insertionPosition!.compareTo(b.insertionPosition!);
      } else if (a.insertionPosition != null) {
        return -1; // a has position, b doesn't - a comes first
      } else if (b.insertionPosition != null) {
        return 1; // b has position, a doesn't - b comes first
      } else {
        // Neither has position, sort by timestamp
        return a.timestamp.compareTo(b.timestamp);
      }
    });

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

    // Show photos as a clean grid of thumbnails
    if (photoAttachments.isNotEmpty) {
      widgets.add(_buildPhotoThumbnailGrid(photoAttachments, theme));
      widgets.add(const SizedBox(height: 16));
    }

    // Show videos as a grid
    if (videoAttachments.isNotEmpty) {
      widgets.add(_buildVideoThumbnailGrid(videoAttachments, theme));
      widgets.add(const SizedBox(height: 16));
    }

    // Add inline reflection blocks with continuation field after each
    for (int index = 0; index < _entryState.blocks.length; index++) {
      final block = _entryState.blocks[index];
      
      // Add the reflection block
      widgets.add(InlineReflectionBlock(
        content: block.content,
        intent: block.intent,
        phase: block.phase,
        onRegenerate: () => _onRegenerateReflection(index),
        onSoften: () => _onSoftenReflection(index),
        onMoreDepth: () => _onMoreDepthReflection(index),
        onContinueWithLumara: _onContinueWithLumara,
        onDelete: () => _onDeleteReflection(index),
      ));
      
      // Add a text field below each reflection to continue the conversation
      widgets.add(const SizedBox(height: 8));
      widgets.add(_buildContinuationField(theme));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }
  
  /// Build continuation text field for user to respond after LUMARA reflection
  Widget _buildContinuationField(ThemeData theme) {
    // This is a simplified TextField for continuation
    // In a full implementation, you'd need to manage separate controllers for each continuation
    return TextField(
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontSize: 16,
        height: 1.5,
      ),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: 'Continue your thoughts...',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white.withOpacity(0.4),
          fontSize: 16,
          height: 1.5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.5),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
        contentPadding: const EdgeInsets.all(12),
      ),
      onChanged: (value) {
        // Store continuation text - you might want to add this to block metadata
      },
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
          _playVideo(video.videoPath);
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
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video thumbnail placeholder or icon
            Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
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

  /// Play video
  void _playVideo(String videoPath) {
    // TODO: Implement video player - can use video_player package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing video: ${videoPath.split('/').last}'),
        duration: const Duration(seconds: 2),
      ),
    );
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
      String actualImagePath = imagePath;
      
      // If this is a photo library ID, load the full resolution image
      if (imagePath.startsWith('ph://')) {
        final fullImagePath = await PhotoLibraryService.loadPhotoFromLibrary(imagePath);
        if (fullImagePath == null) {
          throw Exception('Failed to load photo from photo library');
        }
        actualImagePath = fullImagePath;
      }
      
      // Open full-screen photo viewer in-app
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenPhotoViewer(
            imagePath: actualImagePath,
            analysisText: _getPhotoAnalysisText(imagePath),
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
      // Find the matching PhotoAttachment from entry state
      final photoAttachment = _entryState.attachments
          .whereType<PhotoAttachment>()
          .firstWhere(
            (attachment) => attachment.imagePath == imagePath,
            orElse: () => throw StateError('Photo not found'),
          );

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
    // Photos are displayed separately via _buildInterleavedContent -> _buildPhotoThumbnailGrid
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
  String _buildJournalContext(List<JournalEntry> loadedEntries) {
    final buffer = StringBuffer();
    
    // Add current entry text
    buffer.writeln('Current entry:');
    buffer.writeln(_entryState.text);
    buffer.writeln('---');
    
    // Add loaded entries from memory
    if (loadedEntries.isNotEmpty) {
      buffer.writeln('Recent journal history:');
      for (final entry in loadedEntries.take(25)) {
        buffer.writeln(entry.content);
        buffer.writeln('---');
      }
    }
    
    return buffer.toString().trim();
  }

  /// Build rich context including mood, phase, chrono profile, chats, and media
  Future<Map<String, dynamic>> _buildRichContext(
    List<JournalEntry> loadedEntries,
    UserProfile? userProfile,
  ) async {
    final context = <String, dynamic>{};
    
    // Build entry text from loaded journal entries
    context['entryText'] = _buildJournalContext(loadedEntries);
    
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
    final allEntries = _journalRepository.getAllJournalEntries();
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
    
    setState(() {
      _entryState.blocks.add(block);
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
    
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('LUMARA is thinking...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      final entryText = _buildJournalContext(loadedEntries);
      final phaseHint = _buildPhaseHintJson();
      final keywordsJson = _buildKeywordsJson();
      
      // Map intent to user prompt
      final userIntent = _mapIntentToUserPrompt(block.intent);
      
      // Use ArcLLM with Gemini for reflection
      final newReflection = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: entryText,
        phaseHintJson: phaseHint,
        lastKeywordsJson: keywordsJson,
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
      
      _analytics.logLumaraEvent('inline_reflection_regenerated');
    } catch (e) {
      _analytics.log('lumara_regenerate_error', {'error': e.toString()});
      
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
    
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('LUMARA is softening the tone...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      final entryText = _buildJournalContext(loadedEntries);
      final phaseHint = _buildPhaseHintJson();
      final keywordsJson = _buildKeywordsJson();
      
      // Use softer tone prompt
      final userIntent = 'Soften the tone and make this reflection more gentle, warm, and supportive. Keep the same intent but use more compassionate and encouraging language.';
      
      // Use ArcLLM with Gemini for softer reflection
      final softerReflection = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: entryText,
        phaseHintJson: phaseHint,
        lastKeywordsJson: keywordsJson,
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
      
      _analytics.logLumaraEvent('inline_reflection_softened');
    } catch (e) {
      _analytics.log('lumara_soften_error', {'error': e.toString()});
      
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
    
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('LUMARA is going deeper...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      final entryText = _buildJournalContext(loadedEntries);
      final phaseHint = _buildPhaseHintJson();
      final keywordsJson = _buildKeywordsJson();
      
      // Use deeper analysis prompt
      final userIntent = 'Provide deeper analysis and more profound insight into this reflection. Explore underlying patterns, connections, and deeper meanings.';
      
      // Use ArcLLM with Gemini for deeper reflection
      final deeperReflection = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: entryText,
        phaseHintJson: phaseHint,
        lastKeywordsJson: keywordsJson,
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
      
      _analytics.logLumaraEvent('inline_reflection_deepened');
    } catch (e) {
      _analytics.log('lumara_depth_error', {'error': e.toString()});
      
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
    });
    _analytics.logLumaraEvent('inline_reflection_deleted');
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
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('LUMARA is thinking...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      _analytics.logLumaraEvent('suggestion_selected', data: {'intent': suggestion});
      
      // Build context from progressive memory loader
      final loadedEntries = _memoryLoader.getLoadedEntries();
      final entryText = _buildJournalContext(loadedEntries);
      final phaseHint = _buildPhaseHintJson();
      final keywordsJson = _buildKeywordsJson();
      
      // Map suggestion to user prompt
      final userIntent = _mapSuggestionToUserPrompt(suggestion);
      
      // Use ArcLLM with Gemini for reflection
      final reflection = await _arcLLM.chat(
        userIntent: userIntent,
        entryText: entryText,
        phaseHintJson: phaseHint,
        lastKeywordsJson: keywordsJson,
      );
      
      // Insert the reflection into the text
      final currentText = _textController.text;
      final cursorPosition = _textController.selection.baseOffset;
      
      // Insert reflection at cursor position or end of text
      final insertPosition = (cursorPosition >= 0 && cursorPosition <= currentText.length) 
          ? cursorPosition 
          : currentText.length;
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
  Future<void> _initializeDraftCache() async {
    try {
      await _draftCache.initialize();
      
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
    
    // Initialize draft cache now that we're editing
    _initializeDraftCache();
    
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
      if (await videoFile.exists()) {
        sizeBytes = await videoFile.length();
      }

      // Create a VideoAttachment directly
      final videoAttachment = VideoAttachment(
        type: 'video',
        videoPath: videoPath,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        videoId: DateTime.now().millisecondsSinceEpoch.toString(),
        sizeBytes: sizeBytes,
        altText: 'Video: ${videoPath.split('/').last}',
      );

      setState(() {
        _entryState.addVideoAttachment(videoAttachment);
      });
      
      // Update draft if exists
      if (_currentDraftId != null) {
        final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
        final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
        await _draftCache.updateDraftContentAndMedia(_entryState.text, mediaItems, lumaraBlocks: blocksJson);
      }
      
      print('DEBUG: Video added to entry');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video added to entry'),
          duration: Duration(seconds: 2),
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
}
