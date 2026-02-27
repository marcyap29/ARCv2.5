import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:my_app/arc/chat/bloc/lumara_assistant_cubit.dart';
import 'package:my_app/arc/chat/data/context_provider.dart';
import 'package:my_app/arc/chat/data/context_scope.dart';
import 'package:my_app/arc/chat/data/models/lumara_message.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';
import 'package:my_app/ui/journal/journal_screen.dart';

/// Split screen: resized timeline entry editor (left) and LUMARA chat panel (right).
/// Used when opening a draft from chat via "View & Edit Draft". No LUMARA controls on the editor;
/// all conversation happens in the side panel.
class WritingWithLumaraScreen extends StatefulWidget {
  final String initialContent;
  final String? draftId;

  const WritingWithLumaraScreen({
    super.key,
    required this.initialContent,
    this.draftId,
  });

  @override
  State<WritingWithLumaraScreen> createState() => _WritingWithLumaraScreenState();
}

class _WritingWithLumaraScreenState extends State<WritingWithLumaraScreen> {
  String _draftContent = '';

  @override
  void initState() {
    super.initState();
    _draftContent = widget.initialContent;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LumaraAssistantCubit(
        contextProvider: ContextProvider(LumaraScope.defaultScope),
      )..initialize(),
      child: Scaffold(
        backgroundColor: kcBackgroundColor,
        body: Row(
          children: [
            Expanded(
              child: JournalScreen(
                initialContent: widget.initialContent,
                isViewOnly: false,
                onContentChanged: (content) {
                  setState(() => _draftContent = content);
                },
              ),
            ),
            Container(
              width: 360,
              decoration: const BoxDecoration(
                color: kcSurfaceColor,
                border: Border(
                  left: BorderSide(color: kcBorderColor),
                ),
              ),
              child: _LumaraWritingPanel(draftContent: _draftContent),
            ),
          ],
        ),
      ),
    );
  }
}

class _LumaraWritingPanel extends StatefulWidget {
  final String draftContent;

  const _LumaraWritingPanel({required this.draftContent});

  @override
  State<_LumaraWritingPanel> createState() => _LumaraWritingPanelState();
}

class _LumaraWritingPanelState extends State<_LumaraWritingPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendDraftToLumara() {
    final content = widget.draftContent.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft is empty. Add some content first.')),
      );
      return;
    }
    const prefix = "Please review this draft and share your comments or answer my questions about it.\n\n---\n";
    const suffix = "\n---";
    context.read<LumaraAssistantCubit>().sendMessage(prefix + content + suffix);
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    context.read<LumaraAssistantCubit>().sendMessage(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const LumaraIcon(size: 24, color: kcPrimaryColor),
              const Gap(8),
              Text(
                'LUMARA',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: kcPrimaryTextColor,
                    ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: _sendDraftToLumara,
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send draft for comments'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kcPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const Gap(8),
        const Divider(height: 1),
        Expanded(
          child: BlocBuilder<LumaraAssistantCubit, LumaraAssistantState>(
            builder: (context, state) {
              if (state is LumaraAssistantLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is LumaraAssistantError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const Gap(12),
                        Text(
                          state.message,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcSecondaryTextColor),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(12),
                        TextButton(
                          onPressed: () => context.read<LumaraAssistantCubit>().initializeLumara(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (state is LumaraAssistantLoaded) {
                if (state.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Send your draft above to get feedback, or ask anything about your writing.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcSecondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final message = state.messages[index];
                    return _MessageBubble(message: message);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: 'Ask about your writing...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const Gap(8),
              IconButton.filled(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
                tooltip: 'Send',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final LumaraMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == LumaraMessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const LumaraIcon(size: 28),
            const Gap(8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? kcPrimaryColor.withValues(alpha: 0.9) : kcSurfaceAltColor,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : kcPrimaryTextColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const Gap(8),
        ],
      ),
    );
  }
}
