// lib/lumara/agents/writing/style_profile_service.dart
//
// Phase 5b: Style profile from last 10 journal entries, PRISM-scrubbed,
// extracted via gemini-flash, cached 7 days.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_app/arc/internal/echo/prism_adapter.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyProfile = 'writing_style_profile';
const String _keyTimestamp = 'writing_style_profile_ts';
const int _cacheValidDays = 7;
const int _minEntries = 3;
const int _maxEntries = 10;

const String _styleExtractionPrompt = r'''
Analyse the following journal entries and extract a writing style profile.
Describe: sentence length preference, vocabulary level, use of metaphor,
emotional tone, punctuation habits, and any distinctive patterns.
Do not include any personal information, names, or specific events.
Return only a style description of 150–250 words suitable for use as
a system prompt instruction.

Journal entries:
''';

class StyleProfileService {
  StyleProfileService._();
  static final StyleProfileService instance = StyleProfileService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final _prism = PrismAdapter();
  Future<SharedPreferences>? _prefsFuture;
  Future<SharedPreferences> get _prefsAsync =>
      _prefsFuture ??= SharedPreferences.getInstance();

  /// Returns cached style excerpt if valid; otherwise null (caller may call refresh).
  Future<String?> getCachedProfile() async {
    final prefs = await _prefsAsync;
    final text = prefs.getString(_keyProfile);
    final ts = prefs.getInt(_keyTimestamp);
    if (text == null || text.isEmpty || ts == null) return null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    if (DateTime.now().difference(cachedAt).inDays >= _cacheValidDays) {
      return null;
    }
    return text;
  }

  /// Returns the current profile: from cache if valid, else from refresh (if enough entries).
  /// If fewer than 3 journal entries, returns null.
  Future<String?> getProfile() async {
    final cached = await getCachedProfile();
    if (cached != null) return cached;
    return refresh();
  }

  /// Re-reads journal entries, PRISM-scrubs, calls gemini-flash for style extraction, caches result.
  /// [context] optional; when provided, consent UI can be shown for gemini-flash.
  /// Returns null if fewer than 3 entries or on failure.
  Future<String?> refresh([BuildContext? context]) async {
    final userId = FirebaseAuthService.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return null;

    final entries = await _fetchLastJournalEntries(userId);
    if (entries.length < _minEntries) return null;

    final scrubbed = <String>[];
    for (final text in entries) {
      final result = _prism.scrub(text);
      if (result.scrubbedText.trim().isNotEmpty) {
        scrubbed.add(result.scrubbedText);
      }
    }
    if (scrubbed.length < _minEntries) return null;

    final combined = scrubbed.join('\n---\n');
    final userPrompt = _styleExtractionPrompt + combined;

    final prismResult = await PrismService.instance.authoriseAndCall(
      pluginId: 'gemini-flash',
      params: {
        'system': 'You are a writing analyst. Return only the requested style description. No preamble.',
        'user': userPrompt,
        'max_tokens': 500,
        'temperature': 0.3,
      },
      context: context,
    );
    if (prismResult.isDenied || prismResult.result == null || !prismResult.result!.success) {
      return null;
    }
    final body = _extractText(prismResult.result!.data!);
    if (body == null || body.trim().isEmpty) return null;

    final prefs = await _prefsAsync;
    await prefs.setString(_keyProfile, body.trim());
    await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);
    return body.trim();
  }

  /// Last 10 journal entries from Firestore (users/{userId}/journal_entries), ordered by timestamp desc.
  Future<List<String>> _fetchLastJournalEntries(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('journal_entries')
          .orderBy('timestamp', descending: true)
          .limit(_maxEntries)
          .get();

      final list = <String>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final text = data['entry_text'] as String? ?? '';
        if (text.trim().isNotEmpty) list.add(text.trim());
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  String? _extractText(Map<String, dynamic> data) {
    final text = data['text'] as String?;
    if (text != null && text.isNotEmpty) return text.trim();
    final content = data['content'] as String?;
    if (content != null && content.isNotEmpty) return content.trim();
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final first = candidates.first as Map<String, dynamic>?;
      final contentObj = first?['content'] as Map<String, dynamic>?;
      final parts = contentObj?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        final part = parts.first as Map<String, dynamic>?;
        final partText = part?['text'] as String?;
        if (partText != null && partText.isNotEmpty) return partText.trim();
      }
    }
    return null;
  }

  /// Number of journal entries available (for UI: "Write a few more..." when < 3).
  Future<int> getJournalEntryCount() async {
    final userId = FirebaseAuthService.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return 0;
    final entries = await _fetchLastJournalEntries(userId);
    return entries.length;
  }
}
