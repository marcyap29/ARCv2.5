import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/lumara/orchestrator/lumara_chat_orchestrator.dart';
import 'package:my_app/arc/chat/ui/writing_screen.dart';

/// Full-screen viewer for a draft created from LUMARA chat (View Draft in Agents).
class ChatDraftViewerScreen extends StatelessWidget {
  final String draftId;

  const ChatDraftViewerScreen({super.key, required this.draftId});

  @override
  Widget build(BuildContext context) {
    final content = ChatDraftCache.instance.get(draftId);
    if (content == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Draft')),
        body: const Center(
          child: Text('Draft no longer available. Create a new one from LUMARA.'),
        ),
      );
    }
    final text = content.draft.content;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draft'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Draft copied to clipboard')),
              );
            },
            tooltip: 'Copy',
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const WritingScreen(),
                ),
              );
            },
            icon: const Icon(Icons.edit_note, size: 20),
            label: const Text('Open in Writing Agent'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
