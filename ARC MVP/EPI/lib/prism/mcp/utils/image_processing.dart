import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:image/image.dart' as img;

/// Compute SHA-256 hash of bytes and return as hex string
String sha256Hex(Uint8List bytes) {
  return crypto.sha256.convert(bytes).toString();
}

/// Result of reencoding an image
class Reencoded {
  final Uint8List bytes;
  final String ext;

  const Reencoded({
    required this.bytes,
    required this.ext,
  });
}

/// Reencode full-resolution image with size and quality constraints
Reencoded reencodeFull(
  Uint8List inBytes, {
  int maxEdge = 2048,
  int quality = 85,
}) {
  final im = img.decodeImage(inBytes);
  if (im == null) {
    // If we can't decode, return original bytes as jpg
    return Reencoded(bytes: inBytes, ext: 'jpg');
  }

  // Calculate new dimensions maintaining aspect ratio
  int newWidth = im.width;
  int newHeight = im.height;

  if (im.width > maxEdge || im.height > maxEdge) {
    if (im.width >= im.height) {
      newWidth = maxEdge;
      newHeight = (im.height * maxEdge / im.width).round();
    } else {
      newHeight = maxEdge;
      newWidth = (im.width * maxEdge / im.height).round();
    }
  }

  // Resize image
  final resized = img.copyResize(
    im,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.linear,
  );

  // Encode as JPEG (strips EXIF by default)
  final out = img.encodeJpg(resized, quality: quality);
  return Reencoded(bytes: Uint8List.fromList(out), ext: 'jpg');
}

/// Create thumbnail from full-resolution image
Uint8List makeThumbnail(
  Uint8List fullBytes, {
  int maxEdge = 768,
}) {
  final im = img.decodeImage(fullBytes);
  if (im == null) {
    // If we can't decode, return empty bytes
    return Uint8List(0);
  }

  // Calculate thumbnail dimensions maintaining aspect ratio
  int newWidth = im.width;
  int newHeight = im.height;

  if (im.width > maxEdge || im.height > maxEdge) {
    if (im.width >= im.height) {
      newWidth = maxEdge;
      newHeight = (im.height * maxEdge / im.width).round();
    } else {
      newHeight = maxEdge;
      newWidth = (im.width * maxEdge / im.height).round();
    }
  }

  // Resize image
  final thumbnail = img.copyResize(
    im,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.linear,
  );

  // Encode as JPEG with good quality for thumbnails
  final out = img.encodeJpg(thumbnail, quality: 85);
  return Uint8List.fromList(out);
}

/// Get file extension from image format
String getImageExtension(String format) {
  switch (format.toLowerCase()) {
    case 'heic':
      return 'heic';
    case 'png':
      return 'png';
    case 'webp':
      return 'webp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'jpg';
  }
}

/// Check if image format is supported for processing
bool isSupportedFormat(String format) {
  switch (format.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'heic':
    case 'webp':
      return true;
    default:
      return false;
  }
}
