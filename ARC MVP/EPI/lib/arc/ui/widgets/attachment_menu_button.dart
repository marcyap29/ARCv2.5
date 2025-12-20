// lib/arc/ui/widgets/attachment_menu_button.dart
// Consolidated Attachment Menu - Single "+" icon with dropdown

import 'package:flutter/material.dart';

/// Attachment Menu Button
/// 
/// Replaces separate image/video/camera icons with a single "+" icon
/// that expands into a dropdown menu.
class AttachmentMenuButton extends StatefulWidget {
  final VoidCallback? onPhotoGallery;
  final VoidCallback? onCamera;
  final VoidCallback? onVideoGallery;
  final VoidCallback? onAudio; // Future-proof
  final VoidCallback? onFile; // Future-proof
  
  const AttachmentMenuButton({
    super.key,
    this.onPhotoGallery,
    this.onCamera,
    this.onVideoGallery,
    this.onAudio,
    this.onFile,
  });

  @override
  State<AttachmentMenuButton> createState() => _AttachmentMenuButtonState();
}

class _AttachmentMenuButtonState extends State<AttachmentMenuButton> {
  bool _showMenu = false;
  
  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }
  
  void _handleAction(VoidCallback? action) {
    _toggleMenu();
    action?.call();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main "+" button
        IconButton(
          onPressed: _toggleMenu,
          icon: Icon(
            _showMenu ? Icons.close : Icons.add,
            size: 18,
          ),
          tooltip: 'Add Attachment',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
        
        // Dropdown menu
        if (_showMenu)
          Positioned(
            bottom: 50,
            left: 0,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surface,
              child: Container(
                constraints: const BoxConstraints(minWidth: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onPhotoGallery != null)
                      _buildMenuItem(
                        context: context,
                        icon: Icons.add_photo_alternate,
                        label: 'Add Photo',
                        onTap: () => _handleAction(widget.onPhotoGallery),
                      ),
                    if (widget.onCamera != null)
                      _buildMenuItem(
                        context: context,
                        icon: Icons.camera_alt,
                        label: 'Take Photo',
                        onTap: () => _handleAction(widget.onCamera),
                      ),
                    if (widget.onVideoGallery != null)
                      _buildMenuItem(
                        context: context,
                        icon: Icons.videocam,
                        label: 'Add Video',
                        onTap: () => _handleAction(widget.onVideoGallery),
                      ),
                    if (widget.onAudio != null)
                      _buildMenuItem(
                        context: context,
                        icon: Icons.mic,
                        label: 'Record Audio',
                        onTap: () => _handleAction(widget.onAudio),
                      ),
                    if (widget.onFile != null)
                      _buildMenuItem(
                        context: context,
                        icon: Icons.attach_file,
                        label: 'Add File',
                        onTap: () => _handleAction(widget.onFile),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
