import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/content_parts.dart';
import 'package:my_app/arc/chat/chat/multimodal_chat_service.dart';
import 'package:my_app/polymeta/store/mcp/export/chat_mcp_exporter.dart';
import 'package:my_app/echo/config/echo_config.dart';

void main() {
  group('Multimodal Chat Service Tests', () {
    late MultimodalChatService chatService;

    setUp(() async {
      chatService = MultimodalChatService.instance;
      await chatService.initialize();
    });

    tearDown(() async {
      await chatService.dispose();
    });

    test('should initialize successfully', () {
      expect(chatService.getStatus()['isInitialized'], isTrue);
    });

    test('should create chat session', () async {
      final session = await chatService.createSession(
        subject: 'Test Session',
        tags: ['test', 'demo'],
      );

      expect(session.subject, equals('Test Session'));
      expect(session.tags, equals(['test', 'demo']));
      expect(session.id, startsWith('session:'));
      expect(session.isArchived, isFalse);
      expect(session.isPinned, isFalse);
    });

    test('should send text message', () async {
      final session = await chatService.createSession(subject: 'Test Session');
      
      final contentParts = ContentPartUtils.fromLegacyContent('Hello, LUMARA!');
      final message = await chatService.sendMessage(
        sessionId: session.id,
        contentParts: contentParts,
      );

      expect(message.role, equals(MessageRole.user));
      expect(message.textContent, equals('Hello, LUMARA!'));
      expect(message.sessionId, equals(session.id));
    });

    test('should send multimodal message', () async {
      final session = await chatService.createSession(subject: 'Test Session');
      
      final contentParts = [
        TextContentPart(text: 'Check out this image:'),
        MediaContentPart(
          mime: 'image/jpeg',
          pointer: MediaPointer(
            uri: 'photos://test-image-123',
            role: 'primary',
            metadata: {'width': 1920, 'height': 1080},
          ),
          alt: 'Test image',
        ),
      ];

      final message = await chatService.sendMessage(
        sessionId: session.id,
        contentParts: contentParts,
      );

      expect(message.role, equals(MessageRole.user));
      expect(message.hasMedia, isTrue);
      expect(message.mediaPointers.length, equals(1));
      expect(message.mediaPointers.first.uri, equals('photos://test-image-123'));
    });

    test('should generate response', () async {
      final session = await chatService.createSession(subject: 'Test Session');
      
      final contentParts = ContentPartUtils.fromLegacyContent('How are you today?');
      await chatService.sendMessage(
        sessionId: session.id,
        contentParts: contentParts,
      );

      final messages = chatService.getMessages(session.id);
      expect(messages.length, equals(2)); // User message + AI response
      expect(messages[1].role, equals(MessageRole.assistant));
      expect(messages[1].textContent, isNotEmpty);
    });

    test('should handle PRISM analysis', () async {
      final session = await chatService.createSession(subject: 'Test Session');
      
      final prismSummary = PrismSummary(
        captions: ['A beautiful sunset'],
        objects: ['sun', 'clouds', 'horizon'],
        emotion: EmotionData(
          valence: 0.8,
          arousal: 0.6,
          dominantEmotion: 'peaceful',
        ),
        symbols: ['☀️', '🌅'],
      );

      final contentParts = [
        TextContentPart(text: 'I saw this amazing sunset:'),
        PrismContentPart(summary: prismSummary),
      ];

      final message = await chatService.sendMessage(
        sessionId: session.id,
        contentParts: contentParts,
      );

      expect(message.hasPrismAnalysis, isTrue);
      expect(message.prismSummaries.length, equals(1));
      expect(message.prismSummaries.first.emotion?.valence, equals(0.8));
    });

    test('should switch providers', () async {
      // Test switching to rule-based (should always work)
      await chatService.switchProvider(ProviderType.ruleBased);
      expect(chatService.getStatus()['currentProvider'], equals('rule_based'));

      // Test switching to Ollama (may not be available in test)
      await chatService.switchProvider(ProviderType.ollama);
      // Should fallback to rule-based if Ollama not available
    });

    test('should export to MCP', () async {
      // Create test data
      final session = await chatService.createSession(subject: 'Test Session');
      await chatService.sendMessage(
        sessionId: session.id,
        contentParts: ContentPartUtils.fromLegacyContent('Test message'),
      );

      // Export to MCP
      final result = await chatService.exportToMcp(
        scope: ChatMcpExportScope.all,
      );

      expect(result.success, isTrue);
      expect(result.sessionCount, greaterThan(0));
      expect(result.messageCount, greaterThan(0));
    });

    test('should archive session', () async {
      final session = await chatService.createSession(subject: 'Test Session');
      
      await chatService.archiveSession(session.id);
      
      final sessions = chatService.getSessions(includeArchived: true);
      final archivedSession = sessions.firstWhere((s) => s.id == session.id);
      
      expect(archivedSession.isArchived, isTrue);
      expect(archivedSession.archivedAt, isNotNull);
    });

    test('should pin session', () async {
      final session = await chatService.createSession(subject: 'Test Session');
      
      await chatService.pinSession(session.id);
      
      final sessions = chatService.getSessions();
      final pinnedSession = sessions.firstWhere((s) => s.id == session.id);
      
      expect(pinnedSession.isPinned, isTrue);
    });

    test('should get service status', () {
      final status = chatService.getStatus();
      
      expect(status['isInitialized'], isTrue);
      expect(status['currentProvider'], isA<String>());
      expect(status['availableProviders'], isA<List>());
      expect(status['sessionCount'], isA<int>());
      expect(status['messageCount'], isA<int>());
    });
  });

  group('Content Parts Tests', () {
    test('should create text content part', () {
      final part = TextContentPart(text: 'Hello, world!');
      
      expect(part.mime, equals('text/plain'));
      expect(part.text, equals('Hello, world!'));
    });

    test('should create media content part', () {
      final pointer = MediaPointer(
        uri: 'photos://test-image',
        role: 'primary',
        metadata: {'width': 1920},
      );
      
      final part = MediaContentPart(
        mime: 'image/jpeg',
        pointer: pointer,
        alt: 'Test image',
        durationMs: null,
      );
      
      expect(part.mime, equals('image/jpeg'));
      expect(part.pointer.uri, equals('photos://test-image'));
      expect(part.alt, equals('Test image'));
    });

    test('should create PRISM content part', () {
      final emotion = EmotionData(
        valence: 0.7,
        arousal: 0.5,
        dominantEmotion: 'happy',
      );
      
      final summary = PrismSummary(
        captions: ['A happy moment'],
        emotion: emotion,
        objects: ['smile', 'sunshine'],
      );
      
      final part = PrismContentPart(summary: summary);
      
      expect(part.mime, equals('application/x-prism+json'));
      expect(part.summary.emotion?.valence, equals(0.7));
    });

    test('should serialize and deserialize content parts', () {
      final parts = [
        TextContentPart(text: 'Hello'),
        MediaContentPart(
          mime: 'image/jpeg',
          pointer: MediaPointer(uri: 'photos://test'),
        ),
        PrismContentPart(
          summary: PrismSummary(
            captions: ['Test caption'],
            emotion: EmotionData(valence: 0.5, arousal: 0.5),
          ),
        ),
      ];

      // Test JSON serialization
      for (final part in parts) {
        final json = part.toJson();
        final restored = ContentPart.fromJson(json);
        expect(restored, isA<ContentPart>());
      }
    });

    test('should extract text from content parts', () {
      final parts = [
        TextContentPart(text: 'Hello'),
        TextContentPart(text: 'world!'),
      ];
      
      final text = ContentPartUtils.extractText(parts);
      expect(text, equals('Hello world!'));
    });

    test('should detect media in content parts', () {
      final textParts = [TextContentPart(text: 'Hello')];
      final mediaParts = [
        TextContentPart(text: 'Hello'),
        MediaContentPart(
          mime: 'image/jpeg',
          pointer: MediaPointer(uri: 'photos://test'),
        ),
      ];
      
      expect(ContentPartUtils.hasMedia(textParts), isFalse);
      expect(ContentPartUtils.hasMedia(mediaParts), isTrue);
    });
  });

  group('Chat Models Tests', () {
    test('should create chat session with ULID', () {
      final session = ChatSession.create(subject: 'Test Session');
      
      expect(session.id, isNotEmpty);
      expect(session.subject, equals('Test Session'));
      expect(session.createdAt, isA<DateTime>());
      expect(session.updatedAt, isA<DateTime>());
    });

    test('should create chat message with msg: prefix', () {
      final message = ChatMessage.createText(
        sessionId: 'session:123',
        role: MessageRole.user,
        content: 'Hello, world!',
      );
      
      expect(message.id, startsWith('msg:'));
      expect(message.sessionId, equals('session:123'));
      expect(message.role, equals(MessageRole.user));
      expect(message.textContent, equals('Hello, world!'));
    });

    test('should validate message roles', () {
      expect(ChatMessage.isValidRole('user'), isTrue);
      expect(ChatMessage.isValidRole('assistant'), isTrue);
      expect(ChatMessage.isValidRole('system'), isTrue);
      expect(ChatMessage.isValidRole('invalid'), isFalse);
    });

    test('should generate subject from first message', () {
      final subject = ChatSession.generateSubject('This is a very long message that should be truncated');
      expect(subject, isNotEmpty);
      expect(subject.length, lessThanOrEqualTo(50));
    });
  });
}
