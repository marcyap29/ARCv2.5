import 'package:my_app/arc/chat/ui/widgets/health_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:my_app/shared/app_colors.dart';
import '../bloc/lumara_assistant_cubit.dart';
import '../data/models/lumara_message.dart';
import '../chat/ui/enhanced_chats_screen.dart';
import '../chat/enhanced_chat_repo_impl.dart';
import '../chat/chat_repo_impl.dart';
import 'lumara_quick_palette.dart';
import 'lumara_settings_screen.dart';
import '../widgets/attribution_display_widget.dart';
import '../widgets/enhanced_attribution_display_widget.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/memory/enhanced_attribution_schema.dart';
import 'package:my_app/mira/memory/enhanced_attribution_service.dart';
import 'package:my_app/mira/memory/lumara_attribution_explainer.dart';
import '../config/api_config.dart';
import '../voice/voice_service.dart';
import '../voice/voice_journal/unified_voice_panel.dart';
import '../voice/voice_permissions.dart';
import 'package:my_app/services/assemblyai_service.dart';
import '../services/enhanced_lumara_api.dart';
import '../../../telemetry/analytics.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import '../services/favorites_service.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';
import '../data/models/lumara_favorite.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';
import '../voice/audio_io.dart';
import '../chat/chat_models.dart';
import 'widgets/chat_navigation_drawer.dart';
import 'package:my_app/ui/subscription/lumara_subscription_status.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
// Removed persona selector widget - personas accessed through different UI
import 'package:my_app/services/sentinel/crisis_mode.dart';
import 'package:my_app/arc/chat/models/lumara_reflection_options.dart' as models;
import 'package:my_app/models/engagement_discipline.dart';

/// Main LUMARA Assistant screen
class LumaraAssistantScreen extends StatefulWidget {
  final JournalEntry? currentEntry; // Optional current journal entry for weighted context
  
  const LumaraAssistantScreen({
    super.key,
    this.currentEntry,
  });

  @override
  State<LumaraAssistantScreen> createState() => _LumaraAssistantScreenState();
}

class _LumaraAssistantScreenState extends State<LumaraAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  String? _editingMessageId; // Track which message is being edited
  bool _isInputVisible = true; // Track input visibility
  JournalEntry? _currentEntry; // Store current entry for context
  bool _isDrawerOpen = false; // Track drawer state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _modeMenuKey = GlobalKey();
  
  // Scroll position tracking for scroll buttons
  bool _showScrollToTop = false;
  bool _showScrollToBottom = false;
  
  // Voice service (unified - chat mode)
  UnifiedVoiceService? _voiceService;
  String? _partialTranscript;

  // AudioIO for voiceover
  AudioIO? _audioIO;

  // Enhanced attribution service
  final EnhancedAttributionService _enhancedAttributionService = EnhancedAttributionService();
  
  // Persona system kept but dropdown removed from header (accessed elsewhere)
  // Default: Companion mode
  String _selectedPersona = 'companion';
  
  // Crisis mode tracking
  bool _isCrisisMode = false;

  @override
  void initState() {
    super.initState();
    // Store current entry from widget
    _currentEntry = widget.currentEntry;
    _checkAIConfigurationAndInitialize();
    _inputFocusNode.addListener(_onInputFocusChange);
    _scrollController.addListener(_onScrollChanged);
    _initializeAudioIO();
    _initializeVoiceChat();
    _checkCrisisMode();
  }

  /// Check if user is in crisis mode (Sentinel override)
  Future<void> _checkCrisisMode() async {
    try {
      final authService = FirebaseAuthService.instance;
      final user = authService.currentUser;
      if (user != null) {
        final inCrisis = await CrisisMode.isInCrisisMode(user.uid);
        if (mounted) {
          setState(() {
            _isCrisisMode = inCrisis;
            // Force therapist persona if in crisis mode
            if (inCrisis) {
              _selectedPersona = 'therapist';
            }
          });
        }
      }
    } catch (e) {
      print('Error checking crisis mode: $e');
    }
  }
  
  @override
  void didUpdateWidget(LumaraAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update current entry if widget changed
    if (widget.currentEntry != oldWidget.currentEntry) {
      setState(() {
        _currentEntry = widget.currentEntry;
      });
    }
  }

  void _onInputFocusChange() {
    // Show input when it gains focus or has text
    setState(() {
      _isInputVisible = _inputFocusNode.hasFocus || _messageController.text.isNotEmpty;
    });
  }

  Future<void> _checkAIConfigurationAndInitialize() async {
    // Check if any AI provider is configured
    final apiConfig = LumaraAPIConfig.instance;
    await apiConfig.initialize();

    // Initialize LUMARA directly (no splash page)
    debugPrint('LUMARA Assistant: Initializing directly');
    final cubit = context.read<LumaraAssistantCubit>();
    if (cubit.state is! LumaraAssistantLoaded) {
      cubit.initializeLumara();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.removeListener(_onInputFocusChange);
    _inputFocusNode.dispose();
    _voiceService?.dispose();
    super.dispose();
  }

  /// Initialize voice service (unified - chat mode)
  Future<void> _initializeVoiceChat() async {
    try {
      final cubit = context.read<LumaraAssistantCubit>();
      
      // Get EnhancedLumaraApi
      final enhancedApi = EnhancedLumaraApi(Analytics());
      await enhancedApi.initialize();
      
      // Get AssemblyAI service for cloud STT
      final assemblyAIService = AssemblyAIService();
      
      // Create unified voice service in CHAT mode
      _voiceService = UnifiedVoiceService(
        assemblyAIService: assemblyAIService,
        lumaraApi: enhancedApi,
        journalCubit: null, // Not needed for chat mode
        chatCubit: cubit,
        initialMode: VoiceMode.chat, // Chat mode - saves to chat only
      );
      
      // Set up callbacks
      _voiceService!.onTranscriptUpdate = (transcript) {
        if (mounted) {
          setState(() {
            _partialTranscript = transcript;
          });
        }
      };
      
      final initialized = await _voiceService!.initialize();
      if (!initialized && mounted) {
        debugPrint('Voice service initialization failed - permissions may be denied');
      }
    } catch (e) {
      debugPrint('Error initializing voice service: $e');
    }
  }

  /// Show voice chat panel
  void _showVoiceChatPanel() {
    if (_voiceService == null || !_voiceService!.isInitialized) {
      // Request permissions first
      _requestVoicePermissions();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: UnifiedVoicePanel(
          service: _voiceService!,
          onSessionSaved: () {
            Navigator.pop(context);
          },
          onSessionEnded: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// Request voice permissions
  Future<void> _requestVoicePermissions() async {
    final permState = await VoicePermissions.request();
    if (permState == VoicePermState.allGranted) {
      await _initializeVoiceChat();
      if (_voiceService != null && _voiceService!.isInitialized) {
        _showVoiceChatPanel();
      }
    } else if (permState == VoicePermState.permanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Microphone Permission Required'),
            content: const Text(
              'Voice chat requires microphone permission. Please enable it in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  VoicePermissions.openSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
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
  
  /// Scroll to top of chat
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
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }

  void _scrollToNewAnswer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Scroll down a small amount (approx 2 lines + padding) to show answer started
        final currentOffset = _scrollController.offset;
        final targetOffset = currentOffset + 100.0; // Adjust based on line height
        
        // Don't scroll past max extent
        final maxExtent = _scrollController.position.maxScrollExtent;
        final finalOffset = targetOffset > maxExtent ? maxExtent : targetOffset;

        _scrollController.animateTo(
          finalOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _dismissKeyboard() {
    // Multiple methods to ensure keyboard is dismissed
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    // Also try to remove focus from any text field
    FocusManager.instance.primaryFocus?.unfocus();
    
    // Hide input area when dismissing keyboard (if text is empty)
    // Like ChatGPT, minimize when clicking outside
    setState(() {
      if (_messageController.text.isEmpty) {
        _isInputVisible = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('LUMARA'),
            const SizedBox(width: 12),
            const LumaraSubscriptionStatus(compact: true),
          ],
        ),
        automaticallyImplyLeading: false, // Remove back button since this is a tab
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() => _isDrawerOpen = !_isDrawerOpen);
          },
        ),
        actions: [
          // Voice chat button
          IconButton(
            icon: const Icon(Icons.mic_none),
            tooltip: 'Voice Chat',
            onPressed: _showVoiceChatPanel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'new_chat':
                  _startNewChat();
                  break;
                case 'settings':
                  _showEnhancedSettings();
                  break;
                case 'history':
                  Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedChatsScreen(
                  chatRepo: EnhancedChatRepoImpl(ChatRepoImpl.instance),
                ),
              ),
                  );
                  break;
                case 'clear':
                  _clearChat();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('New Chat'),
                  ],
          ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('LUMARA Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20),
                    SizedBox(width: 12),
                    Text('History'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 12),
                    Text('Clear History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          GestureDetector(
                    onTap: () {
                      // Dismiss keyboard and hide input when tapping conversation area
                      // Like ChatGPT - auto minimize when clicking outside
                      _dismissKeyboard();
                      if (_isDrawerOpen) {
                        setState(() => _isDrawerOpen = false);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        // Messages list
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Hide input when tapping conversation area
                              // Auto minimize like ChatGPT
                              _dismissKeyboard();
                            },
                            onDoubleTap: () {
                              // Show input on double tap to make it easy to bring back
                              setState(() {
                                _isInputVisible = true;
                              });
                              _inputFocusNode.requestFocus();
                            },
                            child: BlocConsumer<LumaraAssistantCubit, LumaraAssistantState>(
                              listener: (context, state) {
                // Show input when LUMARA finishes responding
                if (state is LumaraAssistantLoaded && !state.isProcessing) {
                  setState(() {
                    _isInputVisible = true;
                  });
                  
                  // Show snackbar if there's an API error message
                  if (state.apiErrorMessage != null && state.apiErrorMessage!.isNotEmpty) {
                    // Check if this is a rate limit error
                    if (state.apiErrorMessage == 'RATE_LIMIT_EXCEEDED') {
                      _showRateLimitDialog();
                    } else if (state.apiErrorMessage!.contains('ANONYMOUS_TRIAL_EXPIRED') ||
                               state.apiErrorMessage!.contains('free trial') ||
                               state.apiErrorMessage!.contains('trial of 5 requests')) {
                      // Handle trial expiry - show sign-in dialog
                      _showTrialExpiredDialog();
                    } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.apiErrorMessage!),
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    }
                  }
                }

                // Handle scrolling for new messages
                if (state is LumaraAssistantLoaded) {
                  // We can't easily access 'previous' state here without listenWhen, 
                  // but we can check if the last message is new or if we are processing.
                  // A better approach for scrolling is often to trigger it when the list changes.
                  // However, since we want specific behavior for "new answer", we can check:
                  if (state.messages.isNotEmpty) {
                    final lastMessage = state.messages.last;
                    if (lastMessage.role == 'user') {
                      _scrollToBottom();
                    } else if (lastMessage.role == 'assistant' && state.isProcessing) {
                      // If assistant is processing (streaming/typing), just nudge scroll
                      // We might need a flag to ensure we only do this once per response start
                      // For now, let's rely on the fact that this listener fires on state changes.
                    }
                  }
                }
              },
              listenWhen: (previous, current) {
                // Return true to trigger listener
                if (previous is LumaraAssistantLoaded && current is LumaraAssistantLoaded) {
                  // Check if a new message was added
                  if (current.messages.length > previous.messages.length) {
                    final newMessage = current.messages.last;
                    if (newMessage.role == 'user') {
                      _scrollToBottom();
                    } else if (newMessage.role == 'assistant') {
                      _scrollToNewAnswer();
                    }
                    return true; // Trigger listener for other logic
                  }
                }
                return true; // Default behavior
                              },
                              builder: (context, state) {
                if (state is LumaraAssistantLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (state is LumaraAssistantError) {
                  // Check if error is due to missing configuration
                  final isConfigError = state.message.contains('MissingPluginException') ||
                                       state.message.contains('Failed to initialize') ||
                                       state.message.contains('No implementation found');

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isConfigError ? Icons.warning : Icons.error,
                            size: 64,
                            color: isConfigError ? Colors.orange[300] : Colors.red[300],
                          ),
                          const Gap(16),
                          Text(
                            isConfigError ? 'Error: Failed to initialize LUMARA' : 'Error: ${state.message}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Gap(8),
                          Text(
                            isConfigError
                                ? 'Please configure an AI provider to continue'
                                : state.message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Gap(24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isConfigError) ...[
                                OutlinedButton(
                                  onPressed: () => context.read<LumaraAssistantCubit>().initializeLumara(),
                                  child: const Text('Retry'),
                                ),
                                const Gap(12),
                              ],
                              ElevatedButton(
                                onPressed: () {
                                  // Navigate to appropriate screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => isConfigError
                                          ? const SizedBox.shrink()
                                              : const LumaraSettingsScreen(),
                                    ),
                                  );
                                },
                                child: Text(isConfigError ? 'Set Up AI' : 'Settings'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if (state is LumaraAssistantLoaded) {
                  // Show breadcrumb if this is a forked chat
                  final isForked = state.currentSessionId != null;
                  
                  if (state.messages.isEmpty) {
                    // Show loading indicator even when messages are empty
                    if (state.isProcessing) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLoadingIndicator(context),
                        ],
                      );
                    }
                    return _buildEmptyState();
                  }
                  
                  // Show messages with loading indicator at the bottom when processing
                  return Stack(
                    children: [
                      Column(
                    children: [
                      // Breadcrumb for forked chats
                      if (isForked) _buildForkBreadcrumb(context, state.currentSessionId!),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: state.messages.length,
                          itemBuilder: (context, index) {
                            final message = state.messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
                      ),
                      // Show progress indicator at bottom when processing
                      if (state.isProcessing) _buildLoadingIndicator(context),
                        ],
                      ),
                      // Floating scroll-to-top button (appears when scrolled down)
                      if (_showScrollToTop)
                        Positioned(
                          bottom: 76, // Above scroll-to-bottom button
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'chatScrollToTop',
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
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'chatScrollToBottom',
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
                  );
                }
                
                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        
                        // Message input - show/hide based on visibility state
                        if (_isInputVisible) _buildMessageInput(),
                        if (!_isInputVisible) _buildShowInputButton(),
                      ],
                    ),
                        ),

          // Navigation drawer overlay - slides in from left
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: _isDrawerOpen ? 0 : -MediaQuery.of(context).size.width * 0.75,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {}, // Prevent taps from closing drawer
              child: ChatNavigationDrawer(
                chatRepo: EnhancedChatRepoImpl(ChatRepoImpl.instance),
                currentSessionId: context.read<LumaraAssistantCubit>().currentChatSessionId,
                onSessionSelected: (sessionId) async {
                  // Load the selected session
                  await _loadSession(sessionId);
                  setState(() => _isDrawerOpen = false);
                },
                onNewChat: () {
                  _startNewChat();
                  setState(() => _isDrawerOpen = false);
                },
                onScratchpad: () {
                  // Create or load scratchpad session
                  _loadScratchpad();
                  setState(() => _isDrawerOpen = false);
                },
                onSandbox: () {
                  // Create or load sandbox session
                  _loadSandbox();
                  setState(() => _isDrawerOpen = false);
                },
              ),
            ),
          ),

          // Backdrop overlay when drawer is open
          if (_isDrawerOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isDrawerOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology,
              size: 80,
              color: Colors.grey[400],
            ),
            const Gap(24),
            Text(
              'Ask LUMARA anything about your week',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(16),
            Text(
              'Try asking about patterns, insights, or get a summary of your recent entries.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(32),
            _buildQuickSuggestions(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestions = [
      'Summarize my last 7 days',
      'What patterns do you see?',
      'Why am I in this phase?',
      'Compare this week to last week',
      'Suggest a prompt for tonight',
    ];

    return Column(
      children: suggestions.map((suggestion) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () async => await _sendMessage(suggestion),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: Colors.grey[600]),
                  const Gap(8),
                  Text(
                    suggestion,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Build loading indicator widget (reusable)
  Widget _buildLoadingIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LUMARA is thinking...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress meter
          LinearProgressIndicator(
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(LumaraMessage message) {
    final isUser = message.role == LumaraMessageRole.user;
    final isEditing = _editingMessageId == message.id;
    // Check if this is the intro message to hide actions
    final isIntroMessage = !isUser && (
      message.content.startsWith("Hello! I'm LUMARA") || 
      message.content.startsWith("Hi there! I'm LUMARA") || 
      message.content.startsWith("Hey! I'm LUMARA")
    );

    return Padding(
      key: Key('message_bubble_${message.id}'), // Unique key prevents GlobalKey conflicts
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const LumaraIcon(size: 32),
            const Gap(8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEditing 
                  ? (isUser ? Colors.blue[400] : Colors.grey[200])
                  : (isUser ? Colors.blue[500] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: isEditing 
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editing indicator for user messages
                  if (isEditing && isUser) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Editing...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Header with LUMARA icon and text (unified with in-journal UX)
                  if (!isUser) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LUMARA',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        // Phase badge if available in metadata
                        if (message.metadata.containsKey('phase') && message.metadata['phase'] != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message.metadata['phase'] as String,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Format content into paragraphs for better readability (especially for assistant messages)
                  if (isUser) ...[
                    Text(
                      message.content,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        decoration: isEditing ? TextDecoration.none : null,
                      ),
                    ),
                  ] else ...[
                    ..._buildParagraphs(
                      message.content,
                      TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        height: 1.6, // Increased line height for better mobile readability
                      ),
                    ),
                  ],
                  
                  // Action buttons for user messages (edit/copy)
                  if (isUser) ...[
                    const Gap(8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, size: 16, color: Colors.white.withOpacity(0.8)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _startEditingMessage(message),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, size: 16, color: Colors.white.withOpacity(0.8)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _copyMessage(message.content),
                          tooltip: 'Copy',
                        ),
                      ],
                    ),
                  ],
                  
                  // Copy, star, and delete buttons for assistant messages (lower left)
                  if (!isUser && !isIntroMessage) ...[
                    const Gap(8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.volume_up, size: 16, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _speakMessage(message.content),
                          tooltip: 'Speak',
                        ),
                        IconButton(
                          icon: Icon(Icons.ios_share, size: 16, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _copyMessage(message.content),
                          tooltip: 'Copy/Share',
                        ),
                        IconButton(
                          icon: Icon(Icons.play_arrow, size: 16, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _continueAssistantThought(message),
                          tooltip: 'Continue this thought',
                        ),
                        FutureBuilder<bool>(
                          future: FavoritesService.instance.isFavorite(message.id),
                          builder: (context, snapshot) {
                            final isFavorite = snapshot.data ?? false;
                            return IconButton(
                              icon: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                size: 16,
                                color: isFavorite ? Colors.amber : Colors.grey[600],
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _toggleFavorite(message),
                              tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                            );
                          },
                        ),

                        // Bookmark icon to save entire chat
                        FutureBuilder<String?>(
                          future: _getCurrentSessionId(),
                          builder: (context, snapshot) {
                            final sessionId = snapshot.data;
                            if (sessionId == null) return const SizedBox.shrink();
                            
                            return FutureBuilder<bool>(
                              future: _isChatSaved(sessionId),
                              builder: (context, savedSnapshot) {
                                final isSaved = savedSnapshot.data ?? false;
                                return IconButton(
                                  icon: Icon(
                                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                                    size: 16,
                                    color: isSaved ? const Color(0xFF2196F3) : Colors.grey[600],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _toggleSaveChat(sessionId),
                                  tooltip: isSaved ? 'Unsave Chat' : 'Save Chat',
                                );
                              },
                            );
                          },
                        ),
                        const Spacer(),
                        // Settings icon (matching journal UI)
                        IconButton(
                          icon: Icon(Icons.tune, size: 18, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showChatMessageOptions(context, message),
                          tooltip: 'Options',
                        ),
                      ],
                    ),
                    // Action buttons removed - now in settings menu
                  ],
                  
                  // Enhanced Attribution display for assistant messages
                  if (!isUser && message.attributionTraces != null && message.attributionTraces!.isNotEmpty) ...[
                    const Gap(8),
                    Builder(
                      builder: (context) {
                        print('LumaraAssistantScreen: Rendering attribution display for message ${message.id} with ${message.attributionTraces!.length} traces');

                        // Try to get enhanced attribution data
                        return FutureBuilder(
                          future: _getEnhancedAttributionTrace(message.id),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              // Use enhanced attribution widget
                              return _buildEnhancedAttributionDisplay(
                                snapshot.data!,
                                message.id,
                                message.attributionTraces!,
                              );
                            } else {
                              // Fall back to legacy attribution widget
                              return AttributionDisplayWidget(
                                traces: message.attributionTraces!,
                                responseId: message.id,
                                onWeightChanged: (trace, newWeight) {
                                  _handleAttributionWeightChange(message.id, trace, newWeight);
                                },
                                onExcludeMemory: (trace) {
                                  _handleMemoryExclusion(message.id, trace);
                                },
                              );
                            }
                          },
                        );
                      },
                    ),
                  ],
                  if (!isUser && (message.attributionTraces == null || message.attributionTraces!.isEmpty)) ...[
                    // Debug: Show why attributions aren't showing
                    Builder(
                      builder: (context) {
                        print('LumaraAssistantScreen: Message ${message.id} - attributionTraces is null or empty (null: ${message.attributionTraces == null}, empty: ${message.attributionTraces?.isEmpty ?? true})');
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                  
                  // Web source indicator
                  if (!isUser && _hasWebSource(message)) ...[
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.language,
                            size: 14,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'External Information Used',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  if (message.sources.isNotEmpty) ...[
                    const Gap(8),
                    Wrap(
                      spacing: 4,
                      children: message.sources.map((source) {
                        return Chip(
                          label: Text(source),
                          backgroundColor: isUser 
                              ? Colors.white.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: isUser ? Colors.white : Colors.blue[700],
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const Gap(8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, size: 16, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final isEditing = _editingMessageId != null;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8), // Reduced padding for smaller size
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.blue[700]),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      'Editing message',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelEditing,
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite, size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Health',
                onPressed: _showHealthPreview,
              ),
              Expanded(
                  child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 120.0, // Max height for ~5 lines (24px per line)
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputFocusNode,
                    decoration: InputDecoration(
                      hintText: isEditing ? 'Edit your message...' : 'Ask LUMARA anything...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 5, // Limit to 5 lines, then scroll
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    onSubmitted: (_) async => await _sendCurrentMessage(),
                    onTap: () {
                      // Ensure input is visible when tapped
                      setState(() => _isInputVisible = true);
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const LumaraIcon(size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: _sendCurrentMessage,
                tooltip: 'Send',
              ),
              IconButton(
                key: _modeMenuKey,
                icon: const Icon(Icons.expand_more, size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: _showEngagementModeMenu,
                tooltip: 'Choose engagement mode',
              ),
              IconButton(
                icon: const Icon(Icons.palette, size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: () => _showQuickPalette(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShowInputButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isInputVisible = true;
          });
          _inputFocusNode.requestFocus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[600]!, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                'Tap to ask LUMARA...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCurrentMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      if (_editingMessageId != null) {
        await _resubmitMessage(_editingMessageId!, text);
      } else {
        await _sendMessage(text);
      }
      _messageController.clear();
      _editingMessageId = null;
      // Keep input visible after sending
      setState(() {
        _isInputVisible = true;
      });
      // Don't dismiss keyboard - keep it open for next message
    }
  }

  Future<void> _showEngagementModeMenu() async {
    final anchorContext = _modeMenuKey.currentContext;
    final overlay = Overlay.of(context);
    if (anchorContext == null || overlay == null) return;

    final box = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final offset = box.localToGlobal(Offset.zero, ancestor: overlayBox);

    // Get current engagement settings
    final settingsService = LumaraReflectionSettingsService.instance;
    final currentSettings = await settingsService.getEngagementSettings();
    final currentMode = currentSettings.activeMode;

    final selection = await showMenu<EngagementMode>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 4,
        overlayBox.size.width - offset.dx - box.size.width,
        overlayBox.size.height - offset.dy - box.size.height,
      ),
      items: EngagementMode.values.map((mode) {
        final isSelected = mode == currentMode;
        return PopupMenuItem<EngagementMode>(
          value: mode,
          child: Row(
            children: [
              if (isSelected)
                Icon(Icons.check, size: 18, color: Colors.blue)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mode.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    Text(
                      mode.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );

    if (selection == null) return;

    // Update conversation override (per-session)
    final updated = currentSettings.copyWith(conversationOverride: selection);
    await settingsService.setEngagementSettings(updated);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Engagement mode set to ${selection.displayName}')),
    );
  }

  void _startEditingMessage(LumaraMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _messageController.text = message.content;
    });
    // Scroll to input field
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

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  Future<void> _resubmitMessage(String messageId, String newText) async {
    // Update the cubit to remove messages after the edited one
    context.read<LumaraAssistantCubit>().editAndResubmitMessage(messageId, newText);
    
    // Send the edited message
    await _sendMessage(newText);
  }

  Future<void> _initializeAudioIO() async {
    try {
      _audioIO = AudioIO();
      await _audioIO!.initializeTTS();
    } catch (e) {
      debugPrint('Error initializing AudioIO: $e');
    }
  }

  Future<void> _speakMessage(String text) async {
    try {
      if (_audioIO != null && text.isNotEmpty) {
        // Clean text for speech (remove markdown, etc.)
        final cleanText = _cleanTextForSpeech(text);
        if (cleanText.isNotEmpty) {
          await _audioIO!.speak(cleanText);
        }
      }
    } catch (e) {
      debugPrint('Error speaking message: $e');
    }
  }

  String _cleanTextForSpeech(String text) {
    // Remove markdown formatting
    String cleaned = text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1') // Code
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1') // Links
        .replaceAll(RegExp(r'#{1,6}\s+'), '') // Headers
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Multiple newlines
        .trim();
    return cleaned;
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleFavorite(LumaraMessage message) async {
    if (message.role != LumaraMessageRole.assistant) return;

    try {
      await FavoritesService.instance.initialize();
      final isFavorite = await FavoritesService.instance.isFavorite(message.id);

      if (isFavorite) {
        // Remove from favorites
        await FavoritesService.instance.removeFavoriteBySourceId(message.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from Favorites'),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {}); // Refresh UI
        }
      } else {
        // Add to favorites
        final atCapacity = await FavoritesService.instance.isCategoryAtCapacity('answer');
        if (atCapacity) {
          _showCapacityPopup(context);
          return;
        }

        final favorite = LumaraFavorite.fromMessage(
          content: message.content,
          sourceId: message.id,
          sourceType: 'chat',
          metadata: message.metadata,
        );

        final added = await FavoritesService.instance.addFavorite(favorite);
        if (added && mounted) {
          // Always show snackbar with Manage link
          final isFirstTime = !await FavoritesService.instance.hasShownFirstTimeSnackbar();
          if (isFirstTime) {
            await FavoritesService.instance.markFirstTimeSnackbarShown();
          }
          _showFavoriteAddedSnackbar();
          setState(() {}); // Refresh UI
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


  Future<void> _showCapacityPopup(BuildContext context) async {
    final limit = await FavoritesService.instance.getCategoryLimit('answer');
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorites Full'),
        content: Text(
          'You have reached the maximum of $limit favorites. Please remove some favorites before adding new ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesManagementView(),
                ),
              );
            },
            child: const Text('Manage Favorites'),
          ),
        ],
      ),
    );
  }

  void _showFavoriteAddedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Added to Favorites',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'LUMARA will now adapt its style based on your favorites. Tap to manage them.',
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Manage',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FavoritesManagementView(),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showHealthPreview() async {
    final result = await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return const HealthPreviewSheet();
      },
    );
    if (result == 'attach_health') {
      // Optionally: update draft state to note Health attached (implementation dependent)
    }
  }

  Future<void> _sendMessage(String message) async {
    // Get current entry - prioritize widget's currentEntry, then try to get most recent entry
    JournalEntry? entryToUse = _currentEntry;
    
    // If no entry provided, try to get the most recent entry as fallback
    // This ensures we always have context from the user's journal
    if (entryToUse == null) {
      entryToUse = await _getMostRecentEntry();
      if (entryToUse != null) {
        print('LUMARA: Using most recent entry ${entryToUse.id} as context');
      }
    } else {
      print('LUMARA: Using provided current entry ${entryToUse.id} as context');
    }
    
    // Map persona to conversation mode (enhanced API uses modes, not direct persona)
    models.ConversationMode? personaMode = _personaToConversationMode(_selectedPersona);
    
    // Detect conversation mode from message text (overrides persona mode if detected)
    models.ConversationMode? detectedMode = _detectConversationModeFromText(message);
    
    // Use detected mode if present, otherwise use persona mode
    final finalMode = detectedMode ?? personaMode;
    
    // Note: If entryToUse is still null, sendMessage will work without current entry
    // The weighted context system will still use recent LUMARA responses and other entries
    context.read<LumaraAssistantCubit>().sendMessage(
      message,
      currentEntry: entryToUse,
      conversationMode: finalMode,
      persona: null, // Persona is determined by conversation mode in enhanced API
    );
  }
  
  /// Detect conversation mode from message text
  models.ConversationMode? _detectConversationModeFromText(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('regenerate') || lowerText.contains('different approach')) {
      return null; // Regenerate handled separately
    }
    if (lowerText.contains('reflect more deeply') || lowerText.contains('more depth')) {
      return models.ConversationMode.reflectDeeply;
    }
    if (lowerText.contains('continue thought') || lowerText.contains('continue')) {
      return models.ConversationMode.continueThought;
    }
    if (lowerText.contains('suggest some ideas') || lowerText.contains('suggest ideas')) {
      return models.ConversationMode.ideas;
    }
    if (lowerText.contains('think this through') || lowerText.contains('think through')) {
      return models.ConversationMode.think;
    }
    if (lowerText.contains('different perspective') || lowerText.contains('another way')) {
      return models.ConversationMode.perspective;
    }
    if (lowerText.contains('suggest next steps') || lowerText.contains('next steps')) {
      return models.ConversationMode.nextSteps;
    }
    
    return null;
  }

  void _continueAssistantThought(LumaraMessage message) {
    // Get current entry for context
    JournalEntry? entryToUse = _currentEntry;
    if (entryToUse == null) {
      _getMostRecentEntry().then((entry) {
        if (entry != null) {
          _sendMessageWithMode('Continue thought', models.ConversationMode.continueThought, entry);
        } else {
          _sendMessageWithMode('Continue thought', models.ConversationMode.continueThought, null);
        }
      });
      return;
    }
    
    _sendMessageWithMode('Continue thought', models.ConversationMode.continueThought, entryToUse);
  }
  
  /// Send message with conversation mode and entry
  Future<void> _sendMessageWithMode(
    String text,
    models.ConversationMode mode,
    JournalEntry? entry,
  ) async {
    context.read<LumaraAssistantCubit>().sendMessage(
      text,
      currentEntry: entry,
      conversationMode: mode,
      persona: null, // Persona determined by conversation mode
    );
  }
  
  /// Get the most recent journal entry as fallback for context
  /// This ensures LUMARA always has access to the user's latest journal content
  Future<JournalEntry?> _getMostRecentEntry() async {
    try {
      final journalRepository = JournalRepository();
      final allEntries = await journalRepository.getAllJournalEntries();
      if (allEntries.isNotEmpty) {
        // Sort by creation date, most recent first
        allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final mostRecent = allEntries.first;
        print('LUMARA: Found most recent entry: ${mostRecent.id} (${mostRecent.createdAt})');
        return mostRecent;
      }
    } catch (e) {
      print('LUMARA: Error getting most recent entry: $e');
    }
    return null;
  }

  void _showRateLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Rate Limit Reached'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve reached your free tier limit for LUMARA requests.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Free tier includes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 20 requests per day'),
            Text('• 3 requests per minute'),
            Text('• 30 days of phase history'),
            SizedBox(height: 16),
            Text(
              'Upgrade to Premium for:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Unlimited LUMARA requests'),
            Text('• No rate limiting'),
            Text('• Full phase history access'),
            Text('• Priority support'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to subscription management
              Navigator.pushNamed(context, '/settings/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  void _showTrialExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stars, color: Colors.purple),
            SizedBox(width: 12),
            Text('Free Trial Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You\'ve used your 5 free trial requests. Sign in to continue using LUMARA with all features.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your data will be preserved when you sign in.',
                      style: TextStyle(fontSize: 14, color: Colors.purple),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/sign-in');
            },
            child: const Text('Sign in with Email'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              // Attempt Google sign-in with account linking
              try {
                final result = await FirebaseAuthService.instance.signInWithGoogle();
                if (result != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully signed in! You can continue using LUMARA.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign-in failed: $e'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.account_circle, size: 20),
            label: const Text('Continue with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _startNewChat() async {
    // Dismiss keyboard and clear input
    _dismissKeyboard();
    _messageController.clear();
    
    // Start new chat (saves old chat to history)
    await context.read<LumaraAssistantCubit>().startNewChat();
  }

  void _clearChat() async {
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will clear all messages in the current chat. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    // Second confirmation
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'All conversation history will be permanently deleted. This action is irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Clear Everything'),
          ),
        ],
      ),
    );

    if (secondConfirm == true) {
      if (mounted) {
        context.read<LumaraAssistantCubit>().clearChat();
      }
    }
  }


  void _showQuickPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const LumaraQuickPalette(),
    );
  }


  void _showEnhancedSettings() {
    // Dismiss keyboard first
    _dismissKeyboard();
    
    // Get the cubit instance to pass to settings
    final cubit = context.read<LumaraAssistantCubit>();
    
    // Navigate directly to settings screen with the same cubit instance
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider<LumaraAssistantCubit>.value(
          value: cubit,
          child: const LumaraSettingsScreen(),
        ),
      ),
    );
  }

  /// Get current session ID from cubit
  Future<String?> _getCurrentSessionId() async {
    try {
      final cubit = context.read<LumaraAssistantCubit>();
      return cubit.currentChatSessionId;
    } catch (e) {
      return null;
    }
  }

  /// Check if chat is saved
  Future<bool> _isChatSaved(String sessionId) async {
    try {
      await FavoritesService.instance.initialize();
      final favorite = await FavoritesService.instance.findFavoriteChatBySessionId(sessionId);
      return favorite != null;
    } catch (e) {
      return false;
    }
  }

  /// Toggle save chat
  Future<void> _toggleSaveChat(String sessionId) async {
    try {
      await FavoritesService.instance.initialize();
      final isSaved = await _isChatSaved(sessionId);
      
      if (isSaved) {
        // Unsave chat
        final favorite = await FavoritesService.instance.findFavoriteChatBySessionId(sessionId);
        if (favorite != null) {
          await FavoritesService.instance.removeFavorite(favorite.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chat unsaved'),
                duration: Duration(seconds: 2),
              ),
            );
            setState(() {}); // Refresh UI
          }
        }
      } else {
        // Save chat
        final isAtCapacity = await FavoritesService.instance.isCategoryAtCapacity('chat');
        if (isAtCapacity) {
          _showChatCapacityPopup();
          return;
        }

        // Get all messages from cubit state
        final cubit = context.read<LumaraAssistantCubit>();
        final state = cubit.state;
        if (state is LumaraAssistantLoaded) {
          final conversationText = state.messages.map((msg) {
            final role = msg.role == LumaraMessageRole.user ? 'User' : 'LUMARA';
            return '$role: ${msg.content}';
          }).join('\n\n');

          final favorite = LumaraFavorite.fromChatSession(
            sessionId: sessionId,
            content: 'Chat Session\n\n$conversationText',
            sourceId: sessionId,
            metadata: {
              'messageCount': state.messages.length,
            },
          );

          final added = await FavoritesService.instance.addSavedChat(favorite);
          if (added && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chat saved'),
                duration: Duration(seconds: 2),
              ),
            );
            setState(() {}); // Refresh UI
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot save chat - at capacity (20/20)'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error toggling save chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showChatCapacityPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Chats Full'),
        content: const Text(
          'You have reached the maximum of 20 saved chats. Please remove some saved chats before adding new ones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesManagementView(),
                ),
              );
            },
            child: const Text('Manage Favorites'),
          ),
        ],
      ),
    );
  }


  /// Handle attribution weight changes
  /// Check if message has web sources
  bool _hasWebSource(LumaraMessage message) {
    // Check attribution traces for web references
    if (message.attributionTraces != null && message.attributionTraces!.isNotEmpty) {
      // Check if any trace mentions web or external source
      for (final trace in message.attributionTraces!) {
        final nodeRef = trace.nodeRef.toLowerCase();
        if (nodeRef.contains('web') || 
            nodeRef.contains('external') || 
            nodeRef.contains('search') ||
            trace.relation.toLowerCase().contains('web')) {
          return true;
        }
      }
    }
    
    // Check sources list
    for (final source in message.sources) {
      if (source.toLowerCase().contains('web') || 
          source.toLowerCase().contains('external') ||
          source.toLowerCase().contains('search')) {
        return true;
      }
    }
    
    // Check metadata
    if (message.metadata.containsKey('web_search') || 
        message.metadata.containsKey('external_source')) {
      return true;
    }
    
    return false;
  }

  void _handleAttributionWeightChange(String messageId, AttributionTrace trace, double newWeight) {
    // TODO: Implement weight change logic
    // This would update the memory influence in real-time
    print('Weight changed for memory ${trace.nodeRef}: ${(newWeight * 100).toStringAsFixed(0)}%');
  }

  /// Build paragraphs from content text with improved mobile readability
  List<Widget> _buildParagraphs(String content, TextStyle textStyle) {
    if (content.trim().isEmpty) {
      return [const SizedBox.shrink()];
    }

    // Split by double newlines first (explicit paragraphs)
    List<String> paragraphs = content.split('\n\n');
    
    // Clean up paragraphs - remove single newlines within paragraphs
    paragraphs = paragraphs.map((p) => p.replaceAll('\n', ' ').trim()).toList();
    
    // If no double newlines, try splitting by single newlines
    if (paragraphs.length == 1 && content.contains('\n')) {
      paragraphs = content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    
    // If still single paragraph and it's long, split by sentence endings for better readability
    if (paragraphs.length == 1 && content.length > 150) {
      // Split by periods/exclamation/question marks followed by space and capital letter
      // This creates natural paragraph breaks for long responses
      final sentencePattern = RegExp(r'([.!?])\s+([A-Z])');
      final matches = sentencePattern.allMatches(content);
      
      if (matches.length >= 2) {
        // Extract all sentences
        final sentences = <String>[];
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            final sentence = content.substring(lastIndex, match.start + 1).trim();
            if (sentence.isNotEmpty) {
              sentences.add(sentence);
            }
            lastIndex = match.start + 1;
          }
        }
        if (lastIndex < content.length) {
          final remaining = content.substring(lastIndex).trim();
          if (remaining.isNotEmpty) {
            sentences.add(remaining);
          }
        }
        
        // Group sentences into paragraphs (2-3 sentences per paragraph for readability)
        paragraphs = [];
        for (int i = 0; i < sentences.length; i += 3) {
          final endIndex = (i + 3 < sentences.length) ? i + 3 : sentences.length;
          final paragraphGroup = sentences.sublist(i, endIndex).join(' ');
          paragraphs.add(paragraphGroup);
        }
      }
    }
    
    // If still a single very long paragraph (no sentence breaks found), split by length
    if (paragraphs.length == 1 && content.length > 300) {
      // Split into chunks of ~200 characters at natural word boundaries
      final words = content.split(' ');
      paragraphs = [];
      String currentParagraph = '';
      
      for (final word in words) {
        if ((currentParagraph + word).length > 200 && currentParagraph.isNotEmpty) {
          paragraphs.add(currentParagraph.trim());
          currentParagraph = word;
        } else {
          currentParagraph += (currentParagraph.isEmpty ? '' : ' ') + word;
        }
      }
      if (currentParagraph.trim().isNotEmpty) {
        paragraphs.add(currentParagraph.trim());
      }
    }

    // Filter out empty paragraphs and build widgets with improved spacing
    final widgets = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: i < paragraphs.length - 1 ? 12 : 0),
            child: Text(
              paragraph,
              style: textStyle,
            ),
          ),
        );
      }
    }

    return widgets.isEmpty ? [
      Text(
        content,
        style: textStyle,
      )
    ] : widgets;
  }

  /// Handle memory exclusion
  void _handleMemoryExclusion(String messageId, AttributionTrace trace) {
    // TODO: Implement memory exclusion logic
    // This would exclude the memory from future responses
    print('Memory excluded: ${trace.nodeRef}');
  }

  /// Get enhanced attribution trace for a response
  Future<EnhancedResponseTrace?> _getEnhancedAttributionTrace(String messageId) async {
    try {
      return _enhancedAttributionService.getEnhancedResponseTrace(messageId);
    } catch (e) {
      print('Error getting enhanced attribution trace: $e');
      return null;
    }
  }

  /// Build enhanced attribution display widget
  Widget _buildEnhancedAttributionDisplay(
    EnhancedResponseTrace enhancedTrace,
    String messageId,
    List<AttributionTrace> legacyTraces,
  ) {
    return EnhancedAttributionDisplayWidget(
      responseTrace: enhancedTrace,
      responseId: messageId,
      onWeightChanged: (trace, newWeight) {
        _handleEnhancedAttributionWeightChange(messageId, trace, newWeight);
      },
      onExcludeMemory: (trace) {
        _handleEnhancedMemoryExclusion(messageId, trace);
      },
      onRequestExplanation: () {
        _showAttributionExplanationDialog(enhancedTrace);
      },
    );
  }

  /// Handle enhanced attribution weight change
  void _handleEnhancedAttributionWeightChange(
    String messageId,
    EnhancedAttributionTrace trace,
    double newWeight,
  ) {
    // TODO: Implement enhanced weight change logic
    print('Enhanced attribution weight changed for ${trace.nodeRef}: $newWeight');
  }

  /// Handle enhanced memory exclusion
  void _handleEnhancedMemoryExclusion(String messageId, EnhancedAttributionTrace trace) {
    // TODO: Implement enhanced memory exclusion logic
    print('Enhanced memory excluded: ${trace.nodeRef} (${trace.sourceType.name})');
  }

  /// Show attribution explanation dialog
  void _showAttributionExplanationDialog(EnhancedResponseTrace trace) {
    final explanation = LumaraAttributionExplainer.generateAttributionExplanation(
      responseTrace: trace,
      includeDetailedBreakdown: true,
      includeConfidenceScores: true,
      includeCrossReferences: true,
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, size: 20),
              SizedBox(width: 8),
              Text('Attribution Explanation'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                explanation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showAttributionSystemInfo();
              },
              child: const Text('Learn More'),
            ),
          ],
        );
      },
    );
  }

  /// Show attribution system information
  void _showAttributionSystemInfo() {
    final systemInfo = LumaraAttributionExplainer.generateAttributionSystemPrompt();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 8),
              Text('About Attribution System'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                systemInfo,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Handler methods for action buttons
  Future<void> _handleRegenerate(LumaraMessage message) async {
    if (message.role != LumaraMessageRole.assistant) return;
    
    // Get current entry for context
    JournalEntry? entryToUse = _currentEntry;
    if (entryToUse == null) {
      entryToUse = await _getMostRecentEntry();
    }
    
    // Map persona to conversation mode
    models.ConversationMode? personaMode = _personaToConversationMode(_selectedPersona);
    
    // Send explicit regenerate instruction that references the previous message
    context.read<LumaraAssistantCubit>().sendMessage(
      'Please regenerate your previous response using a different approach, tone, or perspective while maintaining the same core insights.',
      currentEntry: entryToUse,
      conversationMode: personaMode, // Use persona mode for regenerate
      persona: _selectedPersona,
    );
    
    _messageController.clear();
  }

  Future<void> _handleSoftenTone(LumaraMessage message) async {
    if (message.role != LumaraMessageRole.assistant) return;
    
    // Get current entry for context
    JournalEntry? entryToUse = _currentEntry;
    if (entryToUse == null) {
      entryToUse = await _getMostRecentEntry();
    }
    
    // Send explicit instruction to soften tone
    context.read<LumaraAssistantCubit>().sendMessage(
      'Please rephrase your previous response with a softer, more gentle tone while keeping the same insights.',
      currentEntry: entryToUse,
      conversationMode: null,
      persona: _selectedPersona,
    );
    
    _messageController.clear();
  }

  Future<void> _handleMoreDepth(LumaraMessage message) async {
    if (message.role != LumaraMessageRole.assistant) return;
    
    // Get current entry for context
    JournalEntry? entryToUse = _currentEntry;
    if (entryToUse == null) {
      entryToUse = await _getMostRecentEntry();
    }
    
    // Send explicit instruction for more depth
    context.read<LumaraAssistantCubit>().sendMessage(
      'Please provide more depth and detail on the topic from your previous response. Explore the underlying patterns, connections, and implications.',
      currentEntry: entryToUse,
      conversationMode: models.ConversationMode.reflectDeeply,
      persona: _selectedPersona,
    );
    
    _messageController.clear();
  }

  void _handleExploreConversation(LumaraMessage message) {
    if (message.role != LumaraMessageRole.assistant) return;
    // This is already in a chat, so just focus the input
    _inputFocusNode.requestFocus();
  }

  /// Show chat message options menu (matching journal UI)
  void _showChatMessageOptions(BuildContext context, LumaraMessage message) {
    if (message.role != LumaraMessageRole.assistant) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Default options
            ListTile(
              leading: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
              title: const Text('Regenerate'),
              onTap: () {
                Navigator.pop(context);
                _handleRegenerate(message);
              },
            ),
            ListTile(
              leading: Icon(Icons.insights, color: Theme.of(context).colorScheme.primary),
              title: const Text('Reflect more deeply'),
              onTap: () {
                Navigator.pop(context);
                _handleReflectDeeply(message);
              },
            ),
            ListTile(
              leading: Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
              title: const Text('Suggest ideas'),
              onTap: () {
                Navigator.pop(context);
                _handleConversationMode(message, models.ConversationMode.ideas);
              },
            ),
            const Divider(),
            // More options
            ListTile(
              leading: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.primary),
              title: const Text('More options'),
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onTap: () {
                Navigator.pop(context);
                _showMoreOptions(context, message);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show more options (matching journal "Explore options")
  void _showMoreOptions(BuildContext context, LumaraMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Explore options',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Options
            ListTile(
              leading: Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary),
              title: const Text('Continue thought'),
              onTap: () {
                Navigator.pop(context);
                _continueAssistantThought(message);
              },
            ),
            ListTile(
              leading: Icon(Icons.psychology, color: Theme.of(context).colorScheme.primary),
              title: const Text('Analyze, Interpret, Suggest Actions'),
              onTap: () {
                Navigator.pop(context);
                _handleConversationMode(message, models.ConversationMode.think);
              },
            ),
            ListTile(
              leading: Icon(Icons.visibility, color: Theme.of(context).colorScheme.primary),
              title: const Text('Offer a different perspective'),
              onTap: () {
                Navigator.pop(context);
                _handleConversationMode(message, models.ConversationMode.perspective);
              },
            ),
            ListTile(
              leading: Icon(Icons.navigate_next, color: Theme.of(context).colorScheme.primary),
              title: const Text('Suggest next steps'),
              onTap: () {
                Navigator.pop(context);
                _handleConversationMode(message, models.ConversationMode.nextSteps);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Handle conversation mode selection
  Future<void> _handleConversationMode(LumaraMessage message, models.ConversationMode mode) async {
    if (message.role != LumaraMessageRole.assistant) return;
    
    // Get current entry for context
    JournalEntry? entryToUse = _currentEntry;
    if (entryToUse == null) {
      entryToUse = await _getMostRecentEntry();
    }
    
    // Map conversation mode to explicit action-oriented instruction
    // These instructions reference the previous message and request specific actions
    String actionInstruction;
    switch (mode) {
      case models.ConversationMode.ideas:
        actionInstruction = 'Based on your previous response, please suggest some practical ideas I can explore.';
        break;
      case models.ConversationMode.think:
        actionInstruction = 'Please analyze the topic from your previous response, interpret the key points, and suggest concrete actions I can take.';
        break;
      case models.ConversationMode.perspective:
        actionInstruction = 'Please offer a different perspective on what you discussed in your previous response.';
        break;
      case models.ConversationMode.nextSteps:
        actionInstruction = 'Based on your previous response, what are the specific next steps I should consider?';
        break;
      case models.ConversationMode.reflectDeeply:
        actionInstruction = 'Please reflect more deeply on the themes and insights from your previous response. Explore the underlying patterns and connections.';
        break;
      case models.ConversationMode.continueThought:
        actionInstruction = 'Please continue your previous thought exactly where it left off.';
        break;
    }
    
    // Get persona string (already a string)
    final personaString = _selectedPersona;
    
    // Send with explicit instruction, conversation mode, and persona
    context.read<LumaraAssistantCubit>().sendMessage(
      actionInstruction,
      currentEntry: entryToUse,
      conversationMode: mode,
      persona: personaString,
    );
    
    _messageController.clear();
  }
  
  /// Map persona string to conversation mode
  /// The enhanced API uses conversation modes to determine persona
  models.ConversationMode? _personaToConversationMode(String persona) {
    switch (persona) {
      case 'companion':
        return null; // Default - no mode needed
      case 'strategist':
        return models.ConversationMode.think; // Think through maps to strategist
      case 'therapist':
        return models.ConversationMode.reflectDeeply; // Reflect deeply maps to therapist
      case 'challenger':
        return models.ConversationMode.perspective; // Different perspective maps to challenger
      default:
        return null;
    }
  }
  
  // Removed _personaToString method - persona is already a string

  /// Handle reflect deeply
  Future<void> _handleReflectDeeply(LumaraMessage message) async {
    await _handleConversationMode(message, models.ConversationMode.reflectDeeply);
  }

  /// Send message with conversation mode
  /// NOTE: This method is now primarily used by _handleConversationMode
  /// which constructs explicit instructions. This is kept for backward compatibility.
  Future<void> _sendCurrentMessageWithMode(models.ConversationMode mode) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    // Get current entry for context
    JournalEntry? entryToUse = _currentEntry;
    if (entryToUse == null) {
      entryToUse = await _getMostRecentEntry();
    }
    
    // Get persona string (already a string)
    final personaString = _selectedPersona;
    
    // Send with conversation mode and persona
    context.read<LumaraAssistantCubit>().sendMessage(
      text,
      currentEntry: entryToUse,
      conversationMode: mode,
      persona: personaString,
    );
    
    _messageController.clear();
  }

  /// Fork chat from a specific message
  Future<void> _forkChatFromMessage(LumaraMessage message) async {
    if (message.role != LumaraMessageRole.assistant) return;

    final cubit = context.read<LumaraAssistantCubit>();
    final newSessionId = await cubit.forkChatFromMessage(message.id);

    if (newSessionId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat forked - exploring new direction'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Load a specific chat session
  Future<void> _loadSession(String sessionId) async {
    final cubit = context.read<LumaraAssistantCubit>();
    // TODO: Implement session loading in cubit
    // For now, we'll need to add a method to load a session
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session loading not yet implemented')),
    );
  }

  /// Load or create scratchpad session
  Future<void> _loadScratchpad() async {
    // TODO: Implement scratchpad - a special session for quick notes
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scratchpad not yet implemented')),
    );
  }

  /// Load or create sandbox session
  Future<void> _loadSandbox() async {
    // TODO: Implement sandbox - a special session for experimentation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sandbox not yet implemented')),
    );
  }

  /// Build breadcrumb widget for forked chats
  Widget _buildForkBreadcrumb(BuildContext context, String sessionId) {
    return FutureBuilder<ChatSession?>(
      future: EnhancedChatRepoImpl(ChatRepoImpl.instance).getSession(sessionId),
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session?.metadata == null || session!.metadata!['forkedFrom'] == null) {
          return const SizedBox.shrink();
        }

        final forkedFrom = session.metadata!['forkedFrom'] as String;
        final originalSubject = session.metadata!['originalSessionSubject'] as String? ?? 'Original Chat';
        final forkedAt = session.metadata!['forkedAt'] as String?;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: InkWell(
            onTap: () => _navigateToOriginalChat(forkedFrom),
            child: Row(
              children: [
                Icon(
                  Icons.call_split,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Forked from: $originalSubject',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (forkedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatForkTime(forkedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatForkTime(String isoString) {
    try {
      final forkedAt = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(forkedAt);

      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return '';
    }
  }

  /// Navigate to original chat session
  Future<void> _navigateToOriginalChat(String originalSessionId) async {
    // Load the original session
    await _loadSession(originalSessionId);
  }
}
