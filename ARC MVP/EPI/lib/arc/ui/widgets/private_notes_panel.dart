// lib/arc/ui/widgets/private_notes_panel.dart
// Private Notes Panel - Local-only safe area for notes ARC cannot see

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/arc/core/private_notes_storage.dart';

/// Private Notes Panel Widget
/// 
/// **PRIVACY GUARANTEE:**
/// Content typed here is never processed, analyzed, or visible to ARC's intelligence layers.
class PrivateNotesPanel extends StatefulWidget {
  final String entryId;
  final VoidCallback? onClose;
  
  const PrivateNotesPanel({
    super.key,
    required this.entryId,
    this.onClose,
  });

  @override
  State<PrivateNotesPanel> createState() => _PrivateNotesPanelState();
}

class _PrivateNotesPanelState extends State<PrivateNotesPanel> {
  late final TextEditingController _controller;
  final PrivateNotesStorage _storage = PrivateNotesStorage.instance;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadNote();
    _controller.addListener(_onTextChanged);
  }
  
  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }
  
  void _onTextChanged() {
    if (!_isLoading) {
      setState(() {
        _hasUnsavedChanges = true;
      });
      // Auto-save after 2 seconds of no typing
      _debounceSave();
    }
  }
  
  Timer? _saveTimer;
  void _debounceSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      _saveNote();
    });
  }
  
  Future<void> _loadNote() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final content = await _storage.loadPrivateNote(widget.entryId);
      if (content != null) {
        _controller.text = content;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load private notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _saveNote() async {
    if (!_hasUnsavedChanges) return;
    
    try {
      final content = _controller.text.trim();
      if (content.isEmpty) {
        await _storage.deletePrivateNote(widget.entryId);
      } else {
        await _storage.savePrivateNote(widget.entryId, content);
      }
      
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save private notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with privacy indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Private Notes',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Stored locally and never analyzed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasUnsavedChanges)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _saveNote();
                    widget.onClose?.call();
                  },
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // Text area
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: 'Write private notes here...\n\nARC cannot see this content.',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium,
                      textAlignVertical: TextAlignVertical.top,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
