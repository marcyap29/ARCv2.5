import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/media/pointer/pointer_models.dart';

void main() {
  group('Pointer Models JSON Serialization', () {
    test('ImagePointer should serialize/deserialize correctly', () {
      final now = DateTime.now();
      final pointer = ImagePointer(
        id: 'ptr_test123',
        type: 'pointer.image.v1',
        sourceUri: 'applephotos://asset/123',
        descriptor: const ImageDescriptor(
          width: 1920,
          height: 1080,
          mime: 'image/jpeg',
          faces: FaceAnalysis(count: 2),
          ocr: OCRResult(text: 'Test text'),
          labels: ['person', 'outdoor'],
        ),
        samplingManifest: const SamplingManifest(
          policy: 'minimal',
          thumbnails: [
            Thumbnail(size: 256, uri: 'cas://img/256/sha256:abc123'),
          ],
        ),
        integrity: IntegrityData(
          sha256: 'test-hash',
          bytes: 1024,
          createdAt: now,
        ),
        privacy: const PrivacyData(
          containsFaces: true,
          locationPrecision: 'city',
        ),
        provenance: const ProvenanceData(
          device: 'iPhone15,3',
          app: 'photos',
        ),
      );

      // Test serialization
      final json = pointer.toJson();
      expect(json['id'], equals('ptr_test123'));
      expect(json['type'], equals('pointer.image.v1'));
      expect(json['source_uri'], equals('applephotos://asset/123'));
      expect(json['descriptor']['width'], equals(1920));
      expect(json['descriptor']['faces']['count'], equals(2));

      // Test deserialization
      final deserialized = ImagePointer.fromJson(json);
      expect(deserialized.id, equals(pointer.id));
      expect(deserialized.type, equals(pointer.type));
      expect(deserialized.sourceUri, equals(pointer.sourceUri));
      expect(deserialized.descriptor.width, equals(pointer.descriptor.width));
      expect(deserialized.descriptor.faces?.count, equals(2));
    });

    test('AudioPointer should serialize/deserialize correctly', () {
      final now = DateTime.now();
      final pointer = AudioPointer(
        id: 'ptr_audio123',
        type: 'pointer.audio.v1',
        sourceUri: 'voicememos://asset/456',
        descriptor: const AudioDescriptor(
          durationSec: 120.5,
          sampleRate: 16000,
          channels: 1,
          mime: 'audio/m4a',
        ),
        samplingManifest: const AudioSamplingManifest(
          vad: VADWindow(windowSec: 30),
          transcript: [
            TranscriptSegment(ts: [0.0, 30.0], text: 'First segment'),
            TranscriptSegment(ts: [30.0, 60.0], text: 'Second segment'),
          ],
        ),
        integrity: IntegrityData(
          sha256: 'audio-hash',
          bytes: 2048,
          createdAt: now,
        ),
        privacy: const PrivacyData(piiHint: true),
        provenance: const ProvenanceData(
          device: 'iPhone',
          app: 'voicememos',
        ),
      );

      // Test serialization
      final json = pointer.toJson();
      expect(json['descriptor']['duration_sec'], equals(120.5));
      expect(json['sampling_manifest']['transcript'], hasLength(2));
      expect(json['privacy']['pii_hint'], isTrue);

      // Test deserialization
      final deserialized = AudioPointer.fromJson(json);
      expect(deserialized.descriptor.durationSec, equals(120.5));
      expect(deserialized.samplingManifest.transcript, hasLength(2));
      expect(deserialized.privacy.piiHint, isTrue);
    });

    test('VideoPointer should serialize/deserialize correctly', () {
      final now = DateTime.now();
      final pointer = VideoPointer(
        id: 'ptr_video123',
        type: 'pointer.video.v1',
        sourceUri: 'applephotos://asset/789',
        descriptor: const VideoDescriptor(
          durationSec: 62.4,
          width: 1920,
          height: 1080,
          fps: 30,
          audio: AudioChannels(channels: 2),
        ),
        samplingManifest: const VideoSamplingManifest(
          keyframes: [
            Keyframe(t: 0.0, thumbUri: 'cas://kf/000/sha256:frame000'),
            Keyframe(t: 10.0, thumbUri: 'cas://kf/010/sha256:frame010'),
          ],
          captions: [
            TranscriptSegment(ts: [0.0, 10.0], text: 'Video caption 1'),
            TranscriptSegment(ts: [10.0, 20.0], text: 'Video caption 2'),
          ],
        ),
        integrity: IntegrityData(
          sha256: 'video-hash',
          bytes: 4096,
          createdAt: now,
        ),
        privacy: const PrivacyData(containsFaces: true),
        provenance: const ProvenanceData(
          device: 'iPhone',
          app: 'photos',
        ),
      );

      // Test serialization
      final json = pointer.toJson();
      expect(json['descriptor']['duration_sec'], equals(62.4));
      expect(json['descriptor']['audio']['channels'], equals(2));
      expect(json['sampling_manifest']['keyframes'], hasLength(2));

      // Test deserialization
      final deserialized = VideoPointer.fromJson(json);
      expect(deserialized.descriptor.durationSec, equals(62.4));
      expect(deserialized.descriptor.audio?.channels, equals(2));
      expect(deserialized.samplingManifest.keyframes, hasLength(2));
    });

    test('Embedding should serialize/deserialize correctly', () {
      const embedding = Embedding(
        id: 'emb_test123',
        type: 'embedding.v1',
        vector: [0.1, -0.2, 0.3, -0.4],
        model: EmbeddingModel(
          name: 'qwen3-embed-0.6b',
          dim: 768,
          version: 'v1',
        ),
        subject: EmbeddingSubject(
          type: 'pointer.audio.segment',
          ref: 'ptr_audio123',
          span: [29.0, 59.5],
        ),
      );

      // Test serialization
      final json = embedding.toJson();
      expect(json['id'], equals('emb_test123'));
      expect(json['vector'], equals([0.1, -0.2, 0.3, -0.4]));
      expect(json['model']['name'], equals('qwen3-embed-0.6b'));
      expect(json['subject']['span'], equals([29.0, 59.5]));

      // Test deserialization
      final deserialized = Embedding.fromJson(json);
      expect(deserialized.id, equals(embedding.id));
      expect(deserialized.vector, equals(embedding.vector));
      expect(deserialized.model.name, equals(embedding.model.name));
      expect(deserialized.subject.span, equals(embedding.subject.span));
    });

    test('Node should serialize/deserialize correctly', () {
      final now = DateTime.now();
      final node = Node(
        id: 'node_test123',
        type: 'node.v1',
        role: 'media_link',
        links: const NodeLinks(
          entryId: 'entry_456',
          pointerId: 'ptr_789',
        ),
        meta: NodeMeta(
          tags: ['journal', 'video'],
          createdAt: now,
        ),
      );

      // Test serialization
      final json = node.toJson();
      expect(json['id'], equals('node_test123'));
      expect(json['role'], equals('media_link'));
      expect(json['links']['entry_id'], equals('entry_456'));
      expect(json['links']['pointer_id'], equals('ptr_789'));
      expect(json['meta']['tags'], equals(['journal', 'video']));

      // Test deserialization
      final deserialized = Node.fromJson(json);
      expect(deserialized.id, equals(node.id));
      expect(deserialized.role, equals(node.role));
      expect(deserialized.links.entryId, equals(node.links.entryId));
      expect(deserialized.links.pointerId, equals(node.links.pointerId));
      expect(deserialized.meta.tags, equals(node.meta.tags));
    });
  });

  group('Edge Cases', () {
    test('should handle null optional fields', () {
      const descriptor = ImageDescriptor(
        width: 100,
        height: 100,
        mime: 'image/jpeg',
        // All optional fields are null
      );

      final json = descriptor.toJson();
      final deserialized = ImageDescriptor.fromJson(json);

      expect(deserialized.width, equals(100));
      expect(deserialized.height, equals(100));
      expect(deserialized.mime, equals('image/jpeg'));
      expect(deserialized.faces, isNull);
      expect(deserialized.ocr, isNull);
      expect(deserialized.labels, isNull);
    });

    test('should handle empty lists', () {
      const embedding = Embedding(
        id: 'emb_empty',
        type: 'embedding.v1',
        vector: [], // Empty vector
        model: EmbeddingModel(name: 'test', dim: 0, version: 'v1'),
        subject: EmbeddingSubject(type: 'test', ref: 'test'),
      );

      final json = embedding.toJson();
      final deserialized = Embedding.fromJson(json);

      expect(deserialized.vector, isEmpty);
    });
  });
}