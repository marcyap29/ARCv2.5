import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/utils/safe_json_utils.dart';
import 'dart:convert';

void main() {
  group('Safe JSON Utils', () {
    group('safeString', () {
      test('returns string when value is string', () {
        final map = {'key': 'value'};
        expect(safeString(map, 'key'), 'value');
      });

      test('returns null when value is not string', () {
        final map = {'key': 123};
        expect(safeString(map, 'key'), null);
      });

      test('returns null when key does not exist', () {
        final map = <String, dynamic>{};
        expect(safeString(map, 'key'), null);
      });

      test('returns null when map is null', () {
        expect(safeString(null, 'key'), null);
      });
    });

    group('safeInt', () {
      test('returns int when value is int', () {
        final map = {'key': 42};
        expect(safeInt(map, 'key'), 42);
      });

      test('returns null when value is not int', () {
        final map = {'key': 'not an int'};
        expect(safeInt(map, 'key'), null);
      });
    });

    group('safeBool', () {
      test('returns bool when value is bool', () {
        final map = {'key': true};
        expect(safeBool(map, 'key'), true);
      });

      test('returns null when value is not bool', () {
        final map = {'key': 'not a bool'};
        expect(safeBool(map, 'key'), null);
      });
    });

    group('safeList', () {
      test('returns list when value is list', () {
        final map = {'key': [1, 2, 3]};
        expect(safeList(map, 'key'), [1, 2, 3]);
      });

      test('returns null when value is not list', () {
        final map = {'key': 'not a list'};
        expect(safeList(map, 'key'), null);
      });
    });

    group('safeMap', () {
      test('returns map when value is map', () {
        final map = {'key': {'nested': 'value'}};
        expect(safeMap(map, 'key'), {'nested': 'value'});
      });

      test('returns null when value is not map', () {
        final map = {'key': 'not a map'};
        expect(safeMap(map, 'key'), null);
      });
    });

    group('safeField', () {
      test('returns value when type matches', () {
        final map = {'key': 'value'};
        expect(safeField(map, 'key', 'default'), 'value');
      });

      test('returns default when type does not match', () {
        final map = {'key': 123};
        expect(safeField(map, 'key', 'default'), 'default');
      });

      test('returns default when key does not exist', () {
        final map = <String, dynamic>{};
        expect(safeField(map, 'key', 'default'), 'default');
      });
    });

    group('normalizeStringMap', () {
      test('returns same map when already String-keyed', () {
        final input = {'key': 'value'};
        final result = normalizeStringMap(input);
        expect(result, input);
        expect(result, isA<Map<String, dynamic>>());
      });

      test('converts dynamic map to String-keyed map', () {
        final input = {1: 'value', 'key': 2};
        final result = normalizeStringMap(input);
        expect(result, {'1': 'value', 'key': 2});
        expect(result, isA<Map<String, dynamic>>());
      });

      test('returns empty map when input is not map', () {
        final result = normalizeStringMap('not a map');
        expect(result, <String, dynamic>{});
      });

      test('returns empty map when input is null', () {
        final result = normalizeStringMap(null);
        expect(result, <String, dynamic>{});
      });
    });

    group('safeJsonDecode', () {
      test('decodes valid JSON string', () {
        final jsonString = '{"key": "value"}';
        final result = safeJsonDecode(jsonString);
        expect(result, {'key': 'value'});
      });

      test('returns null for invalid JSON', () {
        final invalidJson = 'not valid json';
        final result = safeJsonDecode(invalidJson);
        expect(result, null);
      });

      test('returns null for null input', () {
        final result = safeJsonDecode(null);
        expect(result, null);
      });
    });

    group('safeJsonEncode', () {
      test('encodes valid object', () {
        final object = {'key': 'value'};
        final result = safeJsonEncode(object);
        expect(result, '{"key":"value"}');
      });

      test('returns null for invalid object', () {
        // Create an object that can't be JSON encoded
        final invalidObject = Object();
        final result = safeJsonEncode(invalidObject);
        expect(result, null);
      });

      test('returns null for null input', () {
        final result = safeJsonEncode(null);
        expect(result, 'null'); // jsonEncode(null) returns the string 'null'
      });
    });
  });
}
