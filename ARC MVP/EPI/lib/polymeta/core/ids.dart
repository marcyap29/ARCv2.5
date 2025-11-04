// lib/mira/core/ids.dart
// Deterministic ID generation for MIRA entities
// Ensures stable, predictable identifiers across sessions and exports

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Generate stable keyword ID by normalizing text
String stableKeywordId(String text) {
  final normalized = text.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'kw_$slug';
}

/// Generate stable phase ID from phase name
String stablePhaseId(String name) {
  final normalized = name.trim().toLowerCase();
  return 'ph_$normalized';
}

/// Generate stable emotion ID from emotion name
String stableEmotionId(String name) {
  final normalized = name.trim().toLowerCase();
  return 'em_$normalized';
}

/// Generate stable period ID from date (YYYY-MM-DD format)
String stablePeriodId(DateTime date) {
  final dateStr = date.toIso8601String().substring(0, 10);
  return 'pd_$dateStr';
}

/// Generate deterministic edge ID from source, label, and destination
String deterministicEdgeId(String src, String label, String dst) {
  final combined = '$src|$label|$dst';
  final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 12);
  return 'e_$hash';
}

/// Generate deterministic entry ID from content and timestamp
String deterministicEntryId(String content, DateTime timestamp) {
  final normalized = content.trim();
  final combined = '$normalized|${timestamp.toUtc().toIso8601String()}';
  final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 12);
  return 'entry_$hash';
}

/// Generate stable topic ID from topic slug
String stableTopicId(String topicSlug) {
  final normalized = topicSlug.trim().toLowerCase();
  final slug = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  final hash = sha1.convert(utf8.encode(slug)).toString().substring(0, 8);
  return 'topic_${slug}_$hash';
}

/// Generate stable episode ID from time window
String stableEpisodeId(DateTime startDate, DateTime endDate) {
  final start = startDate.toIso8601String().substring(0, 10);
  final end = endDate.toIso8601String().substring(0, 10);
  final hash = sha1.convert(utf8.encode('$start:$end')).toString().substring(0, 8);
  return 'episode_${start}_${end}_$hash';
}

/// Generate stable summary ID for episode summaries
String stableSummaryId(String episodeId) {
  final hash = sha1.convert(utf8.encode(episodeId)).toString().substring(0, 8);
  return 'summary_${episodeId}_$hash';
}

/// Generate pointer ID for journal entries and media
String stablePointerId(String entryId, String mediaType) {
  final hash = sha1.convert(utf8.encode('$entryId:$mediaType')).toString().substring(0, 8);
  return 'ptr_${entryId}_$hash';
}

/// Generate embedding ID for vectors
String stableEmbeddingId(String pointerId, String modelId, String embeddingVersion) {
  final combined = '$pointerId:$modelId:$embeddingVersion';
  final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 12);
  return 'emb_$hash';
}

/// Generate entry ID for enhanced memory nodes
String generateEntryId(DateTime timestamp) {
  final dateStr = timestamp.toIso8601String().substring(0, 19);
  final hash = sha1.convert(utf8.encode(dateStr)).toString().substring(0, 8);
  return 'ent_$hash';
}

/// Generate message ID for chat messages
String generateMessageId(DateTime timestamp, String role) {
  final combined = '${timestamp.toIso8601String()}:$role';
  final hash = sha1.convert(utf8.encode(combined)).toString().substring(0, 8);
  return 'msg_$hash';
}