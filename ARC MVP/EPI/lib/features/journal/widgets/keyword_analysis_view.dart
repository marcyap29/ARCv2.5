import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/keyword_extraction_cubit.dart';
import 'package:my_app/features/journal/keyword_extraction_state.dart';
import 'package:my_app/features/journal/journal_capture_cubit.dart';
import 'package:my_app/features/journal/widgets/phase_recommendation_dialog.dart';
import 'package:my_app/features/arcforms/phase_recommender.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/features/keyword_extraction/enhanced_keyword_extractor.dart';
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

    // Start keyword extraction with context and animation
    context.read<KeywordExtractionCubit>().extractKeywords(
      widget.content,
      emotion: widget.initialEmotion,
      reason: widget.initialReason,
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onSaveEntry() {
    final keywordState = context.read<KeywordExtractionCubit>().state;
    if (keywordState is KeywordExtractionLoaded) {
      _showPhaseRecommendationDialog(keywordState.selectedKeywords);
    }
  }

  void _showPhaseRecommendationDialog(List<String> selectedKeywords) {
    // Get phase recommendation with selected keywords for improved accuracy
    final recommendedPhase = PhaseRecommender.recommend(
      emotion: widget.initialEmotion ?? '',
      reason: widget.initialReason ?? '',
      text: widget.content,
      selectedKeywords: selectedKeywords,
    );
    
    final rationale = PhaseRecommender.rationale(recommendedPhase);
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PhaseRecommendationDialog(
          recommendedPhase: recommendedPhase,
          rationale: rationale,
          keywords: selectedKeywords,
          onConfirm: (String phase, ArcformGeometry? overrideGeometry) {
            Navigator.of(dialogContext).pop();
            _saveEntryWithPhaseAndGeometry(selectedKeywords, phase, overrideGeometry);
          },
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  void _saveEntryWithPhaseAndGeometry(
    List<String> selectedKeywords, 
    String phase, 
    ArcformGeometry? overrideGeometry
  ) {
    // Save the entry with phase and optional geometry override
    if (overrideGeometry != null) {
      // Use the new method that will handle geometry override
      context.read<JournalCaptureCubit>().saveEntryWithPhaseAndGeometry(
        content: widget.content,
        mood: widget.mood,
        selectedKeywords: selectedKeywords,
        emotion: widget.initialEmotion,
        emotionReason: widget.initialReason,
        phase: phase,
        overrideGeometry: overrideGeometry,
      );
    } else {
      // Use existing method for auto-detected geometry
      context.read<JournalCaptureCubit>().saveEntryWithKeywords(
        content: widget.content,
        mood: widget.mood,
        selectedKeywords: selectedKeywords,
        emotion: widget.initialEmotion,
        emotionReason: widget.initialReason,
      );
    }
    
    // Show success message and return result
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entry saved successfully'),
        backgroundColor: kcSuccessColor,
      ),
    );
    
    Navigator.of(context).pop({
      'save': true,
      'selectedKeywords': selectedKeywords,
      'phase': phase,
      'overrideGeometry': overrideGeometry?.name,
    });
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
                  'Choose up to 5 keywords that best represent your reflection',
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
          
          // Selection count and enhanced metadata
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected: ${state.selectedKeywords.length}/20',
                style: heading2Style(context).copyWith(
                  color: state.selectedKeywords.isNotEmpty ? kcPrimaryColor : kcSecondaryTextColor,
                ),
              ),
              if (state.enhancedResponse != null) ...[ 
                const SizedBox(height: 4),
                Text(
                  'Phase: ${state.enhancedResponse!.meta['current_phase']} • Enhanced with RIVET',
                  style: captionStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          
          // Keywords grid
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.suggestedKeywords
                    .map((keyword) => _buildEnhancedKeywordChip(keyword, state))
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
                else if (state.selectedKeywords.length > 20)
                  Text(
                    'Please select no more than 20 keywords',
                    style: bodyStyle(context).copyWith(
                      color: kcDangerColor,
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

  Widget _buildEnhancedKeywordChip(String keyword, KeywordExtractionLoaded state) {
    final isSelected = state.selectedKeywords.contains(keyword);
    final canSelect = state.selectedKeywords.length < 20 || isSelected;
    
    // Get enhanced metadata if available
    KeywordCandidate? candidate;
    if (state.enhancedResponse != null) {
      try {
        candidate = state.enhancedResponse!.candidates
            .firstWhere((c) => c.keyword == keyword);
      } catch (e) {
        // Keyword not found in candidates, use default styling
      }
    }
    
    // Determine chip styling based on candidate metadata
    Color chipColor = isSelected ? kcPrimaryColor : kcSurfaceColor;
    Color borderColor = isSelected 
        ? kcPrimaryColor 
        : canSelect 
            ? kcSecondaryColor.withOpacity(0.3)
            : kcSecondaryTextColor.withOpacity(0.2);
    
    // Enhanced styling for high-quality candidates
    if (candidate != null && !isSelected) {
      if (candidate.score > 0.7) {
        chipColor = kcPrimaryColor.withOpacity(0.1);
        borderColor = kcPrimaryColor.withOpacity(0.5);
      } else if (candidate.emotion.amplitude > 0.6) {
        chipColor = kcAccentColor.withOpacity(0.1);
        borderColor = kcAccentColor.withOpacity(0.4);
      }
    }
    
    return GestureDetector(
      onTap: canSelect ? () {
        context.read<KeywordExtractionCubit>().toggleKeyword(keyword);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              keyword,
              style: captionStyle(context).copyWith(
                color: isSelected 
                    ? Colors.white 
                    : canSelect 
                        ? kcSecondaryColor 
                        : kcSecondaryTextColor.withOpacity(0.5),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            // Add quality indicator for enhanced candidates
            if (candidate != null && candidate.score > 0.6 && !isSelected) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: candidate.score > 0.8 
                      ? kcPrimaryColor 
                      : candidate.emotion.amplitude > 0.5 
                          ? kcAccentColor 
                          : kcSecondaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
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
            Icon(
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