import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AIEnhancedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;
  final int? maxLines;
  final TextInputAction? textInputAction;

  const AIEnhancedTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.maxLines,
    this.textInputAction,
  });

  @override
  State<AIEnhancedTextField> createState() => _AIEnhancedTextFieldState();
}

class _AIEnhancedTextFieldState extends State<AIEnhancedTextField> {
  late TextEditingController _controller;
  late TextSpan _textSpan;
  late TextSelection _selection;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onTextChanged);
    _updateTextSpan();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _updateTextSpan();
    });
    widget.onChanged(_controller.text);
  }

  void _updateTextSpan() {
    final text = _controller.text;
    final spans = <TextSpan>[];
    
    // Split text by AI suggestion markers
    final parts = text.split(RegExp(r'\[AI_SUGGESTION_START\](.*?)\[AI_SUGGESTION_END\]'));
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Regular text
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(
            text: parts[i],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ));
        }
      } else {
        // AI suggestion text
        if (parts[i].isNotEmpty) {
          spans.add(TextSpan(
            text: parts[i],
            style: TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              backgroundColor: Colors.blue.withOpacity(0.1),
            ),
          ));
        }
      }
    }

    _textSpan = TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _controller,
        maxLines: widget.maxLines,
        textInputAction: widget.textInputAction,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          // This will be handled by the controller listener
        },
      ),
    );
  }
}
