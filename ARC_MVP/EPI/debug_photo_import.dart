#!/usr/bin/env dart
// Debug script to test photo import and reconstruction

import 'dart:convert';

void main() async {
  print('🔍 Photo Import Debug Script');
  print('============================');
  
  // Test photo placeholder regex
  const testContent = 'Test\n\n[PHOTO:photo_1760552888277]\n[PHOTO:photo_1760552888947]';
  final photoPlaceholderRegex = RegExp(r'\[PHOTO:([^\]]+)\]');
  final matches = photoPlaceholderRegex.allMatches(testContent);
  
  print('📝 Test content: $testContent');
  print('🔍 Found ${matches.length} photo placeholders:');
  for (final match in matches) {
    final photoId = match.group(1)!;
    print('  - [PHOTO:$photoId]');
  }
  
  // Test media item creation
  final testMediaJson = {
    'id': 'photo_1760552888277',
    'uri': 'ph://12345678-1234-1234-1234-123456789012',
    'type': 'image',
    'created_at': '2024-01-15T10:30:00.000Z',
    'alt_text': 'Test photo',
    'ocr_text': 'Some text in the photo',
    'analysis_data': {'confidence': 0.95}
  };
  
  print('\n📸 Test media JSON:');
  print(jsonEncode(testMediaJson));
  
  // Test photo ID extraction
  print('\n🔍 Photo ID extraction test:');
  print('Media ID: ${testMediaJson['id']}');
  print('Photo placeholder: [PHOTO:${testMediaJson['id']}]');
  print('Match: ${testMediaJson['id'] == 'photo_1760552888277'}');
  
  print('\n✅ Debug script completed');
}
