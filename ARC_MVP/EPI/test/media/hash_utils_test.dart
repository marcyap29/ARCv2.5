import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/prism/processors/crypto/hash_utils.dart';

void main() {
  group('HashUtils', () {
    test('should generate consistent SHA-256 hashes', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash1 = HashUtils.sha256Hash(data);
      final hash2 = HashUtils.sha256Hash(data);
      
      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex string length
    });

    test('should generate different hashes for different data', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([4, 5, 6]);
      
      final hash1 = HashUtils.sha256Hash(data1);
      final hash2 = HashUtils.sha256Hash(data2);
      
      expect(hash1, isNot(equals(hash2)));
    });

    test('should generate unique pointer IDs', () {
      final id1 = HashUtils.generatePointerId();
      final id2 = HashUtils.generatePointerId();
      
      expect(id1, isNot(equals(id2)));
      expect(id1, startsWith('ptr_'));
      expect(id2, startsWith('ptr_'));
    });

    test('should generate unique embedding IDs', () {
      final id1 = HashUtils.generateEmbeddingId();
      final id2 = HashUtils.generateEmbeddingId();
      
      expect(id1, isNot(equals(id2)));
      expect(id1, startsWith('emb_'));
      expect(id2, startsWith('emb_'));
    });

    test('should generate unique node IDs', () {
      final id1 = HashUtils.generateNodeId();
      final id2 = HashUtils.generateNodeId();
      
      expect(id1, isNot(equals(id2)));
      expect(id1, startsWith('node_'));
      expect(id2, startsWith('node_'));
    });
  });

  group('CASStore', () {
    test('should generate valid CAS URIs', () {
      final uri = CASStore.generateCASUri('img', '256', 'abcd1234');
      expect(uri, equals('cas://img/256/sha256:abcd1234'));
    });

    test('should parse valid CAS URIs', () {
      final longHash = 'a' * 64;
      final uri = 'cas://video/720p/sha256:$longHash';
      final components = CASStore.parseCASUri(uri);
      
      expect(components, isNotNull);
      expect(components!.type, equals('video'));
      expect(components.size, equals('720p'));
      expect(components.hash, equals(longHash));
    });

    test('should return null for invalid CAS URIs', () {
      const invalidUri = 'invalid://not/cas/uri';
      final components = CASStore.parseCASUri(invalidUri);
      expect(components, isNull);
    });

    test('should reject malformed CAS URIs', () {
      final longHash = 'a' * 64;
      final malformedUris = [
        'cas://img/256/md5:abcd1234', // Wrong hash type
        'cas://img/256/sha256:short', // Short hash
        'cas://img/sha256:$longHash', // Missing size
        'cas://sha256:$longHash', // Missing type and size
      ];

      for (final uri in malformedUris) {
        final components = CASStore.parseCASUri(uri);
        expect(components, isNull, reason: 'Should reject: $uri');
      }
    });
  });
}