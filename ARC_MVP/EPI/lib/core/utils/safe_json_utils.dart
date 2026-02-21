import 'dart:convert';

/// Safe JSON and Hive reading utilities to prevent type cast errors

/// Safe string extraction from maps
String? safeString(Map? map, String key) => (map?[key] is String) ? map![key] as String : null;

/// Safe int extraction from maps
int? safeInt(Map? map, String key) => (map?[key] is int) ? map![key] as int : null;

/// Safe double extraction from maps
double? safeDouble(Map? map, String key) => (map?[key] is double) ? map![key] as double : null;

/// Safe bool extraction from maps
bool? safeBool(Map? map, String key) => (map?[key] is bool) ? map![key] as bool : null;

/// Safe list extraction from maps
List? safeList(Map? map, String key) => (map?[key] is List) ? map![key] as List : null;

/// Safe map extraction from maps
Map? safeMap(Map? map, String key) => (map?[key] is Map) ? map![key] as Map : null;

/// Safe field reading with default value
T safeField<T>(Map<String, dynamic> map, String key, T defaultValue) {
  final value = map[key];
  return (value is T) ? value : defaultValue;
}

/// Normalize dynamic map to String-keyed map
Map<String, dynamic> normalizeStringMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

/// Safe JSON decoding with error handling
Map<String, dynamic>? safeJsonDecode(String? jsonString) {
  if (jsonString == null) return null;
  try {
    return jsonDecode(jsonString) as Map<String, dynamic>?;
  } catch (e) {
    return null;
  }
}

/// Safe JSON encoding with error handling
String? safeJsonEncode(Object? object) {
  try {
    return jsonEncode(object);
  } catch (e) {
    return null;
  }
}
