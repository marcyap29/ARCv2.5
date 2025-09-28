/// Utility class for safely coercing Hive data types to avoid null safety issues
/// and handle Set/List conversions that can cause crashes in generated adapters.
class HiveCoerce {
  /// Safely convert any object to a List<T>, returning empty list if null or invalid
  static List<T> listOrEmpty<T>(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.cast<T>();
    return const [];
  }

  /// Convert List to Set<String>, handling null and type safety
  static Set<String> setFromList(Object? raw) {
    if (raw == null) return <String>{};
    if (raw is List) return Set<String>.from(raw.cast<String>());
    if (raw is Set) return raw.cast<String>();
    return <String>{};
  }

  /// Safely convert to Map<String, double>
  static Map<String, double> mapStrDouble(Object? raw) {
    if (raw is Map) return raw.cast<String, double>();
    return const {};
  }

  /// Safely convert to Map<String, String>
  static Map<String, String> mapStrString(Object? raw) {
    if (raw is Map) return raw.cast<String, String>();
    return const {};
  }

  /// Safely convert to Map<String, dynamic>
  static Map<String, dynamic> mapStrDynamic(Object? raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    return const {};
  }

  /// Safely convert to List<String>
  static List<String> listString(Object? raw) {
    return listOrEmpty<String>(raw);
  }

  /// Safely convert to List<Map<String, dynamic>>
  static List<Map<String, dynamic>> listMapStrDynamic(Object? raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return const [];
  }
}