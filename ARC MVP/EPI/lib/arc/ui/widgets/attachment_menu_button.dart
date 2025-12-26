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
  OverlayEntry? _overlayEntry;
  final GlobalKey _buttonKey = GlobalKey();

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });

    if (_showMenu) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final theme = Theme.of(overlayContext);
        return Stack(
          children: [
            // Backdrop to dismiss menu when tapping outside
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Menu positioned above the button
            Positioned(
              left: offset.dx,
              top: offset.dy - 200, // Position above the button
              child: GestureDetector(
                // Stop event propagation to prevent backdrop from dismissing
                onTap: () {},
                behavior: HitTestBehavior.opaque,
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
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleAction(VoidCallback? action) {
    _toggleMenu();
    action?.call();
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _buttonKey,
      child: IconButton(
        onPressed: _toggleMenu,
        icon: Icon(
          _showMenu ? Icons.close : Icons.add,
          size: 18,
        ),
        tooltip: 'Add Attachment',
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      // Use GestureDetector with opaque behavior to ensure taps are captured
      // This prevents the journal entry's GestureDetector from intercepting
      onTap: () {
        // Stop propagation and handle tap
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
        ),
      ),
    );
  }
}
