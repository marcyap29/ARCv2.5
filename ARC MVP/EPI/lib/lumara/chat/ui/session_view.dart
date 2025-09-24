import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_models.dart';
import '../chat_repo.dart';

/// Screen for viewing and interacting with a single chat session
class SessionView extends StatefulWidget {
  final String sessionId;
  final ChatRepo chatRepo;

  const SessionView({
    super.key,
    required this.sessionId,
    required this.chatRepo,
  });

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ChatSession? _session;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await widget.chatRepo.getSession(widget.sessionId);
      final messages = await widget.chatRepo.getMessages(widget.sessionId, lazy: false);

      setState(() {
        _session = session;
        _messages = messages;
        _isLoading = false;
      });

      // Scroll to bottom after loading messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
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
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Add user message
      await widget.chatRepo.addMessage(
        sessionId: widget.sessionId,
        role: MessageRole.user,
        content: content,
      );

      _messageController.clear();

      // TODO: Integrate with LUMARA assistant for response
      // For now, add a simple acknowledgment
      await Future.delayed(const Duration(milliseconds: 500));
      await widget.chatRepo.addMessage(
        sessionId: widget.sessionId,
        role: MessageRole.assistant,
        content: "I understand. Let me think about that...",
      );

      await _loadSession();
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showSessionOptions() async {
    if (_session == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: kcSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SessionOptionsSheet(
        session: _session!,
        chatRepo: widget.chatRepo,
        onSessionUpdated: _loadSession,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kcPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _session?.subject ?? 'Loading...',
          style: heading1Style(context).copyWith(fontSize: 18),
        ),
        actions: [
          if (_session != null)
            IconButton(
              icon: const Icon(Icons.more_vert, color: kcPrimaryColor),
              onPressed: _showSessionOptions,
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _buildMessagesList(),
          ),

          // Input area
          _buildInputArea(),
        ],
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
            Icon(Icons.error, color: kcDangerColor, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error', style: bodyStyle(context)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, color: kcTextSecondaryColor, size: 48),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to begin chatting with LUMARA',
              style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _MessageBubble(message: message);
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        border: Border(top: BorderSide(color: kcBorderColor, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: bodyStyle(context),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
                  filled: true,
                  fillColor: kcBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: kcPrimaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser && !isSystem) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: kcPrimaryColor,
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? kcPrimaryColor
                        : isSystem
                            ? kcWarningColor.withOpacity(0.1)
                            : kcSurfaceColor,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      topLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                      topRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    border: isSystem
                        ? Border.all(color: kcWarningColor.withOpacity(0.3))
                        : null,
                  ),
                  child: Text(
                    message.content,
                    style: bodyStyle(context).copyWith(
                      color: isUser
                          ? Colors.white
                          : isSystem
                              ? kcWarningColor
                              : kcTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: captionStyle(context),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: kcAccentColor,
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _SessionOptionsSheet extends StatefulWidget {
  final ChatSession session;
  final ChatRepo chatRepo;
  final VoidCallback onSessionUpdated;

  const _SessionOptionsSheet({
    required this.session,
    required this.chatRepo,
    required this.onSessionUpdated,
  });

  @override
  State<_SessionOptionsSheet> createState() => _SessionOptionsSheetState();
}

class _SessionOptionsSheetState extends State<_SessionOptionsSheet> {
  late TextEditingController _subjectController;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.session.subject);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _renameSession() async {
    final newSubject = _subjectController.text.trim();
    if (newSubject.isNotEmpty && newSubject != widget.session.subject) {
      try {
        await widget.chatRepo.renameSession(widget.session.id, newSubject);
        widget.onSessionUpdated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat renamed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to rename: $e')),
          );
        }
      }
    }
  }

  Future<void> _togglePin() async {
    try {
      await widget.chatRepo.pinSession(widget.session.id, !widget.session.isPinned);
      widget.onSessionUpdated();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${widget.session.isPinned ? 'unpin' : 'pin'}: $e')),
        );
      }
    }
  }

  Future<void> _toggleArchive() async {
    try {
      await widget.chatRepo.archiveSession(widget.session.id, !widget.session.isArchived);
      widget.onSessionUpdated();
      if (mounted) {
        Navigator.pop(context);
        if (widget.session.isArchived) {
          Navigator.pop(context); // Go back to main screen if restoring
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${widget.session.isArchived ? 'restore' : 'archive'}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat Options',
            style: heading1Style(context).copyWith(fontSize: 20),
          ),
          const SizedBox(height: 24),

          // Rename section
          Text(
            'Subject',
            style: heading2Style(context).copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subjectController,
                  style: bodyStyle(context),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: kcBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _renameSession,
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          ListTile(
            leading: Icon(
              widget.session.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: kcPrimaryColor,
            ),
            title: Text(widget.session.isPinned ? 'Unpin Chat' : 'Pin Chat'),
            subtitle: Text(
              widget.session.isPinned
                  ? 'Remove pin from this chat'
                  : 'Keep this chat at the top',
            ),
            onTap: _togglePin,
          ),

          ListTile(
            leading: Icon(
              widget.session.isArchived ? Icons.unarchive : Icons.archive,
              color: kcAccentColor,
            ),
            title: Text(widget.session.isArchived ? 'Restore Chat' : 'Archive Chat'),
            subtitle: Text(
              widget.session.isArchived
                  ? 'Move this chat back to active list'
                  : 'Move this chat to archive',
            ),
            onTap: _toggleArchive,
          ),

          const SizedBox(height: 16),

          // Session info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Info',
                  style: heading2Style(context).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.session.messageCount} messages',
                  style: captionStyle(context),
                ),
                Text(
                  'Created ${_formatDate(widget.session.createdAt)}',
                  style: captionStyle(context),
                ),
                Text(
                  'Last updated ${_formatDate(widget.session.updatedAt)}',
                  style: captionStyle(context),
                ),
                if (widget.session.isArchived && widget.session.archivedAt != null)
                  Text(
                    'Archived ${_formatDate(widget.session.archivedAt!)}',
                    style: captionStyle(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}