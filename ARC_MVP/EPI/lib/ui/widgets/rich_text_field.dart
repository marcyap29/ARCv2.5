import 'package:flutter/material.dart';

class RichTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;
  final int? maxLines;
  final TextInputAction? textInputAction;

  const RichTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.maxLines,
    this.textInputAction,
  });

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: widget.maxLines,
          textInputAction: widget.textInputAction,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.4, // Ensure consistent line height
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 16,
              height: 1.4, // Match the text style height
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            // This will be handled by the controller listener
          },
        ),
      ),
    );
  }
}
