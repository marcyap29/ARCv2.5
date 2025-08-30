import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/home/home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeInitial());

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  void initialize() {
    emit(HomeLoaded(selectedIndex: _currentIndex));
  }

  void changeTab(int index) {
    _currentIndex = index;
    emit(HomeLoaded(selectedIndex: _currentIndex));
  }
}
