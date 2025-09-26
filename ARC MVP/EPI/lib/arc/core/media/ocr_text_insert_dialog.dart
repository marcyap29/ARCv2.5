import 'package:flutter/material.dart';

/// Dialog for inserting OCR-extracted text into the journal editor
class OCRTextInsertDialog extends StatefulWidget {
  final String extractedText;
  final Function(String) onTextInserted;
  final VoidCallback? onDismissed;
  
  const OCRTextInsertDialog({
    super.key,
    required this.extractedText,
    required this.onTextInserted,
    this.onDismissed,
  });
  
  @override
  State<OCRTextInsertDialog> createState() => _OCRTextInsertDialogState();
}

class _OCRTextInsertDialogState extends State<OCRTextInsertDialog> {
  late TextEditingController _textController;
  bool _isInserting = false;
  
  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.extractedText);
  }
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121621),
      title: const Row(
        children: [
          Icon(
            Icons.text_fields,
            color: Colors.blue,
            size: 24,
          ),
          SizedBox(width: 8),
          Text(
            'Text from Photo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We found text in your photo. Would you like to add it to your journal entry?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Extracted text:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                minHeight: 100,
                maxHeight: 200,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF171C29),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Edit the extracted text...',
                  hintStyle: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The text will be prefixed with "[from photo]" when added to your journal.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Dismiss button
        TextButton(
          onPressed: _isInserting ? null : () {
            Navigator.of(context).pop();
            widget.onDismissed?.call();
          },
          child: const Text(
            'Dismiss',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
        
        // Insert button
        ElevatedButton(
          onPressed: _isInserting ? null : _insertText,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: _isInserting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Add to Journal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ],
    );
  }
  
  Future<void> _insertText() async {
    if (_textController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter some text to add.');
      return;
    }
    
    setState(() {
      _isInserting = true;
    });
    
    try {
      // Simulate processing time
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Format text with prefix
      final formattedText = '[from photo] ${_textController.text.trim()}';
      
      // Insert text
      widget.onTextInserted(formattedText);
      
      // Close dialog
      Navigator.of(context).pop();
      
    } catch (e) {
      _showErrorSnackBar('Failed to insert text: $e');
    } finally {
      setState(() {
        _isInserting = false;
      });
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
