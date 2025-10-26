// lib/lumara/v2/ui/main/lumara_main_interface.dart
// New simplified main interface for LUMARA v2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lumara_interface.dart';
import '../data/lumara_scope.dart';
import '../core/lumara_core.dart';

/// New simplified main interface for LUMARA v2.0
class LumaraMainInterface extends StatefulWidget {
  final Map<String, dynamic>? initialContext;
  
  const LumaraMainInterface({
    super.key,
    this.initialContext,
  });

  @override
  State<LumaraMainInterface> createState() => _LumaraMainInterfaceState();
}

class _LumaraMainInterfaceState extends State<LumaraMainInterface> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<LumaraMessage> _messages = [];
  bool _isGenerating = false;
  LumaraScope _currentScope = LumaraScope.all();
  
  @override
  void initState() {
    super.initState();
    _initializeChat();
  }
  
  void _initializeChat() {
    // Add initial context message if provided
    if (widget.initialContext != null) {
      final context = widget.initialContext!;
      final contextMessage = _buildContextMessage(context);
      _messages.add(contextMessage);
    }
    
    // Add welcome message
    _messages.add(LumaraMessage(
      id: 'welcome',
      role: LumaraMessageRole.assistant,
      content: 'Hello! I\'m LUMARA, your Life-aware Unified Memory & Reflection Assistant. I\'m here to help you explore your thoughts, reflect on your experiences, and provide guidance based on your personal journey. What would you like to explore today?',
      timestamp: DateTime.now(),
    ));
  }
  
  LumaraMessage _buildContextMessage(Map<String, dynamic> context) {
    final content = StringBuffer();
    content.writeln('Context from journal entry:');
    
    if (context['journalContent'] != null) {
      final journalContent = context['journalContent'] as String;
      final preview = journalContent.length > 200 
          ? '${journalContent.substring(0, 200)}...'
          : journalContent;
      content.writeln('Journal: $preview');
    }
    
    if (context['phase'] != null) {
      content.writeln('Phase: ${context['phase']}');
    }
    
    if (context['keywords'] != null) {
      final keywords = context['keywords'] as List<String>;
      if (keywords.isNotEmpty) {
        content.writeln('Keywords: ${keywords.join(', ')}');
      }
    }
    
    if (context['reflection'] != null) {
      content.writeln('Previous reflection: ${context['reflection']}');
    }
    
    return LumaraMessage(
      id: 'context',
      role: LumaraMessageRole.system,
      content: content.toString(),
      timestamp: DateTime.now(),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showScopeSettings,
            tooltip: 'Scope Settings',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scope indicator
          _buildScopeIndicator(),
          
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }
  
  Widget _buildScopeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility, size: 16),
          const SizedBox(width: 8),
          Text(
            'Scope: ${_currentScope.enabledSources.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            'Phase: ${widget.initialContext?['phase'] ?? 'Auto-detect'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(LumaraMessage message) {
    final isUser = message.role == LumaraMessageRole.user;
    final isSystem = message.role == LumaraMessageRole.system;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isSystem 
                  ? Colors.grey[400]
                  : Theme.of(context).primaryColor,
              child: Icon(
                isSystem ? Icons.info : Icons.auto_awesome,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser 
                    ? Theme.of(context).primaryColor
                    : isSystem
                        ? Colors.grey[100]
                        : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isSystem 
                    ? Border.all(color: Colors.grey[300]!)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      color: isUser 
                          ? Colors.white70 
                          : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 16, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isGenerating ? null : _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) return;
    
    // Add user message
    final userMessage = LumaraMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: LumaraMessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
      _isGenerating = true;
    });
    
    _messageController.clear();
    _scrollToBottom();
    
    try {
      final lumara = LumaraCore.instance.interface;
      
      final response = await lumara.ask(
        query: text,
        scope: _currentScope,
        phase: widget.initialContext?['phase'],
      );
      
      if (response.isError) {
        _showError('Failed to get response: ${response.content}');
        return;
      }
      
      final assistantMessage = LumaraMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: LumaraMessageRole.assistant,
        content: response.content,
        timestamp: DateTime.now(),
      );
      
      setState(() {
        _messages.add(assistantMessage);
      });
      
      _scrollToBottom();
    } catch (e) {
      _showError('Error sending message: $e');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }
  
  void _showScopeSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildScopeSettingsSheet(),
    );
  }
  
  Widget _buildScopeSettingsSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LUMARA Scope Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildScopeToggle('Journal Entries', _currentScope.journal, (value) {
            setState(() {
              _currentScope = _currentScope.copyWith(journal: value);
            });
          }),
          _buildScopeToggle('Drafts', _currentScope.drafts, (value) {
            setState(() {
              _currentScope = _currentScope.copyWith(drafts: value);
            });
          }),
          _buildScopeToggle('Chat History', _currentScope.chats, (value) {
            setState(() {
              _currentScope = _currentScope.copyWith(chats: value);
            });
          }),
          _buildScopeToggle('Media', _currentScope.media, (value) {
            setState(() {
              _currentScope = _currentScope.copyWith(media: value);
            });
          }),
          _buildScopeToggle('Phase Detection', _currentScope.phase, (value) {
            setState(() {
              _currentScope = _currentScope.copyWith(phase: value);
            });
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentScope = LumaraScope.all;
                  });
                },
                child: const Text('All'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentScope = LumaraScope.journalOnly;
                  });
                },
                child: const Text('Journal Only'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildScopeToggle(String label, bool value, Function(bool) onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? false),
    );
  }
  
  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _initializeChat();
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
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// LUMARA message for the main interface
class LumaraMessage {
  final String id;
  final LumaraMessageRole role;
  final String content;
  final DateTime timestamp;
  
  const LumaraMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

/// Message role enum
enum LumaraMessageRole {
  user,
  assistant,
  system,
}
