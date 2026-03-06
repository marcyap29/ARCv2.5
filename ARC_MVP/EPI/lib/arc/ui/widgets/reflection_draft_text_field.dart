import 'package:flutter/material.dart';

/// Shared editable text field used for reflection (journal) and writing agent drafts.
/// Keeps UX consistent: same look, feel, and behavior so users have a single
/// familiar writing experience across reflection mode and LUMARA writing outputs.
class ReflectionDraftTextField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String)? onChanged;
  final String hintText;
  final int? minLines;
  final int? maxLines;
  final TextStyle? style;
  final bool autofocus;

  const ReflectionDraftTextField({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = "What's on your mind right now?",
    this.minLines,
    this.maxLines,
    this.style,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final effectiveStyle = style ??
        theme.textTheme.bodyLarge?.copyWith(
          color: onSurface,
          fontSize: 16,
          height: 1.5,
        );
    final hintStyle = theme.textTheme.bodyLarge?.copyWith(
      color: onSurface.withOpacity(0.5),
      fontSize: 16,
      height: 1.5,
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      textCapitalization: TextCapitalization.sentences,
      style: effectiveStyle,
      cursorColor: onSurface,
      cursorWidth: 2.0,
      cursorHeight: 20.0,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
      ),
      textInputAction: TextInputAction.newline,
    );
  }
}
