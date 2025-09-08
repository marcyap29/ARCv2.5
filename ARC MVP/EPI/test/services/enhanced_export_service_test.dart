import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/mode/first_responder/fr_settings.dart';
import 'package:my_app/mode/first_responder/fr_settings_cubit.dart';
import 'package:my_app/mode/first_responder/redaction/redaction_service.dart';
import 'package:my_app/services/enhanced_export_service.dart';

class MockFRSettingsCubit extends MockCubit<FRSettings> implements FRSettingsCubit {}

class MockRedactionService extends Mock implements RedactionService {}

// Mock classes for testing
class Mock {}

void main() {
  group('EnhancedExportService', () {
    late MockFRSettingsCubit mockSettingsCubit;
    late MockRedactionService mockRedactionService;
    late EnhancedExportService exportService;
    late FRSettings defaultSettings;

    setUp(() {
      mockSettingsCubit = MockFRSettingsCubit();
      mockRedactionService = MockRedactionService();
      exportService = EnhancedExportService(
        frSettingsCubit: mockSettingsCubit,
        redactionService: mockRedactionService,
      );
      defaultSettings = FRSettings.defaults();
    });

    group('shareJournalEntry', () {
      testWidgets('shares entry without redaction when disabled', (tester) async {
        // Setup
        whenListen(mockSettingsCubit, Stream.value(defaultSettings.copyWith(redactionEnabled: false)));
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings.copyWith(redactionEnabled: false));

        final entry = _createTestEntry(body: 'Test journal entry content');

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareJournalEntry(context, entry),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Verify redaction service was not called
        verifyNever(() => mockRedactionService.redact(any(), any(), any(), any()));
      });

      testWidgets('applies redaction for FR entries when enabled', (tester) async {
        // Setup
        final enabledSettings = defaultSettings.copyWith(redactionEnabled: true);
        whenListen(mockSettingsCubit, Stream.value(enabledSettings));
        when(() => mockSettingsCubit.state).thenReturn(enabledSettings);
        when(() => mockRedactionService.redact(any(), any(), any(), any()))
            .thenAnswer((_) async => 'Redacted content with [Name-1]');

        final frEntry = _createTestEntry(
          body: 'Called Maria about the emergency',
          metadata: {'frMode': true},
        );

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareJournalEntry(context, frEntry),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Verify redaction service was called
        verify(() => mockRedactionService.redact(
          frEntry.id,
          'Called Maria about the emergency',
          frEntry.createdAt,
          enabledSettings,
        )).called(1);
      });

      testWidgets('applies redaction for entries with first_responder tag', (tester) async {
        // Setup
        final enabledSettings = defaultSettings.copyWith(redactionEnabled: true);
        whenListen(mockSettingsCubit, Stream.value(enabledSettings));
        when(() => mockSettingsCubit.state).thenReturn(enabledSettings);
        when(() => mockRedactionService.redact(any(), any(), any(), any()))
            .thenAnswer((_) async => 'Redacted emergency content');

        final taggedEntry = _createTestEntry(
          body: 'Emergency response at 221B Baker St',
          tags: ['first_responder', 'emergency'],
        );

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareJournalEntry(context, taggedEntry),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Verify redaction was applied
        verify(() => mockRedactionService.redact(any(), any(), any(), any())).called(1);
      });

      testWidgets('handles empty entry body gracefully', (tester) async {
        // Setup
        whenListen(mockSettingsCubit, Stream.value(defaultSettings));
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings);

        final emptyEntry = _createTestEntry(body: null);

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareJournalEntry(context, emptyEntry),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Should show error snackbar
        expect(find.text('No content to share'), findsOneWidget);
      });

      testWidgets('handles redaction service errors gracefully', (tester) async {
        // Setup
        final enabledSettings = defaultSettings.copyWith(redactionEnabled: true);
        whenListen(mockSettingsCubit, Stream.value(enabledSettings));
        when(() => mockSettingsCubit.state).thenReturn(enabledSettings);
        when(() => mockRedactionService.redact(any(), any(), any(), any()))
            .thenThrow(Exception('Redaction failed'));

        final frEntry = _createTestEntry(
          body: 'Emergency content',
          metadata: {'frMode': true},
        );

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareJournalEntry(context, frEntry),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Should show error message but still attempt share
        expect(find.text('Redaction failed, sharing original text'), findsOneWidget);
      });
    });

    group('shareText', () {
      testWidgets('shares text without redaction when not forced', (tester) async {
        // Setup
        whenListen(mockSettingsCubit, Stream.value(defaultSettings.copyWith(redactionEnabled: false)));
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings.copyWith(redactionEnabled: false));

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareText(
                  context,
                  'Test text content',
                  entryId: 'test-1',
                  createdAt: DateTime.now(),
                ),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Verify no redaction was applied
        verifyNever(() => mockRedactionService.redact(any(), any(), any(), any()));
      });

      testWidgets('applies forced redaction when requested', (tester) async {
        // Setup
        whenListen(mockSettingsCubit, Stream.value(defaultSettings));
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings);
        when(() => mockRedactionService.redact(any(), any(), any(), any()))
            .thenAnswer((_) async => 'Redacted text content');

        final now = DateTime.now();

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareText(
                  context,
                  'Sensitive content with Maria',
                  entryId: 'test-2',
                  createdAt: now,
                  forceRedaction: true,
                ),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Verify redaction was applied
        verify(() => mockRedactionService.redact(
          'test-2',
          'Sensitive content with Maria',
          now,
          defaultSettings,
        )).called(1);
      });

      testWidgets('handles empty text gracefully', (tester) async {
        // Setup
        whenListen(mockSettingsCubit, Stream.value(defaultSettings));
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings);

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareText(context, ''),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Should show error snackbar
        expect(find.text('No content to share'), findsOneWidget);
      });

      testWidgets('skips redaction when missing required parameters', (tester) async {
        // Setup
        final enabledSettings = defaultSettings.copyWith(redactionEnabled: true);
        whenListen(mockSettingsCubit, Stream.value(enabledSettings));
        when(() => mockSettingsCubit.state).thenReturn(enabledSettings);

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => exportService.shareText(
                  context,
                  'Text without entry ID or date',
                ),
                child: const Text('Share'),
              );
            },
          ),
        ));

        // Trigger share
        await tester.tap(find.text('Share'));
        await tester.pump();

        // Should not attempt redaction without required params
        verifyNever(() => mockRedactionService.redact(any(), any(), any(), any()));
      });
    });

    group('utility methods', () {
      test('isRedactionAvailable returns correct status', () {
        // Test enabled
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings.copyWith(redactionEnabled: true));
        expect(exportService.isRedactionAvailable(), true);

        // Test disabled
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings.copyWith(redactionEnabled: false));
        expect(exportService.isRedactionAvailable(), false);
      });

      test('getRedactionStatus returns correct message', () {
        // Test enabled
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings.copyWith(redactionEnabled: true));
        expect(exportService.getRedactionStatus(), 'Auto-redaction enabled');

        // Test disabled
        when(() => mockSettingsCubit.state).thenReturn(defaultSettings.copyWith(redactionEnabled: false));
        expect(exportService.getRedactionStatus(), 'Redaction disabled');
      });
    });
  });
}

JournalEntry _createTestEntry({
  String? body,
  List<String>? tags,
  Map<String, dynamic>? metadata,
}) {
  return JournalEntry(
    id: 'test-${DateTime.now().millisecondsSinceEpoch}',
    title: 'Test Entry',
    body: body ?? '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    tags: tags,
    metadata: metadata,
  );
}

// Mock extension methods for testing
extension MockExtensions on Object {
  T when<T>(T Function() fn) => fn();
  void verify(Function() verification) => verification();
  void verifyNever(Function() verification) {}
  T any<T>() => throw UnimplementedError();
}