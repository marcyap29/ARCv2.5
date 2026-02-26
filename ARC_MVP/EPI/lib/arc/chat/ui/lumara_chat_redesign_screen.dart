/// LUMARA Chat Redesign Screen
///
/// Mockup-style chat: Back + LUMARA title, hero block when empty,
/// suggestion buttons, simple input bar. Uses same LumaraAssistantCubit as main chat.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/arc/chat/data/models/lumara_message.dart';
import 'package:my_app/arc/chat/ui/lumara_settings_screen.dart';
import 'package:my_app/arc/chat/chat/ui/enhanced_chats_screen.dart';
import 'package:my_app/arc/chat/chat/enhanced_chat_repo_impl.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';

class LumaraChatRedesignScreen extends StatefulWidget {
  final String? initialMessage;

  const LumaraChatRedesignScreen({super.key, this.initialMessage});

  @override
  State<LumaraChatRedesignScreen> createState() => _LumaraChatRedesignScreenState();
}

class _LumaraChatRedesignScreenState extends State<LumaraChatRedesignScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _responseStyleMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(widget.initialMessage!.trim());
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _controller.clear();
    context.read<LumaraAssistantCubit>().sendMessage(t);
  }

  void _showSettingsAndHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kcSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history, color: kcPrimaryTextColor),
              title: const Text('Chat history',
                  style: TextStyle(color: kcPrimaryTextColor)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnhancedChatsScreen(
                      chatRepo:
                          EnhancedChatRepoImpl(ChatRepoImpl.instance),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.auto_awesome, color: kcPrimaryTextColor),
              title: const Text('LUMARA settings',
                  style: TextStyle(color: kcPrimaryTextColor)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LumaraSettingsScreen(),
                  ),
                );
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
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcSurfaceColor,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          'LUMARA',
          style: TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings & History',
              onPressed: _showSettingsAndHistory,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<LumaraAssistantCubit, LumaraAssistantState>(
              builder: (context, state) {
                if (state is LumaraAssistantLoading) {
                  return const Center(child: CircularProgressIndicator(color: kcPrimaryColor));
                }
                if (state is LumaraAssistantError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: kcSecondaryTextColor),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.read<LumaraAssistantCubit>().initializeLumara(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final messages = state is LumaraAssistantLoaded ? state.messages : <LumaraMessage>[];
                final showHero = messages.isEmpty;

                if (showHero) {
                  return _buildHeroAndSuggestions(context);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildHeroAndSuggestions(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero block with gradient
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5C4033),
                    Color(0xFF4A2C6A),
                    Color(0xFF2D1B4E),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meet LUMARA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your personal AI — reflective intelligence that uses your journal and history when you want deeper, personal answers.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Suggestion buttons
            Row(
              children: [
                Expanded(
                  child: _suggestionChip(
                    context,
                    title: 'Summarize',
                    subtitle: 'my last 7 days',
                    onTap: () => _send('Summarize my last 7 days'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _suggestionChip(
                    context,
                    title: 'Patterns',
                    subtitle: 'what do you see?',
                    onTap: () => _send('What patterns do you see?'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _suggestionChip(
                    context,
                    title: 'Compare',
                    subtitle: 'this week to last',
                    onTap: () => _send('Compare this week to last week'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _suggestionChip(
                    context,
                    title: 'Suggest',
                    subtitle: 'a prompt for tonight',
                    onTap: () => _send('Suggest a prompt for tonight'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: kcSurfaceColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kcBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kcPrimaryTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(LumaraMessage message) {
    final isUser = message.role == LumaraMessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const LumaraIcon(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? kcPrimaryColor : kcSurfaceAltColor,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'LUMARA',
                        style: TextStyle(
                          color: kcPrimaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : kcPrimaryTextColor,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        border: Border(top: BorderSide(color: kcBorderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: kcSecondaryTextColor),
            onPressed: () {
              // Optional: attach or new chat; no-op for now
            },
            tooltip: 'Add',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: kcPrimaryTextColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Ask anything',
                hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: kcBorderColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(_controller.text),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: _responseStyleMenuKey,
            icon: const Icon(Icons.expand_more, size: 20, color: kcSecondaryTextColor),
            onPressed: _showResponseStyleMenu,
            tooltip: 'Response style: Conversation / Detailed analysis',
          ),
          IconButton(
            icon: const LumaraIcon(size: 20),
            onPressed: () => _send(_controller.text),
            tooltip: 'Send',
          ),
          IconButton(
            icon: const Icon(Icons.mic_none, color: kcSecondaryTextColor),
            onPressed: () {
              // Voice: could open voice panel or keep for later
            },
            tooltip: 'Voice',
          ),
        ],
      ),
    );
  }

  Future<void> _showResponseStyleMenu() async {
    final anchorContext = _responseStyleMenuKey.currentContext;
    final overlay = Overlay.of(context);
    if (anchorContext == null || overlay == null) return;

    final box = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final offset = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final cubit = context.read<LumaraAssistantCubit>();
    final useDetailed = cubit.state is LumaraAssistantLoaded && (cubit.state as LumaraAssistantLoaded).useDetailedAnalysis;

    final selection = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 4,
        overlayBox.size.width - offset.dx - box.size.width,
        overlayBox.size.height - offset.dy - box.size.height,
      ),
      items: [
        PopupMenuItem<bool>(
          value: false,
          child: Row(
            children: [
              if (!useDetailed) Icon(Icons.check, size: 18, color: Colors.blue) else const SizedBox(width: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Conversation (perceptive)', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('Short prompt, natural friend-like replies.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            children: [
              if (useDetailed) Icon(Icons.check, size: 18, color: Colors.blue) else const SizedBox(width: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Detailed analysis', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('Full master prompt, temporal/phase-aware analysis.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selection == null) return;
    cubit.setDetailedAnalysis(selection);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(selection ? 'Response style: Detailed analysis' : 'Response style: Conversation (perceptive)'),
      ),
    );
  }
}
