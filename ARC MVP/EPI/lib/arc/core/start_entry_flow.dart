import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/arc/core/widgets/emotion_picker.dart';
import 'package:my_app/arc/core/widgets/reason_picker.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/services/journal_session_cache.dart';
import 'package:my_app/ui/journal/journal_screen.dart';

class StartEntryFlow extends StatefulWidget {
  final VoidCallback? onExitToPhase;
  
  const StartEntryFlow({super.key, this.onExitToPhase});

  @override
  State<StartEntryFlow> createState() => _StartEntryFlowState();
}

class _StartEntryFlowState extends State<StartEntryFlow> {
  final PageController _pageController = PageController();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();
  String? _selectedEmotion;
  String? _selectedReason;
  String _textContent = '';
  final List<MediaItem> _mediaItems = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _textFocusNode.addListener(() {
      if (_textFocusNode.hasFocus) {
        // Scroll to show the text field when keyboard appears
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
    
    // Restore session cache on startup - TEMPORARILY DISABLED FOR UI/UX FLOW TESTING
    // _restoreSession();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pageController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  /// Restore session from cache
  Future<void> _restoreSession() async {
    try {
      final sessionData = await JournalSessionCache.restoreSession();
      if (sessionData != null && sessionData.hasData) {
        print('DEBUG: Restoring journal session: ${sessionData.summary}');
        
        setState(() {
          _selectedEmotion = sessionData.emotion;
          _selectedReason = sessionData.reason;
          _textContent = sessionData.textContent ?? '';
          _textController.text = _textContent;
        });
        
        // Restore media items if any
        if (sessionData.mediaItems != null) {
          for (final itemData in sessionData.mediaItems!) {
            try {
              final mediaItem = MediaItem.fromJson(itemData);
              _mediaItems.add(mediaItem);
            } catch (e) {
              print('ERROR: Failed to restore media item: $e');
            }
          }
        }
        
        // Navigate to appropriate page based on restored data
        if (_selectedEmotion != null && _selectedReason != null) {
          // Go to writing page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(2);
          });
        } else if (_selectedEmotion != null) {
          // Go to reason picker
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(1);
          });
        }
        
        // Show restoration message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restored previous journal session'),
              backgroundColor: kcPrimaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('ERROR: Failed to restore session: $e');
    }
  }

  void _onEmotionSelected(String emotion) {
    setState(() {
      _selectedEmotion = emotion;
    });
    
    // Cache the emotion selection - TEMPORARILY DISABLED FOR UI/UX FLOW TESTING
    // JournalSessionCache.cacheSession(emotion: emotion);
    
    // Animate to reason picker
    Future.delayed(const Duration(milliseconds: 300), () {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onReasonSelected(String reason) {
    setState(() {
      _selectedReason = reason;
    });
    
    // Cache the reason selection - TEMPORARILY DISABLED FOR UI/UX FLOW TESTING
    // JournalSessionCache.cacheSession(
    //   emotion: _selectedEmotion,
    //   reason: reason,
    // );
    
    // Animate to text editor
    Future.delayed(const Duration(milliseconds: 300), () {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Step 1: Emotion Picker
          EmotionPicker(
            onEmotionSelected: _onEmotionSelected,
            onBackPressed: () => Navigator.of(context).pop(),
            selectedEmotion: _selectedEmotion,
            onExitToPhase: widget.onExitToPhase,
          ),
          
          // Step 2: Reason Picker
          if (_selectedEmotion != null)
            ReasonPicker(
              onReasonSelected: _onReasonSelected,
              onBackPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
              ),
              selectedEmotion: _selectedEmotion!,
              selectedReason: _selectedReason,
              onExitToPhase: widget.onExitToPhase,
            ),
          
          // Step 3: Text Editor
          if (_selectedReason != null)
            _buildTextEditor(),
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    return JournalScreen(
      selectedEmotion: _selectedEmotion,
      selectedReason: _selectedReason,
    );
  }
}