import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// import 'package:hive_test/hive_test.dart';
import 'package:my_app/lumara/chat/chat_models.dart';
import 'package:my_app/lumara/chat/chat_repo_impl.dart';

void main() {
  group('ChatRepo Tests', () {
    late ChatRepoImpl chatRepo;

    setUp(() async {
      // Initialize Hive with in-memory storage for testing
      Hive.init('test_hive');

      // Register adapters
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ChatSessionAdapter());
      }
      if (!Hive.isAdapterRegistered(21)) {
        Hive.registerAdapter(ChatMessageAdapter());
      }

      chatRepo = ChatRepoImpl();
      await chatRepo.initialize();
    });

    tearDown(() async {
      await chatRepo.close();
      await Hive.deleteFromDisk();
    });

    group('Session Management', () {
      test('should create session with generated subject', () async {
        final sessionId = await chatRepo.createSession(subject: 'Test Session');

        expect(sessionId, isNotEmpty);

        final session = await chatRepo.getSession(sessionId);
        expect(session, isNotNull);
        expect(session!.subject, 'Test Session');
        expect(session.isPinned, false);
        expect(session.isArchived, false);
        expect(session.messageCount, 0);
      });

      test('should add message and update session count', () async {
        final sessionId = await chatRepo.createSession(subject: 'Test Session');

        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'Hello LUMARA',
        );

        final session = await chatRepo.getSession(sessionId);
        expect(session!.messageCount, 1);

        final messages = await chatRepo.getMessages(sessionId);
        expect(messages.length, 1);
        expect(messages.first.role, MessageRole.user);
        expect(messages.first.content, 'Hello LUMARA');
      });

      test('should rename session', () async {
        final sessionId = await chatRepo.createSession(subject: 'Original');

        await chatRepo.renameSession(sessionId, 'New Name');

        final session = await chatRepo.getSession(sessionId);
        expect(session!.subject, 'New Name');
      });

      test('should pin and unpin session', () async {
        final sessionId = await chatRepo.createSession(subject: 'Test');

        await chatRepo.pinSession(sessionId, true);
        var session = await chatRepo.getSession(sessionId);
        expect(session!.isPinned, true);

        await chatRepo.pinSession(sessionId, false);
        session = await chatRepo.getSession(sessionId);
        expect(session!.isPinned, false);
      });

      test('should archive and restore session', () async {
        final sessionId = await chatRepo.createSession(subject: 'Test');

        await chatRepo.archiveSession(sessionId, true);
        var session = await chatRepo.getSession(sessionId);
        expect(session!.isArchived, true);
        expect(session.archivedAt, isNotNull);

        await chatRepo.archiveSession(sessionId, false);
        session = await chatRepo.getSession(sessionId);
        expect(session!.isArchived, false);
        expect(session.archivedAt, isNull);
      });

      test('should delete session and all messages', () async {
        final sessionId = await chatRepo.createSession(subject: 'Test');
        await chatRepo.addMessage(
          sessionId: sessionId,
          role: MessageRole.user,
          content: 'Test message',
        );

        await chatRepo.deleteSession(sessionId);

        final session = await chatRepo.getSession(sessionId);
        expect(session, isNull);

        final messages = await chatRepo.getMessages(sessionId);
        expect(messages, isEmpty);
      });
    });

    group('Filtering and Search', () {
      setUp(() async {
        // Create test sessions
        await chatRepo.createSession(subject: 'Active Session 1', tags: ['work']);
        await chatRepo.createSession(subject: 'Active Session 2', tags: ['personal']);

        final archivedId = await chatRepo.createSession(subject: 'Archived Session', tags: ['old']);
        await chatRepo.archiveSession(archivedId, true);
      });

      test('should list active sessions only', () async {
        final sessions = await chatRepo.listActive();

        expect(sessions.length, 2);
        expect(sessions.every((s) => !s.isArchived), true);
      });

      test('should list archived sessions only', () async {
        final sessions = await chatRepo.listArchived();

        expect(sessions.length, 1);
        expect(sessions.first.subject, 'Archived Session');
        expect(sessions.first.isArchived, true);
      });

      test('should search sessions by subject', () async {
        final sessions = await chatRepo.listActive(query: 'Session 1');

        expect(sessions.length, 1);
        expect(sessions.first.subject, 'Active Session 1');
      });

      test('should search sessions by tags', () async {
        final sessions = await chatRepo.listActive(query: 'work');

        expect(sessions.length, 1);
        expect(sessions.first.tags, contains('work'));
      });
    });

    group('Auto-Archive Policy', () {
      test('should archive old unpinned sessions', () async {
        // Create old session (simulate by updating timestamp)
        final sessionId = await chatRepo.createSession(subject: 'Old Session');
        final session = await chatRepo.getSession(sessionId);

        // Manually set old timestamp for testing
        final oldSession = session!.copyWith(
          updatedAt: DateTime.now().subtract(const Duration(days: 35)),
        );

        // Manually update in storage (testing hack)
        final box = Hive.box<ChatSession>('chat_sessions');
        await box.put(sessionId, oldSession);

        // Run pruning
        await chatRepo.pruneByPolicy();

        final prunedSession = await chatRepo.getSession(sessionId);
        expect(prunedSession!.isArchived, true);
        expect(prunedSession.archivedAt, isNotNull);
      });

      test('should not archive pinned sessions', () async {
        // Create old pinned session
        final sessionId = await chatRepo.createSession(subject: 'Old Pinned');
        await chatRepo.pinSession(sessionId, true);

        final session = await chatRepo.getSession(sessionId);
        final oldSession = session!.copyWith(
          updatedAt: DateTime.now().subtract(const Duration(days: 35)),
        );

        // Manually update timestamp
        final box = Hive.box<ChatSession>('chat_sessions');
        await box.put(sessionId, oldSession);

        // Run pruning
        await chatRepo.pruneByPolicy();

        final prunedSession = await chatRepo.getSession(sessionId);
        expect(prunedSession!.isArchived, false);
        expect(prunedSession.isPinned, true);
      });
    });

    group('Statistics', () {
      test('should return accurate stats', () async {
        // Create test data
        await chatRepo.createSession(subject: 'Active 1');
        await chatRepo.createSession(subject: 'Active 2');

        final pinnedId = await chatRepo.createSession(subject: 'Pinned');
        await chatRepo.pinSession(pinnedId, true);

        final archivedId = await chatRepo.createSession(subject: 'Archived');
        await chatRepo.archiveSession(archivedId, true);

        // Add some messages
        await chatRepo.addMessage(sessionId: pinnedId, role: MessageRole.user, content: 'Test 1');
        await chatRepo.addMessage(sessionId: pinnedId, role: MessageRole.assistant, content: 'Test 2');

        final stats = await chatRepo.getStats();

        expect(stats['total_sessions'], 4);
        expect(stats['active_sessions'], 3);
        expect(stats['archived_sessions'], 1);
        expect(stats['pinned_sessions'], 1);
        expect(stats['total_messages'], 2);
      });
    });

    group('Message Validation', () {
      test('should reject invalid message roles', () async {
        final sessionId = await chatRepo.createSession(subject: 'Test');

        expect(
          () => chatRepo.addMessage(
            sessionId: sessionId,
            role: 'invalid_role',
            content: 'Test',
          ),
          throwsArgumentError,
        );
      });

      test('should reject messages for non-existent session', () async {
        expect(
          () => chatRepo.addMessage(
            sessionId: 'non_existent',
            role: MessageRole.user,
            content: 'Test',
          ),
          throwsArgumentError,
        );
      });
    });

    group('Subject Generation', () {
      test('should generate subject from message content', () {
        const message = 'Hello LUMARA, I need help with understanding my emotional patterns today';
        final subject = ChatSession.generateSubject(message);

        expect(subject, 'Hello LUMARA need help with understanding emotional patterns');
        expect(subject.length, lessThanOrEqualTo(50));
      });

      test('should handle empty message', () {
        final subject = ChatSession.generateSubject('');
        expect(subject, 'New chat');
      });

      test('should truncate long subjects', () {
        const longMessage = 'This is a very long message that contains many words and should be truncated to a reasonable length for display purposes';
        final subject = ChatSession.generateSubject(longMessage);

        expect(subject.length, lessThanOrEqualTo(50));
        expect(subject, endsWith('...'));
      });
    });
  });
}