// Phase 5a: Document type detection from ParsedDocument fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/outputs/output_tagging.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';

void main() {
  ParsedDocument doc(List<DocumentField> fields) {
    return ParsedDocument(
      keyFields: fields,
      rawText: fields.map((f) => '${f.label}: ${f.value}').join(' '),
      createdAt: DateTime.now(),
    );
  }

  group('detectDocumentType', () {
    test('invoice', () {
      final d = doc([
        const DocumentField(label: 'Total', value: '100'),
        const DocumentField(label: 'Due date', value: '2025-04-01'),
      ]);
      expect(detectDocumentType(d), 'invoice');
    });

    test('receipt', () {
      final d = doc([
        const DocumentField(label: 'Receipt', value: '123'),
        const DocumentField(label: 'Subtotal', value: '50'),
        const DocumentField(label: 'Tax', value: '5'),
      ]);
      expect(detectDocumentType(d), 'receipt');
    });

    test('business_card', () {
      final d = doc([
        const DocumentField(label: 'Name', value: 'Jane'),
        const DocumentField(label: 'Email', value: 'j@x.com'),
        const DocumentField(label: 'Phone', value: '555'),
        const DocumentField(label: 'Company', value: 'Acme'),
      ]);
      expect(detectDocumentType(d), 'business_card');
    });

    test('contract', () {
      final d = doc([
        const DocumentField(label: 'Agreement', value: 'Terms'),
        const DocumentField(label: 'Party', value: 'A'),
        const DocumentField(label: 'Signature', value: 'signed'),
      ]);
      expect(detectDocumentType(d), 'contract');
    });

    test('unknown when no keywords', () {
      final d = doc([
        const DocumentField(label: 'Note', value: 'Something'),
      ]);
      expect(detectDocumentType(d), 'unknown');
    });
  });
}
