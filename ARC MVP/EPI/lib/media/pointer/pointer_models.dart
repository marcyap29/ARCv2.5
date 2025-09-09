import 'package:json_annotation/json_annotation.dart';

part 'pointer_models.g.dart';

@JsonSerializable()
class GPSLocation {
  final double lat;
  final double lon;

  const GPSLocation({
    required this.lat,
    required this.lon,
  });

  factory GPSLocation.fromJson(Map<String, dynamic> json) => _$GPSLocationFromJson(json);
  Map<String, dynamic> toJson() => _$GPSLocationToJson(this);
}

@JsonSerializable()
class ExifData {
  @JsonKey(name: 'taken_at')
  final DateTime? takenAt;
  final GPSLocation? gps;

  const ExifData({
    this.takenAt,
    this.gps,
  });

  factory ExifData.fromJson(Map<String, dynamic> json) => _$ExifDataFromJson(json);
  Map<String, dynamic> toJson() => _$ExifDataToJson(this);
}

@JsonSerializable()
class FaceAnalysis {
  final int count;

  const FaceAnalysis({required this.count});

  factory FaceAnalysis.fromJson(Map<String, dynamic> json) => _$FaceAnalysisFromJson(json);
  Map<String, dynamic> toJson() => _$FaceAnalysisToJson(this);
}

@JsonSerializable()
class OCRResult {
  final String text;

  const OCRResult({required this.text});

  factory OCRResult.fromJson(Map<String, dynamic> json) => _$OCRResultFromJson(json);
  Map<String, dynamic> toJson() => _$OCRResultToJson(this);
}

@JsonSerializable()
class ImageDescriptor {
  final int width;
  final int height;
  final String mime;
  final ExifData? exif;
  final FaceAnalysis? faces;
  final OCRResult? ocr;
  final List<String>? labels;

  const ImageDescriptor({
    required this.width,
    required this.height,
    required this.mime,
    this.exif,
    this.faces,
    this.ocr,
    this.labels,
  });

  factory ImageDescriptor.fromJson(Map<String, dynamic> json) => _$ImageDescriptorFromJson(json);
  Map<String, dynamic> toJson() => _$ImageDescriptorToJson(this);
}

@JsonSerializable()
class AudioDescriptor {
  @JsonKey(name: 'duration_sec')
  final double durationSec;
  @JsonKey(name: 'sample_rate')
  final int sampleRate;
  final int channels;
  final String mime;

  const AudioDescriptor({
    required this.durationSec,
    required this.sampleRate,
    required this.channels,
    required this.mime,
  });

  factory AudioDescriptor.fromJson(Map<String, dynamic> json) => _$AudioDescriptorFromJson(json);
  Map<String, dynamic> toJson() => _$AudioDescriptorToJson(this);
}

@JsonSerializable()
class AudioChannels {
  final int channels;

  const AudioChannels({required this.channels});

  factory AudioChannels.fromJson(Map<String, dynamic> json) => _$AudioChannelsFromJson(json);
  Map<String, dynamic> toJson() => _$AudioChannelsToJson(this);
}

@JsonSerializable()
class VideoDescriptor {
  @JsonKey(name: 'duration_sec')
  final double durationSec;
  final int width;
  final int height;
  final int fps;
  final AudioChannels? audio;

  const VideoDescriptor({
    required this.durationSec,
    required this.width,
    required this.height,
    required this.fps,
    this.audio,
  });

  factory VideoDescriptor.fromJson(Map<String, dynamic> json) => _$VideoDescriptorFromJson(json);
  Map<String, dynamic> toJson() => _$VideoDescriptorToJson(this);
}

@JsonSerializable()
class Thumbnail {
  final int size;
  final String uri;

  const Thumbnail({
    required this.size,
    required this.uri,
  });

  factory Thumbnail.fromJson(Map<String, dynamic> json) => _$ThumbnailFromJson(json);
  Map<String, dynamic> toJson() => _$ThumbnailToJson(this);
}

@JsonSerializable()
class SamplingManifest {
  final String policy;
  final List<Thumbnail>? thumbnails;

  const SamplingManifest({
    required this.policy,
    this.thumbnails,
  });

  factory SamplingManifest.fromJson(Map<String, dynamic> json) => _$SamplingManifestFromJson(json);
  Map<String, dynamic> toJson() => _$SamplingManifestToJson(this);
}

@JsonSerializable()
class VADWindow {
  @JsonKey(name: 'window_sec')
  final int windowSec;

  const VADWindow({required this.windowSec});

  factory VADWindow.fromJson(Map<String, dynamic> json) => _$VADWindowFromJson(json);
  Map<String, dynamic> toJson() => _$VADWindowToJson(this);
}

@JsonSerializable()
class TranscriptSegment {
  final List<double> ts;
  final String text;

  const TranscriptSegment({
    required this.ts,
    required this.text,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) => _$TranscriptSegmentFromJson(json);
  Map<String, dynamic> toJson() => _$TranscriptSegmentToJson(this);
}

@JsonSerializable()
class AudioSamplingManifest {
  final VADWindow vad;
  final List<TranscriptSegment> transcript;

  const AudioSamplingManifest({
    required this.vad,
    required this.transcript,
  });

  factory AudioSamplingManifest.fromJson(Map<String, dynamic> json) => _$AudioSamplingManifestFromJson(json);
  Map<String, dynamic> toJson() => _$AudioSamplingManifestToJson(this);
}

@JsonSerializable()
class Keyframe {
  final double t;
  @JsonKey(name: 'thumb_uri')
  final String thumbUri;

  const Keyframe({
    required this.t,
    required this.thumbUri,
  });

  factory Keyframe.fromJson(Map<String, dynamic> json) => _$KeyframeFromJson(json);
  Map<String, dynamic> toJson() => _$KeyframeToJson(this);
}

@JsonSerializable()
class VideoSamplingManifest {
  final List<Keyframe> keyframes;
  final List<TranscriptSegment> captions;

  const VideoSamplingManifest({
    required this.keyframes,
    required this.captions,
  });

  factory VideoSamplingManifest.fromJson(Map<String, dynamic> json) => _$VideoSamplingManifestFromJson(json);
  Map<String, dynamic> toJson() => _$VideoSamplingManifestToJson(this);
}

@JsonSerializable()
class IntegrityData {
  final String sha256;
  final int bytes;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const IntegrityData({
    required this.sha256,
    required this.bytes,
    required this.createdAt,
  });

  factory IntegrityData.fromJson(Map<String, dynamic> json) => _$IntegrityDataFromJson(json);
  Map<String, dynamic> toJson() => _$IntegrityDataToJson(this);
}

@JsonSerializable()
class PrivacyData {
  @JsonKey(name: 'contains_faces')
  final bool? containsFaces;
  @JsonKey(name: 'location_precision')
  final String? locationPrecision;
  @JsonKey(name: 'pii_hint')
  final bool? piiHint;

  const PrivacyData({
    this.containsFaces,
    this.locationPrecision,
    this.piiHint,
  });

  factory PrivacyData.fromJson(Map<String, dynamic> json) => _$PrivacyDataFromJson(json);
  Map<String, dynamic> toJson() => _$PrivacyDataToJson(this);
}

@JsonSerializable()
class ProvenanceData {
  final String device;
  final String app;

  const ProvenanceData({
    required this.device,
    required this.app,
  });

  factory ProvenanceData.fromJson(Map<String, dynamic> json) => _$ProvenanceDataFromJson(json);
  Map<String, dynamic> toJson() => _$ProvenanceDataToJson(this);
}

@JsonSerializable()
class ImagePointer {
  final String id;
  final String type;
  @JsonKey(name: 'source_uri')
  final String sourceUri;
  final ImageDescriptor descriptor;
  @JsonKey(name: 'sampling_manifest')
  final SamplingManifest samplingManifest;
  final IntegrityData integrity;
  final PrivacyData privacy;
  final ProvenanceData provenance;

  const ImagePointer({
    required this.id,
    required this.type,
    required this.sourceUri,
    required this.descriptor,
    required this.samplingManifest,
    required this.integrity,
    required this.privacy,
    required this.provenance,
  });

  factory ImagePointer.fromJson(Map<String, dynamic> json) => _$ImagePointerFromJson(json);
  Map<String, dynamic> toJson() => _$ImagePointerToJson(this);
}

@JsonSerializable()
class AudioPointer {
  final String id;
  final String type;
  @JsonKey(name: 'source_uri')
  final String sourceUri;
  final AudioDescriptor descriptor;
  @JsonKey(name: 'sampling_manifest')
  final AudioSamplingManifest samplingManifest;
  final IntegrityData integrity;
  final PrivacyData privacy;
  final ProvenanceData provenance;

  const AudioPointer({
    required this.id,
    required this.type,
    required this.sourceUri,
    required this.descriptor,
    required this.samplingManifest,
    required this.integrity,
    required this.privacy,
    required this.provenance,
  });

  factory AudioPointer.fromJson(Map<String, dynamic> json) => _$AudioPointerFromJson(json);
  Map<String, dynamic> toJson() => _$AudioPointerToJson(this);
}

@JsonSerializable()
class VideoPointer {
  final String id;
  final String type;
  @JsonKey(name: 'source_uri')
  final String sourceUri;
  final VideoDescriptor descriptor;
  @JsonKey(name: 'sampling_manifest')
  final VideoSamplingManifest samplingManifest;
  final IntegrityData integrity;
  final PrivacyData privacy;
  final ProvenanceData provenance;

  const VideoPointer({
    required this.id,
    required this.type,
    required this.sourceUri,
    required this.descriptor,
    required this.samplingManifest,
    required this.integrity,
    required this.privacy,
    required this.provenance,
  });

  factory VideoPointer.fromJson(Map<String, dynamic> json) => _$VideoPointerFromJson(json);
  Map<String, dynamic> toJson() => _$VideoPointerToJson(this);
}

@JsonSerializable()
class EmbeddingModel {
  final String name;
  final int dim;
  final String version;

  const EmbeddingModel({
    required this.name,
    required this.dim,
    required this.version,
  });

  factory EmbeddingModel.fromJson(Map<String, dynamic> json) => _$EmbeddingModelFromJson(json);
  Map<String, dynamic> toJson() => _$EmbeddingModelToJson(this);
}

@JsonSerializable()
class EmbeddingSubject {
  final String type;
  final String ref;
  final List<double>? span;

  const EmbeddingSubject({
    required this.type,
    required this.ref,
    this.span,
  });

  factory EmbeddingSubject.fromJson(Map<String, dynamic> json) => _$EmbeddingSubjectFromJson(json);
  Map<String, dynamic> toJson() => _$EmbeddingSubjectToJson(this);
}

@JsonSerializable()
class Embedding {
  final String id;
  final String type;
  final List<double> vector;
  final EmbeddingModel model;
  final EmbeddingSubject subject;

  const Embedding({
    required this.id,
    required this.type,
    required this.vector,
    required this.model,
    required this.subject,
  });

  factory Embedding.fromJson(Map<String, dynamic> json) => _$EmbeddingFromJson(json);
  Map<String, dynamic> toJson() => _$EmbeddingToJson(this);
}

@JsonSerializable()
class NodeLinks {
  @JsonKey(name: 'entry_id')
  final String entryId;
  @JsonKey(name: 'pointer_id')
  final String pointerId;

  const NodeLinks({
    required this.entryId,
    required this.pointerId,
  });

  factory NodeLinks.fromJson(Map<String, dynamic> json) => _$NodeLinksFromJson(json);
  Map<String, dynamic> toJson() => _$NodeLinksToJson(this);
}

@JsonSerializable()
class NodeMeta {
  final List<String> tags;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const NodeMeta({
    required this.tags,
    required this.createdAt,
  });

  factory NodeMeta.fromJson(Map<String, dynamic> json) => _$NodeMetaFromJson(json);
  Map<String, dynamic> toJson() => _$NodeMetaToJson(this);
}

@JsonSerializable()
class Node {
  final String id;
  final String type;
  final String role;
  final NodeLinks links;
  final NodeMeta meta;

  const Node({
    required this.id,
    required this.type,
    required this.role,
    required this.links,
    required this.meta,
  });

  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);
  Map<String, dynamic> toJson() => _$NodeToJson(this);
}