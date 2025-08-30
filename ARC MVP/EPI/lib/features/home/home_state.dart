import 'package:equatable/equatable.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoaded extends HomeState {
  final int selectedIndex;
  
  const HomeLoaded({this.selectedIndex = 0});

  @override
  List<Object> get props => [selectedIndex];
}
