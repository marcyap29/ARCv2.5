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
  late TextSpan _textSpan;
  bool _isComposing = false;

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
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_isComposing) {
      setState(() {
        _updateTextSpan();
      });
      widget.onChanged(_controller.text);
    }
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
            style: widget.style ?? const TextStyle(
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
              color: Colors.blue.shade300,
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
    
    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Rich text display
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: RichText(
                  text: _textSpan,
                ),
              ),
            ),
            // Invisible text field for input
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: widget.maxLines,
              textInputAction: widget.textInputAction,
              style: const TextStyle(
                color: Colors.transparent,
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
                _isComposing = true;
                setState(() {
                  _updateTextSpan();
                });
                widget.onChanged(value);
                _isComposing = false;
              },
            ),
          ],
        ),
      ),
    );
  }
}
