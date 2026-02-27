import 'package:flutter/material.dart';
import 'package:my_app/data/models/media_item.dart';

// Import multimodal integration
import 'package:my_app/mira/store/mcp/orchestrator/multimodal_integration_service.dart';
import 'package:my_app/mira/store/mcp/models/mcp_schemas.dart';

class JournalCaptureViewMultimodal extends StatefulWidget {
  final String? initialEmotion;
  final String? initialReason;
  
  const JournalCaptureViewMultimodal({
    super.key,
    this.initialEmotion,
    this.initialReason,
  });

  @override
  State<JournalCaptureViewMultimodal> createState() => _JournalCaptureViewMultimodalState();
}

class _JournalCaptureViewMultimodalState extends State<JournalCaptureViewMultimodal> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  
  // Media management
  final List<MediaItem> _mediaItems = [];
  final List<McpPointer> _mcpPointers = [];
  bool _isProcessing = false;
  String? _error;

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
                  
                  // Error display
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _error = null),
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                  
                  // Attached media display
                  if (_mcpPointers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildAttachedMedia(),
                  ],
                ],
              ),
            ),
          ),
          
          // Processing indicator
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade900,
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing media...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          
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
      onTap: _isProcessing ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: _isProcessing ? Colors.grey : Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _isProcessing ? Colors.grey : Colors.white70,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mcpPointers.map((pointer) {
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        pointer.mediaType == 'image' 
                            ? Icons.image 
                            : Icons.audiotrack,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePointer(pointer),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePhotoTap() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final pointers = await MultimodalIntegrationService.selectPhotos();
      setState(() {
        _mcpPointers.addAll(pointers);
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleCameraTap() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final pointer = await MultimodalIntegrationService.capturePhoto();
      if (pointer != null) {
        setState(() {
          _mcpPointers.add(pointer);
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleVoiceTap() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final pointer = await MultimodalIntegrationService.recordAudio();
      if (pointer != null) {
        setState(() {
          _mcpPointers.add(pointer);
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  void _removePointer(McpPointer pointer) {
    setState(() {
      _mcpPointers.remove(pointer);
    });
  }

  void _saveEntry() {
    // TODO: Implement journal entry saving with MCP integration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conversation saved with ${_mcpPointers.length} media items'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

