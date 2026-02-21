/// Media Policy Configuration for Draft System
/// 
/// Enforces no-compression policy: originals are stored bit-exactly,
/// only thumbnails are generated for UI performance.
class MediaPolicy {
  // Global media behavior - locked to prevent compression
  static const bool compressOriginals = false;       // locked false
  static const bool transcodeOriginals = false;      // locked false
  static const bool stripExif = false;               // keep EXIF
  static const bool generateThumbs = true;           // allowed
  static const int thumbMaxW = 512;
  static const int thumbMaxH = 512;

  // Safety rails since originals can be large
  static const int maxSingleImportMB = 250;          // hard cap on one file
  static const int maxDraftTotalGB = 5;              // per-draft soft quota
  
  static int get maxSingleImportBytes => maxSingleImportMB * 1024 * 1024;
  static int get maxDraftTotalBytes => maxDraftTotalGB * 1024 * 1024 * 1024;
}

