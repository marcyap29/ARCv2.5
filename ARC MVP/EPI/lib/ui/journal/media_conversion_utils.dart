import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/state/journal_entry_state.dart';

/// Utility class for converting between attachment types and MediaItem
class MediaConversionUtils {
  /// Convert PhotoAttachment to MediaItem
  static MediaItem photoAttachmentToMediaItem(PhotoAttachment attachment) {
    return MediaItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      uri: attachment.imagePath,
      type: MediaType.image,
      createdAt: DateTime.fromMillisecondsSinceEpoch(attachment.timestamp),
      analysisData: attachment.analysisResult,
      altText: attachment.altText,
      // Extract OCR text from analysis if available
      ocrText: attachment.analysisResult['ocr']?['fullText'] as String?,
    );
  }

  /// Convert ScanAttachment to MediaItem
  static MediaItem scanAttachmentToMediaItem(ScanAttachment attachment) {
    return MediaItem(
      id: attachment.sourceImageId,
      uri: attachment.thumbnailPath ?? attachment.sourceImageId, // Use thumbnail or fallback to ID
      type: MediaType.image, // Scan attachments are images
      createdAt: DateTime.now(),
      ocrText: attachment.text,
      altText: 'Scanned text: ${attachment.text.length > 50 ? attachment.text.substring(0, 50) + '...' : attachment.text}',
    );
  }

  /// Convert list of attachments to MediaItem list
  static List<MediaItem> attachmentsToMediaItems(List<dynamic> attachments) {
    final mediaItems = <MediaItem>[];
    
    for (final attachment in attachments) {
      if (attachment is PhotoAttachment) {
        mediaItems.add(photoAttachmentToMediaItem(attachment));
      } else if (attachment is ScanAttachment) {
        mediaItems.add(scanAttachmentToMediaItem(attachment));
      }
    }
    
    return mediaItems;
  }

  /// Check if a MediaItem represents a photo (has analysis data)
  static bool isPhotoMediaItem(MediaItem mediaItem) {
    return mediaItem.analysisData != null && mediaItem.analysisData!.isNotEmpty;
  }

  /// Convert MediaItem back to PhotoAttachment
  static PhotoAttachment mediaItemToPhotoAttachment(MediaItem mediaItem) {
    return PhotoAttachment(
      type: 'photo_analysis',
      imagePath: mediaItem.uri,
      analysisResult: mediaItem.analysisData ?? {},
      timestamp: mediaItem.createdAt.millisecondsSinceEpoch,
      altText: mediaItem.altText,
      // Note: insertionPosition is lost in conversion, will be null
      // This is acceptable as photos will display in chronological order by timestamp
    );
  }

  /// Convert MediaItem back to ScanAttachment
  static ScanAttachment mediaItemToScanAttachment(MediaItem mediaItem) {
    return ScanAttachment(
      type: 'ocr_text',
      text: mediaItem.ocrText ?? '',
      sourceImageId: mediaItem.id,
      thumbnailPath: mediaItem.uri,
    );
  }

  /// Convert list of MediaItems back to attachments
  static List<dynamic> mediaItemsToAttachments(List<MediaItem> mediaItems) {
    final attachments = <dynamic>[];
    
    for (final mediaItem in mediaItems) {
      if (isPhotoMediaItem(mediaItem)) {
        attachments.add(mediaItemToPhotoAttachment(mediaItem));
      } else if (mediaItem.ocrText != null && mediaItem.ocrText!.isNotEmpty) {
        attachments.add(mediaItemToScanAttachment(mediaItem));
      }
    }
    
    return attachments;
  }

  /// Check if a MediaItem represents scanned text
  static bool isScanMediaItem(MediaItem mediaItem) {
    return mediaItem.ocrText != null && mediaItem.ocrText!.isNotEmpty && 
           (mediaItem.analysisData == null || mediaItem.analysisData!.isEmpty);
  }

  /// Get display text for a MediaItem (for hyperlink text)
  static String getDisplayText(MediaItem mediaItem) {
    if (isPhotoMediaItem(mediaItem)) {
      return '*Click to view photo*';
    } else if (isScanMediaItem(mediaItem)) {
      return '*Click to view scanned text*';
    } else {
      return '*Click to view media*';
    }
  }

  /// Get analysis summary for a MediaItem
  static String getAnalysisSummary(MediaItem mediaItem) {
    if (isPhotoMediaItem(mediaItem)) {
      return mediaItem.analysisData?['summary'] as String? ?? 'Photo analyzed';
    } else if (isScanMediaItem(mediaItem)) {
      return 'Scanned text: ${mediaItem.ocrText!.length} characters';
    } else {
      return 'Media item';
    }
  }
}
