// lib/arc/outputs/outputs_cubit.dart
//
// Phase 5a: State for Outputs tab (items, sort, search).

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/arc/outputs/outputs_repository.dart';

class OutputsCubit extends Cubit<OutputsState> {
  OutputsCubit() : super(OutputsState(items: [], sortByTitle: false, searchQuery: '')) {
    _subscribe();
  }

  final OutputsRepository _repo = OutputsRepository.instance;
  void _subscribe() {
    _repo.streamItems().listen((items) {
      if (isClosed) return;
      emit(state.copyWith(items: items));
    });
  }

  void setSortByTitle(bool value) {
    emit(state.copyWith(sortByTitle: value));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query.trim()));
  }

  Future<void> saveItem(OutputItem item) async {
    await _repo.save(item);
  }

  Future<void> updateUserTags(String itemId, List<String> userTags) async {
    await _repo.updateUserTags(itemId, userTags);
  }

  Future<void> deleteItem(String itemId) async {
    await _repo.delete(itemId);
  }
}

class OutputsState {
  final List<OutputItem> items;
  final bool sortByTitle;
  final String searchQuery;

  OutputsState({
    required this.items,
    this.sortByTitle = false,
    this.searchQuery = '',
  });

  OutputsState copyWith({
    List<OutputItem>? items,
    bool? sortByTitle,
    String? searchQuery,
  }) {
    return OutputsState(
      items: items ?? this.items,
      sortByTitle: sortByTitle ?? this.sortByTitle,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
