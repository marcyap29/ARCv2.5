import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/arc/core/widgets/emotion_picker.dart';
import 'package:my_app/arc/core/widgets/reason_picker.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/features/journal/widgets/draft_recovery_dialog.dart';

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
  bool _draftRecoveryAttempted = false; // Circuit breaker to prevent infinite loops

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
    
    // Check for recoverable drafts on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRecoverableDraft();
    });
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

  /// Check for recoverable drafts and navigate appropriately
  Future<void> _checkForRecoverableDraft() async {
    // Circuit breaker to prevent infinite loops
    if (_draftRecoveryAttempted) {
      debugPrint('Draft recovery already attempted, skipping');
      return;
    }
    _draftRecoveryAttempted = true;

    try {
      debugPrint('Starting draft recovery check...');
      final draftCache = DraftCacheService.instance;
      await draftCache.initialize();
      final recoverableDraft = await draftCache.getRecoverableDraft();

      if (recoverableDraft != null && recoverableDraft.hasContent && mounted) {
        // Check if the draft has all necessary components for advanced writing
        final hasEmotion = recoverableDraft.initialEmotion != null;
        final hasReason = recoverableDraft.initialReason != null;
        final hasContent = recoverableDraft.content.trim().isNotEmpty;

        if (hasEmotion && hasReason && hasContent) {
          // Complete draft - navigate directly to advanced writing interface
          debugPrint('Complete draft found, navigating to advanced writing');
          _navigateToAdvancedWriting(recoverableDraft);
        } else {
          // Incomplete draft - show recovery dialog and resume normal flow
          debugPrint('Incomplete draft found, showing recovery dialog');
          await DraftRecoveryDialog.show(
            context,
            recoverableDraft,
            onRestore: () => _restoreDraft(recoverableDraft),
            onDiscard: () => _discardDraft(),
            onViewHistory: () async {
              // TODO: Implement draft history view
              debugPrint('Draft history view requested');
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for recoverable draft: $e');
      // Continue with normal flow if draft recovery fails
    }
  }

  /// Navigate directly to advanced writing interface with complete draft
  void _navigateToAdvancedWriting(JournalDraft draft) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => JournalScreen(
          selectedEmotion: draft.initialEmotion,
          selectedReason: draft.initialReason,
          initialContent: draft.content,
        ),
      ),
    );
  }

  /// Restore draft data and navigate to appropriate step
  void _restoreDraft(JournalDraft draft) {
    setState(() {
      _selectedEmotion = draft.initialEmotion;
      _selectedReason = draft.initialReason;
      _textContent = draft.content;
      _textController.text = _textContent;
      _mediaItems.clear();
      _mediaItems.addAll(draft.mediaItems);
    });

    // Navigate to appropriate page based on restored data
    if (_selectedEmotion != null && _selectedReason != null) {
      // Go directly to writing page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.animateTo(
          2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    } else if (_selectedEmotion != null) {
      // Go to reason picker
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.animateTo(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
    // If no emotion selected, stay on first page (emotion picker)
  }

  /// Discard the current draft
  Future<void> _discardDraft() async {
    try {
      final draftCache = DraftCacheService.instance;
      await draftCache.discardDraft();
    } catch (e) {
      debugPrint('Error discarding draft: $e');
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