import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/keyword_extraction_state.dart';

class KeywordExtractionCubit extends Cubit<KeywordExtractionState> {
  KeywordExtractionCubit() : super(KeywordExtractionInitial());

  void initialize() {
    emit(KeywordExtractionInitial());
  }

  void extractKeywords(String text) {
    emit(KeywordExtractionLoading());

    // Simulate API call delay
    Future.delayed(const Duration(seconds: 1), () {
      // Extract keywords from text (simplified implementation)
      final words = text
          .split(RegExp(r'\s+'))
          .where((word) {
            // Filter out common words and keep only words with 3+ characters
            final commonWords = {
              'the',
              'and',
              'or',
              'but',
              'in',
              'on',
              'at',
              'to',
              'for',
              'of',
              'with',
              'by',
              'a',
              'an',
              'is',
              'are',
              'was',
              'were'
            };
            return word.length >= 3 &&
                !commonWords.contains(word.toLowerCase());
          })
          .map((word) => word.toLowerCase().replaceAll(RegExp(r'[^\w]'), ''))
          .toSet()
          .toList();

      // Take first 15 unique words as suggested keywords
      final suggestedKeywords = words.take(15).toList();

      emit(KeywordExtractionLoaded(
        suggestedKeywords: suggestedKeywords,
        selectedKeywords: const [],
      ));
    });
  }

  void toggleKeyword(String keyword) {
    if (state is KeywordExtractionLoaded) {
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
