import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'insight_service.dart';
import 'models/insight_card.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';

/// State for insight generation
abstract class InsightState extends Equatable {
  const InsightState();

  @override
  List<Object?> get props => [];
}

class InsightInitial extends InsightState {}

class InsightLoading extends InsightState {}

class InsightLoaded extends InsightState {
  final List<InsightCard> cards;
  final DateTime lastUpdated;

  const InsightLoaded({
    required this.cards,
    required this.lastUpdated,
  });

  @override
  List<Object?> get props => [cards, lastUpdated];
}

class InsightError extends InsightState {
  final String message;

  const InsightError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Cubit for managing insight generation and state
class InsightCubit extends Cubit<InsightState> {
  final InsightService _insightService;
  final String _userId;

  InsightCubit({
    required InsightService insightService,
    required String userId,
  }) : _insightService = insightService,
       _userId = userId,
       super(InsightInitial()) {
    print('DEBUG: InsightCubit constructor called');
  }

  /// Generate insights for the last 7 days
  Future<void> generateInsights() async {
    print('DEBUG: InsightCubit.generateInsights called');
    emit(InsightLoading());
    print('DEBUG: Emitted InsightLoading - current state: ${state.runtimeType}');

    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final cards = await _insightService.generateInsights(
        periodStart: sevenDaysAgo,
        periodEnd: now,
      );

      print('DEBUG: InsightCubit emitting InsightLoaded with ${cards.length} cards');
      emit(InsightLoaded(
        cards: cards,
        lastUpdated: now,
      ));
      print('DEBUG: Emitted InsightLoaded - current state: ${state.runtimeType}');
    } catch (e) {
      print('DEBUG: InsightCubit emitting InsightError: $e');
      emit(InsightError('Failed to generate insights: $e'));
      print('DEBUG: Emitted InsightError - current state: ${state.runtimeType}');
    }
  }

  /// Generate insights for a specific period
  Future<void> generateInsightsForPeriod({
    required DateTime start,
    required DateTime end,
  }) async {
    emit(InsightLoading());

    try {
      final cards = await _insightService.generateInsights(
        periodStart: start,
        periodEnd: end,
      );

      emit(InsightLoaded(
        cards: cards,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      emit(InsightError('Failed to generate insights: $e'));
    }
  }

  /// Load existing insights from storage
  Future<void> loadStoredInsights() async {
    emit(InsightLoading());

    try {
      final box = await Hive.openBox<InsightCard>('insight_cards');
      final cards = box.values.toList();
      
      // Sort by creation date, newest first
      cards.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      emit(InsightLoaded(
        cards: cards,
        lastUpdated: DateTime.now(),
      ));
    } catch (e) {
      emit(InsightError('Failed to load stored insights: $e'));
    }
  }

  /// Store insights to Hive
  Future<void> storeInsights(List<InsightCard> cards) async {
    try {
      final box = await Hive.openBox<InsightCard>('insight_cards');
      
      // Clear existing cards for this period
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final existingCards = box.values.where((card) =>
          card.periodStart.isAfter(sevenDaysAgo) && 
          card.periodEnd.isBefore(now)).toList();
      
      for (final card in existingCards) {
        await box.delete(card.id);
      }
      
      // Store new cards
      for (final card in cards) {
        await box.put(card.id, card);
      }
    } catch (e) {
      print('ERROR: Failed to store insights: $e');
    }
  }

  /// Clear all insights
  Future<void> clearInsights() async {
    try {
      final box = await Hive.openBox<InsightCard>('insight_cards');
      await box.clear();
      emit(InsightLoaded(cards: const [], lastUpdated: DateTime.now()));
    } catch (e) {
      emit(InsightError('Failed to clear insights: $e'));
    }
  }
}

/// Factory for creating InsightCubit with dependencies
class InsightCubitFactory {
  static InsightCubit create({
    required JournalRepository journalRepository,
    RivetProvider? rivetProvider,
    required String userId,
  }) {
    final insightService = InsightService(
      journalRepository: journalRepository,
      rivetProvider: rivetProvider,
      userId: userId,
    );
    
    return InsightCubit(
      insightService: insightService,
      userId: userId,
    );
  }
}
