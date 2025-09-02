import 'package:equatable/equatable.dart';
import 'package:my_app/features/keyword_extraction/enhanced_keyword_extractor.dart';

abstract class KeywordExtractionState extends Equatable {
  const KeywordExtractionState();

  @override
  List<Object> get props => [];
}

class KeywordExtractionInitial extends KeywordExtractionState {}

class KeywordExtractionLoading extends KeywordExtractionState {}

class KeywordExtractionLoaded extends KeywordExtractionState {
  final List<String> suggestedKeywords;
  final List<String> selectedKeywords;
  final KeywordExtractionResponse? enhancedResponse;

  const KeywordExtractionLoaded({
    required this.suggestedKeywords,
    required this.selectedKeywords,
    this.enhancedResponse,
  });

  @override
  List<Object> get props => [suggestedKeywords, selectedKeywords];

  KeywordExtractionLoaded copyWith({
    List<String>? suggestedKeywords,
    List<String>? selectedKeywords,
    KeywordExtractionResponse? enhancedResponse,
  }) {
    return KeywordExtractionLoaded(
      suggestedKeywords: suggestedKeywords ?? this.suggestedKeywords,
      selectedKeywords: selectedKeywords ?? this.selectedKeywords,
      enhancedResponse: enhancedResponse ?? this.enhancedResponse,
    );
  }
}

class KeywordExtractionError extends KeywordExtractionState {
  final String message;

  const KeywordExtractionError(this.message);

  @override
  List<Object> get props => [message];
}
