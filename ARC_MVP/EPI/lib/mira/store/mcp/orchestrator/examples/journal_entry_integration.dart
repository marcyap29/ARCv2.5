import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../multimodal_orchestrator_bloc.dart';
import '../ui/multimodal_ui_components.dart';
import '../../models/mcp_schemas.dart';

/// Journal entry widget with multimodal MCP orchestrator integration
class MultimodalJournalEntry extends StatefulWidget {
  final String journalEntryId;

  const MultimodalJournalEntry({
    super.key,
    required this.journalEntryId,
  });

  @override
  State<MultimodalJournalEntry> createState() => _MultimodalJournalEntryState();
}

class _MultimodalJournalEntryState extends State<MultimodalJournalEntry> {
  final TextEditingController _textController = TextEditingController();
  final List<McpPointer> _attachedPointers = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MultimodalOrchestratorBloc(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Journal Entry'),
          actions: [
            IconButton(
              onPressed: _saveEntry,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: Column(
          children: [
            // Text input area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: 'Write your thoughts...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            
            // Multimodal toolbar
            _buildMultimodalToolbar(),
            
            // Attached media display
            if (_attachedPointers.isNotEmpty)
              _buildAttachedMedia(),
            
            // Orchestrator status
            _buildOrchestratorStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildMultimodalToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMediaButton(
            icon: Icons.photo_camera,
            label: 'Photo',
            onTap: () => _handlePhotoTap(),
          ),
          _buildMediaButton(
            icon: Icons.videocam,
            label: 'Video',
            onTap: () => _handleVideoTap(),
          ),
          _buildMediaButton(
            icon: Icons.mic,
            label: 'Audio',
            onTap: () => _handleAudioTap(),
          ),
          _buildMediaButton(
            icon: Icons.attach_file,
            label: 'File',
            onTap: () => _handleFileTap(),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachedMedia() {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attached Media (${_attachedPointers.length})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: McpPointerGallery(
              pointers: _attachedPointers,
              size: 'small',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrchestratorStatus() {
    return BlocBuilder<MultimodalOrchestratorBloc, MultimodalOrchestratorState>(
      builder: (context, state) {
        if (state is MultimodalOrchestratorInitial) {
          return const SizedBox.shrink();
        }

        if (state is MultimodalOrchestratorProcessing) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Processing: ${state.intent}'),
              ],
            ),
          );
        }

        if (state is MultimodalOrchestratorExecuting) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text('Executing commands (${state.completedCommands}/${state.totalCommands})'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: Colors.grey.shade300,
                ),
              ],
            ),
          );
        }

        if (state is MultimodalOrchestratorSuccess) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text('Success: ${state.result.results.length} commands completed'),
              ],
            ),
          );
        }

        if (state is MultimodalOrchestratorFailure) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error: ${state.error}'),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _handlePhotoTap() {
    context.read<MultimodalOrchestratorBloc>().add(const UserTappedPhotoIcon());
  }

  void _handleVideoTap() {
    context.read<MultimodalOrchestratorBloc>().add(const UserTappedVideoIcon());
  }

  void _handleAudioTap() {
    context.read<MultimodalOrchestratorBloc>().add(const UserTappedAudioIcon());
  }

  void _handleFileTap() {
    // TODO: Implement file picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File picker coming soon')),
    );
  }

  void _saveEntry() {
    // TODO: Implement journal entry saving with MCP integration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal entry saved')),
    );
  }
}

/// Example usage in main app
class MultimodalJournalApp extends StatelessWidget {
  const MultimodalJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multimodal Journal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MultimodalJournalEntry(
        journalEntryId: 'example_entry_1',
      ),
    );
  }
}

/// Integration example with existing journal entry
class JournalEntryMultimodalIntegration extends StatefulWidget {
  final String entryId;
  final String initialText;
  final List<McpPointer> existingPointers;

  const JournalEntryMultimodalIntegration({
    super.key,
    required this.entryId,
    this.initialText = '',
    this.existingPointers = const [],
  });

  @override
  State<JournalEntryMultimodalIntegration> createState() => _JournalEntryMultimodalIntegrationState();
}

class _JournalEntryMultimodalIntegrationState extends State<JournalEntryMultimodalIntegration> {
  final TextEditingController _textController = TextEditingController();
  late List<McpPointer> _pointers;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.initialText;
    _pointers = List.from(widget.existingPointers);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MultimodalOrchestratorBloc(),
      child: Column(
        children: [
          // Existing journal entry content
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'Write your journal entry...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          
          // Multimodal toolbar
          _buildMultimodalToolbar(),
          
          // Attached media
          if (_pointers.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.all(8),
              child: McpPointerGallery(
                pointers: _pointers,
                size: 'mini',
              ),
            ),
          
          // Orchestrator status
          _buildOrchestratorStatus(),
        ],
      ),
    );
  }

  Widget _buildMultimodalToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.read<MultimodalOrchestratorBloc>().add(const UserTappedPhotoIcon()),
            icon: const Icon(Icons.photo_camera),
            tooltip: 'Add Photo',
          ),
          IconButton(
            onPressed: () => context.read<MultimodalOrchestratorBloc>().add(const UserTappedVideoIcon()),
            icon: const Icon(Icons.videocam),
            tooltip: 'Add Video',
          ),
          IconButton(
            onPressed: () => context.read<MultimodalOrchestratorBloc>().add(const UserTappedAudioIcon()),
            icon: const Icon(Icons.mic),
            tooltip: 'Add Audio',
          ),
          const Spacer(),
          Text(
            '${_pointers.length} attachments',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrchestratorStatus() {
    return BlocListener<MultimodalOrchestratorBloc, MultimodalOrchestratorState>(
      listener: (context, state) {
        if (state is MultimodalOrchestratorSuccess) {
          // Handle successful command execution
          _handleOrchestratorSuccess(state);
        } else if (state is MultimodalOrchestratorFailure) {
          // Handle command failure
          _handleOrchestratorFailure(state);
        }
      },
      child: BlocBuilder<MultimodalOrchestratorBloc, MultimodalOrchestratorState>(
        builder: (context, state) {
          if (state is MultimodalOrchestratorExecuting) {
            return SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: state.progress,
                backgroundColor: Colors.grey.shade300,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _handleOrchestratorSuccess(MultimodalOrchestratorSuccess state) {
    // Extract pointers from successful commands
    for (final result in state.result.results) {
      if (result.data['pointer'] != null) {
        final pointerData = result.data['pointer'] as Map<String, dynamic>;
        final pointer = McpPointer.fromJson(pointerData);
        setState(() {
          _pointers.add(pointer);
        });
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${state.result.results.length} media items'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleOrchestratorFailure(MultimodalOrchestratorFailure state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${state.error}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
