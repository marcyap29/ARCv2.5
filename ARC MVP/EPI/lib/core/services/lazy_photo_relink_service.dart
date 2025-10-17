import 'package:flutter/services.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/data/models/photo_metadata.dart';

/// Service for lazy photo relinking that only runs when an entry is opened
class LazyPhotoRelinkService {
  static final RegExp _photoTokenRe = RegExp(r'\[PHOTO:(photo_\d{13,})\]');
  
  // Guards to prevent duplicate relinking
  static final Set<String> _relinkInFlight = <String>{};
  static const Duration _relinkCooldown = Duration(minutes: 5);

  /// Check if text contains photo placeholders
  static bool hasPlaceholders(String? text) =>
      text != null && _photoTokenRe.hasMatch(text);

  /// Check if entry has real media (not just placeholders)
  static bool hasRealMedia(JournalEntry entry) =>
      entry.media.any((m) => !(m.uri?.startsWith('placeholder://') ?? true));

  /// Extract photo IDs from text
  static List<String> extractPhotoIds(String? text) =>
      text == null ? [] : _photoTokenRe.allMatches(text).map((m) => m.group(1)!).toList();

  /// Create metadata from placeholder timestamp
  static Map<String, dynamic> metaFromPlaceholder(String placeholderId) {
    final parts = placeholderId.split('_');
    if (parts.length == 2) {
      final ms = int.tryParse(parts[1]);
      if (ms != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        return {
          'placeholder_id': placeholderId,
          'creation_date': dt.toIso8601String(),
          'timestampMs': ms, // Add timestampMs for iOS filtering
        };
      }
    }
    return {'placeholder_id': placeholderId};
  }

  /// Safe string extraction helper
  static String? _asString(Map? m, String k) => (m?[k] is String) ? m![k] as String : null;

  /// Safe map normalization helper
  static Map<String, dynamic> _asStringMapOrNull(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  /// Resolve a single photo URI using iOS bridge with null-safe metadata extraction
  static Future<String> resolvePhotoUri(String placeholderId, Map<String, dynamic> nodeMetadata) async {
    Map<String, dynamic> found = {};
    
    try {
      final photos = (nodeMetadata['photos'] as List?) ?? const [];
      found = photos.cast<Map>().cast<Map<String, dynamic>>().firstWhere(
        (m) => m['placeholder_id'] == placeholderId,
        orElse: () => {},
      );
    } catch (_) {}
    
    if (found.isEmpty) {
      found = metaFromPlaceholder(placeholderId);
    }

    // Safe string extraction with null guards
    final localId = _asString(found, 'local_identifier')?.trim();
    if (localId?.isNotEmpty == true) {
      try {
        final exists = await PhotoLibraryService.photoExistsInLibrary('ph://$localId');
        if (exists) {
          print('Relink result $placeholderId → ph://$localId (local ID)');
          return 'ph://$localId';
        }
      } catch (e) {
        print('Relink error checking local ID for $placeholderId: $e');
      }
    }

    // Safe metadata search with null guards
    try {
      final creationDate = _asString(found, 'creation_date');
      if (creationDate != null) {
               final photoMetadata = PhotoMetadata(
                 localIdentifier: localId ?? '',
                 creationDate: creationDate != null ? DateTime.tryParse(creationDate) : null,
                 filename: _asString(found, 'original_filename'),
                 fileSize: (found['file_size'] is int) ? found['file_size'] as int : null,
                 pixelWidth: (found['pixel_width'] is int) ? found['pixel_width'] as int : null,
                 pixelHeight: (found['pixel_height'] is int) ? found['pixel_height'] as int : null,
                 timestampMs: (found['timestampMs'] is int) ? found['timestampMs'] as int : null,
               );
        final resolved = await PhotoLibraryService.findPhotoByMetadata(photoMetadata);
        if (resolved != null && resolved.startsWith('ph://')) {
          print('Relink result $placeholderId → $resolved (metadata search)');
          return resolved;
        }
      }
    } catch (e) {
      print('Relink error metadata search for $placeholderId: $e');
    }

    print('Relink result $placeholderId → placeholder://$placeholderId (fallback)');
    return 'placeholder://$placeholderId';
  }

  /// Reconstruct media items from text placeholders
  static Future<List<MediaItem>> reconstructMediaFromText({
    required String text,
    required Map<String, dynamic> nodeMetadata,
  }) async {
    final items = <MediaItem>[];
    final matches = _photoTokenRe.allMatches(text);
    
    for (final match in matches) {
      final placeholderId = match.group(1)!;
      final uri = await resolvePhotoUri(placeholderId, nodeMetadata);
      
      items.add(MediaItem(
        id: placeholderId,
        type: MediaType.image,
        uri: uri,
        createdAt: DateTime.now(),
        analysisData: {
          'photo_id': placeholderId,
          'imported': true,
          'placeholder': uri.startsWith('placeholder://'),
          if (uri.startsWith('placeholder://')) 'unavailable': true,
        },
      ));
    }
    
    return items;
  }

  /// Merge media items, replacing placeholders with real URIs
  static List<MediaItem> mergeMedia(List<MediaItem> current, List<MediaItem> real) {
    final map = <String, MediaItem>{for (final m in current) m.id: m};
    
    for (final m in real) {
      map[m.id] = m.uri?.startsWith('placeholder://') == true
          ? (map[m.id] ?? m)  // keep existing if it's already real
          : m;                 // overwrite placeholder with real
    }
    
    return map.values.toList();
  }

  /// Check if relinking should be attempted (cooldown + guards)
  static bool shouldAttemptRelink(JournalEntry entry) {
    // Only relink if needed
    final needsRelink = hasPlaceholders(entry.content) && !hasRealMedia(entry);
    if (!needsRelink) {
      print('Relink skip entry=${entry.id} reason=not_needed');
      return false;
    }

    // Check if already in flight
    if (_relinkInFlight.contains(entry.id)) {
      print('Relink skip entry=${entry.id} reason=in_flight');
      return false;
    }

    // Check cooldown
    final lastAttempt = (entry.metadata?['last_relink_attempt'] as int?);
    if (lastAttempt != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final tooSoon = nowMs - lastAttempt < _relinkCooldown.inMilliseconds;
      if (tooSoon) {
        print('Relink skip entry=${entry.id} reason=cooldown');
        return false;
      }
    }

    return true;
  }

  /// Attempt to relink photos for an entry
  static Future<bool> attemptRelink(JournalEntry entry) async {
    if (!shouldAttemptRelink(entry)) {
      return false;
    }

    final needsRelink = hasPlaceholders(entry.content) && !hasRealMedia(entry);
    if (!needsRelink) {
      print('Relink skip entry=${entry.id} reason=not_needed');
      return false;
    }

    _relinkInFlight.add(entry.id);
    final photoIds = extractPhotoIds(entry.content);
    print('Relink start entry=${entry.id} photos=$photoIds');

    try {
      final resolved = await reconstructMediaFromText(
        text: entry.content ?? '',
        nodeMetadata: (entry.metadata as Map<String, dynamic>?) ?? const {},
      );

      final real = resolved.where((m) => !(m.uri?.startsWith('placeholder://') ?? true)).toList();
      if (real.isNotEmpty) {
        final merged = mergeMedia(entry.media, resolved);
        final updated = entry.copyWith(media: merged);
        
        // Update entry with new media
        // Note: This would need to be handled by the calling code
        print('Relink success entry=${entry.id} resolved=${real.length} photos');
        return true;
      } else {
        print('Relink no_matches entry=${entry.id}');
        return false;
      }
    } catch (e) {
      print('Relink error entry=${entry.id}: $e');
      return false;
    } finally {
      _relinkInFlight.remove(entry.id);
      print('Relink end entry=${entry.id}');
    }
  }
}
