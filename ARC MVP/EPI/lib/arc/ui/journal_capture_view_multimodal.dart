import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/journal_capture_state.dart';
import 'package:my_app/arc/core/keyword_extraction_cubit.dart';
import 'package:my_app/arc/core/widgets/emotion_selection_view.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_app/core/perf/frame_budget.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/media/media_capture_sheet.dart';
import 'package:my_app/arc/core/media/media_strip.dart';
import 'package:my_app/arc/core/media/media_preview_dialog.dart';
import 'package:my_app/arc/core/media/ocr_text_insert_dialog.dart';
import 'package:my_app/core/services/media_store.dart';
import 'package:my_app/mira/store/mcp/orchestrator/ios_vision_orchestrator.dart';
import 'package:my_app/arc/ui/widgets/draft_recovery_dialog.dart';

// Import the Multimodal MCP Orchestrator
import 'package:my_app/mira/store/mcp/orchestrator/multimodal_orchestrator_bloc.dart';
import 'package:my_app/mira/store/mcp/orchestrator/multimodal_orchestrator_commands.dart';
import 'package:my_app/mira/store/mcp/orchestrator/ui/multimodal_ui_components.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';

class JournalCaptureView extends StatefulWidget {
  final String? initialEmotion;
  final String? initialReason;
  
  const JournalCaptureView({
    super.key,
    this.initialEmotion,
    this.initialReason,
  });

  @override
  State<JournalCaptureView> createState() => _JournalCaptureViewState();
}

class _JournalCaptureViewState extends State<JournalCaptureView> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _showVoiceRecorder = false;
  
  // Media management
  final List<MediaItem> _mediaItems = [];
  final List<McpPointer> _mcpPointers = []; // New: MCP pointers for multimodal content
  final MediaStore _mediaStore = MediaStore();
  // final OCRService _ocrService = OCRService(); // TODO: Implement OCR service

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MultimodalOrchestratorBloc(),
      child: BlocBuilder<JournalCaptureCubit, JournalCaptureState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFF121621),
            appBar: AppBar(
              backgroundColor: const Color(0xFF121621),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Write what is true right now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saveEntry,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Main content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prompt
                        const Text(
                          "What's on your mind right now?",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Text input area
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Start writing...',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Multimodal toolbar
                        _buildMultimodalToolbar(),
                        const SizedBox(height: 16),
                        
                        // Attached media display
                        if (_mcpPointers.isNotEmpty)
                          _buildAttachedMedia(),
                      ],
                    ),
                  ),
                ),
                
                // Orchestrator status
                _buildOrchestratorStatus(),
                
                // Continue button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMultimodalToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade700,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Photo button (gallery)
          _buildMediaButton(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () => _handlePhotoTap(),
          ),
          
          // Camera button
          _buildMediaButton(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () => _handleCameraTap(),
          ),
          
          // Microphone button
          _buildMediaButton(
            icon: Icons.mic,
            label: 'Voice',
            onTap: () => _handleVoiceTap(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachedMedia() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade700,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attached Media (${_mcpPointers.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          McpPointerGallery(
            pointers: _mcpPointers,
            size: 'small',
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
            color: Colors.blue.shade900,
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Processing: ${state.intent}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (state is MultimodalOrchestratorExecuting) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Executing commands (${state.completedCommands}/${state.totalCommands})',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ],
            ),
          );
        }

        if (state is MultimodalOrchestratorSuccess) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade900,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 12),
                Text(
                  'Success: ${state.result.results.length} commands completed',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (state is MultimodalOrchestratorFailure) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade900,
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: ${state.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
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

  void _handleCameraTap() {
    // For now, use the same photo flow but we can differentiate later
    context.read<MultimodalOrchestratorBloc>().add(const UserTappedPhotoIcon());
  }

  void _handleVoiceTap() {
    context.read<MultimodalOrchestratorBloc>().add(const UserTappedAudioIcon());
  }

  void _saveEntry() {
    // TODO: Implement journal entry saving with MCP integration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Journal entry saved'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

