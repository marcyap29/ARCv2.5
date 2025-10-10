import 'package:flutter/material.dart';
import 'package:my_app/mcp/orchestrator/multimodal_integration_service.dart';
import 'package:my_app/mcp/models/mcp_schemas.dart';

/// Quick Journal Entry Widget - Floating multimodal access panel
class QuickJournalEntryWidget extends StatefulWidget {
  final Function(String text, List<McpPointer> media)? onEntryCreated;
  final VoidCallback? onNewEntryPressed;
  
  const QuickJournalEntryWidget({
    super.key,
    this.onEntryCreated,
    this.onNewEntryPressed,
  });

  @override
  State<QuickJournalEntryWidget> createState() => _QuickJournalEntryWidgetState();
}

class _QuickJournalEntryWidgetState extends State<QuickJournalEntryWidget> {
  final List<McpPointer> _attachedMedia = [];
  bool _isProcessing = false;
  String? _error;
  bool _showQuickPanel = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main floating action button
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _toggleQuickPanel,
            backgroundColor: Colors.blue,
            child: Icon(
              _showQuickPanel ? Icons.close : Icons.add,
              color: Colors.white,
            ),
          ),
        ),
        
        // Quick panel overlay
        if (_showQuickPanel)
          Positioned(
            bottom: 100,
            right: 20,
            child: _buildQuickPanel(),
          ),
      ],
    );
  }

  Widget _buildQuickPanel() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Quick Journal Entry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleQuickPanel,
                  icon: const Icon(Icons.close, color: Colors.white),
                  iconSize: 20,
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // New Entry Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleNewEntry,
                    icon: const Icon(Icons.create),
                    label: const Text('New Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Multimodal buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildMediaButton(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: _handlePhotoTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMediaButton(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: _handleCameraTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMediaButton(
                        icon: Icons.mic,
                        label: 'Voice',
                        onTap: _handleVoiceTap,
                      ),
                    ),
                  ],
                ),
                
                // Status indicators
                if (_isProcessing) ...[
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Processing...'),
                    ],
                  ),
                ],
                
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade800, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _error = null),
                          icon: Icon(Icons.close, color: Colors.red.shade800, size: 16),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Attached media
                if (_attachedMedia.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attached (${_attachedMedia.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _attachedMedia.map((pointer) {
                            return Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      pointer.mediaType == 'image' 
                                          ? Icons.image 
                                          : Icons.audiotrack,
                                      size: 16,
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => _removeMedia(pointer),
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 8,
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
                  ),
                ],
              ],
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _isProcessing ? Colors.grey.shade200 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isProcessing ? Colors.grey.shade300 : Colors.blue.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: _isProcessing ? Colors.grey : Colors.blue,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: _isProcessing ? Colors.grey : Colors.blue,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleQuickPanel() {
    setState(() {
      _showQuickPanel = !_showQuickPanel;
    });
  }

  void _handleNewEntry() {
    widget.onNewEntryPressed?.call();
    _toggleQuickPanel();
  }

  Future<void> _handlePhotoTap() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final pointers = await MultimodalIntegrationService.selectPhotos();
      setState(() {
        _attachedMedia.addAll(pointers);
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
          _attachedMedia.add(pointer);
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
          _attachedMedia.add(pointer);
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

  void _removeMedia(McpPointer pointer) {
    setState(() {
      _attachedMedia.remove(pointer);
    });
  }
}

/// Quick Journal Entry Button - Simple floating button version
class QuickJournalEntryButton extends StatefulWidget {
  final Function(String text, List<McpPointer> media)? onEntryCreated;
  final VoidCallback? onNewEntryPressed;
  
  const QuickJournalEntryButton({
    super.key,
    this.onEntryCreated,
    this.onNewEntryPressed,
  });

  @override
  State<QuickJournalEntryButton> createState() => _QuickJournalEntryButtonState();
}

class _QuickJournalEntryButtonState extends State<QuickJournalEntryButton> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _showQuickOptions,
      backgroundColor: Colors.blue,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showQuickOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Quick Journal Entry',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // New Entry Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onNewEntryPressed?.call();
                        },
                        icon: const Icon(Icons.create),
                        label: const Text('New Entry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Multimodal buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildMediaButton(
                            icon: Icons.photo_library,
                            label: 'Gallery',
                            onTap: () => _handleMediaAction('gallery'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMediaButton(
                            icon: Icons.camera_alt,
                            label: 'Camera',
                            onTap: () => _handleMediaAction('camera'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMediaButton(
                            icon: Icons.mic,
                            label: 'Voice',
                            onTap: () => _handleMediaAction('voice'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.blue,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMediaAction(String type) {
    Navigator.pop(context);
    
    switch (type) {
      case 'gallery':
        // TODO: Handle gallery selection
        break;
      case 'camera':
        // TODO: Handle camera capture
        break;
      case 'voice':
        // TODO: Handle voice recording
        break;
    }
  }
}

