import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AIStyledTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final TextStyle? style;

  const AIStyledTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.maxLines,
    this.textInputAction,
    this.style,
  });

  @override
  State<AIStyledTextField> createState() => _AIStyledTextFieldState();
}

class _AIStyledTextFieldState extends State<AIStyledTextField> {
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
          inputFormatters: [
            _AISuggestionFormatter(),
          ],
          style: widget.style ?? const TextStyle(
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
            widget.onChanged(value);
          },
        ),
      ),
    );
  }
}

/// Custom text input formatter to handle AI suggestion styling
class _AISuggestionFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // For now, just return the new value as-is
    // The AI suggestion styling will be handled by the journal screen
    // when displaying the text, not during input
    return newValue;
  }
}
