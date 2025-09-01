import 'package:equatable/equatable.dart';

class OnboardingState extends Equatable {
  final int currentPage;
  final String? purpose;
  final String? feeling;
  final String? rhythm;
  final String? currentSeason;
  final String? centralWord;
  final bool isCompleted;

  const OnboardingState({
    this.currentPage = 0,
    this.purpose,
    this.feeling,
    this.rhythm,
    this.currentSeason,
    this.centralWord,
    this.isCompleted = false,
  });

  OnboardingState copyWith({
    int? currentPage,
    String? purpose,
    String? feeling,
    String? rhythm,
    String? currentSeason,
    String? centralWord,
    bool? isCompleted,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      purpose: purpose ?? this.purpose,
      feeling: feeling ?? this.feeling,
      rhythm: rhythm ?? this.rhythm,
      currentSeason: currentSeason ?? this.currentSeason,
      centralWord: centralWord ?? this.centralWord,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        currentPage,
        purpose,
        feeling,
        rhythm,
        currentSeason,
        centralWord,
        isCompleted,
      ];
}
