// test/lumara/social/publish_sheet_test.dart
// Phase 7: PublishSheet — publish disabled with no platforms; enabled with one; schedule toggle shows picker.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/agents/writing/pipeline_draft.dart';
import 'package:my_app/lumara/social/late_profile_service.dart';
import 'package:my_app/lumara/social/publish_sheet.dart';

void main() {
  final sampleAccounts = [
    const SocialAccount(id: 'acc_1', platform: 'linkedin', username: 'user1', profileId: 'p1'),
    const SocialAccount(id: 'acc_2', platform: 'bluesky', username: '@u.bsky.social', profileId: 'p1'),
  ];

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('PublishSheet', () {
    testWidgets('Publish button is disabled when no platform selected', (tester) async {
      PublishSheetResult? result;
      await tester.pumpWidget(wrap(
        PublishSheet(
          draftBody: 'Hello world',
          format: WritingFormat.linkedin,
          accounts: sampleAccounts,
          onPublish: (r) => result = r,
        ),
      ));
      await tester.pumpAndSettle();
      final publishBtn = find.widgetWithText(FilledButton, 'Publish');
      expect(publishBtn, findsOneWidget);
      final button = tester.widget<FilledButton>(publishBtn);
      expect(button.onPressed, isNull);
    });

    testWidgets('Publish button is enabled when one platform selected', (tester) async {
      PublishSheetResult? result;
      await tester.pumpWidget(wrap(
        PublishSheet(
          draftBody: 'Hello world',
          format: WritingFormat.linkedin,
          accounts: sampleAccounts,
          onPublish: (r) => result = r,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      final publishBtn = find.widgetWithText(FilledButton, 'Publish');
      expect(publishBtn, findsOneWidget);
      final button = tester.widget<FilledButton>(publishBtn);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Schedule toggle shows date and time buttons when checked', (tester) async {
      await tester.pumpWidget(wrap(
        PublishSheet(
          draftBody: 'Post',
          format: WritingFormat.article,
          accounts: sampleAccounts,
          onPublish: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Schedule for later'), findsOneWidget);
      // Tap the "Schedule for later" checkbox (last Checkbox in the sheet, after account CheckboxListTiles).
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsWidgets);
    });
  });
}
