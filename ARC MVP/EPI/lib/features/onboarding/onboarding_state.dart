import 'package:equatable/equatable.dart';

class OnboardingState extends Equatable {
  final int currentPage;
  final String? purpose;
  final String? feeling;
  final String? rhythm;
  final bool isCompleted;

  const OnboardingState({
    this.currentPage = 0,
    this.purpose,
    this.feeling,
    this.rhythm,
    this.isCompleted = false,
  });

  OnboardingState copyWith({
    int? currentPage,
    String? purpose,
    String? feeling,
    String? rhythm,
    bool? isCompleted,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      purpose: purpose ?? this.purpose,
      feeling: feeling ?? this.feeling,
      rhythm: rhythm ?? this.rhythm,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        currentPage,
        purpose,
        feeling,
        rhythm,
        isCompleted,
      ];
}
