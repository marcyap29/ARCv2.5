// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';

import 'package:my_app/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize Hive for testing
    await Hive.initFlutter();
    Hive
      ..registerAdapter(UserProfileAdapter())
      ..registerAdapter(JournalEntryAdapter())
      ..registerAdapter(ArcformSnapshotAdapter())
      ..registerAdapter(SAGEAnnotationAdapter());

    // Build our app and trigger a frame.
    await tester.pumpWidget(const App());

    // Wait for the startup timer to complete
    await tester.pump(const Duration(seconds: 2));

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
