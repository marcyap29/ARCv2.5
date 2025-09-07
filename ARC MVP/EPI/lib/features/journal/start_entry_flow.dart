import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/widgets/emotion_picker.dart';
import 'package:my_app/features/journal/widgets/reason_picker.dart';
import 'package:my_app/features/journal/widgets/keyword_analysis_view.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/core/i18n/copy.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/features/journal/media/media_capture_sheet.dart';
import 'package:my_app/features/journal/media/media_strip.dart';
import 'package:my_app/features/journal/media/media_preview_dialog.dart';
import 'package:my_app/core/services/media_store.dart';

class StartEntryFlow extends StatefulWidget {
  const StartEntryFlow({super.key});

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
  final MediaStore _mediaStore = MediaStore();

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _onEmotionSelected(String emotion) {
    setState(() {
      _selectedEmotion = emotion;
    });
    
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
    
    // Animate to text editor
    Future.delayed(const Duration(milliseconds: 300), () {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onTextChanged(String text) {
    setState(() {
      _textContent = text;
    });
  }

  void _onSaveEntry() {
    if (_textContent.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before proceeding'),
          backgroundColor: kcDangerColor,
        ),
      );
      return;
    }

    // Navigate to keyword analysis with all the data
    Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => JournalCaptureCubit(context.read<JournalRepository>()),
        ),
        BlocProvider(
          create: (context) => KeywordExtractionCubit()..initialize(),
        ),
      ],
          child: KeywordAnalysisView(
            content: _textContent,
            mood: _selectedEmotion ?? '',
            initialEmotion: _selectedEmotion,
            initialReason: _selectedReason,
          ),
        ),
      ),
    ).then((result) {
      // Handle save result - if saved successfully, go back to home
      if (result != null && result['save'] == true) {
        // Navigate back to the previous screen
        Navigator.of(context).pop();
      }
    });
  }

  void _onMediaCaptured(MediaItem mediaItem) {
    setState(() {
      _mediaItems.add(mediaItem);
    });
  }

  void _onMediaDeleted(MediaItem mediaItem) async {
    try {
      await _mediaStore.deleteMedia(mediaItem.uri);
      setState(() {
        _mediaItems.remove(mediaItem);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete media: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  void _onMediaPreview(MediaItem mediaItem) {
    showDialog(
      context: context,
      builder: (context) => MediaPreviewDialog(
        mediaItem: mediaItem,
        onDelete: () {
          _onMediaDeleted(mediaItem);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showMediaCaptureSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaCaptureSheet(
        onMediaCaptured: _onMediaCaptured,
      ),
    );
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
            ),
          
          // Step 3: Text Editor
          if (_selectedReason != null)
            _buildTextEditor(),
        ],
      ),
    );
  }

  Widget _buildTextEditor() {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: kcPrimaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Container(
              height: MediaQuery.of(context).size.height - 
                     MediaQuery.of(context).padding.top - 
                     MediaQuery.of(context).padding.bottom,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
                  onPressed: () {
                    // Check if we can go back in the PageView
                    if (_pageController.page != null && _pageController.page! > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                      );
                    } else {
                      // If we're on the first page, just pop back to previous screen
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Context hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$_selectedEmotion • $_selectedReason",
                    style: captionStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  "Write what is true right now",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 28,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  Copy.editorSubtext,
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Media Capture Toolbar
                Card(
                  color: kcSurfaceAltColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Media',
                          style: heading1Style(context).copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Microphone button
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              child: Semantics(
                                label: 'Record voice note',
                                button: true,
                                child: IconButton(
                                  icon: const Icon(Icons.mic, color: kcPrimaryColor),
                                  onPressed: () {
                                    // TODO: Implement voice recording
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Voice recording coming soon!'),
                                        backgroundColor: kcPrimaryColor,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Camera button
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              child: Semantics(
                                label: 'Take photo',
                                button: true,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, color: kcPrimaryColor),
                                  onPressed: _showMediaCaptureSheet,
                                ),
                              ),
                            ),
                            // Gallery button
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              child: Semantics(
                                label: 'Import from gallery',
                                button: true,
                                child: IconButton(
                                  icon: const Icon(Icons.photo_library, color: kcPrimaryColor),
                                  onPressed: _showMediaCaptureSheet,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Media Strip
                if (_mediaItems.isNotEmpty) ...[
                  MediaStrip(
                    mediaItems: _mediaItems,
                    onMediaTapped: _onMediaPreview,
                    onMediaDeleted: _onMediaDeleted,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Text editor
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      onChanged: _onTextChanged,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: bodyStyle(context).copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      cursorColor: Colors.white,
                      cursorWidth: 2.0,
                      cursorHeight: 20.0,
                      decoration: InputDecoration(
                        hintText: Copy.editorPlaceholder,
                        hintStyle: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: kcPrimaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: _onSaveEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: buttonStyle(context).copyWith(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }
}