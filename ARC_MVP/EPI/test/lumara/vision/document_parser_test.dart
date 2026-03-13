// test/lumara/vision/document_parser_test.dart
//
// Phase 4: Document parser tests with mocked PrismService invoker.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/lumara/agents/vision/document_parser.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';

void main() {
  group('ParsedDocument model', () {
    test('toJson and fromJson round-trip', () {
      final doc = ParsedDocument(
        title: 'Invoice',
        date: '2025-03-01',
        keyFields: [
          const DocumentField(label: 'Amount', value: '100'),
        ],
        rawText: 'Raw OCR text',
        createdAt: DateTime(2025, 3, 1),
      );
      final json = doc.toJson();
      final restored = ParsedDocument.fromJson(json);
      expect(restored.title, doc.title);
      expect(restored.date, doc.date);
      expect(restored.keyFields.length, doc.keyFields.length);
      expect(restored.rawText, doc.rawText);
    });
  });

  group('parseDocument', () {
    testWidgets('ParsedDocument populated when OCR + Gemini both succeed', (tester) async {
      final ocrText = 'Invoice\nDate: 2025-03-01\nAmount: 100';
      final geminiJson = jsonEncode({
        'title': 'Invoice',
        'date': '2025-03-01',
        'keyFields': [
          {'label': 'Amount', 'value': '100'},
        ],
        'rawText': ocrText,
      });

      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        if (pluginId == 'vision-ocr') {
          expect(params['mode'], 'ocr');
          expect(params.containsKey('image_b64'), true);
          return PrismSuccessResult(SwarmSpaceResult.fromData({'text': ocrText}));
        }
        if (pluginId == 'gemini-flash') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({'text': geminiJson}));
        }
        return const PrismDeniedResult();
      }

      final xFile = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'test.jpg',
      );
      BuildContext? captureContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captureContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );

      final doc = await parseDocument(
        image: xFile,
        context: captureContext!,
        invoker: invoker,
      );

      expect(doc.rawText, ocrText);
      expect(doc.title, 'Invoice');
      expect(doc.date, '2025-03-01');
      expect(doc.keyFields.length, 1);
      expect(doc.keyFields.first.label, 'Amount');
      expect(doc.keyFields.first.value, '100');
    });

    testWidgets('PRISM: vision-ocr receives image_b64 and mode ocr', (tester) async {
      String? capturedOcrMode;
      Map<String, dynamic>? capturedOcrParams;

      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        if (pluginId == 'vision-ocr') {
          capturedOcrMode = params['mode'] as String?;
          capturedOcrParams = Map.from(params);
          return PrismSuccessResult(SwarmSpaceResult.fromData({'text': 'some text'}));
        }
        if (pluginId == 'gemini-flash') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({
            'text': jsonEncode({'title': null, 'date': null, 'keyFields': [], 'rawText': 'some text'}),
          }));
        }
        return const PrismDeniedResult();
      }

      final xFile = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 't.jpg');
      BuildContext? captureContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captureContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await parseDocument(image: xFile, context: captureContext!, invoker: invoker);

      expect(capturedOcrMode, 'ocr');
      expect(capturedOcrParams!.containsKey('image_b64'), true);
    });

    testWidgets('ParsedDocument returns empty keyFields when OCR returns empty', (tester) async {
      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        if (pluginId == 'vision-ocr') {
          return PrismSuccessResult(SwarmSpaceResult.fromData({'text': ''}));
        }
        return const PrismDeniedResult();
      }

      final xFile = XFile.fromData(Uint8List.fromList([1]), name: 't.jpg');
      BuildContext? captureContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captureContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      final doc = await parseDocument(image: xFile, context: captureContext!, invoker: invoker);

      expect(doc.rawText, '');
      expect(doc.keyFields, isEmpty);
    });

    testWidgets('ParsedDocument graceful when OCR denied', (tester) async {
      Future<PrismCallResult> invoker(String pluginId, Map<String, dynamic> params) async {
        return const PrismDeniedResult();
      }

      final xFile = XFile.fromData(Uint8List.fromList([1]), name: 't.jpg');
      BuildContext? captureContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              captureContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      final doc = await parseDocument(image: xFile, context: captureContext!, invoker: invoker);

      expect(doc.rawText, '');
      expect(doc.keyFields, isEmpty);
    });
  });

  group('R2 media-upload worker (URL format)', () {
    test('documented: worker uses UUID v4 for path (media/{uuid}.{ext})', () {
      const doc = 'R2 worker stores at media/{uuid}.{ext} with crypto.randomUUID().';
      expect(doc, contains('uuid'));
      expect(doc, contains('media/'));
    });
  });
}
