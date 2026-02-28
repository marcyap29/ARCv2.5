/// LUMARA Chat Redesign Screen
///
/// Mockup-style chat: Back + LUMARA title, hero block when empty,
/// suggestion buttons, simple input bar. Uses same LumaraAssistantCubit as main chat.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/arc/chat/data/models/lumara_message.dart';
import 'package:my_app/arc/chat/ui/lumara_settings_screen.dart';
import 'package:my_app/arc/chat/chat/ui/enhanced_chats_screen.dart';
import 'package:my_app/arc/chat/chat/enhanced_chat_repo_impl.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';
import 'package:my_app/shared/widgets/lumara_thinking_dialog.dart';
import 'package:my_app/arc/chat/widgets/attribution_display_widget.dart';
import 'package:my_app/arc/chat/widgets/lumara_message_body.dart';
import 'package:my_app/arc/chat/voice/audio_io.dart';
import 'package:my_app/arc/ui/widgets/attachment_menu_button.dart';
import 'package:my_app/core/services/media_pick_and_analyze_service.dart';

class LumaraChatRedesignScreen extends StatefulWidget {
  final String? initialMessage;

  const LumaraChatRedesignScreen({super.key, this.initialMessage});

  @override
  State<LumaraChatRedesignScreen> createState() => _LumaraChatRedesignScreenState();
}

class _LumaraChatRedesignScreenState extends State<LumaraChatRedesignScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _responseStyleMenuKey = GlobalKey();
  final MediaPickAndAnalyzeService _mediaService = MediaPickAndAnalyzeService();
  List<AnalyzedMedia> _pendingAttachments = [];

  // Scroll-to-top/bottom button state (same architecture as timeline)
  bool _showScrollToTop = false;
  bool _showScrollToBottom = false;

  /// When non-null, user is editing this message; submit will call editMessageAndRegenerate.
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    if (widget.initialMessage != null && widget.initialMessage!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(widget.initialMessage!.trim());
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty && _pendingAttachments.isEmpty) return;

    final attachments = List<AnalyzedMedia>.from(_pendingAttachments);
    if (attachments.isNotEmpty) {
      setState(() => _pendingAttachments.clear());
    }
    if (_editingMessageId != null) {
      context.read<LumaraAssistantCubit>().editMessageAndRegenerate(
        messageId: _editingMessageId!,
        newContent: t.isEmpty ? '📷 [Image attached]' : t,
      );
      setState(() => _editingMessageId = null);
    } else {
      context.read<LumaraAssistantCubit>().sendMessage(
        t.isEmpty ? '📷 [Image attached]' : t,
        attachments: attachments.isNotEmpty ? attachments : null,
      );
    }
    _controller.clear();
  }

  void _startEditMessage(LumaraMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _controller.text = message.content;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: message.content.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handlePhotoGallery() async {
    final result = await _mediaService.pickSingleFromGallery();
    if (result != null && mounted) {
      setState(() => _pendingAttachments.add(result));
    }
  }

  Future<void> _handleCamera() async {
    final result = await _mediaService.captureFromCamera();
    if (result != null && mounted) {
      setState(() => _pendingAttachments.add(result));
    }
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final isNearTop = position.pixels <= 100;
    final isNearBottom = position.pixels >= position.maxScrollExtent - 100;
    final shouldShowTop = !isNearTop;
    final shouldShowBottom = !isNearBottom && position.maxScrollExtent > 200;
    if (_showScrollToTop != shouldShowTop || _showScrollToBottom != shouldShowBottom) {
      setState(() {
        _showScrollToTop = shouldShowTop;
        _showScrollToBottom = shouldShowBottom;
      });
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _showScrollToTop = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _showScrollToBottom = false);
    }
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
              leading: const Icon(Icons.add_circle_outline, color: kcPrimaryTextColor),
              title: const Text('Start new chat',
                  style: TextStyle(color: kcPrimaryTextColor)),
              subtitle: const Text('Current chat moves to timeline',
                  style: TextStyle(color: kcSecondaryTextColor, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                await context.read<LumaraAssistantCubit>().startNewChat();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New chat started')),
                  );
                }
              },
            ),
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
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

                final loadedState = state is LumaraAssistantLoaded ? state : null;
                final messages = loadedState?.messages ?? <LumaraMessage>[];
                final showHero = messages.isEmpty && (loadedState?.isProcessing != true);

                if (showHero) {
                  return _buildHeroAndSuggestions(context);
                }

                final isProcessing = loadedState?.isProcessing ?? false;
                final processingSteps = loadedState?.processingSteps ?? [];

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length + (isProcessing ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return _buildMessageBubble(messages[index]);
                    }
                    return LumaraThinkingIndicator(
                      customMessage: 'LUMARA is thinking...',
                      showProgressBar: false,
                      processingSteps: processingSteps.isNotEmpty ? processingSteps : ['LUMARA is thinking...'],
                    );
                  },
                );
              },
            ),
            ),
          ),
          _buildInputBar(context),
        ],
      ),
          // Scroll-to-top/bottom buttons (same architecture as timeline)
          if (_showScrollToTop)
            Positioned(
              bottom: 140,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'chatScrollToTop',
                onPressed: _scrollToTop,
                backgroundColor: kcSurfaceAltColor,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
              ),
            ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'chatScrollToBottom',
                onPressed: _scrollToBottom,
                backgroundColor: kcSurfaceAltColor,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ),
            ),
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
                  isUser
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              message.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: message.content),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Copied to clipboard'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    tooltip: 'Copy',
                                  ),
                                  IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      onPressed: () => _startEditMessage(message),
                                      tooltip: 'Edit',
                                    ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : LumaraMessageBody(
                          content: message.content,
                          textStyle: TextStyle(
                            color: kcPrimaryTextColor,
                            fontSize: 15,
                            height: 1.4,
                          ),
                          linkColor: kcPrimaryColor,
                        ),
                  if (!isUser && message.content.isNotEmpty)
                    _ChatMessageActionsWidget(content: message.content),
                  if (!isUser && message.attributionTraces != null && message.attributionTraces!.isNotEmpty)
                    AttributionDisplayWidget(
                      traces: message.attributionTraces!,
                      responseId: message.id,
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
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        border: Border(top: BorderSide(color: kcBorderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editingMessageId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Editing message',
                    style: TextStyle(
                      color: kcPrimaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _editingMessageId = null;
                        _controller.clear();
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          if (_pendingAttachments.isNotEmpty) _buildPendingAttachments(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AttachmentMenuButton(
                onPhotoGallery: _handlePhotoGallery,
                onCamera: _handleCamera,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  style: const TextStyle(color: kcPrimaryTextColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: _editingMessageId != null
                        ? 'Edit your message and send to regenerate...'
                        : 'Ask anything',
                    hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: kcBorderColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
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
        ],
      ),
    );
  }

  Widget _buildPendingAttachments() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final a = _pendingAttachments[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(a.imagePath),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _pendingAttachments.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showResponseStyleMenu() async {
    final anchorContext = _responseStyleMenuKey.currentContext;
    final overlay = Overlay.of(context);
    if (anchorContext == null) return;

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
              if (!useDetailed) const Icon(Icons.check, size: 18, color: Colors.blue) else const SizedBox(width: 18),
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
              if (useDetailed) const Icon(Icons.check, size: 18, color: Colors.blue) else const SizedBox(width: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Detailed analysis', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('Full master prompt with temporal context.', style: TextStyle(fontSize: 11, color: Colors.grey)),
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

/// Copy and Play actions for LUMARA chat replies (matches older UX).
class _ChatMessageActionsWidget extends StatefulWidget {
  final String content;

  const _ChatMessageActionsWidget({required this.content});

  @override
  State<_ChatMessageActionsWidget> createState() => _ChatMessageActionsWidgetState();
}

class _ChatMessageActionsWidgetState extends State<_ChatMessageActionsWidget> {
  AudioIO? _audioIO;

  Future<void> _initAudio() async {
    if (_audioIO != null) return;
    try {
      final io = AudioIO();
      await io.initializeTTS();
      if (mounted) setState(() => _audioIO = io);
    } catch (_) {}
  }

  String _cleanForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'#{1,6}\s+'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<void> _speak() async {
    await _initAudio();
    if (_audioIO != null && widget.content.isNotEmpty) {
      final clean = _cleanForSpeech(widget.content);
      if (clean.isNotEmpty) await _audioIO!.speak(clean);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.6);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.copy_outlined, size: 18, color: iconColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.play_arrow_outlined, size: 20, color: iconColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _speak,
            tooltip: 'Listen',
          ),
        ],
      ),
    );
  }
}
