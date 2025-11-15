import 'package:my_app/arc/chat/ui/widgets/health_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import '../bloc/lumara_assistant_cubit.dart';
import '../data/models/lumara_message.dart';
import '../chat/ui/enhanced_chats_screen.dart';
import '../chat/enhanced_chat_repo_impl.dart';
import '../chat/chat_repo_impl.dart';
import 'lumara_quick_palette.dart';
import 'lumara_settings_screen.dart';
import '../widgets/attribution_display_widget.dart';
import 'package:my_app/polymeta/memory/enhanced_memory_schema.dart';
import '../config/api_config.dart';
import '../voice/voice_chat_service.dart';
import 'voice_chat_panel.dart';
import '../voice/voice_permissions.dart';
import '../data/context_provider.dart';
import '../data/context_scope.dart';
import '../services/enhanced_lumara_api.dart';
import '../../../telemetry/analytics.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';

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
  
  // Voice chat service
  VoiceChatService? _voiceChatService;
  String? _partialTranscript;

  @override
  void initState() {
    super.initState();
    // Store current entry from widget
    _currentEntry = widget.currentEntry;
    _checkAIConfigurationAndInitialize();
    _inputFocusNode.addListener(_onInputFocusChange);
    _initializeVoiceChat();
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
    _voiceChatService?.dispose();
    super.dispose();
  }

  /// Initialize voice chat service
  Future<void> _initializeVoiceChat() async {
    try {
      final cubit = context.read<LumaraAssistantCubit>();
      final contextProvider = ContextProvider(LumaraScope.defaultScope);
      
      // Get EnhancedLumaraApi from cubit (access via private field workaround)
      // For now, create a new instance
      final enhancedApi = EnhancedLumaraApi(Analytics());
      await enhancedApi.initialize();
      
      _voiceChatService = VoiceChatService(
        lumaraApi: enhancedApi,
        journalCubit: null, // Not needed for chat screen
        chatCubit: cubit,
        contextProvider: contextProvider,
      );
      
      final initialized = await _voiceChatService!.initialize();
      if (!initialized && mounted) {
        debugPrint('Voice chat initialization failed - permissions may be denied');
      }
      
      // Listen to partial transcript stream
      _voiceChatService!.partialTranscriptStream.listen((transcript) {
        if (mounted) {
          setState(() {
            _partialTranscript = transcript;
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing voice chat: $e');
    }
  }

  /// Show voice chat panel
  void _showVoiceChatPanel() {
    if (_voiceChatService == null || _voiceChatService!.controller == null) {
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
        child: VoiceChatPanel(
          controller: _voiceChatService!.controller!,
          diagnostics: _voiceChatService!.diagnostics,
          partialTranscript: _partialTranscript,
        ),
      ),
    );
  }

  /// Request voice permissions
  Future<void> _requestVoicePermissions() async {
    final permState = await VoicePermissions.request();
    if (permState == VoicePermState.allGranted) {
      await _initializeVoiceChat();
      if (_voiceChatService != null && _voiceChatService!.controller != null) {
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

  void _scrollToBottom() {
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

  void _dismissKeyboard() {
    // Multiple methods to ensure keyboard is dismissed
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    
    // Also try to remove focus from any text field
    FocusManager.instance.primaryFocus?.unfocus();
    
    // Hide input area when dismissing keyboard (if text is empty)
    setState(() {
      if (_messageController.text.isEmpty) {
        _isInputVisible = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Assistant'),
        automaticallyImplyLeading: false, // Remove back button since this is a tab
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _startNewChat(),
            tooltip: 'New Chat',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showEnhancedSettings(),
            tooltip: 'API Settings',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnhancedChatsScreen(
                  chatRepo: EnhancedChatRepoImpl(ChatRepoImpl.instance),
                ),
              ),
            ),
            tooltip: 'Chat History',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => _clearChat(),
            tooltip: 'Clear Chat',
          ),
        ],
      ),
              body: GestureDetector(
                onTap: () {
                  // Dismiss keyboard and hide input when tapping conversation area
                  _dismissKeyboard();
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    // Messages list
                    Expanded(
            child: GestureDetector(
              onTap: () {
                // Hide input when tapping conversation area
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
                }
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
                  return Column(
                    children: [
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
                  );
                }
                
              return const SizedBox.shrink();
              },
            ),
            ),
          ),
          
          // Message input - show/hide based on visibility state
          // Also show a button to bring it back if hidden
          if (_isInputVisible)
            _buildMessageInput()
          else
            _buildShowInputButton(),
        ],
      ),
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
            onTap: () => _sendMessage(suggestion),
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
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.psychology, size: 16, color: Colors.blue[700]),
            ),
            const Gap(8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[500] : Colors.grey[100],
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        const Spacer(),
                        // Copy and delete buttons in header (unified with in-journal UX)
                        IconButton(
                          icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _copyMessage(message.content),
                          tooltip: 'Copy',
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _deleteMessage(message),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Format content into paragraphs for better readability (especially for assistant messages)
                  if (isUser)
                    Text(
                      message.content,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  else
                    ..._buildParagraphs(
                      message.content,
                      TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        height: 1.6, // Increased line height for better mobile readability
                      ),
                    ),
                  
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
                  
                  // Attribution display for assistant messages
                  if (!isUser && message.attributionTraces != null && message.attributionTraces!.isNotEmpty) ...[
                    const Gap(8),
                    Builder(
                      builder: (context) {
                        print('LumaraAssistantScreen: Rendering AttributionDisplayWidget for message ${message.id} with ${message.attributionTraces!.length} traces');
                        return AttributionDisplayWidget(
                          traces: message.attributionTraces!,
                          responseId: message.id,
                          onWeightChanged: (trace, newWeight) {
                            // Handle weight change
                            _handleAttributionWeightChange(message.id, trace, newWeight);
                          },
                          onExcludeMemory: (trace) {
                            // Handle memory exclusion
                            _handleMemoryExclusion(message.id, trace);
                          },
                        );
                      },
                    ),
                  ] else if (!isUser) ...[
                    // Debug: Show why attributions aren't showing
                    Builder(
                      builder: (context) {
                        print('LumaraAssistantScreen: Message ${message.id} - attributionTraces is null or empty (null: ${message.attributionTraces == null}, empty: ${message.attributionTraces?.isEmpty ?? true})');
                        return const SizedBox.shrink();
                      },
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
            children: [
              IconButton(
                icon: const Icon(Icons.favorite, size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Health',
                onPressed: _showHealthPreview,
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
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
                    onSubmitted: (_) => _sendCurrentMessage(),
                    onTap: () {
                      // Ensure input is visible when tapped
                      setState(() => _isInputVisible = true);
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: _sendCurrentMessage,
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

  void _sendCurrentMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      if (_editingMessageId != null) {
        _resubmitMessage(_editingMessageId!, text);
      } else {
        _sendMessage(text);
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

  void _resubmitMessage(String messageId, String newText) {
    // Update the cubit to remove messages after the edited one
    context.read<LumaraAssistantCubit>().editAndResubmitMessage(messageId, newText);
    
    // Send the edited message
    _sendMessage(newText);
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

  void _deleteMessage(LumaraMessage message) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<LumaraAssistantCubit>().deleteMessage(message.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
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

  void _sendMessage(String message) {
    // Get current entry - prioritize widget's currentEntry, then try to get most recent entry
    JournalEntry? entryToUse = _currentEntry;
    
    // If no entry provided, try to get the most recent entry as fallback
    // This ensures we always have context from the user's journal
    if (entryToUse == null) {
      entryToUse = _getMostRecentEntry();
      if (entryToUse != null) {
        print('LUMARA: Using most recent entry ${entryToUse.id} as context');
      }
    } else {
      print('LUMARA: Using provided current entry ${entryToUse.id} as context');
    }
    
    // Note: If entryToUse is still null, sendMessage will work without current entry
    // The weighted context system will still use recent LUMARA responses and other entries
    context.read<LumaraAssistantCubit>().sendMessage(message, currentEntry: entryToUse);
  }
  
  /// Get the most recent journal entry as fallback for context
  /// This ensures LUMARA always has access to the user's latest journal content
  JournalEntry? _getMostRecentEntry() {
    try {
      final journalRepository = JournalRepository();
      final allEntries = journalRepository.getAllJournalEntries();
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

  /// Handle attribution weight changes
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
    
    // If still single paragraph, try splitting by sentence endings for better readability
    if (paragraphs.length == 1) {
      // Split by periods/exclamation/question marks followed by space and capital letter
      // This creates natural paragraph breaks for long responses
      final sentencePattern = RegExp(r'([.!?])\s+([A-Z])');
      final matches = sentencePattern.allMatches(content);
      
      if (matches.length >= 2) {
        paragraphs = [];
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            final sentence = content.substring(lastIndex, match.start + 1).trim();
            if (sentence.isNotEmpty) {
              paragraphs.add(sentence);
            }
            lastIndex = match.start + 1;
          }
        }
        if (lastIndex < content.length) {
          final remaining = content.substring(lastIndex).trim();
          if (remaining.isNotEmpty) {
            paragraphs.add(remaining);
          }
        }
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

}