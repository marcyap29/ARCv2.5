import 'package:equatable/equatable.dart';

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

  const KeywordExtractionLoaded({
    required this.suggestedKeywords,
    required this.selectedKeywords,
  });

  @override
  List<Object> get props => [suggestedKeywords, selectedKeywords];

  KeywordExtractionLoaded copyWith({
    List<String>? suggestedKeywords,
    List<String>? selectedKeywords,
  }) {
    return KeywordExtractionLoaded(
      suggestedKeywords: suggestedKeywords ?? this.suggestedKeywords,
      selectedKeywords: selectedKeywords ?? this.selectedKeywords,
    );
  }
}
