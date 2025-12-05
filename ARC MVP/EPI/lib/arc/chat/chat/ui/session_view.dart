import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import '../../bloc/lumara_assistant_cubit.dart';
import '../../data/context_provider.dart';
import '../../data/context_scope.dart';
import '../../services/favorites_service.dart';
import '../../data/models/lumara_favorite.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';
import '../../voice/audio_io.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';

// Real context provider for SessionView that respects scope
class SessionContextProvider extends ContextProvider {
  SessionContextProvider(LumaraScope scope) : super(scope);
  
  // This will use the real ContextProvider implementation
  // which respects the scope settings for journal, phase, arcforms, etc.
}

// App lifecycle observer for auto-save
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback? onPaused;
  final VoidCallback? onDetached;

  _AppLifecycleObserver({this.onPaused, this.onDetached});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        onPaused?.call();
        break;
      case AppLifecycleState.detached:
        onDetached?.call();
        break;
      default:
        break;
    }
  }
}

class SessionView extends StatefulWidget {
  final String sessionId;
  final ChatRepo chatRepo;

  const SessionView({
    Key? key,
    required this.sessionId,
    required this.chatRepo,
  }) : super(key: key);

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  ChatSession? _session;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;
  String? _editingMessageId; // Track which message is being edited
  bool _isChatSaved = false;
  
  LumaraAssistantCubit? _lumaraCubit;
  LumaraScope _scope = LumaraScope.defaultScope;
  AudioIO? _audioIO;
  final FavoritesService _favoritesService = FavoritesService.instance;

  @override
  void initState() {
    super.initState();
    _initializeLumaraCubit();
    _loadSession();
    _setupAutoSave();
    _initializeAudioIO();
    _checkIfChatSaved();
  }

  Future<void> _checkIfChatSaved() async {
    if (widget.sessionId.isEmpty) return;
    try {
      await _favoritesService.initialize();
      final isSaved = await _favoritesService.isChatSaved(widget.sessionId);
      if (mounted) {
        setState(() {
          _isChatSaved = isSaved;
        });
      }
    } catch (e) {
      print('Error checking if chat is saved: $e');
    }
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _lumaraCubit?.close();
    super.dispose();
  }

  Future<void> _initializeLumaraCubit() async {
    _lumaraCubit = LumaraAssistantCubit(
      contextProvider: SessionContextProvider(_scope),
    );
    await _lumaraCubit!.initialize();
  }

  void _setupAutoSave() {
    // Auto-save on app lifecycle changes
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(
      onPaused: () => _lumaraCubit?.autoSaveConversation(),
      onDetached: () => _lumaraCubit?.autoSaveConversation(),
    ));
  }

  Future<void> _loadSession() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      var session = await widget.chatRepo.getSession(widget.sessionId);
      
      // If session doesn't exist, try to restore it from archived or recreate from saved chat
      if (session == null) {
        // Check if it's in archived sessions
        final allSessions = await widget.chatRepo.listAll(includeArchived: true);
        try {
          session = allSessions.firstWhere(
            (s) => s.id == widget.sessionId,
          );
          
          // If it's archived, restore it automatically
          if (session.isArchived) {
            await widget.chatRepo.archiveSession(session.id, false);
            // Reload to get updated session
            session = await widget.chatRepo.getSession(widget.sessionId);
          }
        } catch (_) {
          // Session not found in active or archived - try to recreate from saved chat
          session = await _tryRecreateSessionFromSavedChat();
          if (session == null) {
            throw Exception('Session not found and could not be recreated from saved chat');
          }
        }
      }

      // Load messages using the actual session ID (may differ from widget.sessionId if recreated)
      // At this point, session is guaranteed to be non-null (exception thrown if recreation fails)
      final messages = await widget.chatRepo.getMessages(session!.id);
      
      setState(() {
        _session = session;
        _messages = messages;
        _isLoading = false;
      });
      
      // Check if chat is saved after loading session
      _checkIfChatSaved();
    } catch (e) {
      setState(() {
        _error = 'Session not found. It may have been deleted.';
        _isLoading = false;
      });
    }
  }

  /// Try to recreate a session from a saved chat favorite
  Future<ChatSession?> _tryRecreateSessionFromSavedChat() async {
    try {
      final favoritesService = FavoritesService.instance;
      await favoritesService.initialize();
      
      // Find saved chat with matching session ID
      final savedChats = await favoritesService.getSavedChats();
      final savedChat = savedChats.firstWhere(
        (fav) => fav.sessionId == widget.sessionId,
        orElse: () => throw Exception('Saved chat not found'),
      );
      
      print('🔄 SessionView: Attempting to recreate session ${widget.sessionId} from saved chat');
      
      // Parse the saved chat content to extract subject and messages
      final content = savedChat.content;
      String subject = 'Restored Chat';
      final messages = <Map<String, String>>[];
      
      // Parse content format: "Chat: {subject}\n\nUser: {msg}\n\nLUMARA: {msg}\n\n..."
      if (content.startsWith('Chat Session\n\n') || content.startsWith('Chat:')) {
        final lines = content.split('\n');
        int lineIndex = 0;
        
        // Extract subject
        if (content.startsWith('Chat:')) {
          final subjectLine = lines[0];
          subject = subjectLine.replaceFirst('Chat:', '').trim();
          if (subject.isEmpty) subject = 'Restored Chat';
          lineIndex = 1; // Skip subject line
        } else if (content.startsWith('Chat Session\n\n')) {
          subject = 'Restored Chat';
          lineIndex = 2; // Skip "Chat Session" and empty line
        }
        
        // Parse messages
        String? currentRole;
        String? currentContent;
        
        for (int i = lineIndex; i < lines.length; i++) {
          final line = lines[i].trim();
          
          if (line.isEmpty) {
            // Empty line - save current message if any
            if (currentRole != null && currentContent != null && currentContent.isNotEmpty) {
              messages.add({
                'role': currentRole,
                'content': currentContent.trim(),
              });
              currentRole = null;
              currentContent = null;
            }
            continue;
          }
          
          if (line.startsWith('User:') || line.startsWith('LUMARA:')) {
            // Save previous message if any
            if (currentRole != null && currentContent != null && currentContent.isNotEmpty) {
              messages.add({
                'role': currentRole,
                'content': currentContent.trim(),
              });
            }
            
            // Start new message
            if (line.startsWith('User:')) {
              currentRole = 'user';
              currentContent = line.replaceFirst('User:', '').trim();
            } else if (line.startsWith('LUMARA:')) {
              currentRole = 'assistant';
              currentContent = line.replaceFirst('LUMARA:', '').trim();
            }
          } else if (currentRole != null) {
            // Continuation of current message
            if (currentContent != null) {
              currentContent += '\n$line';
            } else {
              currentContent = line;
            }
          }
        }
        
        // Save last message if any
        if (currentRole != null && currentContent != null && currentContent.isNotEmpty) {
          messages.add({
            'role': currentRole,
            'content': currentContent.trim(),
          });
        }
      }
      
      // Use metadata subject if available
      if (savedChat.metadata.containsKey('subject')) {
        subject = savedChat.metadata['subject'] as String? ?? subject;
      }
      
      print('🔄 SessionView: Recreating session "$subject" with ${messages.length} messages');
      
      // Create the session with the original ID
      final newSessionId = await widget.chatRepo.createSession(
        subject: subject,
        tags: [],
      );
      
      // If the new session ID doesn't match, we need to update the saved chat
      // But for now, let's try to use the original ID if possible
      // Actually, we can't control the session ID when creating, so we'll use the new one
      
      // Add all messages
      for (final msg in messages) {
        await widget.chatRepo.addMessage(
          sessionId: newSessionId,
          role: msg['role']!,
          content: msg['content']!,
        );
      }
      
      // Update the saved chat to point to the new session ID
      if (newSessionId != widget.sessionId) {
        print('⚠️ SessionView: Created new session $newSessionId (original: ${widget.sessionId})');
        // Update the favorite's sessionId by removing and re-adding
        await favoritesService.removeFavorite(savedChat.id);
        final updatedFavorite = savedChat.copyWith(sessionId: newSessionId);
        await favoritesService.addSavedChat(updatedFavorite);
      }
      
      // Get the created session
      final createdSession = await widget.chatRepo.getSession(newSessionId);
      print('✅ SessionView: Successfully recreated session $newSessionId');
      
      return createdSession;
    } catch (e) {
      print('❌ SessionView: Failed to recreate session from saved chat: $e');
      return null;
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending || _lumaraCubit == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      // If session is archived, restore it automatically when continuing conversation
      if (_session != null && _session!.isArchived) {
        await widget.chatRepo.archiveSession(widget.sessionId, false);
        // Reload session to get updated state
        await _loadSession();
      }
      
      // If editing, remove messages after the edited one
      if (_editingMessageId != null) {
        _resubmitMessage(_editingMessageId!, content);
        _editingMessageId = null;
      } else {
        // Set the current chat session ID in LUMARA cubit
        _lumaraCubit!.currentChatSessionId = widget.sessionId;
        
        // Send message through LUMARA assistant
        await _lumaraCubit!.sendMessage(content);
      }
      
      _messageController.clear();
      await _loadSession();
      
      // Only scroll to bottom after sending a new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _startEditingMessage(ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _messageController.text = message.textContent;
    });
    // Scroll to input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });
  }

  void _resubmitMessage(String messageId, String newText) async {
    // Find the index of the message being edited
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    // Remove all messages from this one onwards (including the assistant response)
    final messagesToKeep = _messages.sublist(0, messageIndex);
    
    // Update the message with new text (create a new message with updated content)
    final updatedMessage = ChatMessage.createText(
      sessionId: widget.sessionId,
      role: MessageRole.user,
      content: newText,
    );
    
    // Update local messages list
    setState(() {
      _messages = [...messagesToKeep, updatedMessage];
    });

    // Delete messages from database after the edited one
    try {
      for (int i = messageIndex; i < _messages.length; i++) {
        await widget.chatRepo.deleteMessage(_messages[i].id);
      }
    } catch (e) {
      print('Error deleting messages: $e');
    }

    // Set the current chat session ID in LUMARA cubit
    _lumaraCubit!.currentChatSessionId = widget.sessionId;
    
    // Send the edited message
    await _lumaraCubit!.sendMessage(newText);
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

  Future<void> _toggleFavorite(ChatMessage message) async {
    if (message.role != MessageRole.assistant) return;

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
          _showCapacityPopup();
          return;
        }

        final favorite = LumaraFavorite.fromMessage(
          content: message.textContent,
          sourceId: message.id,
          sourceType: 'chat',
          metadata: message.metadata ?? {},
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

  void _showCapacityPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Favorites Full'),
        content: const Text(
          'You have reached the maximum of 25 favorites. Please remove some favorites before adding new ones.',
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _toggleSaveChat() async {
    if (_session == null) return;

    try {
      await _favoritesService.initialize();
      
      if (_isChatSaved) {
        // Unsave chat
        final favorite = await _favoritesService.findFavoriteChatBySessionId(widget.sessionId);
        if (favorite != null) {
          await _favoritesService.removeFavorite(favorite.id);
          if (mounted) {
            setState(() {
              _isChatSaved = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chat unsaved'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // Save chat
        final isAtCapacity = await _favoritesService.isCategoryAtCapacity('chat');
        if (isAtCapacity) {
          _showChatCapacityPopup();
          return;
        }

        // Format all messages as conversation text
        final conversationText = _messages.map((msg) {
          final role = msg.role == MessageRole.user ? 'User' : 'LUMARA';
          return '$role: ${msg.textContent}';
        }).join('\n\n');

        final favorite = LumaraFavorite.fromChatSession(
          sessionId: widget.sessionId,
          content: 'Chat: ${_session!.subject}\n\n$conversationText',
          sourceId: widget.sessionId,
          metadata: {
            'subject': _session!.subject,
            'messageCount': _messages.length,
          },
        );

        final added = await _favoritesService.addSavedChat(favorite);
        if (added && mounted) {
          setState(() {
            _isChatSaved = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat saved'),
              duration: Duration(seconds: 2),
            ),
          );
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

  void _showSessionOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Session'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement edit session
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive Session'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement archive session
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Session'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement delete session
              },
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_session?.subject ?? 'Loading...'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_session != null) ...[
            IconButton(
              icon: Icon(
                _isChatSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isChatSaved ? const Color(0xFF2196F3) : null,
              ),
              onPressed: _toggleSaveChat,
              tooltip: _isChatSaved ? 'Unsave Chat' : 'Save Chat',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSessionOptions,
              tooltip: 'Chat Options',
            ),
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearChat,
              tooltip: 'Clear Chat',
            ),
          ],
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text field
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: _buildMessagesList(),
            ),

            // Message input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSession,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
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
              const SizedBox(height: 24),
              Text(
                'Ask LUMARA anything about your week',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Try asking about patterns, insights, or get a summary of your recent entries.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildQuickSuggestions(),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser && !isSystem) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[100],
              child: LumaraIcon(size: 16, color: Colors.blue[700]),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[500] : Colors.grey[100],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use paragraph formatting for LUMARA responses
                  if (!isUser && !isSystem)
                    ..._buildChatParagraphs(message.textContent)
                  else
                    Text(
                      message.textContent,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  
                  // Action buttons for user messages (edit/copy)
                  if (isUser && !isSystem) ...[
                    const SizedBox(height: 8),
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
                          onPressed: () => _copyMessage(message.textContent),
                          tooltip: 'Copy',
                        ),
                      ],
                    ),
                  ],
                  
                  // Copy, star, and delete buttons for assistant messages
                  if (!isUser && !isSystem) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _copyMessage(message.textContent),
                          tooltip: 'Copy',
                        ),
                        IconButton(
                          icon: Icon(Icons.volume_up, size: 16, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _speakMessage(message.textContent),
                          tooltip: 'Speak',
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
                        IconButton(
                          icon: Icon(
                            _isChatSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 16,
                            color: _isChatSaved ? const Color(0xFF2196F3) : Colors.grey[600],
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _toggleSaveChat,
                          tooltip: _isChatSaved ? 'Unsave Chat' : 'Save Chat',
                        ),
                      ],
                    ),
                    // Action buttons (same as in-journal LUMARA Answers)
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _ActionButton(
                          label: 'Regenerate',
                          icon: Icons.refresh,
                          onPressed: () => _handleRegenerate(message),
                        ),
                        _ActionButton(
                          label: 'Soften tone',
                          icon: Icons.favorite_outline,
                          onPressed: () => _handleSoftenTone(message),
                        ),
                        _ActionButton(
                          label: 'More depth',
                          icon: Icons.insights,
                          onPressed: () => _handleMoreDepth(message),
                        ),
                        _ActionButton(
                          label: 'Continue thought',
                          icon: Icons.play_arrow,
                          onPressed: () => _handleContinueThought(message),
                        ),
                        _ActionButton(
                          label: 'Explore LUMARA conversation options',
                          icon: Icons.chat,
                          onPressed: () => _handleExploreConversation(message),
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[500],
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final isEditing = _editingMessageId != null;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  const SizedBox(width: 8),
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
                icon: const Icon(Icons.mic),
                onPressed: () {
                  // TODO: Implement voice input
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: isEditing ? 'Edit your message...' : 'Ask LUMARA anything...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  minLines: 1,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const LumaraIcon(size: 20),
                onPressed: _isSending ? null : _sendMessage,
                tooltip: 'Send',
              ),
              IconButton(
                icon: const Icon(Icons.palette),
                onPressed: () {
                  // TODO: Implement quick palette
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear messages from the session
              _messages.clear();
              setState(() {});
              // TODO: Clear messages from database
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestions = [
      'What patterns do you see in my recent entries?',
      'How has my mood been this week?',
      'What should I focus on today?',
      'Summarize my week for me',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () {
            _messageController.text = suggestion;
            _sendMessage();
          },
        );
      }).toList(),
    );
  }

  /// Build paragraphs for chat messages using in-chat formatting rules:
  /// - Sentences: min 10 words
  /// - Paragraphs: min 3 sentences, max 5 sentences
  /// - Fallback: use simpler logic for smaller paragraphs
  List<Widget> _buildChatParagraphs(String content) {
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

    // If still single paragraph, apply in-chat formatting rules
    if (paragraphs.length == 1) {
      paragraphs = _formatInChatParagraphs(content);
    }

    // Filter out empty paragraphs and build widgets
    final widgets = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: i < paragraphs.length - 1 ? 12 : 0),
            child: Text(
              paragraph,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }

    return widgets.isEmpty ? [
      Text(
        content,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          height: 1.5,
        ),
      )
    ] : widgets;
  }

  /// Format content into paragraphs using in-chat rules:
  /// - Fixed: 3 sentences per paragraph
  List<String> _formatInChatParagraphs(String content) {
    final sentences = _extractChatSentences(content);

    if (sentences.length < 3) {
      // If less than 3 sentences, return as single paragraph
      return [content];
    }

    final paragraphs = <String>[];

    // Group every 3 sentences together
    for (int i = 0; i < sentences.length; i += 3) {
      final endIndex = (i + 3 < sentences.length) ? i + 3 : sentences.length;
      final paragraphSentences = sentences.sublist(i, endIndex);
      paragraphs.add(paragraphSentences.join(' '));
    }

    return paragraphs;
  }

  /// Extract sentences that meet minimum word requirements for chat
  List<String> _extractValidChatSentences(String text, {required int minWords}) {
    final allSentences = _extractChatSentences(text);
    final validSentences = <String>[];

    for (final sentence in allSentences) {
      final wordCount = sentence.trim().split(RegExp(r'\s+')).length;
      if (wordCount >= minWords) {
        validSentences.add(sentence);
      } else {
        // If sentence is too short, try to combine with previous sentence
        if (validSentences.isNotEmpty) {
          final lastSentence = validSentences.removeLast();
          final combined = '$lastSentence $sentence';
          validSentences.add(combined);
        } else {
          // Keep short sentence as is if it's the first one
          validSentences.add(sentence);
        }
      }
    }

    return validSentences;
  }

  /// Fallback to simpler grouping for chat edge cases
  List<String> _fallbackToChatGrouping(String content) {
    final sentences = _extractChatSentences(content);

    if (sentences.length >= 2) {
      final paragraphs = <String>[];

      // Group every 3 sentences together for chat (larger groups than journal)
      for (int i = 0; i < sentences.length; i += 3) {
        final endIndex = (i + 3 < sentences.length) ? i + 3 : sentences.length;
        final paragraphSentences = sentences.sublist(i, endIndex);
        paragraphs.add(paragraphSentences.join(' '));
      }

      return paragraphs;
    }

    return [content];
  }

  /// Extract sentences for chat formatting
  List<String> _extractChatSentences(String text) {
    if (text.trim().isEmpty) return [];

    final sentences = <String>[];

    // Enhanced sentence pattern that handles:
    // - Standard endings: . ! ?
    // - Quotes and parentheses: "Hello." or (end).
    // - Abbreviations: handles common abbreviations like "Dr.", "etc.", "i.e."
    final sentencePattern = RegExp(
      r'(?<![A-Z][a-z]\.)\s*([^.!?]*[.!?]+(?:\s*["\)]*)?)\s*(?=[A-Z]|$)',
      multiLine: true,
    );

    final matches = sentencePattern.allMatches(text);

    if (matches.isEmpty) {
      // Fallback: if no clear sentence boundaries, return the whole text
      return [text.trim()];
    }

    for (final match in matches) {
      final sentence = match.group(1)?.trim();
      if (sentence != null && sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    // If we didn't capture everything, add remaining text
    final totalCaptured = matches.fold<int>(0, (sum, match) => sum + (match.group(0)?.length ?? 0));
    if (totalCaptured < text.length * 0.8) {
      // Fallback to simpler splitting if complex regex missed too much
      return _simpleChatSentenceSplit(text);
    }

    return sentences.where((s) => s.trim().isNotEmpty).toList();
  }

  /// Simple sentence splitting as fallback for chat
  List<String> _simpleChatSentenceSplit(String text) {
    // Split by sentence endings followed by whitespace and capital letter
    final parts = text.split(RegExp(r'([.!?])\s+(?=[A-Z])'));
    final sentences = <String>[];

    for (int i = 0; i < parts.length; i += 2) {
      String sentence = parts[i];
      if (i + 1 < parts.length) {
        sentence += parts[i + 1]; // Add the punctuation back
      }
      sentence = sentence.trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    return sentences.isNotEmpty ? sentences : [text.trim()];
  }

  // Handler methods for action buttons
  void _handleRegenerate(ChatMessage message) {
    if (message.role != MessageRole.assistant) return;
    _messageController.text = 'Can you regenerate your last response with a different approach?';
    _sendMessage();
  }

  void _handleSoftenTone(ChatMessage message) {
    if (message.role != MessageRole.assistant) return;
    _messageController.text = 'Can you soften the tone of your last response?';
    _sendMessage();
  }

  void _handleMoreDepth(ChatMessage message) {
    if (message.role != MessageRole.assistant) return;
    _messageController.text = 'Can you provide more depth on this topic?';
    _sendMessage();
  }

  void _handleContinueThought(ChatMessage message) {
    if (message.role != MessageRole.assistant) return;
    _messageController.text = 'Please continue your thought.';
    _sendMessage();
  }

  void _handleExploreConversation(ChatMessage message) {
    if (message.role != MessageRole.assistant) return;
    // This is already in a chat, so just focus the input
    FocusScope.of(context).requestFocus(FocusNode());
  }
}

/// Action button for chat message bubbles (same style as in-journal)
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: isPrimary 
            ? theme.colorScheme.primary 
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isPrimary 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(44, 32), // Accessibility minimum
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
