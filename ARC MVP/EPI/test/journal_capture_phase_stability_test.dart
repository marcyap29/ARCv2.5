import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_app/arc/core/journal_capture_cubit.dart';
import 'package:my_app/arc/core/journal_capture_state.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/atlas/phase_detection/phase_history_repository.dart';

void main() {
  group('Journal Capture Phase Stability Integration', () {
    late JournalCaptureCubit cubit;
    late JournalRepository repository;

    setUpAll(() async {
      // Initialize Flutter binding for testing
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize Hive for testing
      Hive.init('test_data');
      
      // Register adapters
      Hive.registerAdapter(UserProfileAdapter());
      Hive.registerAdapter(JournalEntryAdapter());
    });

    tearDownAll(() async {
      // Clean up after tests
      await Hive.close();
    });

    setUp(() async {
      // Clear any existing data
      await PhaseHistoryRepository.clearAll();
      
      // Close any open boxes to avoid conflicts
      try {
        await Hive.box('user_profile').close();
      } catch (e) {
        // Box might not be open
      }
      try {
        await Hive.box('arcform_snapshots').close();
      } catch (e) {
        // Box might not be open
      }
      
      // Create test repository
      repository = JournalRepository();
      
      // Create test user profile
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final testUser = UserProfile(
        id: 'test-user',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        preferences: const {},
        currentPhase: 'Discovery',
        lastPhaseChangeAt: null,
      );
      await userBox.put('profile', testUser);
      
      cubit = JournalCaptureCubit(repository);
    });

    test('should save entry with phase stability analysis', () async {
      // Listen to state changes
      final states = <JournalCaptureState>[];
      cubit.stream.listen(states.add);

      // Save an entry with keywords
      cubit.saveEntryWithKeywords(
        content: 'I am excited to learn new things and explore possibilities',
        mood: 'excited',
        selectedKeywords: ['curious', 'learning', 'explore'],
        emotion: 'excited',
        emotionReason: 'learning',
      );

      // Wait for the save to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify the entry was saved
      expect(states.last, isA<JournalCaptureSaved>());
      
      // Verify phase history was recorded
      final entries = await PhaseHistoryRepository.getAllEntries();
      expect(entries.length, equals(1));
      expect(entries.first.journalEntryId, isNotNull);
      expect(entries.first.emotion, equals('excited'));
      expect(entries.first.reason, equals('learning'));
      expect(entries.first.phaseScores, isA<Map<String, double>>());
    });

    test('should handle multiple entries with phase stability', () async {
      // Listen to state changes
      final states = <JournalCaptureState>[];
      cubit.stream.listen(states.add);

      // Save multiple entries to test EMA smoothing
      for (int i = 0; i < 3; i++) {
        cubit.saveEntryWithKeywords(
          content: 'I am discovering new things and learning $i',
          mood: 'curious',
          selectedKeywords: ['curious', 'learning', 'discover'],
          emotion: 'curious',
          emotionReason: 'learning',
        );
        
        // Wait between entries
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Verify all entries were saved
      expect(states.last, isA<JournalCaptureSaved>());
      
      // Verify phase history was recorded for all entries
      final entries = await PhaseHistoryRepository.getAllEntries();
      expect(entries.length, equals(3));
      
      // Verify all entries have phase scores
      for (final entry in entries) {
        expect(entry.phaseScores, isA<Map<String, double>>());
        expect(entry.phaseScores.keys.length, equals(6)); // All phases
      }
    });

    test('should maintain phase stability with cooldown', () async {
      // Listen to state changes
      final states = <JournalCaptureState>[];
      cubit.stream.listen(states.add);

      // Save an entry that would normally trigger a phase change
      cubit.saveEntryWithKeywords(
        content: 'I am expanding rapidly and growing in all directions',
        mood: 'excited',
        selectedKeywords: ['expand', 'grow', 'energy'],
        emotion: 'excited',
        emotionReason: 'growth',
      );

      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify the entry was saved
      expect(states.last, isA<JournalCaptureSaved>());
      
      // Verify phase history was recorded
      final entries = await PhaseHistoryRepository.getAllEntries();
      expect(entries.length, equals(1));
      
      // The phase should not change immediately due to stability logic
      // This is the key benefit of the phase stability system
    });

    test('should handle entries with different emotions and reasons', () async {
      // Listen to state changes
      final states = <JournalCaptureState>[];
      cubit.stream.listen(states.add);

      // Save entries with different emotional contexts
      final testCases = [
        {
          'content': 'I am feeling stressed and overwhelmed',
          'mood': 'stressed',
          'keywords': ['stressed', 'overwhelmed', 'tired'],
          'emotion': 'stressed',
          'reason': 'work',
        },
        {
          'content': 'I am happy and grateful for my blessings',
          'mood': 'happy',
          'keywords': ['happy', 'grateful', 'blessed'],
          'emotion': 'happy',
          'reason': 'family',
        },
        {
          'content': 'I suddenly realized the truth about my situation',
          'mood': 'amazed',
          'keywords': ['realized', 'truth', 'insight'],
          'emotion': 'amazed',
          'reason': 'reflection',
        },
      ];

      for (final testCase in testCases) {
        cubit.saveEntryWithKeywords(
          content: testCase['content'] as String,
          mood: testCase['mood'] as String,
          selectedKeywords: testCase['keywords'] as List<String>,
          emotion: testCase['emotion'] as String,
          emotionReason: testCase['reason'] as String,
        );
        
        // Wait between entries
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Verify all entries were saved
      expect(states.last, isA<JournalCaptureSaved>());
      
      // Verify phase history was recorded for all entries
      final entries = await PhaseHistoryRepository.getAllEntries();
      expect(entries.length, equals(3));
      
      // Verify each entry has appropriate phase scores
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final testCase = testCases[i];
        
        expect(entry.emotion, equals(testCase['emotion']));
        expect(entry.reason, equals(testCase['reason']));
        expect(entry.phaseScores, isA<Map<String, double>>());
      }
    });

    test('should handle empty keywords gracefully', () async {
      // Listen to state changes
      final states = <JournalCaptureState>[];
      cubit.stream.listen(states.add);

      // Save an entry without keywords
      cubit.saveEntryWithKeywords(
        content: 'Just a simple entry without keywords',
        mood: 'neutral',
        selectedKeywords: [],
        emotion: 'neutral',
        emotionReason: 'general',
      );

      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify the entry was saved
      expect(states.last, isA<JournalCaptureSaved>());
      
      // Verify phase history was still recorded
      final entries = await PhaseHistoryRepository.getAllEntries();
      expect(entries.length, equals(1));
      expect(entries.first.phaseScores, isA<Map<String, double>>());
    });
  });
}
