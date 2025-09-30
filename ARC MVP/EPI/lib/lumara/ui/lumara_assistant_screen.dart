import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import '../bloc/lumara_assistant_cubit.dart';
import '../data/models/lumara_message.dart';
import '../chat/ui/chats_screen.dart';
import 'lumara_quick_palette.dart';
import 'lumara_consent_sheet.dart';
import 'lumara_settings_screen.dart';
import '../widgets/attribution_display_widget.dart';
import '../../mira/memory/enhanced_memory_schema.dart';

/// Main LUMARA Assistant screen
class LumaraAssistantScreen extends StatefulWidget {
  const LumaraAssistantScreen({super.key});

  @override
  State<LumaraAssistantScreen> createState() => _LumaraAssistantScreenState();
}

class _LumaraAssistantScreenState extends State<LumaraAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Only initialize LUMARA if not already loaded (to preserve chat history)
    final cubit = context.read<LumaraAssistantCubit>();
    if (cubit.state is! LumaraAssistantLoaded) {
      cubit.initializeLumara();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUMARA Assistant'),
        automaticallyImplyLeading: false, // Remove back button since this is a tab
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showEnhancedSettings(),
            tooltip: 'API Settings',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatsScreen()),
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
                  // Dismiss keyboard when tapping outside text field
                  _dismissKeyboard();
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    // Scope chips
                    _buildScopeChips(),

                    // Messages list
                    Expanded(
            child: BlocConsumer<LumaraAssistantCubit, LumaraAssistantState>(
              listener: (context, state) {
                if (state is LumaraAssistantLoaded) {
                  _scrollToBottom();
                }
              },
              builder: (context, state) {
                if (state is LumaraAssistantLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (state is LumaraAssistantError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        const Gap(16),
                        Text(
                          'Error: ${state.message}',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const Gap(16),
                        ElevatedButton(
                          onPressed: () => context.read<LumaraAssistantCubit>().initializeLumara(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (state is LumaraAssistantLoaded) {
                  if (state.messages.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return _buildMessageBubble(message);
                    },
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
          ),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    ),
    );
  }

  Widget _buildScopeChips() {
    return BlocBuilder<LumaraAssistantCubit, LumaraAssistantState>(
      builder: (context, state) {
        if (state is! LumaraAssistantLoaded) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              _buildScopeChip('Journal', state.scope.journal, () {
                context.read<LumaraAssistantCubit>().toggleScope('journal');
              }),
              _buildScopeChip('Phase', state.scope.phase, () {
                context.read<LumaraAssistantCubit>().toggleScope('phase');
              }),
              _buildScopeChip('Arcforms', state.scope.arcforms, () {
                context.read<LumaraAssistantCubit>().toggleScope('arcforms');
              }),
              _buildScopeChip('Voice', state.scope.voice, () {
                context.read<LumaraAssistantCubit>().toggleScope('voice');
              }),
              _buildScopeChip('Media', state.scope.media, () {
                context.read<LumaraAssistantCubit>().toggleScope('media');
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScopeChip(String label, bool isActive, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
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
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  
                  // Attribution display for assistant messages
                  if (!isUser && message.attributionTraces != null && message.attributionTraces!.isNotEmpty) ...[
                    const Gap(8),
                    AttributionDisplayWidget(
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Reduced top padding for more chat space
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
              onSubmitted: (_) => _sendCurrentMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendCurrentMessage,
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () => _showQuickPalette(),
          ),
        ],
      ),
    );
  }

  void _sendCurrentMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      _sendMessage(text);
      _messageController.clear();
    }
  }

  void _sendMessage(String message) {
    context.read<LumaraAssistantCubit>().sendMessage(message);
  }

  void _clearChat() {
    context.read<LumaraAssistantCubit>().clearChat();
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
    
    // Navigate to enhanced LUMARA settings
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LumaraSettingsScreen(),
      ),
    );
  }

  /// Handle attribution weight changes
  void _handleAttributionWeightChange(String messageId, AttributionTrace trace, double newWeight) {
    // TODO: Implement weight change logic
    // This would update the memory influence in real-time
    print('Weight changed for memory ${trace.nodeRef}: ${(newWeight * 100).toStringAsFixed(0)}%');
  }

  /// Handle memory exclusion
  void _handleMemoryExclusion(String messageId, AttributionTrace trace) {
    // TODO: Implement memory exclusion logic
    // This would exclude the memory from future responses
    print('Memory excluded: ${trace.nodeRef}');
  }

}