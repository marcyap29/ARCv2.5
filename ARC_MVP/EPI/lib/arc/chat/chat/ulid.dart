import 'dart:math';

/// ULID (Universally Unique Lexicographically Sortable Identifier) generator
/// Provides stable, deterministic IDs for chat sessions and messages
class ULID {
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Random _random = Random.secure();

  /// Generate a new ULID with current timestamp
  static String generate() {
    return generateAt(DateTime.now().millisecondsSinceEpoch);
  }

  /// Generate ULID at specific timestamp (for testing)
  static String generateAt(int timestamp) {
    final timeChars = _encodeTime(timestamp);
    final randomChars = _encodeRandom();
    return timeChars + randomChars;
  }

  /// Encode timestamp portion (10 characters)
  static String _encodeTime(int timestamp) {
    var chars = '';
    var time = timestamp;

    for (int i = 9; i >= 0; i--) {
      final mod = time % 32;
      chars = _alphabet[mod] + chars;
      time = time ~/ 32;
    }

    return chars.padLeft(10, '0');
  }

  /// Encode random portion (16 characters)
  static String _encodeRandom() {
    var chars = '';

    for (int i = 0; i < 16; i++) {
      chars += _alphabet[_random.nextInt(32)];
    }

    return chars;
  }

  /// Extract timestamp from ULID
  static int extractTimestamp(String ulid) {
    if (ulid.length != 26) {
      throw ArgumentError('Invalid ULID length');
    }

    final timeChars = ulid.substring(0, 10);
    int timestamp = 0;

    for (int i = 0; i < timeChars.length; i++) {
      final char = timeChars[i];
      final value = _alphabet.indexOf(char);
      if (value == -1) {
        throw ArgumentError('Invalid ULID character: $char');
      }
      timestamp = timestamp * 32 + value;
    }

    return timestamp;
  }

  /// Validate ULID format
  static bool isValid(String ulid) {
    if (ulid.length != 26) return false;

    for (int i = 0; i < ulid.length; i++) {
      if (!_alphabet.contains(ulid[i])) {
        return false;
      }
    }

    return true;
  }
}