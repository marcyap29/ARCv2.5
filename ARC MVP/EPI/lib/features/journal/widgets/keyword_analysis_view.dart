import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_state.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/timeline/timeline_cubit.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class KeywordAnalysisView extends StatefulWidget {
  final String content;
  final String mood;
  final String? initialEmotion;
  final String? initialReason;
  
  const KeywordAnalysisView({
    super.key,
    required this.content,
    required this.mood,
    this.initialEmotion,
    this.initialReason,
  });

  @override
  State<KeywordAnalysisView> createState() => _KeywordAnalysisViewState();
}

class _KeywordAnalysisViewState extends State<KeywordAnalysisView>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize progress animation
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // Start keyword extraction and animation
    context.read<KeywordExtractionCubit>().extractKeywords(widget.content);
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onSaveEntry() async {
    final keywordState = context.read<KeywordExtractionCubit>().state;
    if (keywordState is KeywordExtractionLoaded) {
      // Save entry directly without showing phase dialog
      // Phase detection is now handled by Phase Quiz or RIVET system
      context.read<JournalCaptureCubit>().saveEntryWithKeywords(
        content: widget.content,
        mood: widget.mood,
        selectedKeywords: keywordState.selectedKeywords,
        emotion: widget.initialEmotion,
        emotionReason: widget.initialReason,
        context: context,
      );
      
      // Show simple success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry saved successfully'),
            backgroundColor: kcSuccessColor,
          ),
        );
        
        // Refresh timeline and navigate back to home
        context.read<TimelineCubit>().refreshEntries();
        
        // Navigate back to home screen (removing all journal creation screens)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeView()),
          (route) => false,
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: kcBackgroundColor,
        appBar: AppBar(
          backgroundColor: kcBackgroundColor,
          title: Text('ARC Analysis', style: heading1Style(context)),
          actions: [
          BlocBuilder<KeywordExtractionCubit, KeywordExtractionState>(
            builder: (context, state) {
              if (state is KeywordExtractionLoaded && 
                  state.selectedKeywords.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ElevatedButton(
                    onPressed: _onSaveEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text('Save Entry', style: buttonStyle(context)),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<KeywordExtractionCubit, KeywordExtractionState>(
        builder: (context, state) {
          if (state is KeywordExtractionLoading || state is KeywordExtractionInitial) {
            return _buildAnalysisProgress();
          }

          if (state is KeywordExtractionLoaded) {
            return _buildKeywordSelection(state);
          }

          if (state is KeywordExtractionError) {
            return _buildErrorState(state.message);
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildAnalysisProgress() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sacred geometry animation/icon
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              gradient: kcPrimaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_graph,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            'ARC is analyzing your entry',
            style: heading1Style(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          Text(
            'Discovering the keywords that matter most...',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: kcSurfaceColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          kcPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_progressAnimation.value * 100).round()}%',
                    style: captionStyle(context).copyWith(
                      color: kcPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordSelection(KeywordExtractionLoaded state) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: kcPrimaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keywords Discovered',
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose keywords that best represent your reflection',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Context reminder
          if (widget.initialEmotion != null || widget.initialReason != null) ...[
            Text(
              'Your reflection context:',
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.initialEmotion != null) ...[
                  _buildContextTag(widget.initialEmotion!),
                  const SizedBox(width: 8),
                ],
                if (widget.initialReason != null)
                  _buildContextTag(widget.initialReason!),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // Selection count
          Text(
            'Selected: ${state.selectedKeywords.length}',
            style: heading2Style(context).copyWith(
              color: state.selectedKeywords.isNotEmpty ? kcPrimaryColor : kcSecondaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          
          // Keywords grid
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: state.suggestedKeywords
                    .map((keyword) => _buildKeywordChip(keyword, state.selectedKeywords))
                    .toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Selection guidance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcSurfaceAltColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.selectedKeywords.isEmpty)
                  Text(
                    'Select at least 1 keyword to save your entry',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  )
                else
                  Text(
                    'Great selection! Tap "Save Entry" when ready.',
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcSecondaryColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: captionStyle(context).copyWith(
          color: kcSecondaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildKeywordChip(String keyword, List<String> selectedKeywords) {
    final isSelected = selectedKeywords.contains(keyword);
    
    return GestureDetector(
      onTap: () {
        context.read<KeywordExtractionCubit>().toggleKeyword(keyword);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? kcPrimaryColor : kcSurfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected 
                ? kcPrimaryColor 
                : kcSecondaryColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          keyword,
          style: bodyStyle(context).copyWith(
            color: isSelected 
                ? Colors.white 
                : kcSecondaryColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: kcDangerColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Analysis Failed',
              style: heading1Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<KeywordExtractionCubit>().extractKeywords(widget.content);
                _progressController.reset();
                _progressController.forward();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
              ),
              child: Text('Try Again', style: buttonStyle(context)),
            ),
          ],
        ),
      ),
    );
  }
}