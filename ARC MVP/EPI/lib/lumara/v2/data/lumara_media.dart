// lib/lumara/v2/data/lumara_media.dart
// Unified media access for LUMARA

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/lumara_service.dart';

/// Unified media access for LUMARA
class LumaraMedia {
  final LumaraService _service;
  
  LumaraMedia(this._service);
  
  /// Get photos with optional filters
  Future<List<LumaraPhoto>> getPhotos({
    int? limit,
    DateTime? since,
    String? journalEntryId,
    List<String>? keywords,
  }) async {
    try {
      return await _service.getPhotos(
        limit: limit,
        since: since,
        journalEntryId: journalEntryId,
        keywords: keywords,
      );
    } catch (e) {
      debugPrint('LUMARA Media: Error getting photos: $e');
      return [];
    }
  }
  
  /// Get audio recordings
  Future<List<LumaraAudio>> getAudioRecordings({
    int? limit,
    DateTime? since,
    String? journalEntryId,
  }) async {
    try {
      return await _service.getAudioRecordings(
        limit: limit,
        since: since,
        journalEntryId: journalEntryId,
      );
    } catch (e) {
      debugPrint('LUMARA Media: Error getting audio: $e');
      return [];
    }
  }
  
  /// Get video recordings
  Future<List<LumaraVideo>> getVideoRecordings({
    int? limit,
    DateTime? since,
    String? journalEntryId,
  }) async {
    try {
      return await _service.getVideoRecordings(
        limit: limit,
        since: since,
        journalEntryId: journalEntryId,
      );
    } catch (e) {
      debugPrint('LUMARA Media: Error getting video: $e');
      return [];
    }
  }
  
  /// Get all media for a specific journal entry
  Future<List<LumaraMediaItem>> getMediaForEntry(String journalEntryId) async {
    try {
      final photos = await getPhotos(journalEntryId: journalEntryId);
      final audio = await getAudioRecordings(journalEntryId: journalEntryId);
      final video = await getVideoRecordings(journalEntryId: journalEntryId);
      
      return [
        ...photos.map((p) => LumaraMediaItem.photo(p)),
        ...audio.map((a) => LumaraMediaItem.audio(a)),
        ...video.map((v) => LumaraMediaItem.video(v)),
      ];
    } catch (e) {
      debugPrint('LUMARA Media: Error getting media for entry: $e');
      return [];
    }
  }
  
  /// Analyze media content (OCR, transcription, etc.)
  Future<LumaraMediaAnalysis> analyzeMedia(LumaraMediaItem media) async {
    try {
      return await _service.analyzeMedia(media);
    } catch (e) {
      debugPrint('LUMARA Media: Error analyzing media: $e');
      return LumaraMediaAnalysis.empty();
    }
  }
  
  /// Get media file path
  Future<String?> getMediaPath(String mediaId) async {
    try {
      return await _service.getMediaPath(mediaId);
    } catch (e) {
      debugPrint('LUMARA Media: Error getting media path: $e');
      return null;
    }
  }
}

/// Base class for LUMARA media items
abstract class LumaraMediaItem {
  final String id;
  final String type;
  final DateTime createdAt;
  final String? journalEntryId;
  final Map<String, dynamic> metadata;
  
  const LumaraMediaItem({
    required this.id,
    required this.type,
    required this.createdAt,
    this.journalEntryId,
    this.metadata = const {},
  });
  
  factory LumaraMediaItem.photo(LumaraPhoto photo) => _PhotoMediaItem(photo);
  factory LumaraMediaItem.audio(LumaraAudio audio) => _AudioMediaItem(audio);
  factory LumaraMediaItem.video(LumaraVideo video) => _VideoMediaItem(video);
  
  Map<String, dynamic> toJson();
}

class _PhotoMediaItem extends LumaraMediaItem {
  final LumaraPhoto photo;
  
  _PhotoMediaItem(this.photo) : super(
    id: photo.id,
    type: 'photo',
    createdAt: photo.createdAt,
    journalEntryId: photo.journalEntryId,
    metadata: photo.metadata,
  );
  
  @override
  Map<String, dynamic> toJson() => photo.toJson();
}

class _AudioMediaItem extends LumaraMediaItem {
  final LumaraAudio audio;
  
  _AudioMediaItem(this.audio) : super(
    id: audio.id,
    type: 'audio',
    createdAt: audio.createdAt,
    journalEntryId: audio.journalEntryId,
    metadata: audio.metadata,
  );
  
  @override
  Map<String, dynamic> toJson() => audio.toJson();
}

class _VideoMediaItem extends LumaraMediaItem {
  final LumaraVideo video;
  
  _VideoMediaItem(this.video) : super(
    id: video.id,
    type: 'video',
    createdAt: video.createdAt,
    journalEntryId: video.journalEntryId,
    metadata: video.metadata,
  );
  
  @override
  Map<String, dynamic> toJson() => video.toJson();
}

/// Photo media item
class LumaraPhoto {
  final String id;
  final DateTime createdAt;
  final String? journalEntryId;
  final String? filePath;
  final String? localIdentifier;
  final int? width;
  final int? height;
  final int? fileSize;
  final String? caption;
  final Map<String, dynamic> metadata;
  
  const LumaraPhoto({
    required this.id,
    required this.createdAt,
    this.journalEntryId,
    this.filePath,
    this.localIdentifier,
    this.width,
    this.height,
    this.fileSize,
    this.caption,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'photo',
      'createdAt': createdAt.toIso8601String(),
      'journalEntryId': journalEntryId,
      'filePath': filePath,
      'localIdentifier': localIdentifier,
      'width': width,
      'height': height,
      'fileSize': fileSize,
      'caption': caption,
      'metadata': metadata,
    };
  }
}

/// Audio media item
class LumaraAudio {
  final String id;
  final DateTime createdAt;
  final String? journalEntryId;
  final String? filePath;
  final double? durationSeconds;
  final int? fileSize;
  final String? transcription;
  final Map<String, dynamic> metadata;
  
  const LumaraAudio({
    required this.id,
    required this.createdAt,
    this.journalEntryId,
    this.filePath,
    this.durationSeconds,
    this.fileSize,
    this.transcription,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'audio',
      'createdAt': createdAt.toIso8601String(),
      'journalEntryId': journalEntryId,
      'filePath': filePath,
      'durationSeconds': durationSeconds,
      'fileSize': fileSize,
      'transcription': transcription,
      'metadata': metadata,
    };
  }
}

/// Video media item
class LumaraVideo {
  final String id;
  final DateTime createdAt;
  final String? journalEntryId;
  final String? filePath;
  final double? durationSeconds;
  final int? fileSize;
  final int? width;
  final int? height;
  final String? transcription;
  final Map<String, dynamic> metadata;
  
  const LumaraVideo({
    required this.id,
    required this.createdAt,
    this.journalEntryId,
    this.filePath,
    this.durationSeconds,
    this.fileSize,
    this.width,
    this.height,
    this.transcription,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'video',
      'createdAt': createdAt.toIso8601String(),
      'journalEntryId': journalEntryId,
      'filePath': filePath,
      'durationSeconds': durationSeconds,
      'fileSize': fileSize,
      'width': width,
      'height': height,
      'transcription': transcription,
      'metadata': metadata,
    };
  }
}

/// Media analysis results
class LumaraMediaAnalysis {
  final String mediaId;
  final String? extractedText;
  final String? transcription;
  final List<String> detectedObjects;
  final List<String> keywords;
  final Map<String, dynamic> metadata;
  
  const LumaraMediaAnalysis({
    required this.mediaId,
    this.extractedText,
    this.transcription,
    this.detectedObjects = const [],
    this.keywords = const [],
    this.metadata = const {},
  });
  
  factory LumaraMediaAnalysis.empty() {
    return const LumaraMediaAnalysis(mediaId: '');
  }
  
  Map<String, dynamic> toJson() {
    return {
      'mediaId': mediaId,
      'extractedText': extractedText,
      'transcription': transcription,
      'detectedObjects': detectedObjects,
      'keywords': keywords,
      'metadata': metadata,
    };
  }
}
