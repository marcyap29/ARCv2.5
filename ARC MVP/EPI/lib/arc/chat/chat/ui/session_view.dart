import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import '../../bloc/lumara_assistant_cubit.dart';
import '../../data/context_provider.dart';
import '../../data/context_scope.dart';

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
  
  LumaraAssistantCubit? _lumaraCubit;
  LumaraScope _scope = LumaraScope.defaultScope;

  @override
  void initState() {
    super.initState();
    _initializeLumaraCubit();
    _loadSession();
    _setupAutoSave();
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

      final session = await widget.chatRepo.getSession(widget.sessionId);
      if (session == null) {
        setState(() {
          _error = 'Session not found';
          _isLoading = false;
        });
        return;
      }

      final messages = await widget.chatRepo.getMessages(widget.sessionId);
      
      setState(() {
        _session = session;
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending || _lumaraCubit == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Set the current chat session ID in LUMARA cubit
      _lumaraCubit!.currentChatSessionId = widget.sessionId;
      
      // Send message through LUMARA assistant
      await _lumaraCubit!.sendMessage(content);
      
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
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
            // Scope chips
            _buildScopeChips(),

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
              child: Icon(Icons.psychology, size: 16, color: Colors.blue[700]),
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
              child: Text(
                message.textContent,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
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
                hintText: 'Ask LUMARA anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
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
                : const Icon(Icons.send),
            onPressed: _isSending ? null : _sendMessage,
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () {
              // TODO: Implement quick palette
            },
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

  void _toggleScope(String scopeType) {
    setState(() {
      switch (scopeType) {
        case 'journal':
          _scope = _scope.copyWith(journal: !_scope.journal);
          break;
        case 'phase':
          _scope = _scope.copyWith(phase: !_scope.phase);
          break;
        case 'arcforms':
          _scope = _scope.copyWith(arcforms: !_scope.arcforms);
          break;
        case 'voice':
          _scope = _scope.copyWith(voice: !_scope.voice);
          break;
        case 'media':
          _scope = _scope.copyWith(media: !_scope.media);
          break;
        case 'drafts':
          _scope = _scope.copyWith(drafts: !_scope.drafts);
          break;
        case 'chats':
          _scope = _scope.copyWith(chats: !_scope.chats);
          break;
      }
    });
    
    // Recreate the LumaraAssistantCubit with the new scope
    _lumaraCubit?.close();
    _initializeLumaraCubit();
  }

  Widget _buildScopeChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        children: [
          _buildScopeChip('Journal', _scope.journal, () => _toggleScope('journal')),
          _buildScopeChip('Phase', _scope.phase, () => _toggleScope('phase')),
          _buildScopeChip('Arcforms', _scope.arcforms, () => _toggleScope('arcforms')),
          _buildScopeChip('Voice', _scope.voice, () => _toggleScope('voice')),
          _buildScopeChip('Media', _scope.media, () => _toggleScope('media')),
          _buildScopeChip('Drafts', _scope.drafts, () => _toggleScope('drafts')),
          _buildScopeChip('Chats', _scope.chats, () => _toggleScope('chats')),
        ],
      ),
    );
  }

  Widget _buildScopeChip(String label, bool isActive, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue[700],
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
}
