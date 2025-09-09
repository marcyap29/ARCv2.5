// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pointer_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GPSLocation _$GPSLocationFromJson(Map<String, dynamic> json) => GPSLocation(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );

Map<String, dynamic> _$GPSLocationToJson(GPSLocation instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lon': instance.lon,
    };

ExifData _$ExifDataFromJson(Map<String, dynamic> json) => ExifData(
      takenAt: json['taken_at'] == null
          ? null
          : DateTime.parse(json['taken_at'] as String),
      gps: json['gps'] == null
          ? null
          : GPSLocation.fromJson(json['gps'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ExifDataToJson(ExifData instance) => <String, dynamic>{
      'taken_at': instance.takenAt?.toIso8601String(),
      'gps': instance.gps,
    };

FaceAnalysis _$FaceAnalysisFromJson(Map<String, dynamic> json) => FaceAnalysis(
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$FaceAnalysisToJson(FaceAnalysis instance) =>
    <String, dynamic>{
      'count': instance.count,
    };

OCRResult _$OCRResultFromJson(Map<String, dynamic> json) => OCRResult(
      text: json['text'] as String,
    );

Map<String, dynamic> _$OCRResultToJson(OCRResult instance) => <String, dynamic>{
      'text': instance.text,
    };

ImageDescriptor _$ImageDescriptorFromJson(Map<String, dynamic> json) =>
    ImageDescriptor(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      mime: json['mime'] as String,
      exif: json['exif'] == null
          ? null
          : ExifData.fromJson(json['exif'] as Map<String, dynamic>),
      faces: json['faces'] == null
          ? null
          : FaceAnalysis.fromJson(json['faces'] as Map<String, dynamic>),
      ocr: json['ocr'] == null
          ? null
          : OCRResult.fromJson(json['ocr'] as Map<String, dynamic>),
      labels:
          (json['labels'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$ImageDescriptorToJson(ImageDescriptor instance) =>
    <String, dynamic>{
      'width': instance.width,
      'height': instance.height,
      'mime': instance.mime,
      'exif': instance.exif,
      'faces': instance.faces,
      'ocr': instance.ocr,
      'labels': instance.labels,
    };

AudioDescriptor _$AudioDescriptorFromJson(Map<String, dynamic> json) =>
    AudioDescriptor(
      durationSec: (json['duration_sec'] as num).toDouble(),
      sampleRate: (json['sample_rate'] as num).toInt(),
      channels: (json['channels'] as num).toInt(),
      mime: json['mime'] as String,
    );

Map<String, dynamic> _$AudioDescriptorToJson(AudioDescriptor instance) =>
    <String, dynamic>{
      'duration_sec': instance.durationSec,
      'sample_rate': instance.sampleRate,
      'channels': instance.channels,
      'mime': instance.mime,
    };

AudioChannels _$AudioChannelsFromJson(Map<String, dynamic> json) =>
    AudioChannels(
      channels: (json['channels'] as num).toInt(),
    );

Map<String, dynamic> _$AudioChannelsToJson(AudioChannels instance) =>
    <String, dynamic>{
      'channels': instance.channels,
    };

VideoDescriptor _$VideoDescriptorFromJson(Map<String, dynamic> json) =>
    VideoDescriptor(
      durationSec: (json['duration_sec'] as num).toDouble(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      fps: (json['fps'] as num).toInt(),
      audio: json['audio'] == null
          ? null
          : AudioChannels.fromJson(json['audio'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$VideoDescriptorToJson(VideoDescriptor instance) =>
    <String, dynamic>{
      'duration_sec': instance.durationSec,
      'width': instance.width,
      'height': instance.height,
      'fps': instance.fps,
      'audio': instance.audio,
    };

Thumbnail _$ThumbnailFromJson(Map<String, dynamic> json) => Thumbnail(
      size: (json['size'] as num).toInt(),
      uri: json['uri'] as String,
    );

Map<String, dynamic> _$ThumbnailToJson(Thumbnail instance) => <String, dynamic>{
      'size': instance.size,
      'uri': instance.uri,
    };

SamplingManifest _$SamplingManifestFromJson(Map<String, dynamic> json) =>
    SamplingManifest(
      policy: json['policy'] as String,
      thumbnails: (json['thumbnails'] as List<dynamic>?)
          ?.map((e) => Thumbnail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SamplingManifestToJson(SamplingManifest instance) =>
    <String, dynamic>{
      'policy': instance.policy,
      'thumbnails': instance.thumbnails,
    };

VADWindow _$VADWindowFromJson(Map<String, dynamic> json) => VADWindow(
      windowSec: (json['window_sec'] as num).toInt(),
    );

Map<String, dynamic> _$VADWindowToJson(VADWindow instance) => <String, dynamic>{
      'window_sec': instance.windowSec,
    };

TranscriptSegment _$TranscriptSegmentFromJson(Map<String, dynamic> json) =>
    TranscriptSegment(
      ts: (json['ts'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      text: json['text'] as String,
    );

Map<String, dynamic> _$TranscriptSegmentToJson(TranscriptSegment instance) =>
    <String, dynamic>{
      'ts': instance.ts,
      'text': instance.text,
    };

AudioSamplingManifest _$AudioSamplingManifestFromJson(
        Map<String, dynamic> json) =>
    AudioSamplingManifest(
      vad: VADWindow.fromJson(json['vad'] as Map<String, dynamic>),
      transcript: (json['transcript'] as List<dynamic>)
          .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AudioSamplingManifestToJson(
        AudioSamplingManifest instance) =>
    <String, dynamic>{
      'vad': instance.vad,
      'transcript': instance.transcript,
    };

Keyframe _$KeyframeFromJson(Map<String, dynamic> json) => Keyframe(
      t: (json['t'] as num).toDouble(),
      thumbUri: json['thumb_uri'] as String,
    );

Map<String, dynamic> _$KeyframeToJson(Keyframe instance) => <String, dynamic>{
      't': instance.t,
      'thumb_uri': instance.thumbUri,
    };

VideoSamplingManifest _$VideoSamplingManifestFromJson(
        Map<String, dynamic> json) =>
    VideoSamplingManifest(
      keyframes: (json['keyframes'] as List<dynamic>)
          .map((e) => Keyframe.fromJson(e as Map<String, dynamic>))
          .toList(),
      captions: (json['captions'] as List<dynamic>)
          .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VideoSamplingManifestToJson(
        VideoSamplingManifest instance) =>
    <String, dynamic>{
      'keyframes': instance.keyframes,
      'captions': instance.captions,
    };

IntegrityData _$IntegrityDataFromJson(Map<String, dynamic> json) =>
    IntegrityData(
      sha256: json['sha256'] as String,
      bytes: (json['bytes'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$IntegrityDataToJson(IntegrityData instance) =>
    <String, dynamic>{
      'sha256': instance.sha256,
      'bytes': instance.bytes,
      'created_at': instance.createdAt.toIso8601String(),
    };

PrivacyData _$PrivacyDataFromJson(Map<String, dynamic> json) => PrivacyData(
      containsFaces: json['contains_faces'] as bool?,
      locationPrecision: json['location_precision'] as String?,
      piiHint: json['pii_hint'] as bool?,
    );

Map<String, dynamic> _$PrivacyDataToJson(PrivacyData instance) =>
    <String, dynamic>{
      'contains_faces': instance.containsFaces,
      'location_precision': instance.locationPrecision,
      'pii_hint': instance.piiHint,
    };

ProvenanceData _$ProvenanceDataFromJson(Map<String, dynamic> json) =>
    ProvenanceData(
      device: json['device'] as String,
      app: json['app'] as String,
    );

Map<String, dynamic> _$ProvenanceDataToJson(ProvenanceData instance) =>
    <String, dynamic>{
      'device': instance.device,
      'app': instance.app,
    };

ImagePointer _$ImagePointerFromJson(Map<String, dynamic> json) => ImagePointer(
      id: json['id'] as String,
      type: json['type'] as String,
      sourceUri: json['source_uri'] as String,
      descriptor:
          ImageDescriptor.fromJson(json['descriptor'] as Map<String, dynamic>),
      samplingManifest: SamplingManifest.fromJson(
          json['sampling_manifest'] as Map<String, dynamic>),
      integrity:
          IntegrityData.fromJson(json['integrity'] as Map<String, dynamic>),
      privacy: PrivacyData.fromJson(json['privacy'] as Map<String, dynamic>),
      provenance:
          ProvenanceData.fromJson(json['provenance'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ImagePointerToJson(ImagePointer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'source_uri': instance.sourceUri,
      'descriptor': instance.descriptor,
      'sampling_manifest': instance.samplingManifest,
      'integrity': instance.integrity,
      'privacy': instance.privacy,
      'provenance': instance.provenance,
    };

AudioPointer _$AudioPointerFromJson(Map<String, dynamic> json) => AudioPointer(
      id: json['id'] as String,
      type: json['type'] as String,
      sourceUri: json['source_uri'] as String,
      descriptor:
          AudioDescriptor.fromJson(json['descriptor'] as Map<String, dynamic>),
      samplingManifest: AudioSamplingManifest.fromJson(
          json['sampling_manifest'] as Map<String, dynamic>),
      integrity:
          IntegrityData.fromJson(json['integrity'] as Map<String, dynamic>),
      privacy: PrivacyData.fromJson(json['privacy'] as Map<String, dynamic>),
      provenance:
          ProvenanceData.fromJson(json['provenance'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AudioPointerToJson(AudioPointer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'source_uri': instance.sourceUri,
      'descriptor': instance.descriptor,
      'sampling_manifest': instance.samplingManifest,
      'integrity': instance.integrity,
      'privacy': instance.privacy,
      'provenance': instance.provenance,
    };

VideoPointer _$VideoPointerFromJson(Map<String, dynamic> json) => VideoPointer(
      id: json['id'] as String,
      type: json['type'] as String,
      sourceUri: json['source_uri'] as String,
      descriptor:
          VideoDescriptor.fromJson(json['descriptor'] as Map<String, dynamic>),
      samplingManifest: VideoSamplingManifest.fromJson(
          json['sampling_manifest'] as Map<String, dynamic>),
      integrity:
          IntegrityData.fromJson(json['integrity'] as Map<String, dynamic>),
      privacy: PrivacyData.fromJson(json['privacy'] as Map<String, dynamic>),
      provenance:
          ProvenanceData.fromJson(json['provenance'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$VideoPointerToJson(VideoPointer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'source_uri': instance.sourceUri,
      'descriptor': instance.descriptor,
      'sampling_manifest': instance.samplingManifest,
      'integrity': instance.integrity,
      'privacy': instance.privacy,
      'provenance': instance.provenance,
    };

EmbeddingModel _$EmbeddingModelFromJson(Map<String, dynamic> json) =>
    EmbeddingModel(
      name: json['name'] as String,
      dim: (json['dim'] as num).toInt(),
      version: json['version'] as String,
    );

Map<String, dynamic> _$EmbeddingModelToJson(EmbeddingModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'dim': instance.dim,
      'version': instance.version,
    };

EmbeddingSubject _$EmbeddingSubjectFromJson(Map<String, dynamic> json) =>
    EmbeddingSubject(
      type: json['type'] as String,
      ref: json['ref'] as String,
      span: (json['span'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$EmbeddingSubjectToJson(EmbeddingSubject instance) =>
    <String, dynamic>{
      'type': instance.type,
      'ref': instance.ref,
      'span': instance.span,
    };

Embedding _$EmbeddingFromJson(Map<String, dynamic> json) => Embedding(
      id: json['id'] as String,
      type: json['type'] as String,
      vector: (json['vector'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      model: EmbeddingModel.fromJson(json['model'] as Map<String, dynamic>),
      subject:
          EmbeddingSubject.fromJson(json['subject'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$EmbeddingToJson(Embedding instance) => <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'vector': instance.vector,
      'model': instance.model,
      'subject': instance.subject,
    };

NodeLinks _$NodeLinksFromJson(Map<String, dynamic> json) => NodeLinks(
      entryId: json['entry_id'] as String,
      pointerId: json['pointer_id'] as String,
    );

Map<String, dynamic> _$NodeLinksToJson(NodeLinks instance) => <String, dynamic>{
      'entry_id': instance.entryId,
      'pointer_id': instance.pointerId,
    };

NodeMeta _$NodeMetaFromJson(Map<String, dynamic> json) => NodeMeta(
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$NodeMetaToJson(NodeMeta instance) => <String, dynamic>{
      'tags': instance.tags,
      'created_at': instance.createdAt.toIso8601String(),
    };

Node _$NodeFromJson(Map<String, dynamic> json) => Node(
      id: json['id'] as String,
      type: json['type'] as String,
      role: json['role'] as String,
      links: NodeLinks.fromJson(json['links'] as Map<String, dynamic>),
      meta: NodeMeta.fromJson(json['meta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$NodeToJson(Node instance) => <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'role': instance.role,
      'links': instance.links,
      'meta': instance.meta,
    };
