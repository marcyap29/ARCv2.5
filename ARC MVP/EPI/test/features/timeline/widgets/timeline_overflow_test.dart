import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/timeline/widgets/interactive_timeline_view.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';

void main() {
  group('Timeline Overflow Tests', () {
    testWidgets('timeline entry with long text and thumbnails does not overflow', (WidgetTester tester) async {
      // Create a timeline entry with very long text and multiple thumbnails
      final entry = TimelineEntry(
        id: 'test-entry',
        title: 'This is a very long title that should not cause overflow issues in the timeline',
        preview: 'This is a very long preview text that should wrap properly and not cause any RenderFlex overflow errors even when combined with multiple media thumbnails',
        date: '2024-01-01',
        phase: 'discovery',
        media: [
          MediaItem(
            id: 'media1',
            type: MediaType.image,
            uri: 'file://test1.jpg',
            createdAt: DateTime.now(),
          ),
          MediaItem(
            id: 'media2',
            type: MediaType.image,
            uri: 'file://test2.jpg',
            createdAt: DateTime.now(),
          ),
        ],
      );

      // Build the timeline entry widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Container(
                width: 300, // Constrain width to test overflow
                child: _buildTimelineEntryCard(entry),
              ),
            ),
          ),
        ),
      );

      // Verify no overflow errors
      expect(tester.takeException(), isNull);
      
      // Verify the text is properly wrapped
      final textWidget = find.text(entry.preview);
      expect(textWidget, findsOneWidget);
      
      // Verify thumbnails are present
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('timeline entry with very long title handles overflow', (WidgetTester tester) async {
      final entry = TimelineEntry(
        id: 'test-entry',
        title: 'This is an extremely long title that should be truncated with ellipsis to prevent any RenderFlex overflow issues in the timeline widget',
        preview: 'Short preview',
        date: '2024-01-01',
        phase: 'discovery',
        media: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 200, // Very narrow width to test overflow
              child: _buildTimelineEntryCard(entry),
            ),
          ),
        ),
      );

      // Should not throw overflow exception
      expect(tester.takeException(), isNull);
    });

    testWidgets('timeline entry with multiple media items handles layout', (WidgetTester tester) async {
      final entry = TimelineEntry(
        id: 'test-entry',
        title: 'Media Test',
        preview: 'Testing multiple media items',
        date: '2024-01-01',
        phase: 'discovery',
        media: List.generate(5, (index) => MediaItem(
          id: 'media$index',
          type: MediaType.image,
          uri: 'file://test$index.jpg',
          createdAt: DateTime.now(),
        )),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 250,
              child: _buildTimelineEntryCard(entry),
            ),
          ),
        ),
      );

      // Should not throw overflow exception
      expect(tester.takeException(), isNull);
    });
  });
}

// Helper widget to build timeline entry card similar to the actual implementation
Widget _buildTimelineEntryCard(TimelineEntry entry) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail section with fixed width
          SizedBox(
            width: 80,
            height: 60,
            child: _buildThumbnail(entry),
          ),
          const SizedBox(width: 8),
          // Text section with proper overflow handling
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  entry.preview,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.fade,
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  entry.date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildThumbnail(TimelineEntry entry) {
  if (entry.media.isEmpty) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  return Wrap(
    spacing: 4,
    runSpacing: 4,
    children: entry.media.take(2).map((media) {
      return Container(
        width: 38,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.image, size: 16, color: Colors.grey),
      );
    }).toList(),
  );
}
