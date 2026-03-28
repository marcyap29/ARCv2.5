import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// iOS [NSItemProvider] often fails with "Cannot load representation of type
/// public.png/jpeg" for HEIC, screenshots, and iCloud-backed assets when the
/// plugin requests full image metadata. Using [requestFullMetadata]: false
/// avoids that path for most gallery picks.
///
/// Forcing [maxWidth]/[maxHeight]/[imageQuality] makes iOS decode and re-encode
/// (typically JPEG), which avoids the broken `public.png` item provider path.
///
/// If multi-select still throws [invalid_image], we fall back to single-image
/// pick, then to [FilePicker] (different native API) so the user can attach photos.
final class RobustGalleryPicker {
  RobustGalleryPicker._();

  /// Large enough for full-res editing; small enough to steer iOS through JPEG path.
  static const double _kMaxDimension = 8192;
  static const int _kJpegQuality = 88;

  static bool _isRepresentationFailure(PlatformException e) {
    if (e.code == 'invalid_image') return true;
    final m = e.message ?? '';
    return m.contains('Cannot load representation') ||
        m.contains('NSItemProviderErrorDomain');
  }

  static Future<List<XFile>> _pickImagesViaFilePicker({int? limit}) async {
    final allowMulti = limit == null || limit > 1;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: allowMulti,
      allowCompression: false,
    );
    if (result == null || result.files.isEmpty) return [];
    final out = <XFile>[];
    for (final f in result.files) {
      if (limit != null && out.length >= limit) break;
      final p = f.path;
      if (p != null && p.isNotEmpty) {
        out.add(XFile(p));
      } else if (f.bytes != null) {
        out.add(XFile.fromData(f.bytes!, name: f.name));
      }
    }
    return out;
  }

  static Future<List<XFile>> pickMulti(
    ImagePicker picker, {
    int? limit,
  }) async {
    try {
      return await picker.pickMultiImage(
        limit: limit,
        requestFullMetadata: false,
        maxWidth: _kMaxDimension,
        maxHeight: _kMaxDimension,
        imageQuality: _kJpegQuality,
      );
    } on PlatformException catch (e) {
      if (!_isRepresentationFailure(e)) rethrow;
      try {
        final one = await picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
          maxWidth: _kMaxDimension,
          maxHeight: _kMaxDimension,
          imageQuality: _kJpegQuality,
        );
        if (one != null) return [one];
      } on PlatformException catch (e2) {
        if (!_isRepresentationFailure(e2)) rethrow;
      }
      return _pickImagesViaFilePicker(limit: limit);
    }
  }

  static Future<XFile?> pickSingleGallery(
    ImagePicker picker, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final mw = maxWidth ?? _kMaxDimension;
    final mh = maxHeight ?? _kMaxDimension;
    final q = imageQuality ?? _kJpegQuality;
    try {
      return await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
        maxWidth: mw,
        maxHeight: mh,
        imageQuality: q,
      );
    } on PlatformException catch (e) {
      if (!_isRepresentationFailure(e)) rethrow;
      final r = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: false,
      );
      if (r != null && r.files.isNotEmpty) {
        final f = r.files.single;
        final p = f.path;
        if (p != null && p.isNotEmpty) return XFile(p);
        if (f.bytes != null) {
          return XFile.fromData(f.bytes!, name: f.name);
        }
      }
      return null;
    }
  }

  static Future<XFile?> pickCamera(
    ImagePicker picker, {
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) {
    return picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
      imageQuality: imageQuality ?? _kJpegQuality,
      maxWidth: maxWidth ?? _kMaxDimension,
      maxHeight: maxHeight ?? _kMaxDimension,
    );
  }
}
