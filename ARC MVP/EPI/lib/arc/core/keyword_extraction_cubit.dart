import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/core/keyword_extraction_state.dart';
import 'package:my_app/prism/extractors/enhanced_keyword_extractor.dart';
import 'package:my_app/features/arcforms/phase_recommender.dart';

class KeywordExtractionCubit extends Cubit<KeywordExtractionState> {
  KeywordExtractionCubit() : super(KeywordExtractionInitial());

  void initialize() {
    emit(KeywordExtractionInitial());
  }

  void extractKeywords(String text, {String? emotion, String? reason}) {
    emit(KeywordExtractionLoading());

    // Simulate realistic processing delay for better UX
    Future.delayed(const Duration(seconds: 2), () {
      // Check if cubit is still active before emitting
      if (!isClosed) {
        try {
          // Determine current phase for context
          final currentPhase = PhaseRecommender.recommend(
            emotion: emotion ?? '',
            reason: reason ?? '',
            text: text,
          );

          // Use enhanced keyword extractor with RIVET gating
          final response = EnhancedKeywordExtractor.extractKeywords(
            entryText: text,
            currentPhase: currentPhase,
          );

          // Extract keywords from candidates
          final allKeywords = response.candidates.map((c) => c.keyword).toList();
          final preselectedKeywords = response.chips;

          emit(KeywordExtractionLoaded(
            suggestedKeywords: allKeywords,
            selectedKeywords: preselectedKeywords,
            enhancedResponse: response, // Store full response for metadata
          ));
        } catch (e) {
          if (!isClosed) {
            emit(KeywordExtractionError('Failed to extract keywords: $e'));
          }
        }
      }
    });
  }

  void toggleKeyword(String keyword) {
    if (!isClosed && state is KeywordExtractionLoaded) {
      final currentState = state as KeywordExtractionLoaded;
      final selectedKeywords = List<String>.from(currentState.selectedKeywords);

      if (selectedKeywords.contains(keyword)) {
        selectedKeywords.remove(keyword);
      } else {
        selectedKeywords.add(keyword);
      }

      emit(KeywordExtractionLoaded(
        suggestedKeywords: currentState.suggestedKeywords,
        selectedKeywords: selectedKeywords,
      ));
    }
  }
}
