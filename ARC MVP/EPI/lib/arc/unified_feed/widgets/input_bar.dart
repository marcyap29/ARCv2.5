/// Input Bar
///
/// The unified input bar at the bottom of the feed screen.
/// Provides text input, voice recording trigger, and attachment options.
/// This replaces the separate input areas from the old chat and journal screens.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';

class FeedInputBar extends StatefulWidget {
  /// Called when the user submits a text message.
  final ValueChanged<String>? onSubmit;

  /// Called when the user taps the voice button.
  final VoidCallback? onVoiceTap;

  /// Called when the user taps the attachment button.
  final VoidCallback? onAttachmentTap;

  /// Called when the user taps the new entry button (pen icon).
  final VoidCallback? onNewEntryTap;

  /// Placeholder text when input is empty.
  final String hintText;

  /// Whether the input bar is enabled.
  final bool enabled;

  /// Whether to show the voice button.
  final bool showVoiceButton;

  const FeedInputBar({
    super.key,
    this.onSubmit,
    this.onVoiceTap,
    this.onAttachmentTap,
    this.onNewEntryTap,
    this.hintText = 'Talk to LUMARA...',
    this.enabled = true,
    this.showVoiceButton = true,
  });

  @override
  State<FeedInputBar> createState() => _FeedInputBarState();
}

class _FeedInputBarState extends State<FeedInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit?.call(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        border: Border(
          top: BorderSide(
            color: kcBorderColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment/new entry button
          if (widget.onNewEntryTap != null)
            _buildActionButton(
              icon: Icons.edit_note,
              onTap: widget.onNewEntryTap!,
              tooltip: 'New entry',
            ),

          const SizedBox(width: 8),

          // Text input field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: kcSurfaceAltColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? kcPrimaryColor.withOpacity(0.5)
                      : kcBorderColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(
                        color: kcPrimaryTextColor,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: kcSecondaryTextColor.withOpacity(0.5),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _onSubmit(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),

                  // Attachment button (inside input field)
                  if (widget.onAttachmentTap != null && !_hasText)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: kcSecondaryTextColor.withOpacity(0.5),
                          size: 22,
                        ),
                        onPressed: widget.onAttachmentTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send or Voice button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _hasText
                ? _buildSendButton()
                : widget.showVoiceButton
                    ? _buildActionButton(
                        icon: Icons.mic,
                        onTap: widget.onVoiceTap ?? () {},
                        tooltip: 'Voice',
                        isPrimary: true,
                      )
                    : _buildSendButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      key: const ValueKey('send'),
      onTap: _hasText ? _onSubmit : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _hasText
              ? kcPrimaryColor
              : kcPrimaryColor.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_upward,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary
              ? kcPrimaryColor.withOpacity(0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isPrimary
              ? kcPrimaryColor
              : kcSecondaryTextColor.withOpacity(0.6),
          size: 22,
        ),
      ),
    );
  }
}
